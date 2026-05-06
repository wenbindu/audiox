# AudioX v1 Release Notes

## Release

- Version: `1.0.0`
- Bundle identifier: `local.audiox.app`
- Target platform: macOS 13+
- Build output: `dist/AudioX.app`
- Installer output: `dist/AudioX-1.0.0.dmg`
- Runtime requirement: Xcode is not required for the packaged app.
- Runtime guidance: FFmpeg is prompted only when the user plays a format that needs it.

## Scope

AudioX v1 is a local macOS audio project player. It focuses on loading, organizing, playing, looping, and visually comparing audio files.

Supported workflows:

- Import one or more audio files through the open panel.
- Drag files or folders into the app.
- Recursively import recognized audio files from folders.
- Remove selected tracks or clear the whole playlist.
- Reorder tracks inside the playlist.
- Play one track, then loop through the list.
- Compare multiple tracks through generated waveform rows.

## Supported formats

- Native AVFoundation path: `mp3`, `wav`, `aac`, `m4a`
- FFmpeg fallback path: `ogg`, `opus`, `flac`
- Dedicated P3 path: `p3`

## P3 design

The P3 path is intentionally separate from the generic FFmpeg decoder.

Reason:

P3 files from the xiaozhi/ESP workflow are not regular media containers. They are framed Opus payload streams. FFmpeg cannot reliably open them directly as files.

Current implementation:

- Read 4-byte big-endian P3 headers.
- Extract Opus payload frames.
- Remux frames into a temporary Ogg Opus file.
- Use FFmpeg to decode the temporary Ogg Opus file into a temporary WAV file.
- Play and analyze the WAV file through the existing AVFoundation path.

## App icon

The v1 icon uses a warm clay background inspired by Claude-like visual tones, with a simple speaker and waveform motif. The generated resource is committed as:

- `Resources/AppIcon.icns`

The source generator is:

- `scripts/generate_icon.swift`

## Build commands

Packaged runtime only needs macOS and FFmpeg for fallback formats. Xcode/Swift are only needed when building from source.

Build the app bundle:

```bash
scripts/package_app.sh
```

Build the DMG:

```bash
scripts/package_dmg.sh
```

## Manual validation checklist

1. Launch `dist/AudioX.app`.
2. Import a `wav` file and confirm play, pause, stop, and seek.
3. Import an `mp3` or `m4a` file and confirm native playback.
4. Import an `ogg`, `opus`, or `flac` file and confirm FFmpeg fallback playback.
5. Import a xiaozhi/ESP `.p3` file and confirm playback.
6. Add at least two files to waveform comparison and confirm waveform rows render.
7. Drag a folder into the app and confirm recursive audio import.
8. Reorder playlist items by dragging inside the list.
9. Enable loop playback and confirm the selected row follows the next track.
10. Close the window and confirm playback stops and the app exits.

## Known limitations

- No saved project file yet.
- No persistent waveform cache yet.
- App bundle and DMG are unsigned.
- P3 detection is extension-based in v1.
- P3 handling targets the xiaozhi/ESP framed Opus format.
