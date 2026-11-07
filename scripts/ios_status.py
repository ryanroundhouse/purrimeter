#!/usr/bin/env python3
"""Exit 0 once Apple's public lookup contains Purrimeter; 1 while unpublished."""
import json
import sys
from urllib.request import urlopen

sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parent / 'deployment'))
from app_store import APP_ID, APP_STORE_URL

with urlopen(f'https://itunes.apple.com/lookup?id={APP_ID}&country=ca', timeout=30) as response:
    data = json.load(response)
matches = [app for app in data.get('results', []) if str(app.get('trackId')) == APP_ID
           and app.get('bundleId') == 'com.roundhouselabsinc.purrimeter']
if matches:
    print(f"Live on the App Store: {matches[0]['version']} — {APP_STORE_URL}")
    sys.exit(0)
print('Purrimeter is not yet available on the Canadian App Store.')
sys.exit(1)
