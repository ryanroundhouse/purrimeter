#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
  ""|--prepare-only) ;;
  *) echo 'Usage: scripts/publish_website.sh [--prepare-only]' >&2; exit 2 ;;
esac
python3 scripts/package_website.py
if [ "${1:-}" = --prepare-only ]; then exit 0; fi

# This is the only publication entry point; ordinary game builds stay local.
target=ryan@146.190.246.30
release=$(cat build/website-release.txt)
remote_dir=$(ssh -o BatchMode=yes "$target" 'mktemp -d /tmp/purrimeter-web.XXXXXXXX')
if ! [[ "$remote_dir" =~ ^/tmp/purrimeter-web\.[a-zA-Z0-9]+$ ]]; then
  echo 'Unexpected remote staging path' >&2; exit 1
fi
cleanup() { ssh -o BatchMode=yes "$target" "rm -rf -- '$remote_dir'" || true; }
trap cleanup EXIT
scp -q build/purrimeter-website.tar.gz "$target:$remote_dir/site.tar.gz"
ssh -o BatchMode=yes "$target" "tar -xzf '$remote_dir/site.tar.gz' -C '$remote_dir' && sudo bash '$remote_dir/deploy/activate.sh' '$remote_dir' '$release'"
curl --fail --silent --show-error https://purrimeter.graham.pub/healthz
printf '\nPublished https://purrimeter.graham.pub/ (%s)\n' "$release"
