"""Production deployment transaction. Sent over SSH; only uses Python's stdlib.

All mutations run under the orchestration and legacy publisher locks. Paths are
explicit so tests can exercise real filesystem transitions in an isolated root.
"""
import base64
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request

RETENTION = 7 * 24 * 3600
SITE_ID = r"\d{8}T\d{6}Z-[a-f0-9]{12}"
GAME_ID = r"\d+\.\d+\.\d+-\d+"
RELAY_ID = r"(?:updates-)?[a-f0-9]{7,64}"
DEPLOY_ID = r"\d+\.\d+\.\d+-[a-f0-9]{40}"
PLAY_LISTING = 'https://play.google.com/store/apps/details?id=com.roundhouselabsinc.purrimeter'
CONFIG = b"[Service]\nEnvironment=GAME_RELEASE_FILE=/var/www/purrimeter/current/game-release.json\n"


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text())


def write_json(path, value):
    path = Path(path)
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(json.dumps(value, indent=2) + '\n')
    os.replace(tmp, path)


def signed_release(path):
    # Signature verification is performed by the built release tool and relay.
    return json.loads(base64.b64decode(read_json(path)['payload'], validate=True))


def semver(value):
    if not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', value):
        raise ValueError('Version must be MAJOR.MINOR.PATCH without leading zeroes')
    return tuple(map(int, value.split('.')))


def directories(root, pattern):
    if not root.exists():
        return []
    return [p for p in root.iterdir() if not p.is_symlink() and p.is_dir()
            and re.fullmatch(pattern, p.name)]


def retain(paths, active=(), now=None):
    now = time.time() if now is None else now
    ordered = sorted(paths, key=lambda p: p.stat().st_mtime, reverse=True)
    return set(active) | set(ordered[:3]) | {p for p in ordered if now - p.stat().st_mtime < RETENTION}


def safe_remove(path, root, pattern):
    if path.parent != root or not re.fullmatch(pattern, path.name) or path.is_symlink():
        raise ValueError(f'Unsafe cleanup candidate: {path}')
    if path.exists():
        shutil.rmtree(path)


def extract(archive, destination):
    with tarfile.open(archive) as bundle:
        entries = bundle.getmembers()
        for entry in entries:
            parts = Path(entry.name).parts
            if (Path(entry.name).is_absolute() or '..' in parts or not parts
                    or not (entry.isfile() or entry.isdir())):
                raise ValueError(f'Unsafe archive entry: {entry.name}')
        bundle.extractall(destination, members=entries, filter='data')


def atomic_link(target, link):
    temp = link.with_name(link.name + '.deploy-next')
    temp.unlink(missing_ok=True)
    temp.symlink_to(target)
    os.replace(temp, link)


def install_file(source, target, mode=0o644):
    if target.exists():
        if digest(source) != digest(target):
            raise ValueError(f'Cannot overwrite immutable bytes: {target}')
        target.chmod(mode)
        return
    temp = target.with_name('.' + target.name + '.deploy-copy')
    shutil.copyfile(source, temp)
    temp.chmod(mode)
    os.replace(temp, target)


