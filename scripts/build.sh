#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# A Developer ID identity kept stable across builds and Sparkle updates is what lets the
# Accessibility grant survive future rebuilds. SIGN_IDENTITY=- signs ad hoc for local
# testing without a certificate.
SIGN_IDENTITY="${KIITO_SIGN_IDENTITY:-Developer ID Application}"
APP="$ROOT/build/Kiito.app"
FRAMEWORKS="$APP/Contents/Frameworks"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf "$APP"
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

# Sign inside-out, without --deep, so every nested binary gets its own hardened-runtime
# signature: Sparkle's XPC services, Autoupdate and Updater.app, then the framework
# itself, then the app.
CODESIGN_FLAGS=(--force --options runtime)
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    CODESIGN_FLAGS+=(--timestamp)
fi

SPARKLE_FRAMEWORK="$FRAMEWORKS/Sparkle.framework"
find "$SPARKLE_FRAMEWORK/Versions/Current/XPCServices" -maxdepth 1 -name "*.xpc" -exec \
    codesign "${CODESIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" {} \;
codesign "${CODESIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "$SPARKLE_FRAMEWORK/Versions/Current/Autoupdate"
codesign "${CODESIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "$SPARKLE_FRAMEWORK/Versions/Current/Updater.app"
codesign "${CODESIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "$SPARKLE_FRAMEWORK"

codesign "${CODESIGN_FLAGS[@]}" --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
