#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
go_bin="${GO_BIN:-$PWD/.tools/go/bin/go}"
if [ ! -x "$go_bin" ]; then go_bin="$(command -v go)"; fi
export GOPATH="$PWD/.tools/gopath" GOCACHE="$PWD/.tools/gocache"
mkdir -p dist/server
for arch in amd64 arm64; do
  CGO_ENABLED=0 GOOS=linux GOARCH="$arch" "$go_bin" -C server build -trimpath -ldflags='-s -w' -o "../dist/server/purrimeter-relay-linux-$arch" .
done
cp server/{main.go,hub.go,state.go,go.mod,go.sum,Dockerfile,compose.yaml,Caddyfile,.dockerignore,README.md} dist/server/
tar -czf dist/Purrimeter-Server.tar.gz -C dist server
printf 'Built dist/Purrimeter-Server.tar.gz (Linux amd64/arm64 binaries and Docker source)\n'
