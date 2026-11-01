#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
go_bin="${GO_BIN:-$PWD/.tools/go/bin/go}"
if [ ! -x "$go_bin" ]; then go_bin="$(command -v go)"; fi
godot_bin="${GODOT:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
export GOPATH="$PWD/.tools/gopath" GOCACHE="$PWD/.tools/gocache"
mkdir -p build
"$go_bin" -C server test -race ./...
"$go_bin" -C server build -o ../build/purrimeter-relay .
test_dir="$(mktemp -d "$PWD/build/relay-test.XXXXXX")"
relay_pid=""
cleanup() {
  if [ -n "$relay_pid" ]; then kill "$relay_pid" 2>/dev/null || true; wait "$relay_pid" 2>/dev/null || true; fi
  rm -rf "$test_dir"
}
trap cleanup EXIT
ALLOW_DEVELOPMENT_BUILDS=true LISTEN_ADDR=127.0.0.1:0 SIGNING_KEY_FILE="$test_dir/signing.key" ./build/purrimeter-relay > "$test_dir/server.log" 2>&1 &
relay_pid=$!
# The relay prints its bound address after net.Listen, including its ephemeral port.
port=""
for ((i=0; i<50; i++)); do
  port="$(sed -n 's/.*listening on 127.0.0.1:\([0-9]*\).*/\1/p' "$test_dir/server.log")"
  if [ -n "$port" ]; then break; fi
  sleep 0.1
done
if [ -z "$port" ]; then cat "$test_dir/server.log"; exit 1; fi
"$godot_bin" --headless --path game --script res://tests/multiplayer.gd \
  --log-file "$PWD/build/multiplayer-integration.log" -- --multiplayer-test --server "ws://127.0.0.1:$port/ws"
# Godot can exit zero on a script parse error; insist on the success marker too.
if ! rg -q 'Multiplayer checks: 0 failure\(s\)' build/multiplayer-integration.log; then exit 1; fi
