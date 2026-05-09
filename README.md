# AudioX

[简体中文](README.zh-CN.md)

AudioX is a macOS audio player for common audio formats and xiaozhi/ESP `.p3` files. It provides playlist playback, drag-and-drop import, loop mode, fast waveform preview, and multi-track waveform comparison.

## Features

- Native playback: `mp3`, `wav`, `aac`, `m4a`, `aif`, `aiff`, `caf`
- FFmpeg fallback: `ogg`, `opus`, `flac`, `p3`, raw `pcm`
- Dedicated P3 parser for xiaozhi/ESP framed Opus streams
- Batch import, folder drag-and-drop, de-duplication, removal, and list reordering
- EN / Chinese language switch
- Playlist loop playback with current-row tracking
- Multi-track waveform comparison with quick preview and full metrics update

## Installation

Requires macOS 15.0 or later.

Download the latest DMG from the GitHub Releases page, open it, and drag `AudioX.app` into `Applications`.

Choose the build for your Mac:
- `AudioX-<version>-arm64.dmg` for Apple Silicon Macs.
- `AudioX-<version>-intel.dmg` for Intel Macs.
- `AudioX-<version>-universal.dmg` for both architectures.

The packaged app bundles FFmpeg and does not require Xcode or a separate FFmpeg install.

When running from source, install FFmpeg for `ogg`, `opus`, `flac`, `p3`, and raw `pcm`:

```bash
brew install ffmpeg
```

## Usage

Open AudioX, import audio files or drag files/folders into the window, then select a track to play.

Click the waveform button on playlist rows to compare tracks.

For long audio files, AudioX shows a lightweight waveform preview first, then updates the row with full waveform data and metrics when analysis completes.

## Samples

Sample files for supported formats are available in `samples/`.

They are generated from a CC0 source audio file and include `wav`, `mp3`, `m4a`, `aac`, `flac`, `ogg`, `opus`, `p3`, `aiff`, `caf`, and raw `pcm`. See [samples/SOURCES.md](samples/SOURCES.md).

## Development

Development, build, pull request, and release instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Build

Generate the app icon when `Resources/new.png` changes:

```bash
scripts/generate_app_icon.sh
```

Build versioned DMGs:

```bash
scripts/package_dmg.sh arm64 --version 1.0.4
scripts/package_dmg.sh intel --version 1.0.4
scripts/package_dmg.sh universal --version 1.0.4
```

Output:

```text
dist/AudioX-1.0.4-arm64.dmg
dist/AudioX-1.0.4-intel.dmg
dist/AudioX-1.0.4-universal.dmg
```

## Status

AudioX v1 is macOS-only. iOS requires a separate target.

## License

AudioX is released under the [MIT License](LICENSE).
