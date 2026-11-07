#!/usr/bin/env python3
"""Export Godot to Xcode, archive, and verify an App Store IPA (or simulator app)."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_ID = 'com.roundhouselabsinc.purrimeter'
TEAM_ID = 'CC36J3BH7X'


def run(command, log):
    print('+ ' + ' '.join(map(str, command)), flush=True)
    with (ROOT / 'build' / log).open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    text = (ROOT / 'build' / log).read_text()
    if result.returncode or any(marker in text for marker in ('SCRIPT ERROR:', 'Parse Error:', 'Compile Error:', 'Failed to export')):
        raise RuntimeError(f'{log}:\n{text[-8000:]}')


def authentication():
    """Use the release API key when configured, otherwise Xcode's signed-in account."""
    path = Path(os.environ.get('PURRIMETER_APP_STORE_CREDENTIALS', '~/.config/purrimeter/app-store.json')).expanduser()
    if not path.is_file():
        return []
    config = json.loads(path.read_text())
    return ['-authenticationKeyPath', str(Path(config['key_file']).expanduser()),
            '-authenticationKeyID', config['key_id'], '-authenticationKeyIssuerID', config['issuer_id']]


def verify_ipa(path, version=None):
    with zipfile.ZipFile(path) as archive:
        info = plistlib.loads(archive.read('Payload/Purrimeter.app/Info.plist'))
        if info['CFBundleIdentifier'] != BUNDLE_ID:
            raise ValueError('IPA has the wrong bundle identifier')
        if version and (info['CFBundleShortVersionString'] != version or info['CFBundleVersion'] != version):
            raise ValueError('IPA version/build does not match the release')
        if info.get('ITSAppUsesNonExemptEncryption') is not False:
            raise ValueError('IPA must declare its exempt encryption use')
        if 'Payload/Purrimeter.app/embedded.mobileprovision' not in archive.namelist():
            raise ValueError('IPA is missing its distribution provisioning profile')
        if archive.testzip() is not None:
            raise ValueError('IPA failed ZIP integrity validation')
    return info


def build(simulator=False):
    godot = os.environ.get('GODOT', str(ROOT / '.tools/Godot.app/Contents/MacOS/Godot'))
    if not (ROOT / '.tools/templates/ios.zip').is_file():
        subprocess.run(['./scripts/setup_godot.sh'], cwd=ROOT, check=True)
    (ROOT / 'build').mkdir(exist_ok=True)
    destination = ROOT / ('build/ios-simulator-project' if simulator else 'dist/ios')
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    run([godot, '--headless', '--path', 'game', '--editor', '--import', '--quit'], 'ios-import.log')
    run([godot, '--headless', '--path', 'game', '--export-release', 'iOS', str(destination / 'Purrimeter.zip')], 'ios-export.log')
    # The engine template emits empty permission strings even when camera and
    # microphone modules are unused. Do not ship misleading permission prompts.
    plist = destination / 'Purrimeter/Purrimeter-Info.plist'
    info = plistlib.loads(plist.read_bytes())
    for key in ('NSCameraUsageDescription', 'NSMicrophoneUsageDescription', 'NSPhotoLibraryUsageDescription'):
        if not info.get(key):
            info.pop(key, None)
    plist.write_bytes(plistlib.dumps(info))
    project = ['xcodebuild', '-project', str(destination / 'Purrimeter.xcodeproj'),
               '-scheme', 'Purrimeter', '-configuration', 'Release']
    if simulator:
        # Godot 4.7.2's official template contains x86_64 simulator objects even
        # though its XCFramework Info.plist advertises both architectures.
        library = destination / 'Purrimeter.xcframework/ios-arm64_x86_64-simulator/libgodot.a'
        native_library = ROOT / '.tools/ios-simulator-source/godot-4.7.2-stable/bin/libgodot.ios.template_release.arm64.simulator.a'
        if native_library.is_file():
            shutil.copy2(native_library, library)
        architectures = subprocess.check_output(['lipo', '-archs', str(library)], text=True).split()
        architecture = 'arm64' if 'arm64' in architectures else 'x86_64'
        run([*project, '-sdk', 'iphonesimulator', '-destination', 'generic/platform=iOS Simulator',
             '-derivedDataPath', 'build/ios-simulator', f'ARCHS={architecture}', 'CODE_SIGNING_ALLOWED=NO', 'build'], 'ios-simulator.log')
        app = ROOT / 'build/ios-simulator/Build/Products/Release-iphonesimulator/Purrimeter.app'
        subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
        print(f'Simulator app ({architecture}): {app}')
        return
    auth = authentication()
    run([*project, '-destination', 'generic/platform=iOS', '-archivePath', 'build/Purrimeter.xcarchive',
         '-derivedDataPath', 'build/ios-device', '-allowProvisioningUpdates', *auth,
         'CODE_SIGN_IDENTITY=Apple Development', 'archive'], 'ios-archive.log')
    options = ROOT / 'build/ios-export-options.plist'
    options.write_bytes(plistlib.dumps({'method': 'app-store-connect', 'teamID': TEAM_ID,
        'signingStyle': 'automatic', 'destination': 'export', 'manageAppVersionAndBuildNumber': False,
        'uploadSymbols': True}))
    run(['xcodebuild', '-exportArchive', '-archivePath', 'build/Purrimeter.xcarchive',
         '-exportOptionsPlist', str(options), '-exportPath', str(destination),
         '-allowProvisioningUpdates', *auth], 'ios-sign.log')
    ipa = destination / 'Purrimeter.ipa'
    verify_ipa(ipa)
    # Verify the exported distribution signature, not just the development archive.
    check = ROOT / 'build/ios-verify'
    if check.exists():
        shutil.rmtree(check)
    subprocess.run(['ditto', '-x', '-k', str(ipa), str(check)], check=True)
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(check / 'Payload/Purrimeter.app')], check=True)
    profile = plistlib.loads(subprocess.check_output(['security', 'cms', '-D', '-i',
        str(check / 'Payload/Purrimeter.app/embedded.mobileprovision')]))
    if profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices') or profile['Entitlements'].get('get-task-allow'):
        raise ValueError('IPA is not signed for App Store distribution')
    if profile['Entitlements']['application-identifier'] != f'{TEAM_ID}.{BUNDLE_ID}':
        raise ValueError('Distribution profile does not match Purrimeter')
    print(f'Built and verified {ipa}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', action='store_true')
    build(parser.parse_args().simulator)
