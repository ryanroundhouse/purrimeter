#!/bin/bash
# Export the signed Android App Bundle. Signing uses the Play upload keystore
# described in ~/.config/purrimeter/android-upload.properties (storeFile,
# keyAlias, storePassword), or PURRIMETER_ANDROID_UPLOAD_PROPERTIES.
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [ ! -f .tools/templates/android_source.zip ]; then ./scripts/setup_godot.sh; fi
props="${PURRIMETER_ANDROID_UPLOAD_PROPERTIES:-$HOME/.config/purrimeter/android-upload.properties}"
if [ ! -f "$props" ]; then
  echo "Missing Android upload keystore properties: $props" >&2
  echo "Create the upload keystore first; see docs/android.md." >&2
  exit 1
fi
read_prop() { sed -n "s/^$1=//p" "$props" | head -n 1; }
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(read_prop storeFile)"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$(read_prop keyAlias)"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(read_prop storePassword)"
if [ ! -f "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]; then echo "Upload keystore not found: $GODOT_ANDROID_KEYSTORE_RELEASE_PATH" >&2; exit 1; fi
# Godot only reads the JDK and SDK locations from its editor settings.
python3 scripts/configure_godot_android.py
export JAVA_HOME="${PURRIMETER_JAVA_HOME:-$(/usr/libexec/java_home -v 17)}"
# The Gradle build template is generated tooling, not source: install it from the
# downloaded templates whenever this checkout (or an isolated build tree) lacks it.
if [ ! -f game/android/.build_version ] || ! cmp -s game/android/.build_version .tools/templates/version.txt; then
  rm -rf game/android/build
  mkdir -p game/android/build
  unzip -qo .tools/templates/android_source.zip -d game/android/build
  cp .tools/templates/version.txt game/android/.build_version
fi
# Keep the editor's resource scan out of the Gradle tree: a previous export leaves
# staged copies of every asset there, which would otherwise be re-exported.
touch game/android/.gdignore
rm -rf game/android/build/assetPackInstallTime/src/main/assets
# An editor scan that ran before .gdignore existed leaves .import files Gradle rejects.
find game/android/build -name "*.import" -delete
rm -rf dist/android
mkdir -p dist/android build
"$godot_bin" --headless --path game --editor --import --quit > build/android-import.log 2>&1
if grep -q 'SCRIPT ERROR\|Parse Error\|Compile Error' build/android-import.log; then cat build/android-import.log; exit 1; fi
"$godot_bin" --headless --path game --export-release Android ../dist/android/Purrimeter.aab > build/android-export.log 2>&1 || { cat build/android-export.log; exit 1; }
if grep -q 'SCRIPT ERROR\|Failed to export\|ERROR: Project export' build/android-export.log || [ ! -s dist/android/Purrimeter.aab ]; then cat build/android-export.log; exit 1; fi
jarsigner -verify dist/android/Purrimeter.aab > build/android-verify.log 2>&1 || { cat build/android-verify.log; exit 1; }
if grep -q 'unsigned' build/android-verify.log; then cat build/android-verify.log; exit 1; fi
printf 'Built dist/android/Purrimeter.aab\n'
