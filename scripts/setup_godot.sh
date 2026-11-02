#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=4.7.2
base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
mkdir -p .tools
if [ ! -x .tools/Godot.app/Contents/MacOS/Godot ]; then
  curl -fL --retry 3 "$base/Godot_v${version}-stable_macos.universal.zip" -o .tools/godot.zip
  unzip -qo .tools/godot.zip -d .tools
fi
if [ ! -f .tools/templates/macos.zip ] || [ ! -f .tools/templates/windows_release_x86_64.exe ] || [ ! -f .tools/templates/web_nothreads_release.zip ] || [ ! -f .tools/templates/android_source.zip ]; then
  if [ ! -f .tools/templates.tpz ]; then curl -fL --retry 3 "$base/Godot_v${version}-stable_export_templates.tpz" -o .tools/templates.tpz; fi
  unzip -qo .tools/templates.tpz 'templates/macos.zip' 'templates/windows_release_x86_64.exe' 'templates/windows_debug_x86_64.exe' 'templates/version.txt' 'templates/web_nothreads_release.zip' 'templates/web_nothreads_debug.zip' 'templates/android_release.apk' 'templates/android_debug.apk' 'templates/android_source.zip' -d .tools
fi
.tools/Godot.app/Contents/MacOS/Godot --headless --version
