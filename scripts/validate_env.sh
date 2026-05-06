#!/usr/bin/env bash
set -euo pipefail

printf "== AudioX 依赖环境检查 ==\n"
printf "Time: %s\n" "$(date '+%F %T')"

if command -v swift >/dev/null 2>&1; then
  printf "[OK] swift: "
  swift --version | head -n 1
else
  printf "[ERR] swift not found\n"
fi

if command -v swift >/dev/null 2>&1; then
  printf "[OK] swift package: "
  swift package --version | head -n 1
fi

if command -v xcodebuild >/dev/null 2>&1; then
  if xcodebuild -version >/tmp/audiox_xcodebuild_version.txt 2>&1; then
    printf "[OK] xcodebuild: "
    head -n 1 /tmp/audiox_xcodebuild_version.txt
  else
    printf "[WARN] xcodebuild: 仅有 Command Line Tools，未指向完整 Xcode\n"
    cat /tmp/audiox_xcodebuild_version.txt
  fi
else
  printf "[WARN] xcodebuild missing (仅命令行工具环境时常见)\n"
fi

if command -v ffmpeg >/dev/null 2>&1; then
  printf "[OK] ffmpeg: "
  ffmpeg -version | head -n 1
else
  printf "[WARN] ffmpeg missing（ogg/opus/p3 推荐）\n"
fi

printf "Path: $(xcode-select -p)\n"
