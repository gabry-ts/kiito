#!/usr/bin/env bash
# Builds the app (if needed) and packages it as build/Kiito-<version>.dmg, with a
# background image, an /Applications link for drag-and-drop install, and a matching
# code signature. Requires create-dmg (`brew install create-dmg`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Kiito.app"
NAME="Kiito"
SIGN_IDENTITY="${KIITO_SIGN_IDENTITY:-Developer ID Application}"

REBUILD=0
for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD=1 ;;
    esac
done

if [[ ! -d "$APP" || "$REBUILD" -eq 1 ]]; then
    "$ROOT/scripts/build.sh"
fi

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg is required: brew install create-dmg" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="$ROOT/build/$NAME-$VERSION.dmg"
STAGING="$ROOT/build/dmg-staging"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING/.background"
ditto "$APP" "$STAGING/$NAME.app"
# Pre-seed the retina background so Finder can pick it up automatically; create-dmg only
# copies the 1x file passed via --background, alongside whatever is already there.
cp "$ROOT/Resources/dmg/background@2x.png" "$STAGING/.background/background@2x.png"

# Icon slot coordinates below must match scripts/generate-dmg-background.py, which draws
# the arrow and label between them.
create-dmg \
    --volname "$NAME $VERSION" \
    --background "$ROOT/Resources/dmg/background.png" \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$NAME.app" 150 190 \
    --hide-extension "$NAME.app" \
    --app-drop-link 450 190 \
    --codesign "$SIGN_IDENTITY" \
    --overwrite \
    "$DMG" \
    "$STAGING"

rm -rf "$STAGING"
echo "Built $DMG ($(du -h "$DMG" | cut -f1 | xargs))"
