#!/usr/bin/env python3
"""Report whether Purrimeter is live on Google Play.

Prints the production track's releases (from the Play API) and the public store page's HTTP status.
The API status only reflects the requested rollout, so "live" means the public store page answers 200.
Exits 0 when the store page is live, 1 otherwise.
"""
import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/deployment'))
import play  # noqa: E402

PACKAGE = 'com.roundhouselabsinc.purrimeter'
STORE_URL = f'https://play.google.com/store/apps/details?id={PACKAGE}'


def production_releases(publisher):
    edit = publisher.call('POST', f'{play.API}{PACKAGE}/edits', payload={})['id']
    try:
        track = publisher.call('GET', publisher.api(edit, '/tracks/production'))
    finally:
        try:
            publisher.call('DELETE', publisher.api(edit))
        except play.PlayError:
            pass
    return track.get('releases', [])


def store_page_status():
    request = urllib.request.Request(STORE_URL, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


if __name__ == '__main__':
    account = Path(os.environ.get('PURRIMETER_PLAY_SERVICE_ACCOUNT', '~/.config/purrimeter/play-service-account.json')).expanduser()
    releases = production_releases(play.Publisher(json.loads(account.read_text()), PACKAGE, log=lambda *_: None))
    for release in releases or [{}]:
        codes = ','.join(release.get('versionCodes', []))
        print(f"production track: {release.get('status', 'no releases')} {release.get('name', '')} [{codes}]")
    status = store_page_status()
    print(f'store page: HTTP {status} {"(live)" if status == 200 else "(not published yet)"}')
    sys.exit(0 if status == 200 else 1)
