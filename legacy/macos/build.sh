#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/Purrimeter.app/Contents/MacOS build/Purrimeter.app/Contents/Resources build/module-cache
swiftc -target "$(uname -m)-apple-macos13.0" -O -module-cache-path build/module-cache Sources/Game.swift Sources/App.swift -o build/Purrimeter.app/Contents/MacOS/Purrimeter -framework AppKit -framework AVFoundation
cp Assets/*.png Assets/*.wav build/Purrimeter.app/Contents/Resources/
cat > build/Purrimeter.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Purrimeter</string>
<key>CFBundleIdentifier</key><string>local.purrimeter.game</string>
<key>CFBundleName</key><string>Purrimeter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticTermination</key><false/>
</dict></plist>
PLIST
codesign --force --sign - build/Purrimeter.app
printf 'Built %s/build/Purrimeter.app\n' "$PWD"
