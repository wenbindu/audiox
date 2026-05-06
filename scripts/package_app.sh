#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${AUDIOX_VERSION:-1.0.0}"
TARGET="${1:-native}"

case "$TARGET" in
    native)
        BUILD_ARGS=(-c release)
        APP_DIR="$ROOT_DIR/dist/AudioX.app"
        ;;
    arm|arm64)
        BUILD_ARGS=(-c release --arch arm64)
        APP_DIR="$ROOT_DIR/dist/AudioX-$VERSION-arm64.app"
        ;;
    intel|x86_64)
        BUILD_ARGS=(-c release --arch x86_64)
        APP_DIR="$ROOT_DIR/dist/AudioX-$VERSION-intel.app"
        ;;
    universal|universal2)
        BUILD_ARGS=(-c release --arch arm64 --arch x86_64)
        APP_DIR="$ROOT_DIR/dist/AudioX-$VERSION-universal.app"
        ;;
    *)
        echo "Usage: scripts/package_app.sh [native|arm|arm64|intel|x86_64|universal]" >&2
        exit 64
        ;;
esac

CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"

cd "$ROOT_DIR"
if [[ ! -f "$ICON_FILE" ]]; then
    echo "Missing $ICON_FILE. Run scripts/generate_app_icon.sh first." >&2
    exit 66
fi
swift build "${BUILD_ARGS[@]}" >&2
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_DIR/AudioX" "$MACOS_DIR/AudioX"
cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>AudioX</string>
    <key>CFBundleIdentifier</key>
    <string>local.audiox.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>AudioX</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__VERSION__</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Audio Files</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.audio</string>
                <string>public.mp3</string>
                <string>public.wav</string>
                <string>public.mpeg-4-audio</string>
            </array>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>mp3</string>
                <string>wav</string>
                <string>m4a</string>
                <string>aac</string>
                <string>flac</string>
                <string>ogg</string>
                <string>opus</string>
                <string>p3</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

perl -0pi -e "s/__VERSION__/$VERSION/g" "$CONTENTS_DIR/Info.plist"

echo "$APP_DIR"
