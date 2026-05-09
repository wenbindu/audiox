# AudioX v1 / AudioX v1

## Summary / 概要

AudioX v1 is a macOS audio project player for common audio files and xiaozhi/ESP `.p3` files.

AudioX v1 是一个 macOS 音频项目播放器，支持通用音频和 xiaozhi/乐鑫 `.p3` 文件。

## Version / 版本

- Version / 版本：`1.0.4`
- Platform / 平台：macOS 15.0+
- App bundle / App 包：`dist/AudioX.app`
- DMG：`dist/AudioX-<version>-arm64.dmg`, `dist/AudioX-<version>-intel.dmg`, `dist/AudioX-<version>-universal.dmg`

## Formats / 格式

- Native / 原生：`mp3`, `wav`, `aac`, `m4a`, `aif`, `aiff`, `caf`
- FFmpeg fallback：`ogg`, `opus`, `flac`, raw `pcm`
- Dedicated P3 path / P3 专用链路：`p3`

## Waveform / 波形

- Long files show a lightweight waveform preview first.
- Full waveform data and metrics replace the preview after analysis completes.
- SNR is omitted when unavailable or intentionally skipped to avoid blocking UI feedback.

- 长音频会先显示轻量级波形预览。
- 完整分析完成后再更新完整波形和指标。
- SNR 不可用或为避免阻塞界面时会自动隐藏。

## P3 / P3

P3 files from xiaozhi/ESP are framed Opus payload streams, not normal media containers.

xiaozhi/乐鑫 P3 是带帧头的 Opus payload 流，不是普通媒体容器。

Current path:

当前链路：

```text
P3 -> Opus packets -> temporary Ogg Opus -> temporary WAV -> AVAudioPlayer
```

## Validation / 验证

- Import and play `wav`, `mp3`, or `m4a`.
- 导入并播放 `wav`、`mp3` 或 `m4a`。
- Import and play `ogg`, `opus`, `flac`, `p3`, or raw `pcm` with bundled FFmpeg.
- 使用内置 FFmpeg 导入并播放 `ogg`、`opus`、`flac`、`p3` 或裸 `pcm`。
- Drag files or folders into the app.
- 拖拽文件或文件夹到 App。
- Reorder playlist items and verify loop playback follows the current row.
- 拖拽排序列表，并确认循环播放时选中态跟随当前播放项。
- Compare multiple waveforms.
- 对比多个音频波形。
- Drag `samples/` into the app and verify all sample formats import.
- 将 `samples/` 拖入 App，确认所有样本格式可导入。

## License / 许可证

MIT License.

使用 MIT License。
