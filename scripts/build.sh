#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$godot_bin" ]; then ./scripts/setup_godot.sh; fi
mkdir -p dist/macos dist/windows build
./scripts/build_updater.sh
"$godot_bin" --headless --path game --editor --import --quit
"$godot_bin" --headless --path game --export-release macOS ../dist/macos/Purrimeter.app
"$godot_bin" --headless --path game --export-release Windows ../dist/windows/Purrimeter.exe
cp docs/PLAY.txt dist/windows/README.txt
cp docs/GODOT-LICENSE.txt docs/GODOT-COPYRIGHT.txt dist/windows/
cp docs/PLAY.txt dist/macos/README.txt
cp docs/GODOT-LICENSE.txt docs/GODOT-COPYRIGHT.txt dist/macos/
cp build/PurrimeterUpdater dist/macos/Purrimeter.app/Contents/MacOS/
cp build/PurrimeterUpdater.exe dist/windows/
./scripts/build_web.sh
python3 scripts/stamp_build.py
codesign --force --deep --sign - dist/macos/Purrimeter.app
codesign --verify --deep --strict dist/macos/Purrimeter.app
rm -f dist/Purrimeter-macOS.zip dist/Purrimeter-Windows.zip
ditto -c -k --sequesterRsrc --keepParent dist/macos dist/Purrimeter-macOS.zip
(cd dist/windows && zip -q -r ../Purrimeter-Windows.zip .)
# Keep the original handoff location current, too.
# ditto merges directories; remove the generated old bundle so legacy resources
# cannot invalidate the freshly exported signature.
rm -rf build/Purrimeter.app
ditto dist/macos/Purrimeter.app build/Purrimeter.app
codesign --verify --deep --strict build/Purrimeter.app
printf '\nBuilt macOS, Windows and Web packages\n'
