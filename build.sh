#!/bin/bash
# SwiftPM cannot emit an .app bundle, and the Touch Bar service ignores a bare
# binary, so assemble the bundle by hand. Ad-hoc signing is enough for a locally
# built, unsandboxed agent app.
set -euo pipefail

cd "$(dirname "$0")"

APP="StripGauge.app"
BINARY=".build/release/stripgauge"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BINARY" "$APP/Contents/MacOS/stripgauge"
codesign --force --sign - "$APP"

echo "built $PWD/$APP"
