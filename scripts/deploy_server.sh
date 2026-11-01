#!/bin/bash
# Explicit deployment; preserves identity and restores the old service on failure.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build_server.sh
target=ryan@146.190.246.30
release="updates-$(shasum -a 256 dist/server/purrimeter-relay-linux-amd64 | cut -c1-12)"
stage=$(ssh -o BatchMode=yes "$target" 'mktemp -d /tmp/purrimeter-relay.XXXXXXXX')
[[ "$stage" =~ ^/tmp/purrimeter-relay\.[a-zA-Z0-9]+$ ]] || exit 1
cleanup() { ssh -o BatchMode=yes "$target" "rm -rf -- '$stage'" || true; }
trap cleanup EXIT
scp -q dist/server/purrimeter-relay-linux-amd64 "$target:$stage/relay"
ssh -o BatchMode=yes "$target" "sudo bash -s -- '$stage' '$release'" <<'REMOTE'
set -euo pipefail
stage=$1
release=$2
root=/opt/purrimeter
config=/etc/systemd/system/purrimeter.service.d/game-release.conf
exec 9>/var/lock/purrimeter-relay.lock
flock -x 9
test -s /var/www/purrimeter/current/game-release.json
previous=$(readlink "$root/current")
mkdir -p "$root/releases/$release" /etc/systemd/system/purrimeter.service.d
if [ -e "$config" ]; then cp -a "$config" "$stage/previous.conf"; fi
install -m 0755 "$stage/relay" "$root/releases/$release/purrimeter-relay"
printf '[Service]\nEnvironment=GAME_RELEASE_FILE=/var/www/purrimeter/current/game-release.json\n' > "$config"
rollback() {
 result=$?
 if [ "$result" -ne 0 ]; then
  ln -s "$previous" "$root/recover-$release"
  mv -Tf "$root/recover-$release" "$root/current"
  if [ -e "$stage/previous.conf" ]; then cp -a "$stage/previous.conf" "$config"; else rm -f "$config"; fi
  systemctl daemon-reload
  systemctl restart purrimeter
  echo 'Relay deployment failed; previous service restored.' >&2
 fi
 exit "$result"
}
trap rollback EXIT
ln -s "$root/releases/$release" "$root/next-$release"
mv -Tf "$root/next-$release" "$root/current"
systemctl daemon-reload
systemctl restart purrimeter
for attempt in {1..30}; do
 if curl --fail --silent http://127.0.0.1:18080/updates > "$stage/live-release.json"; then break; fi
 sleep 0.2
done
cmp /var/www/purrimeter/current/game-release.json "$stage/live-release.json"
curl --fail --silent https://purrimeter.graham.pub/updates > "$stage/public-release.json"
cmp "$stage/live-release.json" "$stage/public-release.json"
systemctl is-active --quiet purrimeter
trap - EXIT
printf 'Activated relay %s (previous %s)\n' "$release" "$previous"
REMOTE
