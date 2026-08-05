#!/usr/bin/env bash
# Build Snipe.app from the Swift package.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building (release)..."
swift build -c release

echo "==> Assembling Snipe.app..."
rm -rf dist/Snipe.app
mkdir -p dist/Snipe.app/Contents/MacOS dist/Snipe.app/Contents/Resources
cp .build/release/Snipe dist/Snipe.app/Contents/MacOS/Snipe
cp Resources/Info.plist dist/Snipe.app/Contents/Info.plist
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns dist/Snipe.app/Contents/Resources/
fi

echo "==> Codesigning (ad-hoc)..."
codesign --force --deep --sign - dist/Snipe.app

echo "==> Done: dist/Snipe.app"
