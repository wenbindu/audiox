#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_PNG="${1:-$ROOT_DIR/Resources/new.png}"
OUTPUT_ICNS="${2:-$ROOT_DIR/Resources/AppIcon.icns}"

if [[ ! -f "$SOURCE_PNG" ]]; then
    echo "Missing icon source: $SOURCE_PNG" >&2
    exit 66
fi

mkdir -p "$ROOT_DIR/.build/module-cache"
swift -module-cache-path "$ROOT_DIR/.build/module-cache" \
    "$ROOT_DIR/scripts/generate_icon.swift" \
    "$OUTPUT_ICNS" \
    "$SOURCE_PNG"

