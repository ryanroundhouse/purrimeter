#!/bin/bash
set -euo pipefail
stage=$1
release=$2
[[ "$stage" =~ ^/tmp/purrimeter-web\.[a-zA-Z0-9]+$ ]] || exit 2
[[ "$release" =~ ^[0-9]{8}T[0-9]{6}Z-[a-f0-9]{12}$ ]] || exit 2
exec 9>/var/lock/purrimeter-website.lock
flock -x 9

root=/var/www/purrimeter
config=/etc/nginx/sites-available/purrimeter.graham.pub
snippet=/etc/nginx/snippets/purrimeter-website.conf
destination="$root/releases/$release"
test ! -e "$destination"

# Verify the upload before changing the live tree or nginx configuration.
python3 - "$stage/public" <<'PY'
import hashlib, json, sys
from pathlib import Path
root = Path(sys.argv[1])
manifest = json.loads((root / 'release.json').read_text())
for name, expected in manifest['files'].items():
    path = root / name
    if not path.resolve().is_relative_to(root.resolve()):
        raise SystemExit('Invalid manifest path')
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    if actual != expected:
        raise SystemExit(f'Checksum mismatch: {name}')
print('Uploaded site and client checksums verified')
PY

install -d -m 0755 "$root/releases" "$root/config-backups" /etc/nginx/snippets
cp -a "$stage/public" "$destination"
chown -R root:root "$destination"
find "$destination" -type d -exec chmod 0755 {} +
find "$destination" -type f -exec chmod 0644 {} +
backup="$root/config-backups/$release"
mkdir "$backup"
cp -a "$config" "$backup/site.conf"
if [ -e "$snippet" ]; then cp -a "$snippet" "$backup/snippet.conf"; fi
previous=$(readlink "$root/current" || true)
printf '%s\n' "$previous" > "$backup/previous-release.txt"
activated=false
rollback() {
  result=$?
  if [ "$result" -ne 0 ]; then
    cp -a "$backup/site.conf" "$config"
    if [ -e "$backup/snippet.conf" ]; then cp -a "$backup/snippet.conf" "$snippet"; else rm -f "$snippet"; fi
    if [ -n "$previous" ]; then
      ln -s "$previous" "$root/rollback-$release"
      mv -Tf "$root/rollback-$release" "$root/current"
    elif [ "$activated" = true ]; then rm -f "$root/current"; fi
    nginx -t && systemctl reload nginx || true
    echo 'Website publication failed; previous configuration restored.' >&2
  fi
  exit "$result"
}
trap rollback EXIT
install -m 0644 "$stage/deploy/nginx.conf" "$snippet"
python3 - "$config" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
include = '    include /etc/nginx/snippets/purrimeter-website.conf;'
old = '    location / {\n        return 404;\n    }'
if include not in text:
    if text.count(old) != 1:
        raise SystemExit('Unexpected nginx configuration; refusing to replace routes')
    path.write_text(text.replace(old, include))
PY
ln -s "$destination" "$root/next-$release"
mv -Tf "$root/next-$release" "$root/current"
activated=true
nginx -t
systemctl reload nginx
test "$(curl --fail --silent --show-error https://purrimeter.graham.pub/healthz)" = ok
curl --fail --silent --show-error https://purrimeter.graham.pub/release.json > "$stage/live-release.json"
cmp "$destination/release.json" "$stage/live-release.json"
systemctl is-active --quiet purrimeter
trap - EXIT
printf 'Activated %s; previous release: %s\n' "$release" "${previous:-none}"
