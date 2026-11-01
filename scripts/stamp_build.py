#!/usr/bin/env python3
"""Attach the same embedded release identity to both archives."""
import configparser,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
c=configparser.ConfigParser();c.read(root/'game/network/build.cfg')
build={k:v.strip('"') for k,v in c['release'].items()};build['sequence']=int(build['sequence'])
for name in ['macos','windows']:
 (root/'dist'/name/'game-build.json').write_text(json.dumps(build)+'\n')
(root/'dist/game-build.json').write_text(json.dumps(build)+'\n')
