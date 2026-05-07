#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:?Usage: scripts/bundle_ffmpeg.sh /path/to/AudioX.app}"
CONTENTS_DIR="$APP_DIR/Contents"
TOOLS_DIR="$CONTENTS_DIR/Resources/Tools"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
FFMPEG_BIN="${FFMPEG_PATH:-$(command -v ffmpeg || true)}"

if [[ ! -x "$FFMPEG_BIN" ]]; then
    echo "Missing ffmpeg. Install it before packaging: brew install ffmpeg" >&2
    exit 66
fi

while [[ -L "$FFMPEG_BIN" ]]; do
    LINK_TARGET="$(readlink "$FFMPEG_BIN")"
    case "$LINK_TARGET" in
        /*) FFMPEG_BIN="$LINK_TARGET" ;;
        *) FFMPEG_BIN="$(cd "$(dirname "$FFMPEG_BIN")" && cd "$(dirname "$LINK_TARGET")" && pwd -P)/$(basename "$LINK_TARGET")" ;;
    esac
done

mkdir -p "$TOOLS_DIR" "$FRAMEWORKS_DIR"
cp -p "$FFMPEG_BIN" "$TOOLS_DIR/ffmpeg"
chmod u+w "$TOOLS_DIR/ffmpeg"
chmod +x "$TOOLS_DIR/ffmpeg"

QUEUE_FILE="$(mktemp)"
SEEN_FILE="$(mktemp)"
trap 'rm -f "$QUEUE_FILE" "$SEEN_FILE"' EXIT

echo "$TOOLS_DIR/ffmpeg" > "$QUEUE_FILE"

while true; do
    NEXT_FILE="$(comm -23 <(sort -u "$QUEUE_FILE") <(sort -u "$SEEN_FILE") | head -n 1 || true)"
    [[ -n "$NEXT_FILE" ]] || break

    echo "$NEXT_FILE" >> "$SEEN_FILE"
    otool -L "$NEXT_FILE" 2>/dev/null | tail -n +2 | awk '{print $1}' | while read -r LIB; do
        case "$LIB" in
            /opt/homebrew/*|/usr/local/*)
                if [[ -f "$LIB" ]]; then
                    DEST="$FRAMEWORKS_DIR/$(basename "$LIB")"
                    if [[ ! -f "$DEST" ]]; then
                        cp -p "$LIB" "$DEST"
                        chmod u+w "$DEST"
                    fi
                    echo "$DEST" >> "$QUEUE_FILE"
                fi
                ;;
        esac
    done
done

patch_binary() {
    local FILE="$1"
    chmod u+w "$FILE"

    if [[ "$FILE" == *.dylib ]]; then
        install_name_tool -id "@rpath/$(basename "$FILE")" "$FILE" 2>/dev/null || true
        install_name_tool -add_rpath "@loader_path" "$FILE" 2>/dev/null || true
    else
        install_name_tool -add_rpath "@executable_path/../../Frameworks" "$FILE" 2>/dev/null || true
    fi

    otool -L "$FILE" 2>/dev/null | tail -n +2 | awk '{print $1}' | while read -r LIB; do
        case "$LIB" in
            /opt/homebrew/*|/usr/local/*)
                install_name_tool -change "$LIB" "@rpath/$(basename "$LIB")" "$FILE" 2>/dev/null || true
                ;;
        esac
    done

    codesign --force --sign - "$FILE" >/dev/null 2>&1 || true
}

patch_binary "$TOOLS_DIR/ffmpeg"
find "$FRAMEWORKS_DIR" -maxdepth 1 -type f -name '*.dylib' -print | while read -r DYLIB; do
    patch_binary "$DYLIB"
done

echo "$TOOLS_DIR/ffmpeg"
