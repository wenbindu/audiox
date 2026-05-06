# AudioX TODO

## Done
- [x] Restore Swift 6 build compatibility.
- [x] Convert the app from single-file playback to playlist/project workflow.
- [x] Support batch import through the open panel.
- [x] Support drag-and-drop file and folder import.
- [x] Support recursive folder import with audio-extension filtering.
- [x] Deduplicate imports by normalized file path at ViewModel and UseCase boundaries.
- [x] Support multi-select removal and full playlist clearing.
- [x] Support single-track playback from the list.
- [x] Support previous/next controls and list loop playback.
- [x] Support internal list reordering.
- [x] Add waveform analysis service.
- [x] Optimize waveform analysis for long audio files with chunked reads.
- [x] Add multi-audio waveform comparison view.
- [x] Keep OGG/OPUS/FLAC playback and waveform analysis on the FFmpeg fallback path.
- [x] Add dedicated xiaozhi/ESP P3 parser and Opus remux decode path.
- [x] Keep selected row and scroll position aligned with current track during loop playback.
- [x] Stop playback and terminate the app when the last window closes.
- [x] Add v1 app icon resource.
- [x] Add local DMG packaging script.
- [x] Remove runtime dependency-check panel and guide FFmpeg installation only when playback needs it.

## Next
- [ ] Persist project files, playlist order, and comparison selection.
- [ ] Cache waveform data on disk instead of rebuilding every launch.
- [ ] Add duration/status columns for every playlist item.
- [ ] Add failed-item diagnostics and retry controls.
- [ ] Add content sniffing for `p3` and common audio containers instead of extension-only detection.
- [ ] v1.1 short term: bundle a trimmed LGPL FFmpeg binary inside `AudioX.app` for install-and-play OGG/OPUS/FLAC/P3 support.
- [ ] v1.1 short term: update decoder lookup to prefer bundled `Contents/Resources/Tools/ffmpeg`, then fall back to system PATH.
- [ ] v2 long term: remove FFmpeg dependency by decoding P3/OPUS through libopus/libogg and FLAC through libFLAC or native replacements.
- [ ] v2 long term: replace external-process decoding with an in-process PCM pipeline for lower latency and smaller distribution size.
- [ ] Add unit tests for playlist reorder/remove/loop behavior.
- [ ] Add UI smoke validation for drag import and waveform rendering.
- [ ] Add Developer ID signing and notarization for public distribution.
