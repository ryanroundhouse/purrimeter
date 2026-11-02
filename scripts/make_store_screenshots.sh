#!/bin/bash
# Capture Google Play screenshots from the real game at phone and tablet sizes.
# Scenes use the staged demonstration garden (see app.gd preview_scene), never a
# player's save. Requires a windowed macOS session; output goes to store/android/images.
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
out="store/android/images"
capture() { # folder name scene WxH scale
  local folder="$1" name="$2" scene="$3" size="$4" scale="$5"
  mkdir -p "$out/$folder"
  "$godot_bin" --path game --resolution "$size" -- --app-preview "$PWD/$out/$folder/$name.png" --mobile-test --preview-scene "$scene" --preview-scale "$scale" > "build/store-$folder-$name.log" 2>&1
  if grep -q 'SCRIPT ERROR' "build/store-$folder-$name.log"; then cat "build/store-$folder-$name.log"; exit 1; fi
  python3 - "$out/$folder/$name.png" "$size" <<'PY'
import struct,sys
path,size=sys.argv[1],sys.argv[2]
with open(path,'rb') as f: head=f.read(24)
w,h=struct.unpack('>II',head[16:24]); ew,eh=(int(x) for x in size.split('x'))
if (w,h)!=(ew,eh): raise SystemExit(f'{path}: got {w}x{h}, expected {ew}x{eh}; the window was clamped by the display')
PY
  echo "captured $folder/$name.png"
}
rm -rf "$out/phone" "$out/tablet7" "$out/tablet10"
# Phone: 1080x1800 portrait (logical 540x900 at 2x) and one 1800x1080 landscape.
i=1
for scene in garden placement inspect powerups multiplayer chat achievements; do
  capture phone "$(printf '%02d' $i)-$scene" "$scene" 1080x1800 2; i=$((i+1))
done
capture phone "08-landscape" garden 1800x1080 2
# Tablets: landscape 1800x1120 (logical 900x560 at 2x) for the 7" and 10" slots.
for folder in tablet7 tablet10; do
  i=1
  for scene in garden multiplayer powerups achievements; do
    capture "$folder" "$(printf '%02d' $i)-$scene" "$scene" 1800x1120 2; i=$((i+1))
  done
done
echo "Store screenshots written to $out"
