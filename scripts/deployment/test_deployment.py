"""Filesystem integration tests: no production SSH, services, keys or game builds."""
import base64
import io
import json
import os
from pathlib import Path
import shutil
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

import local
from remote import (CONFIG, Host, RETENTION, digest, extract, read_json,
                    safe_remove, signed_release, write_json)


class FixtureHost(Host):
    def __init__(self, root):
        super().__init__(root)
        self.calls = []
        self.fail_restart = False
        self.fail_public = False
        self.fail_nginx = False
        self.fail_cleanup = False
        self.running = None

    def run(self, *args):
        self.calls.append(args)
        if args == ('systemctl', 'restart', 'purrimeter'):
            if self.fail_restart:
                self.fail_restart = False
                raise RuntimeError('injected restart failure')
            self.running = digest(self.current(self.relay) / 'purrimeter-relay')
        if args == ('nginx', '-t') and self.fail_nginx:
            self.fail_nginx = False
            raise RuntimeError('injected nginx failure')

    def running_relay_digest(self):
        return self.running

    def fetch(self, path):
        if self.fail_public and path == '/release.json':
            raise RuntimeError('injected public verification failure')
        if path == '/healthz':
            return b'ok\n'
        if path == '/updates':
            return (self.current(self.web) / 'game-release.json').read_bytes()
        return (self.current(self.web) / path.lstrip('/')).read_bytes()

    def public_hash(self, path):
        if path.startswith('/game-releases/'):
            return digest(self.web / path.lstrip('/'))
        return digest(self.current(self.web) / path.lstrip('/'))

    def cleanup(self, protected=None):
        if self.fail_cleanup:
            raise RuntimeError('injected cleanup failure')
        super().cleanup(protected)


def make_site(path, version, commit, sequence):
    path.mkdir(parents=True)
    (path / 'downloads').mkdir()
    (path / 'play').mkdir()
    (path / 'play/index.html').write_text('browser entry')
    (path / 'play/index.wasm').write_bytes(b'wasm')
    (path / 'index.html').write_text('home')
    game = {'id': f'{version}-{sequence}', 'version': version, 'sequence': sequence, 'packages': {}}
    for platform, name in [('macos', 'Purrimeter-macOS.zip'), ('windows', 'Purrimeter-Windows.zip'), ('web', 'Purrimeter-Web.zip')]:
        file = path / 'downloads' / name
        file.write_bytes((version + name).encode())
        game['packages'][platform] = {'url': f"https://purrimeter.graham.pub/game-releases/{game['id']}/{name}",
                                      'sha256': digest(file), 'size': file.stat().st_size}
    game['packages']['android'] = {'url': 'https://play.google.com/store/apps/details?id=com.roundhouselabsinc.purrimeter',
                                   'sha256': 'ab' * 32, 'size': 5, 'version_code': 2000000}
    (path / 'downloads/Purrimeter-Server.tar.gz').write_bytes(b'server archive')
    (path / 'downloads/SHA256SUMS.txt').write_text('checksums')
    write_json(path / 'game-release.json', {'payload': base64.b64encode(json.dumps(game).encode()).decode()})
    write_json(path / 'release.json', {'source_commit': commit, 'source_dirty': False,
                                      'files': {str(p.relative_to(path)): digest(p) for p in path.rglob('*') if p.is_file()}})


class DeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.host = FixtureHost(self.root)
        self.commit = 'a' * 40
        self.old_site = self.host.web / 'releases/20200101T000000Z-111111111111'
        self.old_relay = self.host.relay / 'releases/1234567'
        make_site(self.old_site, '1.0.0', 'b' * 40, 1)
        self.old_relay.mkdir(parents=True)
        (self.old_relay / 'purrimeter-relay').write_bytes(b'old relay')
        (self.host.web / 'current').symlink_to(self.old_site)
        (self.host.relay / 'current').symlink_to(self.old_relay)
        self.host.running = digest(self.old_relay / 'purrimeter-relay')
        self.host.dropin.parent.mkdir(parents=True)
        self.host.dropin.write_bytes(CONFIG)
        self.host.snippet.parent.mkdir(parents=True)
        self.host.snippet.write_text('old nginx')
        self.host.site_config.parent.mkdir(parents=True)
        self.host.site_config.write_text('include /etc/nginx/snippets/purrimeter-website.conf;')
        (self.root / 'var/lock').mkdir(parents=True)
        (self.host.web / 'game-releases').mkdir()
        self.build = self.root / 'build'
        self.build.mkdir()

    def bundle(self, relay=b'new relay', version='2.0.0'):
        stage = self.build / 'stage'
        if stage.exists():
            shutil.rmtree(stage)
        make_site(stage / 'public', version, self.commit, 2)
        (stage / 'relay').write_bytes(relay)
        (stage / 'nginx.conf').write_text('new nginx')
        archive = self.build / 'bundle.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            for name in ('public', 'relay', 'nginx.conf'):
                tar.add(stage / name, arcname=name)
        meta = {'id': f'{version}-{self.commit}', 'version': version, 'commit': self.commit,
                'site': '20260101T000000Z-222222222222', 'relay_sha256': digest(stage / 'relay'),
                'bundle_sha256': digest(archive), 'bundle_bytes': archive.stat().st_size, 'required_bytes': 1}
        return meta, archive.read_bytes()

    def deploy(self, meta, bundle):
        self.host.deploy(meta, io.BytesIO(bundle))

    def test_full_deployment_then_verified_noop(self):
        meta, bundle = self.bundle()
        self.deploy(meta, bundle)
        self.assertEqual(signed_release(self.host.web / 'current/game-release.json')['version'], '2.0.0')
        self.assertEqual(self.host.calls.count(('systemctl', 'restart', 'purrimeter')), 1)
        state = read_json(self.host.history / meta['id'] / 'state.json')
        self.assertIn('verified_at', state)
        self.assertFalse((self.host.history / meta['id'] / 'stage').exists())
        with patch.object(self.host, 'activate_site', side_effect=AssertionError('must not republish')):
            self.host.deploy(meta, io.BytesIO(b''))
        self.assertEqual(self.host.calls.count(('systemctl', 'restart', 'purrimeter')), 1)

    def test_unchanged_relay_does_not_restart(self):
        meta, bundle = self.bundle(b'old relay')
        self.deploy(meta, bundle)
        self.assertNotIn(('systemctl', 'restart', 'purrimeter'), self.host.calls)

    def test_service_config_change_requires_restart(self):
        meta, bundle = self.bundle(b'old relay')
        self.host.dropin.write_bytes(b'old configuration')
        self.deploy(meta, bundle)
        self.assertIn(('systemctl', 'restart', 'purrimeter'), self.host.calls)

    def test_interrupted_restart_is_detected_from_running_binary(self):
        meta, bundle = self.bundle(b'old relay')
        self.host.running = 'different running binary'
        self.deploy(meta, bundle)
        self.assertIn(('systemctl', 'restart', 'purrimeter'), self.host.calls)

    def test_failed_relay_restores_binary_and_config(self):
        meta, bundle = self.bundle()
        self.host.dropin.write_bytes(b'previous config')
        self.host.fail_restart = True
        with self.assertRaisesRegex(RuntimeError, 'restart failure'):
            self.deploy(meta, bundle)
        self.assertEqual(self.host.current(self.host.relay), self.old_relay)
        self.assertEqual(self.host.dropin.read_bytes(), b'previous config')
        self.assertEqual(self.host.current(self.host.web), self.old_site)
        self.deploy(meta, bundle)

    def test_nginx_failure_does_not_publish_clients(self):
        meta, bundle = self.bundle()
        self.host.fail_nginx = True
        with self.assertRaisesRegex(RuntimeError, 'nginx failure'):
            self.deploy(meta, bundle)
        self.assertEqual(self.host.current(self.host.web), self.old_site)
        self.assertEqual(self.host.snippet.read_text(), 'old nginx')
        self.deploy(meta, bundle)

    def test_post_publication_failure_never_downgrades_and_retry_verifies(self):
        meta, bundle = self.bundle()
        self.host.fail_public = True
        with self.assertRaisesRegex(RuntimeError, 'verification failure'):
            self.deploy(meta, bundle)
        self.assertEqual(self.host.current(self.host.web).name, meta['site'])
        self.host.fail_public = False
        self.deploy(meta, bundle)
        self.assertEqual(self.host.calls.count(('systemctl', 'restart', 'purrimeter')), 1)

    def test_cleanup_failure_is_distinct_and_retry_does_not_republish(self):
        meta, bundle = self.bundle()
        self.host.fail_cleanup = True
        with self.assertRaisesRegex(RuntimeError, 'Deployment succeeded; cleanup failed'):
            self.deploy(meta, bundle)
        self.host.fail_cleanup = False
        with patch.object(self.host, 'activate_site', side_effect=AssertionError('must not republish')):
            self.host.deploy(meta, io.BytesIO(b''))

    def test_interrupted_upload_and_tampered_retry(self):
        meta, bundle = self.bundle()
        with self.assertRaisesRegex(RuntimeError, 'Upload interrupted'):
            self.deploy(meta, bundle[:10])
        self.assertEqual(self.host.current(self.host.web), self.old_site)
        bad = dict(meta, bundle_sha256='0' * 64)
        with self.assertRaisesRegex(ValueError, 'exact original'):
            self.deploy(bad, bundle)
        self.deploy(meta, bundle)

    def test_reject_version_reuse_and_downgrade(self):
        meta, bundle = self.bundle(version='1.0.0')
        with self.assertRaisesRegex(ValueError, 'newer'):
            self.deploy(meta, bundle)

    def test_unfinished_version_cannot_be_reused_for_another_commit(self):
        meta, bundle = self.bundle()
        other = self.host.history / ('2.0.0-' + 'f' * 40)
        other.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, 'another source commit'):
            self.deploy(meta, bundle)

    def test_upload_checksum_failure_leaves_live_state_untouched(self):
        meta, bundle = self.bundle()
        with self.assertRaisesRegex(ValueError, 'Upload checksum mismatch'):
            self.deploy(meta, bytes([bundle[0] ^ 1]) + bundle[1:])
        self.assertEqual(self.host.current(self.host.web), self.old_site)
        self.assertNotIn(('systemctl', 'restart', 'purrimeter'), self.host.calls)

    def test_insufficient_space_cleans_but_never_relaxes_retention(self):
        meta, bundle = self.bundle()
        meta['required_bytes'] = 100
        usage = shutil._ntuple_diskusage(100, 100, 0)
        with patch('remote.shutil.disk_usage', return_value=usage), patch.object(self.host, 'cleanup') as cleanup:
            with self.assertRaisesRegex(RuntimeError, 'Insufficient disk'):
                self.deploy(meta, bundle)
            cleanup.assert_called_once()
        self.assertEqual(self.host.current(self.host.web), self.old_site)

    def test_legacy_cleanup_preserves_active_grace_and_backup_dependencies(self):
        old = time.time() - RETENTION * 2
        sites = []
        for i in range(8):
            name = f'2020010{i+2}T000000Z-{i:012x}'
            site = self.host.web / 'releases' / name
            make_site(site, f'0.0.{i}', self.commit, i+2)
            game = self.host.web / 'game-releases' / f'0.0.{i}-{i+2}'
            game.mkdir()
            os.utime(game, (old + i, old + i))
            os.utime(site, (old + i, old + i))
            sites.append(site)
        os.utime(self.old_site, (old, old))
        # A recent deployment and a retained recovery target are protected.
        os.utime(sites[0], None)
        backup = self.host.web / 'config-backups' / sites[-1].name
        backup.mkdir(parents=True)
        (backup / 'previous-release.txt').write_text(str(sites[1]))
        symlink = self.host.web / 'releases/20210101T000000Z-aaaaaaaaaaaa'
        symlink.symlink_to(self.build)
        self.host.cleanup()
        self.assertTrue(self.old_site.exists())
        self.assertTrue(sites[0].exists())
        self.assertTrue(sites[1].exists())
        self.assertFalse(sites[2].exists())
        self.assertFalse((self.host.web / 'game-releases/0.0.2-4').exists())
        self.assertTrue((self.host.web / 'game-releases/0.0.1-3').exists())
        self.assertTrue(symlink.is_symlink())
        self.assertTrue(self.build.exists())

    def test_lock_excludes_other_deployments(self):
        with self.host.locks():
            with self.assertRaises(BlockingIOError):
                with self.host.locks():
                    self.fail('second writer acquired lock')

    def test_cleanup_understands_legacy_unsigned_website_snapshots(self):
        legacy = self.host.web / 'releases/20201001T000000Z-ffffffffffff'
        legacy.mkdir()
        (legacy / 'index.html').write_text('pre-updater website')
        self.host.cleanup()
        self.assertTrue(legacy.exists())

    def test_archive_path_traversal_and_links_rejected(self):
        for name, kind in [('../outside', tarfile.REGTYPE), ('link', tarfile.SYMTYPE)]:
            path = self.build / 'bad.tar'
            with tarfile.open(path, 'w') as bundle:
                item = tarfile.TarInfo(name)
                item.type = kind
                item.linkname = '/etc/passwd'
                bundle.addfile(item)
            with self.assertRaisesRegex(ValueError, 'Unsafe archive'):
                extract(path, self.build / 'out')

    def test_frozen_local_artifacts_cannot_be_rebuilt_after_damage(self):
        record = self.build / 'local'
        record.mkdir()
        state = {'prepared': True, 'bundle_sha256': 'a' * 64}
        with self.assertRaisesRegex(ValueError, 'refusing to rebuild'):
            local.prepare(record, state, {})

    def test_play_publication_runs_once_per_prepared_release(self):
        record = self.build / 'release'
        record.mkdir()
        (record / 'Purrimeter.aab').write_bytes(b'bundle')
        state = {'version': '2.0.0', 'android_sha256': digest(record / 'Purrimeter.aab'), 'version_code': 2000000}
        calls = []

        class FakePublisher:
            def __init__(self, account, package):
                calls.append(('init', account, package))

            def publish(self, bundle, code, version, listing, track):
                calls.append(('publish', bundle.name, code, version, listing, track))
                return {'version_code': code, 'track': track, 'edit': 'e1'}

        state = local.publish_play(record, state, 'internal', {'client_email': 'svc'}, 'listing', publisher=FakePublisher)
        self.assertEqual(calls[1], ('publish', 'Purrimeter.aab', 2000000, '2.0.0', 'listing', 'internal'))
        self.assertEqual(calls[0][2], local.PLAY_PACKAGE)
        self.assertIn('committed_at', read_json(record / 'state.json')['play'])
        local.publish_play(record, state, 'production', {}, 'listing', publisher=FakePublisher)
        self.assertEqual(len(calls), 2, 'a committed release is never uploaded twice')
        (record / 'Purrimeter.aab').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'changed'):
            local.publish_play(record, {'version': '2.0.1', 'android_sha256': 'a' * 64, 'version_code': 2000100}, 'production', {}, 'listing', publisher=FakePublisher)
        self.assertEqual(len(calls), 2)

    def test_clean_source_gate_includes_untracked_files(self):
        with patch.object(local, 'output', return_value='?? untracked'):
            with self.assertRaisesRegex(ValueError, 'untracked'):
                local.source_commit()

    def test_local_cleanup_only_removes_owned_history(self):
        history = self.build / 'history'
        history.mkdir()
        unrelated = history / 'my-work'
        unrelated.mkdir()
        old = time.time() - RETENTION * 2
        records = []
        for i in range(6):
            record = history / f'1.0.{i}-{self.commit}'
            record.mkdir()
            write_json(record / 'state.json', {'verified_at': old+i})
            os.utime(record, (old+i, old+i))
            records.append(record)
        with patch.object(local, 'HISTORY', history):
            local.local_cleanup(records[0])
        self.assertTrue(records[0].exists())
        self.assertFalse(records[1].exists())
        self.assertTrue(records[-1].exists())
        self.assertTrue(unrelated.exists())


if __name__ == '__main__':
    unittest.main()
