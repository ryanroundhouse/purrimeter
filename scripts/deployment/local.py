"""Build, verify, deploy and clean up a complete Purrimeter release."""
import argparse
import base64
import fcntl
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tarfile
import time

from remote import DEPLOY_ID, RETENTION, digest, extract, read_json, retain, safe_remove, semver, write_json

ROOT = Path(__file__).resolve().parents[2]
TARGET = 'ryan@146.190.246.30'
HISTORY = ROOT / 'build/deployments'
SSH = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15',
       '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3', TARGET]


def output(*args, cwd=ROOT, env=None):
    return subprocess.check_output(args, cwd=cwd, env=env, text=True).strip()


def source_commit():
    if output('git', 'status', '--porcelain', '--untracked-files=all'):
        raise ValueError('Commit or remove working-tree changes before deploying (including untracked files).')
    return output('git', 'rev-parse', 'HEAD')


def prerequisites():
    if platform.system() != 'Darwin' or sys.version_info < (3, 11):
        raise ValueError('Run on macOS with Python 3.11 or newer')
    if not hasattr(tarfile, 'data_filter'):
        raise ValueError('Update Python: tar extraction filters are required')
    for command in ('git', 'ssh', 'node', 'lipo', 'codesign', 'ditto', 'zip', 'rg'):
        if not shutil.which(command):
            raise ValueError(f'Missing prerequisite: {command}')
    godot = Path(os.environ.get('GODOT', ROOT / '.tools/Godot.app/Contents/MacOS/Godot')).resolve()
    go = os.environ.get('GO_BIN') or str(ROOT / '.tools/go/bin/go')
    if not Path(go).is_file():
        go = shutil.which(go) or shutil.which('go') or ''
    if not go or not godot.is_file():
        raise ValueError('Install Go and run scripts/setup_godot.sh before deployment')
    if not output(str(godot), '--headless', '--version').startswith('4.7.2.'):
        raise ValueError('Godot 4.7.2 is required')
    for name in ('macos.zip', 'windows_release_x86_64.exe', 'web_nothreads_release.zip'):
        if not (ROOT / '.tools/templates' / name).is_file():
            raise ValueError(f'Missing export template: {name}; run scripts/setup_godot.sh')
    key = Path(os.environ.get('PURRIMETER_RELEASE_KEY', '~/.config/purrimeter/release-signing.key')).expanduser().resolve()
    if not key.is_file() or stat.S_IMODE(key.stat().st_mode) & 0o077:
        raise ValueError('Release signing key must exist with owner-only permissions')
    raw = key.read_bytes()
    public = base64.b64decode((ROOT / 'server/internal/releases/public.key').read_text().strip())
    if len(raw) != 64 or raw[32:] != public:
        raise ValueError('Release signing key does not match the official public key')
    # Resolve the dependency once, so isolated source builds use the same module.
    dependency = os.environ.get('PLAYWRIGHT_MODULE')
    if not dependency:
        installed = ROOT / '.tools/deploy/node_modules/playwright'
        dependency = str(installed) if installed.exists() else 'playwright'
    try:
        playwright = output('node', '-e', "process.stdout.write(require.resolve(process.argv[1]))", dependency)
    except subprocess.CalledProcessError as error:
        raise ValueError('Install Playwright: npm install --prefix .tools/deploy playwright@1.63.0; then .tools/deploy/node_modules/.bin/playwright install chromium. Or set PLAYWRIGHT_MODULE.') from error
    executable = output('node', '-e', "process.stdout.write(require(process.argv[1]).chromium.executablePath())", playwright)
    if not Path(executable).is_file():
        raise ValueError('Install the Playwright Chromium browser before deploying')
    return {**os.environ, 'GODOT': str(godot), 'GO_BIN': str(Path(go).resolve()),
            'PURRIMETER_RELEASE_KEY': str(key), 'PLAYWRIGHT_MODULE': playwright,
            # Commit provenance belongs in the publication manifest. Embedding
            # unrelated repository commits would restart an unchanged relay.
            'GOFLAGS': os.environ.get('GOFLAGS', '') + ' -buildvcs=false'}


def remote_command(action, meta=None):
    code = (ROOT / 'scripts/deployment/remote.py').read_bytes()
    program = 'import base64; exec(compile(base64.b64decode(' + repr(base64.b64encode(code).decode()) + "), '<deployment>', 'exec'))"
    args = ['sudo', '-n', 'python3', '-c', program, action]
    if meta is not None:
        args.append(json.dumps(meta, separators=(',', ':')))
    return [*SSH, shlex.join(args)]


def inspect_remote():
    try:
        return json.loads(output(*remote_command('inspect')))
    except subprocess.CalledProcessError as error:
        raise RuntimeError('VM preflight failed; see SSH diagnostics above') from error


def local_cleanup(protected):
    if not HISTORY.exists():
        return
    records = [p for p in HISTORY.iterdir() if p.is_dir() and not p.is_symlink()
               and re.fullmatch(DEPLOY_ID, p.name) and (p / 'state.json').is_file()]
    successful = [p for p in records if read_json(p / 'state.json').get('verified_at')]
    keep = retain(successful, [protected]) | {p for p in records if time.time() - p.stat().st_mtime < RETENTION}
    for record in records:
        if record not in keep:
            print(f'Local cleanup: {record}', flush=True)
            safe_remove(record, HISTORY, DEPLOY_ID)


