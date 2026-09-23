#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIGN_IDENTITY="${KIITO_SIGN_IDENTITY:-Apple Development: gabrielepartiti@outlook.com (CD2U989KNR)}"
APP="$ROOT/build/Kiito.app"

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Kiito" "$APP/Contents/MacOS/Kiito"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
shopt -s nullglob
for icon in "$ROOT"/Resources/MenuBarIcon*.png; do
    cp "$icon" "$APP/Contents/Resources/"
done
shopt -u nullglob

# A stable signing identity keeps the Accessibility grant valid across rebuilds.
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
