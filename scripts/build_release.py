#!/usr/bin/env python3
"""Build both platforms under one immutable identity and sign the release."""
import hashlib,json,os,re,subprocess,sys,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
version=sys.argv[1] if len(sys.argv)>1 else ''
if not re.fullmatch(r'\d+\.\d+\.\d+',version): raise SystemExit('Usage: scripts/build_release.py MAJOR.MINOR.PATCH')
sequence=int(time.time());identity=f'{version}-{sequence}'
config=root/'game/network/build.cfg';presets=root/'game/export_presets.cfg';old_config=config.read_bytes();old_presets=presets.read_text()
try:
 config.write_text(f'[release]\nid="{identity}"\nsequence={sequence}\nversion="{version}"\n')
 text=re.sub(r'(application/(?:short_version|version)=)"[^"]+"',rf'\g<1>"{version}"',old_presets)
 text=re.sub(r'(application/(?:file_version|product_version)=)"[^"]+"',rf'\g<1>"{version}.0"',text);presets.write_text(text)
 subprocess.run(['./scripts/build.sh'],cwd=root,check=True)
finally:
 config.write_bytes(old_config);presets.write_text(old_presets)
manifest={'id':identity,'sequence':sequence,'version':version,'packages':{}}
for platform,name in [('macos','Purrimeter-macOS.zip'),('windows','Purrimeter-Windows.zip')]:
 path=root/'dist'/name
 with path.open('rb') as stream: digest=hashlib.file_digest(stream,'sha256').hexdigest()
 manifest['packages'][platform]={'url':f'https://purrimeter.graham.pub/game-releases/{identity}/{name}','sha256':digest,'size':path.stat().st_size}
unsigned=root/'build/game-release-unsigned.json';unsigned.write_text(json.dumps(manifest))
key=os.environ.get('PURRIMETER_RELEASE_KEY',str(Path.home()/'.config/purrimeter/release-signing.key'))
subprocess.run([str(root/'build/purrimeter-release'),'sign',key,str(unsigned),str(root/'dist/game-release.json')],check=True)
print(f'Signed game release {identity}. Run scripts/publish_website.sh to publish.')
