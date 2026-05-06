# AudioX

[简体中文](README.zh-CN.md)

AudioX is a macOS audio player for common audio formats and xiaozhi/ESP `.p3` files. It provides playlist playback, drag-and-drop import, loop mode, and waveform comparison.

## Features

- Native playback: `mp3`, `wav`, `aac`, `m4a`
- FFmpeg fallback: `ogg`, `opus`, `flac`, `p3`
- Dedicated P3 parser for xiaozhi/ESP framed Opus streams
- Batch import, folder drag-and-drop, de-duplication, removal, and list reordering
- Playlist loop playback with current-row tracking
- Multi-track waveform comparison

## Installation

Download the latest DMG from the GitHub Releases page, open it, and drag `AudioX.app` into `Applications`.

The packaged app does not require Xcode.

FFmpeg is required for `ogg`, `opus`, `flac`, and `p3` in v1:

```bash
brew install ffmpeg
```

## Usage

Open AudioX, import audio files or drag files/folders into the window, then select a track to play.

Click the waveform button on playlist rows to compare tracks.

## Development

Development, build, pull request, and release instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

## Status

AudioX v1 is macOS-only. iOS requires a separate target.

## License

No license has been selected yet.