class Host:
    def __init__(self, root=Path('/'), origin='https://purrimeter.graham.pub'):
        self.root = root
        self.web = root / 'var/www/purrimeter'
        self.relay = root / 'opt/purrimeter'
        self.history = self.web / 'deployments'
        self.dropin = root / 'etc/systemd/system/purrimeter.service.d/game-release.conf'
        self.snippet = root / 'etc/nginx/snippets/purrimeter-website.conf'
        self.site_config = root / 'etc/nginx/sites-available/purrimeter.graham.pub'
        self.origin = origin

    def run(self, *args):
        subprocess.run(args, check=True)

    def fetch(self, path):
        with urllib.request.urlopen(self.origin + path, timeout=60) as response:
            return response.read()

    def public_hash(self, path):
        with urllib.request.urlopen(self.origin + path, timeout=120) as response:
            return hashlib.file_digest(response, 'sha256').hexdigest()

    def current(self, root):
        path = (root / 'current').resolve(strict=True)
        if path.parent != root / 'releases':
            raise ValueError(f'Unexpected current release target: {path}')
        return path

    def running_relay_digest(self):
        pid = subprocess.check_output(['systemctl', 'show', '-p', 'MainPID', '--value', 'purrimeter'], text=True).strip()
        executable = self.root / f'proc/{pid}/exe'
        return digest(executable) if pid.isdigit() and pid != '0' and executable.exists() else None

    def inspect(self):
        if not hasattr(tarfile, 'data_filter'):
            raise RuntimeError('Update Python: tar extraction filters are required')
        site, relay = self.current(self.web), self.current(self.relay)
        # Check existing-host prerequisites without changing files or services.
        self.run('nginx', '-t')
        return {'game': signed_release(site / 'game-release.json'),
                'site': site.name, 'relay': relay.name,
                'relay_sha256': digest(relay / 'purrimeter-relay'),
                'running_relay_sha256': self.running_relay_digest(),
                'config_matches': self.dropin.exists() and self.dropin.read_bytes() == CONFIG,
                'source_commit': read_json(site / 'release.json').get('source_commit'),
                'free_bytes': shutil.disk_usage(self.web).free}

    @contextlib.contextmanager
    def locks(self):
        with contextlib.ExitStack() as stack:
            for name in ('purrimeter-deployment', 'purrimeter-relay', 'purrimeter-website'):
                lock = stack.enter_context((self.root / f'var/lock/{name}.lock').open('a'))
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            yield

    def cleanup_plan(self, protected=None):
        sites = directories(self.web / 'releases', SITE_ID)
        relays = directories(self.relay / 'releases', RELAY_ID)
        games = directories(self.web / 'game-releases', GAME_ID)
        backups = directories(self.web / 'config-backups', SITE_ID)
        records = directories(self.history, DEPLOY_ID)
        keep_sites = retain(sites, [self.current(self.web)])
        keep_relays = retain(relays, [self.current(self.relay)])
        successful = [p for p in records if (p / 'state.json').exists()
                      and read_json(p / 'state.json').get('verified_at')]
        keep_records = retain(successful) | {p for p in records if time.time() - p.stat().st_mtime < RETENTION}
        if protected:
            keep_records.add(protected)
        for record in keep_records:
            if not (record / 'state.json').exists():
                continue
            state = read_json(record / 'state.json')
            for name in ('site', 'previous_site'):
                if state.get(name):
                    keep_sites.add(self.web / 'releases' / state[name])
            for name in ('relay', 'previous_relay'):
                if state.get(name):
                    keep_relays.add(self.relay / 'releases' / state[name])
        keep_backups = {p for p in backups if p.name in {s.name for s in keep_sites}
                        or time.time() - p.stat().st_mtime < RETENTION}
        # Keep the direct recovery target of each retained backup, not an
        # unbounded chain of every backup ever made.
        for backup in keep_backups:
            previous = backup / 'previous-release.txt'
            if previous.exists() and previous.read_text().strip():
                path = Path(previous.read_text().strip())
                if path.parent != self.web / 'releases' or not re.fullmatch(SITE_ID, path.name):
                    raise ValueError(f'Unsafe backup reference: {previous}')
                keep_sites.add(path)
        keep_games = retain(games)
        for site in keep_sites:
            if not site.exists():
                raise ValueError(f'Missing retained website: {site}')
            # The first website snapshots predate signed game releases and
            # contain only their own downloads, with no immutable-store links.
            if not (site / 'game-release.json').exists():
                continue
            game_id = signed_release(site / 'game-release.json')['id']
            if not re.fullmatch(GAME_ID, game_id):
                raise ValueError('Invalid retained game identity')
            keep_games.add(self.web / 'game-releases' / game_id)
        groups = [(sites, keep_sites, self.web / 'releases', SITE_ID),
                  (backups, keep_backups, self.web / 'config-backups', SITE_ID),
                  (games, keep_games, self.web / 'game-releases', GAME_ID),
                  (relays, keep_relays, self.relay / 'releases', RELAY_ID),
                  (records, keep_records, self.history, DEPLOY_ID)]
        return [(p, root, pattern) for paths, keep, root, pattern in groups for p in paths if p not in keep]

    def cleanup(self, protected=None):
        for path, root, pattern in self.cleanup_plan(protected):
            print(f'Cleanup: {path}', flush=True)
            safe_remove(path, root, pattern)

    def check_version(self, meta, record):
        active = signed_release(self.current(self.web) / 'game-release.json')
        for other in directories(self.history, DEPLOY_ID):
            if other != record and other.name.startswith(meta['version'] + '-'):
                raise ValueError('This version belongs to another source commit; choose a newer version')
        if record.exists() and (record / 'state.json').exists():
            state = read_json(record / 'state.json')
            if state['bundle_sha256'] != meta['bundle_sha256']:
                raise ValueError('Retry requires the exact original prepared artifacts')
            if semver(meta['version']) < semver(active['version']):
                raise ValueError('This deployment has been superseded; refusing to downgrade')
            return state
        if semver(meta['version']) <= semver(active['version']):
            raise ValueError('New deployment version must be newer than the live version')
        return dict(meta)

    def verify_site(self, site, meta):
        manifest = read_json(site / 'release.json')
        if manifest['source_commit'] != meta['commit'] or manifest['source_dirty']:
            raise ValueError('Website provenance does not match the committed source')
        for name, checksum in manifest['files'].items():
            file = site / name
            if not file.resolve().is_relative_to(site.resolve()) or file.is_symlink() or digest(file) != checksum:
                raise ValueError(f'Uploaded file checksum mismatch: {name}')
        game = signed_release(site / 'game-release.json')
        if game['version'] != meta['version'] or not re.fullmatch(GAME_ID, game['id']):
            raise ValueError('Unexpected game release identity')
        for platform, package in game['packages'].items():
            if platform in ('android', 'ios'):
                # Stores host mobile packages; the manifest records their exact digests.
                expected_url = PLAY_LISTING if platform == 'android' else 'https://apps.apple.com/app/id6831635489'
                if package['url'] != expected_url or not re.fullmatch(r'[a-f0-9]{64}', package['sha256']) or package['size'] <= 0:
                    raise ValueError('Unexpected mobile package metadata')
                continue
            names = {'macos': 'Purrimeter-macOS.zip', 'windows': 'Purrimeter-Windows.zip', 'web': 'Purrimeter-Web.zip'}
            name = names[platform]
            file = site / 'downloads' / name
            if package['url'] != f"{self.origin}/game-releases/{game['id']}/{name}":
                raise ValueError('Unexpected immutable package URL')
            if digest(file) != package['sha256'] or file.stat().st_size != package['size']:
                raise ValueError('Signed package checksum mismatch')
        if set(game['packages']) != {'macos', 'windows', 'web', 'android', 'ios'}:
            raise ValueError('All five game platforms are required')
        if 'downloads/Purrimeter-Server.tar.gz' not in manifest['files']:
            raise ValueError('Self-hosting server download is required')
        return game

    def install_tree(self, source, target):
        if target.exists():
            # Interrupted installs are recoverable, but immutable bytes may not change.
            for file in source.rglob('*'):
                if file.is_file():
                    existing = target / file.relative_to(source)
                    if existing.exists() and digest(existing) != digest(file):
                        raise ValueError(f'Cannot overwrite immutable bytes: {existing}')
        target.mkdir(parents=True, exist_ok=True)
        for file in source.rglob('*'):
            existing = target / file.relative_to(source)
            if file.is_dir():
                existing.mkdir(parents=True, exist_ok=True)
                existing.chmod(0o755)
            else:
                existing.parent.mkdir(parents=True, exist_ok=True)
                install_file(file, existing)
        target.chmod(0o755)

    def verify_relay(self, expected):
        self.run('systemctl', 'is-active', '--quiet', 'purrimeter')
        for attempt in range(30):
            try:
                if self.fetch('/updates') == expected and self.fetch('/healthz').strip() == b'ok':
                    return
            except OSError:
                pass
            time.sleep(0.2)
        raise RuntimeError('Relay health or release metadata did not match')

    def activate_relay(self, stage, state, record):
        desired = stage / 'relay'
        relay_id = 'updates-' + digest(desired)[:12]
        previous = self.current(self.relay)
        changed = (digest(previous / 'purrimeter-relay') != digest(desired)
                   or self.running_relay_digest() != digest(desired)
                   or not self.dropin.exists() or self.dropin.read_bytes() != CONFIG)
        state['relay'] = relay_id if changed else previous.name
        state.setdefault('previous_relay', previous.name)
        write_json(record / 'state.json', state)
        if not changed:
            print('Relay unchanged; no restart.', flush=True)
            return
        target = self.relay / 'releases' / relay_id
        target.mkdir(exist_ok=True)
        binary = target / 'purrimeter-relay'
        if binary.exists() and digest(binary) != digest(desired):
            raise ValueError('Relay identity collision')
        install_file(desired, binary, 0o755)
        old_config = self.dropin.read_bytes() if self.dropin.exists() else None
        self.dropin.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.dropin.write_bytes(CONFIG)
            atomic_link(target, self.relay / 'current')
            self.run('systemctl', 'daemon-reload')
            self.run('systemctl', 'restart', 'purrimeter')
            self.verify_relay((self.web / 'current/game-release.json').read_bytes())
            os.utime(target, None)
        except BaseException:
            atomic_link(previous, self.relay / 'current')
            if old_config is None:
                self.dropin.unlink(missing_ok=True)
            else:
                self.dropin.write_bytes(old_config)
            self.run('systemctl', 'daemon-reload')
            self.run('systemctl', 'restart', 'purrimeter')
            raise

    def activate_site(self, stage, state, record):
        site = stage / 'public'
        game = self.verify_site(site, state)
        active = signed_release(self.current(self.web) / 'game-release.json')
        if game['id'] != active['id'] and game['sequence'] <= active['sequence']:
            raise ValueError('New game release sequence must exceed the live sequence; check the publishing Mac clock')
        destination = self.web / 'releases' / state['site']
        self.install_tree(site, destination)
        immutable = self.web / 'game-releases' / game['id']
        immutable.mkdir(parents=True, exist_ok=True)
        # Validate every existing immutable file before any copy.
        sources = {name: file for name, file in [
            *[(Path(p['url']).name, site / 'downloads' / Path(p['url']).name) for k, p in game['packages'].items() if k not in ('android', 'ios')],
            ('release.json', site / 'game-release.json')]}
        for name, source in sources.items():
            target = immutable / name
            if target.exists() and digest(target) != digest(source):
                raise ValueError('Cannot overwrite immutable game package')
        self.install_tree(site / 'play', immutable / 'web')
        for name, source in sources.items():
            install_file(source, immutable / name)
        backup = self.web / 'config-backups' / state['site']
        backup.mkdir(parents=True, exist_ok=True)
        if not (backup / 'site.conf').exists():
            shutil.copy2(self.site_config, backup / 'site.conf')
            if self.snippet.exists():
                shutil.copy2(self.snippet, backup / 'snippet.conf')
            (backup / 'previous-release.txt').write_text(str(self.current(self.web)) + '\n')
        state.setdefault('previous_site', self.current(self.web).name)
        write_json(record / 'state.json', state)
        include = 'include /etc/nginx/snippets/purrimeter-website.conf;'
        if include not in self.site_config.read_text():
            raise ValueError('Existing production nginx include is required')
        self.snippet.parent.mkdir(parents=True, exist_ok=True)
        previous_snippet = self.snippet.read_bytes() if self.snippet.exists() else None
        try:
            shutil.copy2(stage / 'nginx.conf', self.snippet)
            self.run('nginx', '-t')
            self.run('systemctl', 'reload', 'nginx')
        except BaseException:
            if previous_snippet is None:
                self.snippet.unlink(missing_ok=True)
            else:
                self.snippet.write_bytes(previous_snippet)
            self.run('nginx', '-t')
            self.run('systemctl', 'reload', 'nginx')
            raise
        # Once this pointer moves, clients can upgrade. Never automatically move
        # it backwards, even if verification/SSH fails immediately afterwards.
        state['publication_started'] = True
        write_json(record / 'state.json', state)
        atomic_link(destination, self.web / 'current')
        os.utime(destination, None)
        os.utime(immutable, None)

    def verify_public(self, state):
        site = self.current(self.web)
        if site.name != state['site']:
            raise RuntimeError('Production points at a different website release')
        relay = self.current(self.relay) / 'purrimeter-relay'
        if digest(relay) != state['relay_sha256'] or self.dropin.read_bytes() != CONFIG:
            raise RuntimeError('Production relay differs from the prepared deployment')
        if self.running_relay_digest() != state['relay_sha256']:
            raise RuntimeError('Running relay differs from the prepared deployment')
        self.verify_relay((site / 'game-release.json').read_bytes())
        if self.fetch('/release.json') != (site / 'release.json').read_bytes():
            raise RuntimeError('Public website manifest differs')
        for name, expected in read_json(site / 'release.json')['files'].items():
            if name.startswith('downloads/') or name in ('play/index.html', 'game-release.json'):
                if self.public_hash('/' + name) != expected:
                    raise RuntimeError(f'Public checksum mismatch: {name}')
        game = signed_release(site / 'game-release.json')
        for name, expected in read_json(site / 'release.json')['files'].items():
            if name.startswith('play/'):
                path = f"/game-releases/{game['id']}/web/{name[5:]}"
                if self.public_hash(path) != expected:
                    raise RuntimeError(f'Immutable browser asset differs: {name}')
        for platform, package in game['packages'].items():
            if platform in ('android', 'ios'):
                continue
            prefix = self.origin + '/'
            if not package['url'].startswith(prefix):
                raise ValueError('Unexpected package origin')
            if self.public_hash(package['url'][len(self.origin):]) != package['sha256']:
                raise RuntimeError('Immutable public download differs')

    def deploy(self, meta, stream):
        if not re.fullmatch(DEPLOY_ID, meta['id']) or meta['id'] != f"{meta['version']}-{meta['commit']}":
            raise ValueError('Invalid deployment identity')
        if not re.fullmatch(SITE_ID, meta['site']):
            raise ValueError('Invalid website release identity')
        record = self.history / meta['id']
        with self.locks():
            state = self.check_version(meta, record)
            if state.get('verified_at'):
                self.verify_public(state)
                self.finish_cleanup(record)
                print('Already deployed; verified production and completed cleanup.', flush=True)
                return
            self.history.mkdir(parents=True, exist_ok=True)
            record.mkdir(exist_ok=True)
            write_json(record / 'state.json', state)
            if shutil.disk_usage(self.web).free < meta['required_bytes']:
                self.cleanup(record)
                if shutil.disk_usage(self.web).free < meta['required_bytes']:
                    raise RuntimeError('Insufficient disk space after retention-safe cleanup')
            archive = record / 'bundle.tar.gz'
            print(f"Receiving {meta['bundle_bytes'] / 1024**2:.1f} MiB deployment bundle...", flush=True)
            with archive.open('wb') as output:
                remaining = meta['bundle_bytes']
                while remaining:
                    block = stream.read(min(1024 * 1024, remaining))
                    if not block:
                        raise RuntimeError('Upload interrupted; rerun with the same version')
                    output.write(block)
                    remaining -= len(block)
            if digest(archive) != meta['bundle_sha256']:
                raise ValueError('Upload checksum mismatch')
            stage = record / 'stage'
            if stage.exists():
                shutil.rmtree(stage)
            stage.mkdir()
            extract(archive, stage)
            self.verify_site(stage / 'public', state)
            if digest(stage / 'relay') != state['relay_sha256']:
                raise ValueError('Uploaded relay checksum mismatch')
            self.activate_relay(stage, state, record)
            self.activate_site(stage, state, record)
            self.verify_public(state)
            state['verified_at'] = time.time()
            write_json(record / 'state.json', state)
            print('Deployment succeeded and public downloads verified.', flush=True)
            self.finish_cleanup(record)

    def finish_cleanup(self, record):
        try:
            (record / 'bundle.tar.gz').unlink(missing_ok=True)
            if (record / 'stage').exists():
                shutil.rmtree(record / 'stage')
            self.cleanup(record)
        except Exception as error:
            raise RuntimeError(f'Deployment succeeded; cleanup failed: {error}') from error


def main():
    host = Host()
    action = sys.argv[1]
    if action == 'inspect':
        state = host.inspect()
        state['cleanup'] = [str(p) for p, _, _ in host.cleanup_plan()]
        print(json.dumps(state))
    elif action == 'deploy':
        host.deploy(json.loads(sys.argv[2]), sys.stdin.buffer)
    else:
        raise ValueError('Unknown remote action')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Deployment error: {error}', file=sys.stderr)
        sys.exit(1)
