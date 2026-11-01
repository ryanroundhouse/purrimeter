#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
if [ ! -f .tools/templates/web_nothreads_release.zip ]; then ./scripts/setup_godot.sh; fi
rm -rf dist/web
mkdir -p dist/web build
"$godot_bin" --headless --path game --editor --import --quit > build/web-import.log 2>&1
if rg -q 'SCRIPT ERROR|Parse Error|Compile Error' build/web-import.log; then cat build/web-import.log; exit 1; fi
"$godot_bin" --headless --path game --export-release Web ../dist/web/index.html > build/web-export.log 2>&1
if rg -q 'SCRIPT ERROR|Failed to export' build/web-export.log; then cat build/web-export.log; exit 1; fi
cp game/web/browser.js game/web/browser.css dist/web/
cp docs/GODOT-LICENSE.txt docs/GODOT-COPYRIGHT.txt dist/web/
python3 - <<'PY'
import configparser, gzip, json, re
from pathlib import Path
c=configparser.ConfigParser(); c.read('game/network/build.cfg')
build={k:v.strip('"') for k,v in c['release'].items()}; build['sequence']=int(build['sequence'])
root=Path('dist/web'); (root/'game-build.json').write_text(json.dumps(build)+'\n')
# Keep executable config out of inline script for the strict /play CSP.
p=root/'index.html'; text=p.read_text()
match=re.search(r'<script>(window.PURRIMETER_CONFIG = .*?;)</script>',text,re.S)
if not match: raise SystemExit('Missing browser configuration')
(root/'config.js').write_text(match[1]+'\n')
p.write_text(text[:match.start()]+'<script src="config.js"></script>'+text[match.end():])
for asset in root.iterdir():
 if asset.suffix in ('.wasm','.pck','.js','.css') and asset.name != 'config.js':
  asset.with_name(asset.name+'.gz').write_bytes(gzip.compress(asset.read_bytes(),mtime=0))
PY
rm -f dist/Purrimeter-Web.zip
(cd dist/web && zip -q -r ../Purrimeter-Web.zip .)
printf 'Built dist/web and dist/Purrimeter-Web.zip\n'
