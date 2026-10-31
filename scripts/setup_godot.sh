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
if [ ! -f .tools/templates/macos.zip ] || [ ! -f .tools/templates/windows_release_x86_64.exe ]; then
  curl -fL --retry 3 "$base/Godot_v${version}-stable_export_templates.tpz" -o .tools/templates.tpz
  unzip -qo .tools/templates.tpz 'templates/macos.zip' 'templates/windows_release_x86_64.exe' 'templates/windows_debug_x86_64.exe' 'templates/version.txt' -d .tools
fi
.tools/Godot.app/Contents/MacOS/Godot --headless --version
