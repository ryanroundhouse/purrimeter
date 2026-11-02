"""Play publication tests: scripted HTTP transport, real RSA signing, no network."""
import base64
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import play


def make_listing(root, phones=3):
    (root / 'images/phone').mkdir(parents=True)
    (root / 'images/tablet7').mkdir()
    (root / 'listing.json').write_text(json.dumps({
        'title': 'Purrimeter — The Garden Guard', 'shortDescription': 'Cats defend the garden.',
        'fullDescription': 'Long text.', 'contactEmail': 'ryan@example.com', 'contactWebsite': 'https://example.com/'}))
    (root / 'release-notes.txt').write_text('Version {version} notes')
    (root / 'images/icon.png').write_bytes(b'icon')
    (root / 'images/feature.png').write_bytes(b'feature')
    for i in range(phones):
        (root / f'images/phone/0{i}.png').write_bytes(b'phone%d' % i)
    (root / 'images/tablet7/01.png').write_bytes(b'tablet')
    return play.Listing(root)


class FakeTransport:
    def __init__(self, bundles=None, fail=None):
        self.calls = []
        self.bundles = bundles or []
        self.fail = fail or {}

    def __call__(self, method, url, headers, body):
        self.calls.append((method, url, headers, body))
        for (fail_method, suffix), response in self.fail.items():
            if method == fail_method and url.split('?')[0].endswith(suffix):
                return response
        if url.endswith('/token'):
            return 200, json.dumps({'access_token': 'secret-token'}).encode()
        if url.endswith('/edits'):
            return 200, json.dumps({'id': 'edit-1'}).encode()
        if url.endswith('/bundles') and method == 'GET':
            return 200, json.dumps({'bundles': self.bundles}).encode()
        if url.endswith('/bundles?uploadType=media'):
            import hashlib
            return 200, json.dumps({'versionCode': 4000200, 'sha256': hashlib.sha256(body).hexdigest()}).encode()
        if url.endswith(':commit'):
            return 200, json.dumps({'id': 'edit-1'}).encode()
        return 200, b'{}'


KEY = None


def openssl_key():
    global KEY
    if KEY is None:
        KEY = subprocess.run(['openssl', 'genrsa', '2048'], capture_output=True, text=True, check=True).stdout
    return KEY


class PlayTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / 'Purrimeter.aab'
        self.bundle.write_bytes(b'bundle bytes')
        self.account = {'client_email': 'svc@example.iam.gserviceaccount.com', 'token_uri': 'https://oauth2.googleapis.com/token', 'private_key': openssl_key()}
        self.listing = make_listing(self.root / 'store')

    def publisher(self, transport):
        return play.Publisher(self.account, 'com.roundhouselabsinc.purrimeter', transport=transport, now=lambda: 1_800_000_000, log=lambda *_: None)

    @unittest.skipUnless(shutil.which('openssl'), 'openssl is required to verify signatures')
    def test_jwt_signature_verifies_with_openssl(self):
        data = b'header.claims'
        signature = play.rsa_sign_sha256(self.account['private_key'], data)
        key = self.root / 'key.pem'
        key.write_text(self.account['private_key'])
        public = subprocess.run(['openssl', 'rsa', '-in', str(key), '-pubout'], capture_output=True, text=True, check=True).stdout
        (self.root / 'pub.pem').write_text(public)
        (self.root / 'data').write_bytes(data)
        (self.root / 'sig').write_bytes(signature)
        verified = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(self.root / 'pub.pem'), '-signature', str(self.root / 'sig'), str(self.root / 'data')],
                                  capture_output=True, text=True)
        self.assertIn('Verified OK', verified.stdout)
        # PKCS#1 keys are accepted as well as PKCS#8.
        pkcs1 = subprocess.run(['openssl', 'rsa', '-in', str(key), '-traditional'], capture_output=True, text=True, check=True).stdout
        self.assertEqual(play.rsa_sign_sha256(pkcs1, data), signature)

    def test_version_code_scheme(self):
        self.assertEqual(play.version_code('4.0.2'), 4000200)
        self.assertLess(play.version_code('4.0.9'), play.version_code('4.1.0'))
        self.assertLess(play.version_code('4.99.99'), play.version_code('5.0.0'))
        with self.assertRaises(ValueError):
            play.version_code('4.100.0')

    def test_full_publication_sequence(self):
        transport = FakeTransport()
        result = self.publisher(transport).publish(self.bundle, 4000200, '4.0.2', self.listing, track='production')
        self.assertEqual(result['track'], 'production')
        methods = [(m, u.split('/edits/edit-1')[-1].split('?')[0]) for m, u, _, _ in transport.calls[2:]]
        self.assertEqual(methods[:3], [('GET', '/bundles'), ('POST', '/bundles'), ('PUT', '/tracks/production')])
        self.assertIn(('PUT', '/details'), methods)
        self.assertIn(('PUT', '/listings/en-US'), methods)
        self.assertEqual(methods[-2:], [('POST', ':validate'), ('POST', ':commit')])
        # The token is exchanged once and sent with every API call.
        token_calls = [c for c in transport.calls if c[1].endswith('/token')]
        self.assertEqual(len(token_calls), 1)
        assertion = dict(x.split('=') for x in token_calls[0][3].decode().split('&'))['assertion']
        header, claims, _ = assertion.split('.')
        claims = json.loads(base64.urlsafe_b64decode(claims + '=='))
        self.assertEqual(claims['scope'], play.SCOPE)
        self.assertEqual(claims['exp'] - claims['iat'], 3600)
        self.assertTrue(all(c[2].get('Authorization') == 'Bearer secret-token' for c in transport.calls[1:]))
        track = json.loads([c for c in transport.calls if c[1].endswith('/tracks/production')][0][3])
        self.assertEqual(track['releases'][0]['versionCodes'], ['4000200'])
        self.assertEqual(track['releases'][0]['status'], 'completed')
        self.assertEqual(track['releases'][0]['releaseNotes'][0]['text'], 'Version 4.0.2 notes')
        upload = [c for c in transport.calls if c[1].endswith('/bundles?uploadType=media')][0]
        self.assertEqual(upload[3], b'bundle bytes')
        self.assertEqual(upload[2]['Content-Type'], 'application/octet-stream')
        # Images: every type is cleared once, then each file uploaded in sorted order.
        deletes = [u.rsplit('/', 1)[-1] for m, u, _, _ in transport.calls if m == 'DELETE']
        self.assertEqual(sorted(deletes), ['featureGraphic', 'icon', 'phoneScreenshots', 'sevenInchScreenshots'])
        phones = [b for m, u, h, b in transport.calls if 'phoneScreenshots?uploadType' in u]
        self.assertEqual(phones, [b'phone0', b'phone1', b'phone2'])
        self.assertNotIn('tenInchScreenshots', deletes)

    def test_rerun_reuses_existing_bundle_and_rejects_different_content(self):
        import hashlib
        digest = hashlib.sha256(b'bundle bytes').hexdigest()
        transport = FakeTransport(bundles=[{'versionCode': 4000200, 'sha256': digest}])
        self.publisher(transport).publish(self.bundle, 4000200, '4.0.2', self.listing, track='internal')
        self.assertFalse(any(u.endswith('/bundles?uploadType=media') for _, u, _, _ in transport.calls))
        self.assertTrue(any(u.endswith('/tracks/internal') for _, u, _, _ in transport.calls))
        conflicting = FakeTransport(bundles=[{'versionCode': 4000200, 'sha256': 'f' * 64}])
        with self.assertRaisesRegex(play.PlayError, 'different content'):
            self.publisher(conflicting).publish(self.bundle, 4000200, '4.0.2', self.listing)

    def test_api_errors_stop_before_commit(self):
        transport = FakeTransport(fail={('POST', ':validate'): (400, b'{"error": {"message": "Listing incomplete"}}')})
        with self.assertRaisesRegex(play.PlayError, 'Listing incomplete'):
            self.publisher(transport).publish(self.bundle, 4000200, '4.0.2', self.listing)
        self.assertFalse(any(u.endswith(':commit') for _, u, _, _ in transport.calls))
        with self.assertRaisesRegex(play.PlayError, 'token exchange'):
            self.publisher(FakeTransport(fail={('POST', 'token'): (401, b'denied')})).publish(self.bundle, 4000200, '4.0.2', self.listing)

    def test_dry_run_touches_nothing(self):
        transport = FakeTransport()
        result = self.publisher(transport).publish(self.bundle, 4000200, '4.0.2', self.listing, dry_run=True)
        self.assertEqual(transport.calls, [])
        self.assertTrue(result['dry_run'])

    def test_listing_validation(self):
        bad = self.root / 'bad'
        make_listing(bad, phones=1)
        with self.assertRaisesRegex(ValueError, 'two phone screenshots'):
            play.Listing(bad).images()
        text = json.loads((bad / 'listing.json').read_text())
        text['title'] = 'x' * 31
        (bad / 'listing.json').write_text(json.dumps(text))
        with self.assertRaisesRegex(ValueError, 'title'):
            play.Listing(bad)


if __name__ == '__main__':
    unittest.main()