def run_logged(command, source, env, log):
    print('+ ' + shlex.join(command), flush=True)
    with log.open('a') as transcript:
        transcript.write('\n+ ' + shlex.join(command) + '\n')
        transcript.flush()
        process = subprocess.Popen(command, cwd=source, env=env, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        script_error = False
        for line in process.stdout:
            transcript.write(line)
            print(line, end='', flush=True)
            if any(marker in line for marker in ('SCRIPT ERROR:', 'Parse Error:', 'Compile Error:')):
                script_error = True
        status = process.wait()
        if status or script_error:
            raise RuntimeError(f'Check/build failed: {shlex.join(command)}; see {log}')


def prepare(record, state, env):
    archive = record / 'bundle.tar.gz'
    if state.get('prepared'):
        if not archive.is_file() or digest(archive) != state['bundle_sha256']:
            raise ValueError('Prepared artifacts are missing or changed; refusing to rebuild an immutable release')
        print('Reusing exact prepared artifacts.', flush=True)
        return state
    source = record / 'source'
    if source.exists():
        shutil.rmtree(source)
    source.mkdir()
    source_tar = record / 'source.tar'
    with source_tar.open('wb') as stream:
        subprocess.run(['git', 'archive', state['commit']], cwd=ROOT, stdout=stream, check=True)
    extract(source_tar, source)
    source_tar.unlink()
    (source / '.tools').symlink_to(ROOT / '.tools', target_is_directory=True)
    commands = [
        ['./scripts/test.sh'],
        ['./scripts/test_multiplayer.sh'],
        ['./scripts/build_release.py', state['version']],
        ['./scripts/build_server.sh'],
        [sys.executable, 'scripts/package_website.py', '--source-commit', state['commit']],
        ['node', 'scripts/test_browser_release.cjs'],
    ]
    for command in commands:
        run_logged(command, source, env, record / 'build.log')
    site = source / 'build/website'
    website_id = (source / 'build/website-release.txt').read_text().strip()
    relay = source / 'dist/server/purrimeter-relay-linux-amd64'
    # freeze source/tool outputs into a single retryable transport artifact
    with tarfile.open(archive, 'w:gz') as bundle:
        bundle.add(site, arcname='public')
        bundle.add(relay, arcname='relay')
        bundle.add(source / 'website/deploy/nginx.conf', arcname='nginx.conf')
    expanded = sum(p.stat().st_size for p in site.rglob('*') if p.is_file())
    state.update(prepared=True, site=website_id, relay_sha256=digest(relay),
                 bundle_sha256=digest(archive), bundle_bytes=archive.stat().st_size,
                 # uploaded tar + extraction + site + immutable game tree + margin
                 required_bytes=archive.stat().st_size + 3 * expanded + 256 * 1024 * 1024)
    write_json(record / 'state.json', state)
    return state


def validate_version(version, live, state):
    if HISTORY.exists():
        for other in HISTORY.iterdir():
            if (other.is_dir() and not other.is_symlink() and re.fullmatch(DEPLOY_ID, other.name)
                    and other.name.startswith(version + '-') and other.name != state['id']):
                raise ValueError('This version belongs to another source commit; choose a newer version')
    comparison = semver(version), semver(live['game']['version'])
    if comparison[0] < comparison[1] or (comparison[0] == comparison[1] and not state.get('prepared')):
        raise ValueError('Use a version newer than production, or resume its exact prepared deployment')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version', help='Explicit MAJOR.MINOR.PATCH release version')
    parser.add_argument('--preview', action='store_true', help='Read-only preflight and deployment plan')
    args = parser.parse_args()
    semver(args.version)
    commit = source_commit()
    env = prerequisites()
    record = HISTORY / f'{args.version}-{commit}'
    state = read_json(record / 'state.json') if (record / 'state.json').exists() else {
        'id': record.name, 'commit': commit, 'version': args.version, 'created_at': time.time()}
    live = inspect_remote()
    validate_version(args.version, live, state)
    print(f"Source: {commit}\nTarget: {TARGET}\nLive game: {live['game']['id']}\nRequested version: {args.version}", flush=True)
    if args.preview:
        if state.get('prepared'):
            restart = (state['relay_sha256'] != live['relay_sha256']
                       or state['relay_sha256'] != live['running_relay_sha256'] or not live['config_matches'])
            print(f"Prepared artifacts available; relay restart: {'yes' if restart else 'no'}")
        else:
            print('Build/test/sign all clients, updaters, server and website. Restart relay only if built bytes or service configuration differ.')
        print(f"VM free space: {live['free_bytes'] / 1024**3:.2f} GiB. Exact required space is calculated after packaging.")
        print('Upload, verify relay, activate site/clients, verify public hashes, clean up. No changes made.')
        print('Eligible remote cleanup:\n' + ('\n'.join(live['cleanup']) or '(none)'))
        return
    HISTORY.mkdir(parents=True, exist_ok=True)
    with (HISTORY / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        # Reload under the lock: another local deployment may have just finished.
        state = read_json(record / 'state.json') if (record / 'state.json').exists() else state
        record.mkdir(exist_ok=True)
        write_json(record / 'state.json', state)
        local_cleanup(record)
        state = prepare(record, state, env)
        with (record / 'bundle.tar.gz').open('rb') as stream:
            status = subprocess.run(remote_command('deploy', state), stdin=stream).returncode
        if status:
            raise RuntimeError(f'Remote deployment or cleanup failed. Retry the same command; artifacts and log: {record}')
        state['verified_at'] = time.time()
        write_json(record / 'state.json', state)
        try:
            local_cleanup(record)
        except Exception as error:
            raise RuntimeError(f'Deployment succeeded; cleanup failed locally: {error}') from error
        print(f'Deployed {args.version} from {commit}. Logs and retry artifacts: {record}', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print(f'Deployment stopped: {error}', file=sys.stderr)
        sys.exit(1)
