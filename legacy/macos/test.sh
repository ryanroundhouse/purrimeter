#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
swiftc -O -module-cache-path build/module-cache Sources/Game.swift Tests/main.swift -o build/game-tests
build/game-tests
