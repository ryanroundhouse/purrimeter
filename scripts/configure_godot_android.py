#!/usr/bin/env python3
"""Point the Godot editor at the local JDK 17 and Android SDK for Android exports.

Godot reads these two paths only from its editor settings file; there is no
command-line or environment override. This upserts them without touching
other settings and prints the resulting paths.
"""
import os
import re
import subprocess
import sys
from pathlib import Path

SETTINGS = Path.home() / 'Library/Application Support/Godot/editor_settings-4.7.tres'


def java_home():
    explicit = os.environ.get('PURRIMETER_JAVA_HOME')
    if explicit:
        return explicit
    try:
        return subprocess.check_output(['/usr/libexec/java_home', '-v', '17'], text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return ''


def android_sdk():
    for candidate in (os.environ.get('ANDROID_HOME'), os.environ.get('ANDROID_SDK_ROOT'), str(Path.home() / 'Library/Android/sdk')):
        if candidate and (Path(candidate) / 'platform-tools').is_dir():
            return candidate
    return ''


def upsert(text, key, value):
    line = f'{key} = "{value}"'
    pattern = re.compile(rf'^{re.escape(key)} = .*$', re.M)
    if pattern.search(text):
        return pattern.sub(line, text)
    if '[resource]' not in text:
        text = text.rstrip('\n') + '\n\n[resource]\n'
    return text.rstrip('\n') + '\n' + line + '\n'


def configure(settings=SETTINGS, java=None, sdk=None):
    java = java or java_home()
    sdk = sdk or android_sdk()
    if not java or not (Path(java) / 'bin/java').is_file():
        raise SystemExit('JDK 17 not found; install openjdk@17 or set PURRIMETER_JAVA_HOME')
    if not sdk:
        raise SystemExit('Android SDK not found; install it at ~/Library/Android/sdk or set ANDROID_HOME')
    text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    updated = upsert(upsert(text, 'export/android/java_sdk_path', java), 'export/android/android_sdk_path', sdk)
    if updated != text:
        settings.parent.mkdir(parents=True, exist_ok=True)
        settings.write_text(updated)
    return java, sdk


if __name__ == '__main__':
    java, sdk = configure()
    print(f'Java SDK: {java}\nAndroid SDK: {sdk}')
    sys.exit(0)
