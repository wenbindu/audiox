# AudioX

[简体中文](README.zh-CN.md)

AudioX is a macOS audio player for common audio formats and xiaozhi/ESP `.p3` files. It provides playlist playback, drag-and-drop import, loop mode, and waveform comparison.

## Features

- Native playback: `mp3`, `wav`, `aac`, `m4a`
- FFmpeg fallback: `ogg`, `opus`, `flac`, `p3`
- Dedicated P3 parser for xiaozhi/ESP framed Opus streams
- Batch import, folder drag-and-drop, de-duplication, removal, and list reordering
- EN / Chinese language switch
- Playlist loop playback with current-row tracking
- Multi-track waveform comparison

## Installation

Requires macOS 15.0 or later.

Download the latest DMG from the GitHub Releases page, open it, and drag `AudioX.app` into `Applications`.

Choose the build for your Mac:
- `AudioX-<version>-arm64.dmg` for Apple Silicon Macs.
- `AudioX-<version>-intel.dmg` for Intel Macs.
- `AudioX-<version>-universal.dmg` for both architectures.

The packaged app bundles FFmpeg and does not require Xcode or a separate FFmpeg install.

When running from source, install FFmpeg for `ogg`, `opus`, `flac`, and `p3`:

```bash
brew install ffmpeg
```

## Usage

Open AudioX, import audio files or drag files/folders into the window, then select a track to play.

Click the waveform button on playlist rows to compare tracks.

## Development

Development, build, pull request, and release instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Build

Generate the app icon when `Resources/new.png` changes:

```bash
scripts/generate_app_icon.sh
```

Build versioned DMGs:

```bash
scripts/package_dmg.sh arm64 --version 1.0.2
scripts/package_dmg.sh intel --version 1.0.2
scripts/package_dmg.sh universal --version 1.0.2
```

Output:

```text
dist/AudioX-1.0.2-arm64.dmg
dist/AudioX-1.0.2-intel.dmg
dist/AudioX-1.0.2-universal.dmg
```

## Status

AudioX v1 is macOS-only. iOS requires a separate target.

## License

No license has been selected yet.
