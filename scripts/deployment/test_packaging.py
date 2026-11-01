"""Exercise real archive/website packaging with small synthetic signed packages."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location('package_website', Path(__file__).parents[1] / 'package_website.py')
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dist = self.root / 'dist'
        self.dist.mkdir()
        (self.root / 'build/website').mkdir(parents=True)
        self.website = self.root / 'website'
        (self.website / 'assets').mkdir(parents=True)
        (self.website / 'deploy').mkdir()
        for name in ('index.html', 'style.css', 'download.js'):
            (self.website / name).write_text(name)
        (self.dist / 'game-release.json').write_text('signed envelope')
        self.game = {'id': '2.0.0-2', 'sequence': 2, 'version': '2.0.0', 'packages': {}}
        files = {
            'macos': ('Purrimeter-macOS.zip', ['macos/Purrimeter.app/Contents/MacOS/Purrimeter'], 'macos/game-build.json'),
            'windows': ('Purrimeter-Windows.zip', ['Purrimeter.exe', 'Purrimeter.pck'], 'game-build.json'),
            'web': ('Purrimeter-Web.zip', ['index.html', 'index.js', 'index.wasm', 'index.pck', 'config.js', 'browser.js', 'browser.css'], 'game-build.json'),
        }
        for platform, (name, names, stamp) in files.items():
            archive = self.dist / name
            with zipfile.ZipFile(archive, 'w') as bundle:
                for file in names:
                    bundle.writestr(file, '<script src="config.js"></script>' if file == 'index.html' else '"index"')
                bundle.writestr(stamp, json.dumps({'id': '2.0.0-2', 'sequence': 2}))
            self.game['packages'][platform] = {'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(), 'size': archive.stat().st_size}
        with tarfile.open(self.dist / 'Purrimeter-Server.tar.gz', 'w:gz') as archive:
            for name in ('server/purrimeter-relay-linux-amd64', 'server/purrimeter-relay-linux-arm64', 'server/README.md'):
                archive.addfile(tarfile.TarInfo(name))

    def package(self):
        with patch.object(packager, 'ROOT', self.root), patch.object(packager.subprocess, 'run'), patch.object(packager.subprocess, 'check_output', return_value=json.dumps(self.game)):
            packager.package('a' * 40)

    def test_server_download_and_checksums_ship_with_source_provenance(self):
        self.package()
        site = self.root / 'build/website'
        self.assertEqual((site / 'downloads/Purrimeter-Server.tar.gz').read_bytes(), (self.dist / 'Purrimeter-Server.tar.gz').read_bytes())
        self.assertIn('Purrimeter-Server.tar.gz', (site / 'downloads/SHA256SUMS.txt').read_text())
        manifest = json.loads((site / 'release.json').read_text())
        self.assertEqual(manifest['source_commit'], 'a' * 40)
        self.assertFalse(manifest['source_dirty'])
        self.assertIn('downloads/Purrimeter-Server.tar.gz', manifest['files'])
        self.assertIn('/game-releases/2.0.0-2/web/config.js', (site / 'play/index.html').read_text())

    def test_missing_server_archive_fails_before_replacing_preview(self):
        sentinel = self.root / 'build/website/sentinel'
        sentinel.write_text('previous preview')
        (self.dist / 'Purrimeter-Server.tar.gz').unlink()
        with self.assertRaisesRegex(ValueError, 'build_server.sh'):
            self.package()
        self.assertTrue(sentinel.exists())

    def test_changed_client_archive_is_rejected(self):
        with (self.dist / 'Purrimeter-Web.zip').open('ab') as stream:
            stream.write(b'changed')
        with self.assertRaisesRegex(ValueError, 'does not match signed'):
            self.package()


if __name__ == '__main__':
    unittest.main()
