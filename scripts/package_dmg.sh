#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${AUDIOX_VERSION:-1.0.0}"
TARGET="${1:-native}"
DMG_ROOT="$ROOT_DIR/dist/dmg-root"
case "$TARGET" in
    native)
        DMG_PATH="$ROOT_DIR/dist/AudioX-$VERSION.dmg"
        VOLUME_NAME="AudioX $VERSION"
        ;;
    arm|arm64)
        DMG_PATH="$ROOT_DIR/dist/AudioX-$VERSION-arm64.dmg"
        VOLUME_NAME="AudioX $VERSION arm64"
        ;;
    intel|x86_64)
        DMG_PATH="$ROOT_DIR/dist/AudioX-$VERSION-intel.dmg"
        VOLUME_NAME="AudioX $VERSION intel"
        ;;
    universal|universal2)
        DMG_PATH="$ROOT_DIR/dist/AudioX-$VERSION-universal.dmg"
        VOLUME_NAME="AudioX $VERSION universal"
        ;;
    *)
        echo "Usage: scripts/package_dmg.sh [native|arm|arm64|intel|x86_64|universal]" >&2
        exit 64
        ;;
esac

APP_DIR="$("$ROOT_DIR/scripts/package_app.sh" "$TARGET" | tail -n 1)"

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/AudioX.app"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$DMG_ROOT"
echo "$DMG_PATH"
