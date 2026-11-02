#!/usr/bin/env python3
"""Push the Google Play store listing (text, contact details, images) from store/android without a release.

Use after a release that ran with --skip-listing, or whenever the listing content changes between releases.
"""
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/deployment'))
import play  # noqa: E402

PACKAGE = 'com.roundhouselabsinc.purrimeter'

if __name__ == '__main__':
    account = Path(os.environ.get('PURRIMETER_PLAY_SERVICE_ACCOUNT', '~/.config/purrimeter/play-service-account.json')).expanduser()
    listing = play.Listing(ROOT / 'store/android')
    result = play.Publisher(json.loads(account.read_text()), PACKAGE).publish_listing(listing)
    print(f"Store listing published (edit {result['edit']}).")
