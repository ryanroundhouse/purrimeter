#!/usr/bin/env python3
"""Capture the real iOS app's staged scenes on iPhone and iPad simulators."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BUNDLE = 'com.roundhouselabsinc.purrimeter'


def sim(*args):
    return subprocess.check_output(['xcrun', 'simctl', *args], text=True).strip()


def capture(device, family, app):
    devices = json.loads(sim('list', 'devices', 'available', '--json'))['devices']
    match = next((d for group in devices.values() for d in group if d['udid'] == device), None)
    if not match:
        raise ValueError(f'Simulator is not available: {device}')
    started = match['state'] != 'Booted'
    try:
        if started:
            sim('boot', device)
        sim('bootstatus', device, '-b')
        sim('install', device, str(app))
        container = Path(sim('get_app_container', device, BUNDLE, 'data'))
        output = ROOT / 'store/ios/screenshots/en-US'
        output.mkdir(parents=True, exist_ok=True)
        for index, scene in enumerate(('garden', 'main-menu', 'placement', 'inspect', 'powerups', 'multiplayer'), 1):
            # The application captures its rendered viewport and exits. It uses
            # an isolated demonstration garden and never touches a player's save.
            name = f'{family}-{index:02d}-{scene}.png'
            target = container / 'Documents' / name
            target.unlink(missing_ok=True)
            subprocess.run(['xcrun', 'simctl', 'terminate', device, BUNDLE], capture_output=True)
            sim('launch', device, BUNDLE, '--', '--app-preview', f'user://{name}', '--preview-scene', scene)
            deadline = time.monotonic() + 60
            while not target.is_file() and time.monotonic() < deadline:
                time.sleep(1)
            if not target.is_file():
                raise RuntimeError(f'The iOS app did not capture {scene}; inspect its runtime logs')
            raw = target.read_bytes()
            dimensions = struct.unpack('>II', raw[16:24])
            allowed = {(2868, 1320), (2796, 1290), (2688, 1242)} if family == 'iphone' else {(2752, 2064), (2732, 2048)}
            if dimensions not in allowed:
                raise ValueError(f'{name}: {dimensions} is not an expected App Store screenshot size')
            shutil.copy2(target, output / name)
            print(f'Captured {name}: {dimensions}', flush=True)
    finally:
        if started:
            sim('shutdown', device)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--iphone', required=True, help='UDID from xcrun simctl list devices available')
    parser.add_argument('--ipad', required=True, help='13-inch iPad Pro simulator UDID')
    args = parser.parse_args()
    app = ROOT / 'build/ios-simulator/Build/Products/Release-iphonesimulator/Purrimeter.app'
    if not app.is_dir():
        raise SystemExit('First run python3 scripts/build_ios.py --simulator')
    capture(args.iphone, 'iphone', app)
    capture(args.ipad, 'ipad', app)
