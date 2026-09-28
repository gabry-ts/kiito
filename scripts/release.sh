#!/usr/bin/env bash
# Builds, signs, packages, notarizes and staples a release DMG, then generates the
# Sparkle appcast for it. Used by .github/workflows/release.yml; safe to run locally,
# except it talks to Apple's notarization service, so it needs real credentials.
#
# Required environment:
#   ASC_API_KEY_PATH    - path to the App Store Connect API private key (.p8)
#   ASC_API_KEY_ID       - App Store Connect API key ID
#   ASC_API_ISSUER_ID    - App Store Connect API issuer ID
#   SPARKLE_ED_KEY_FILE  - path to the Sparkle EdDSA private key, used to sign the appcast
# Optional:
#   KIITO_SIGN_IDENTITY  - codesign identity (see scripts/build.sh; defaults to the first
#                          "Developer ID Application" identity in the keychain)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="Kiito"
REPO="gabry-ts/kiito"
SPARKLE_VERSION="2.10.0" # keep in sync with the SwiftPM dependency in Package.swift

: "${ASC_API_KEY_PATH:?Set ASC_API_KEY_PATH to the App Store Connect API .p8 key path}"
: "${ASC_API_KEY_ID:?Set ASC_API_KEY_ID}"
: "${ASC_API_ISSUER_ID:?Set ASC_API_ISSUER_ID}"
: "${SPARKLE_ED_KEY_FILE:?Set SPARKLE_ED_KEY_FILE to the Sparkle EdDSA private key file path}"

"$ROOT/scripts/build.sh"
"$ROOT/scripts/make-dmg.sh"

APP="$ROOT/build/$NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="$ROOT/build/$NAME-$VERSION.dmg"

echo "Notarizing $DMG..."
xcrun notarytool submit "$DMG" \
    --key "$ASC_API_KEY_PATH" \
    --key-id "$ASC_API_KEY_ID" \
    --issuer "$ASC_API_ISSUER_ID" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG"

echo "Preparing appcast..."
APPCAST_DIR="$ROOT/build/appcast-input"
rm -rf "$APPCAST_DIR"
mkdir -p "$APPCAST_DIR"
cp "$DMG" "$APPCAST_DIR/"

# generate_appcast embeds release notes for a new item when a file with the same
# basename as the archive sits next to it in the input folder.
for ext in md html; do
    NOTES="$ROOT/docs/release-notes/$VERSION.$ext"
    if [[ -f "$NOTES" ]]; then
        cp "$NOTES" "$APPCAST_DIR/$NAME-$VERSION.$ext"
        break
    fi
done

SPARKLE_TOOLS="$ROOT/build/sparkle-tools"
GENERATE_APPCAST="$SPARKLE_TOOLS/bin/generate_appcast"
if [[ ! -x "$GENERATE_APPCAST" ]]; then
    echo "Downloading Sparkle $SPARKLE_VERSION tools..."
    mkdir -p "$SPARKLE_TOOLS"
    curl -sSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
        -o "$ROOT/build/sparkle-tools.tar.xz"
    tar -xJf "$ROOT/build/sparkle-tools.tar.xz" -C "$SPARKLE_TOOLS" bin/generate_appcast bin/sign_update
    rm "$ROOT/build/sparkle-tools.tar.xz"
    chmod +x "$GENERATE_APPCAST" "$SPARKLE_TOOLS/bin/sign_update"
fi

# A single-DMG input folder produces a single-item appcast, which is all "latest" feed
# needs.
"$GENERATE_APPCAST" "$APPCAST_DIR" \
    --ed-key-file "$SPARKLE_ED_KEY_FILE" \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" \
    --embed-release-notes \
    -o "$ROOT/build/appcast.xml"

echo "Release artifacts ready:"
echo "  $DMG"
echo "  $ROOT/build/appcast.xml"
