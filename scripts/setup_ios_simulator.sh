#!/bin/bash
# Godot 4.7.2's official iOS template lacks an arm64 simulator library.
# Build only the missing simulator engine from the matching official source.
set -euo pipefail
cd "$(dirname "$0")/.."
version=4.7.2
source_dir="$PWD/.tools/ios-simulator-source"
mkdir -p "$source_dir"
if [ ! -d "$source_dir/godot-$version-stable" ]; then
  curl -fL --retry 3 "https://github.com/godotengine/godot/archive/refs/tags/$version-stable.tar.gz" -o "$source_dir/godot.tar.gz"
  tar -xzf "$source_dir/godot.tar.gz" -C "$source_dir"
fi
if [ ! -x "$source_dir/venv/bin/scons" ]; then
  python3 -m venv "$source_dir/venv"
  "$source_dir/venv/bin/pip" install 'scons==4.9.1'
fi
cd "$source_dir/godot-$version-stable"
"$source_dir/venv/bin/scons" platform=ios target=template_release arch=arm64 simulator=yes vulkan=no metal=no -j6
