#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SIGN_IDENTITY="${KIITO_SIGN_IDENTITY:-Apple Development: gabrielepartiti@outlook.com (CD2U989KNR)}"
APP="$ROOT/build/Kiito.app"
FRAMEWORKS="$APP/Contents/Frameworks"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$FRAMEWORKS"
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

ditto "$BIN_DIR/Sparkle.framework" "$FRAMEWORKS/Sparkle.framework"

# SwiftPM only wires up @executable_path/../lib by default; Sparkle.framework is looked
# up via @rpath, so add the Frameworks directory to the search path.
if ! otool -l "$APP/Contents/MacOS/Kiito" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Kiito"
fi

# A stable signing identity keeps the Accessibility grant valid across rebuilds.
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
