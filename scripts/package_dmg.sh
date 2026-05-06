#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${AUDIOX_VERSION:-1.0.0}"
TARGET="${1:-native}"
DMG_ROOT="$ROOT_DIR/dist/dmg-root"
BACKGROUND_FILE="$ROOT_DIR/Resources/dmg-background.png"
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
mkdir -p "$ROOT_DIR/.build/module-cache"
swift -module-cache-path "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/scripts/generate_dmg_background.swift" "$BACKGROUND_FILE" >/dev/null

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT/.background"
cp -R "$APP_DIR" "$DMG_ROOT/AudioX.app"
ln -s /Applications "$DMG_ROOT/Applications"
cp "$BACKGROUND_FILE" "$DMG_ROOT/.background/background.png"

rm -f "$DMG_PATH"
RW_DMG="$ROOT_DIR/dist/AudioX-$VERSION-$TARGET.rw.dmg"
rm -f "$RW_DMG"
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDRW \
    "$RW_DMG" >/dev/null

MOUNT_DIR="$(mktemp -d /tmp/audiox-dmg.XXXXXX)"
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

osascript <<APPLESCRIPT
tell application "Finder"
    set dmgFolder to folder POSIX file "$MOUNT_DIR"
    open dmgFolder
    set current view of container window of dmgFolder to icon view
    set toolbar visible of container window of dmgFolder to false
    set statusbar visible of container window of dmgFolder to false
    set bounds of container window of dmgFolder to {120, 120, 840, 560}
    set viewOptions to the icon view options of container window of dmgFolder
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to file ".background:background.png" of dmgFolder
    set position of item "AudioX.app" of dmgFolder to {190, 205}
    set position of item "Applications" of dmgFolder to {535, 205}
    close container window of dmgFolder
    open dmgFolder
    update dmgFolder without registering applications
    delay 1
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet
rmdir "$MOUNT_DIR"

hdiutil convert "$RW_DMG" \
    -format UDZO \
    -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG"

rm -rf "$DMG_ROOT"
echo "$DMG_PATH"
