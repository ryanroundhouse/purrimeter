"""Publish a signed Android App Bundle and the store listing through the Google Play Developer API.

Pure standard library: the service account JWT is signed here (RSASSA-PKCS1-v1_5
with SHA-256) so no key material ever leaves this process or touches a temporary
file. Every HTTP exchange goes through one injectable transport, which the tests
replace with a scripted fake.
"""
import base64
import hashlib
import json
import mimetypes
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'
UPLOAD = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/'
SCOPE = 'https://www.googleapis.com/auth/androidpublisher'
LANGUAGE = 'en-US'
IMAGE_TYPES = {'icon': 'icon', 'feature': 'featureGraphic', 'phone': 'phoneScreenshots',
               'tablet7': 'sevenInchScreenshots', 'tablet10': 'tenInchScreenshots'}
LIMITS = {'title': 30, 'shortDescription': 80, 'fullDescription': 4000}
SHA256_PREFIX = bytes.fromhex('3031300d060960864801650304020105000420')


def version_code(version):
    """MAJOR.MINOR.PATCH -> strictly increasing Play version code with room for a two-digit suffix."""
    major, minor, patch = (int(part) for part in version.split('.'))
    if minor > 99 or patch > 99:
        raise ValueError('Minor and patch versions must stay below 100 for the Play version code scheme')
    return major * 1_000_000 + minor * 10_000 + patch * 100


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def _der_read(data, offset):
    tag = data[offset]
    length = data[offset + 1]
    offset += 2
    if length & 0x80:
        count = length & 0x7f
        length = int.from_bytes(data[offset:offset + count], 'big')
        offset += count
    return tag, data[offset:offset + length], offset + length


def _der_sequence(data):
    tag, body, _ = _der_read(data, 0)
    if tag != 0x30:
        raise ValueError('Expected an ASN.1 sequence')
    items = []
    offset = 0
    while offset < len(body):
        tag, value, offset = _der_read(body, offset)
        items.append((tag, value))
    return items


def rsa_private_key(pem):
    """Return (n, d) from a PKCS#8 or PKCS#1 PEM private key."""
    lines = [line.strip() for line in pem.strip().splitlines() if line.strip() and not line.startswith('-----')]
    der = base64.b64decode(''.join(lines))
    items = _der_sequence(der)
    if len(items) == 3 and items[2][0] == 0x04:  # PKCS#8 PrivateKeyInfo wrapping RSAPrivateKey
        items = _der_sequence(items[2][1])
    if len(items) < 4 or any(tag != 0x02 for tag, _ in items[:4]):
        raise ValueError('Unsupported private key format; an RSA key is required')
    n = int.from_bytes(items[1][1], 'big')
    d = int.from_bytes(items[3][1], 'big')
    return n, d


def rsa_sign_sha256(pem, data):
    n, d = rsa_private_key(pem)
    size = (n.bit_length() + 7) // 8
    digest = SHA256_PREFIX + hashlib.sha256(data).digest()
    padded = b'\x00\x01' + b'\xff' * (size - len(digest) - 3) + b'\x00' + digest
    return pow(int.from_bytes(padded, 'big'), d, n).to_bytes(size, 'big')


def default_transport(method, url, headers, body):
    request = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


class PlayError(RuntimeError):
    pass


class Listing:
    """Store listing content kept in the repository: text in listing.json, images beside it."""

    def __init__(self, directory):
        self.directory = Path(directory)
        self.text = json.loads((self.directory / 'listing.json').read_text())
        for field, limit in LIMITS.items():
            value = self.text.get(field, '')
            if not value.strip() or len(value) > limit:
                raise ValueError(f'listing.json {field} must be 1-{limit} characters')
        for field in ('contactEmail', 'contactWebsite'):
            if not self.text.get(field):
                raise ValueError(f'listing.json requires {field}')

    def images(self):
        found = {}
        for folder, image_type in IMAGE_TYPES.items():
            path = self.directory / 'images' / folder
            if path.is_dir():
                files = sorted(p for p in path.iterdir() if p.suffix.lower() in ('.png', '.jpg', '.jpeg'))
            elif (path.with_suffix('.png')).is_file():
                files = [path.with_suffix('.png')]
            else:
                files = []
            if files:
                found[image_type] = files
        for required in ('icon', 'featureGraphic', 'phoneScreenshots'):
            if required not in found:
                raise ValueError(f'Store listing is missing {required} images under {self.directory / "images"}')
        if len(found['phoneScreenshots']) < 2:
            raise ValueError('Play requires at least two phone screenshots')
        return found

    def release_notes(self, version):
        notes = (self.directory / 'release-notes.txt')
        text = notes.read_text().strip() if notes.is_file() else ''
        return (text or 'Purrimeter {version}: the latest garden, cats and multiplayer fixes.').replace('{version}', version)[:500]


