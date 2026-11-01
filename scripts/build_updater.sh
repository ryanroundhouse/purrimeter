#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
go_bin="${GO_BIN:-$PWD/.tools/go/bin/go}"
export GOPATH="$PWD/.tools/gopath" GOCACHE="$PWD/.tools/gocache"
mkdir -p build/updater
for arch in amd64 arm64; do
 CGO_ENABLED=0 GOOS=darwin GOARCH="$arch" "$go_bin" -C server build -trimpath -ldflags='-s -w' -o "../build/updater/darwin-$arch" ./cmd/updater
done
lipo -create build/updater/darwin-amd64 build/updater/darwin-arm64 -output build/PurrimeterUpdater
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 "$go_bin" -C server build -trimpath -ldflags='-s -w -H=windowsgui' -o ../build/PurrimeterUpdater.exe ./cmd/updater
"$go_bin" -C server build -o ../build/purrimeter-release ./cmd/release
