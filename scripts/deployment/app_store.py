"""Retryable App Store publication of one frozen IPA, listing, and release identity."""
import json
import os
from pathlib import Path
import subprocess
import time

from remote import digest, write_json

APP_ID = '6831635489'
APP_STORE_URL = f'https://apps.apple.com/app/id{APP_ID}'
ACCEPTED = {'WAITING_FOR_REVIEW', 'IN_REVIEW', 'PENDING_APPLE_RELEASE',
            'PENDING_DEVELOPER_RELEASE', 'PROCESSING_FOR_APP_STORE', 'READY_FOR_SALE',
            'READY_FOR_DISTRIBUTION', 'PREORDER_READY_FOR_SALE'}


class Client:
    def __init__(self, credentials, version, runner=subprocess.run):
        self.credentials = str(credentials)
        self.version = version
        self.runner = runner

    def call(self, operation, **values):
        request = {'operation': operation, 'credentials': self.credentials,
                   'app_id': APP_ID, 'version': self.version, 'build_number': self.version, **values}
        result = self.runner(['ruby', str(Path(__file__).with_suffix('.rb'))],
                             input=json.dumps(request), text=True, capture_output=True,
                             env={**os.environ, 'FASTLANE_SKIP_UPDATE_CHECK': '1',
                                  'FASTLANE_OPT_OUT_USAGE': '1', 'CI': '1'})
        # The adapter never logs key material. Preserve actionable transporter/API diagnostics.
        lines = result.stdout.splitlines()
        for line in lines:
            if not line.startswith('PURRIMETER_RESULT='):
                print(line, flush=True)
        if result.returncode:
            raise RuntimeError(f'App Store {operation} failed:\n{result.stderr[-4000:]}')
        for line in reversed(lines):
            if line.startswith('PURRIMETER_RESULT='):
                return json.loads(line.split('=', 1)[1])
        raise RuntimeError(f'App Store {operation} returned no completion receipt')


def validate_listing(folder):
    folder = Path(folder)
    data = json.loads((folder / 'listing.json').read_text())
    for name, limit in (('name', 30), ('subtitle', 30), ('description', 4000), ('keywords', 100)):
        if not data.get(name) or len(data[name]) > limit:
            raise ValueError(f'Invalid iOS listing {name} (maximum {limit} characters)')
    for device in ('iphone', 'ipad'):
        if not list((folder / 'screenshots/en-US').glob(f'{device}-*.png')):
            raise ValueError(f'Missing {device} App Store screenshots')
    if not all(data.get('review', {}).get(k) for k in ('first_name', 'last_name', 'email_address', 'notes')):
        raise ValueError('Complete App Review contact information in store/ios/listing.json')


def publish(record, state, credentials, listing, *, include_listing=True, client=None,
            sleep=time.sleep, timeout=1800):
    """Checkpoint each external action. A retry never silently replaces an IPA."""
    record = Path(record)
    ipa = record / 'Purrimeter.ipa'
    if not ipa.is_file() or digest(ipa) != state['ios_sha256']:
        raise ValueError('Prepared iOS IPA is missing or changed; refusing to publish altered bytes')
    publication = state.setdefault('app_store', {})
    if publication.get('sha256') and publication['sha256'] != state['ios_sha256']:
        raise ValueError('App Store attempt belongs to different IPA bytes')
    if publication.get('submitted_at'):
        print(f"App Store: {state['version']} already submitted; not uploading again.", flush=True)
        return state
    api = client or Client(credentials, state['version'])
    status = api.call('status')
    build = status.get('build')
    if build and not publication.get('upload_started_at'):
        # Apple exposes build identity but not an IPA digest. Never claim an
        # independently uploaded build matches our frozen release.
        raise ValueError('This build already exists on Apple without a local upload receipt; choose a new version')
    if status.get('state') in ACCEPTED:
        if not build or status.get('selected_build') != build['id']:
            raise ValueError('Apple submission selected a different build')
        publication.update(submitted_at=time.time(), build_id=build['id'], state=status['state'])
        write_json(record / 'state.json', state)
        return state
    if status.get('review_in_progress'):
        raise ValueError('Another App Store submission is still in review; retry after it finishes (or use --skip-app-store)')
    if not build and not publication.get('uploaded_at'):
        if publication.get('upload_started_at'):
            raise ValueError('Previous Apple upload outcome is unknown and its build is not visible yet. Check App Store Connect; do not rebuild or blindly re-upload.')
        publication.update(sha256=state['ios_sha256'], upload_started_at=time.time())
        write_json(record / 'state.json', state)
        api.call('upload', ipa=str(ipa.resolve()))
        publication['uploaded_at'] = time.time()
        write_json(record / 'state.json', state)
    deadline = time.monotonic() + timeout
    while not build or build['state'] == 'PROCESSING':
        if time.monotonic() >= deadline:
            raise RuntimeError('Apple is still processing the build. Rerun this same release to resume.')
        print('App Store: waiting for Apple to process the uploaded build…', flush=True)
        sleep(30)
        status = api.call('status')
        build = status.get('build')
    if build['state'] != 'VALID':
        raise ValueError(f"Apple rejected build processing: {build['state']}; inspect App Store Connect")
    publication['build_id'] = build['id']
    if include_listing and not publication.get('listing_at'):
        api.call('listing', listing=str(Path(listing).resolve()))
        publication['listing_at'] = time.time()
        write_json(record / 'state.json', state)
    result = api.call('submit')
    status = api.call('status')
    if status.get('state') not in ACCEPTED or status.get('selected_build') != build['id']:
        raise RuntimeError('Apple submission was sent but is not confirmed yet; rerun the same release to reconcile')
    publication.update(result, submitted_at=time.time(), state=status['state'])
    write_json(record / 'state.json', state)
    return state