class Publisher:
    def __init__(self, account, package, transport=default_transport, now=time.time, log=print):
        self.account = account
        self.package = package
        self.transport = transport
        self.now = now
        self.log = log
        self._token = None

    # --- transport helpers -------------------------------------------------
    def token(self):
        if self._token:
            return self._token
        issued = int(self.now())
        header = b64url(json.dumps({'alg': 'RS256', 'typ': 'JWT'}).encode())
        claims = b64url(json.dumps({'iss': self.account['client_email'], 'scope': SCOPE, 'aud': self.account['token_uri'],
                                    'iat': issued, 'exp': issued + 3600}).encode())
        signing_input = f'{header}.{claims}'.encode()
        assertion = signing_input.decode() + '.' + b64url(rsa_sign_sha256(self.account['private_key'], signing_input))
        body = urllib.parse.urlencode({'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion': assertion}).encode()
        status, raw = self.transport('POST', self.account['token_uri'], {'Content-Type': 'application/x-www-form-urlencoded'}, body)
        if status != 200:
            raise PlayError(f'Play token exchange failed ({status}): {raw[:400].decode(errors="replace")}')
        self._token = json.loads(raw)['access_token']
        return self._token

    def call(self, method, url, payload=None, body=None, content_type=None):
        headers = {'Authorization': 'Bearer ' + self.token()}
        if payload is not None:
            body = json.dumps(payload).encode()
            content_type = 'application/json'
        if content_type:
            headers['Content-Type'] = content_type
        status, raw = self.transport(method, url, headers, body)
        if status >= 300:
            raise PlayError(f'Play API {method} {url} failed ({status}): {raw[:1000].decode(errors="replace")}')
        return json.loads(raw) if raw else {}

    def api(self, edit, path=''):
        return f'{API}{self.package}/edits/{edit}{path}'

    def upload(self, edit, path):
        return f'{UPLOAD}{self.package}/edits/{edit}{path}?uploadType=media'

    # --- publication -------------------------------------------------------
    def publish(self, bundle, code, version, listing, track='production', status='completed', dry_run=False):
        """Upload the bundle once, assign it to the track, refresh the listing, validate and commit."""
        bundle = Path(bundle)
        digest = hashlib.sha256(bundle.read_bytes()).hexdigest()
        images = listing.images()
        notes = listing.release_notes(version)
        self.log(f'Play: {self.package} version code {code} ({version}) -> {track}/{status}')
        if dry_run:
            return {'version_code': code, 'track': track, 'dry_run': True}
        edit = self.call('POST', f'{API}{self.package}/edits', payload={})['id']
        existing = {int(item['versionCode']): item.get('sha256', '') for item in self.call('GET', self.api(edit, '/bundles')).get('bundles', [])}
        if code in existing:
            if existing[code] and existing[code] != digest:
                raise PlayError(f'Version code {code} already exists on Play with different content; publish a newer version')
            self.log('Play: bundle already uploaded; reusing it')
        else:
            uploaded = self.call('POST', self.upload(edit, '/bundles'), body=bundle.read_bytes(), content_type='application/octet-stream')
            if int(uploaded.get('versionCode', code)) != code:
                raise PlayError(f'Play reported version code {uploaded.get("versionCode")} for a bundle built as {code}')
            if uploaded.get('sha256') and uploaded['sha256'] != digest:
                raise PlayError('Uploaded bundle digest differs from the local file')
        release = {'name': version, 'versionCodes': [str(code)], 'status': status,
                   'releaseNotes': [{'language': LANGUAGE, 'text': notes}]}
        self.call('PUT', self.api(edit, f'/tracks/{track}'), payload={'track': track, 'releases': [release]})
        self.call('PUT', self.api(edit, '/details'), payload={'defaultLanguage': LANGUAGE, 'contactEmail': listing.text['contactEmail'],
                                                              'contactWebsite': listing.text['contactWebsite']})
        self.call('PUT', self.api(edit, f'/listings/{LANGUAGE}'), payload={'language': LANGUAGE, 'title': listing.text['title'],
                                                                         'shortDescription': listing.text['shortDescription'],
                                                                         'fullDescription': listing.text['fullDescription']})
        for image_type, files in images.items():
            self.call('DELETE', self.api(edit, f'/listings/{LANGUAGE}/{image_type}'))
            for file in files:
                mime = mimetypes.guess_type(file.name)[0] or 'image/png'
                self.call('POST', self.upload(edit, f'/listings/{LANGUAGE}/{image_type}'), body=file.read_bytes(), content_type=mime)
        self.call('POST', self.api(edit, ':validate'), payload={})
        committed = self.call('POST', self.api(edit, ':commit'), payload={})
        self.log(f'Play: committed edit {committed.get("id", edit)}')
        return {'version_code': code, 'track': track, 'status': status, 'edit': committed.get('id', edit), 'sha256': digest}
