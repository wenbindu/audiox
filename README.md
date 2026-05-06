# AudioX

AudioX is a macOS audio player for common audio formats and xiaozhi/ESP `.p3` files. It provides playlist playback, drag-and-drop import, loop mode, and waveform comparison.

AudioX 是一个 macOS 音频播放器，支持通用音频和 xiaozhi/乐鑫 `.p3` 文件，提供列表播放、拖拽导入、循环播放和波形对比。

## Features / 功能

- Native playback: `mp3`, `wav`, `aac`, `m4a`
- 原生播放：`mp3`, `wav`, `aac`, `m4a`
- FFmpeg fallback: `ogg`, `opus`, `flac`, `p3`
- FFmpeg fallback：`ogg`, `opus`, `flac`, `p3`
- Dedicated P3 parser for xiaozhi/ESP framed Opus streams
- xiaozhi/乐鑫 P3 帧封装 Opus 专用解析链路
- Batch import, folder drag-and-drop, de-duplication, removal, and list reordering
- 批量导入、文件夹拖拽、去重、移除和列表排序
- Playlist loop playback with current-row tracking
- 列表循环播放，并自动跟随当前播放项
- Multi-track waveform comparison
- 多音频波形对比

## Installation / 安装

Download the latest DMG from the GitHub Releases page, open it, and drag `AudioX.app` into `Applications`.

从 GitHub Releases 页面下载最新 DMG，打开后将 `AudioX.app` 拖入 `Applications`。

The packaged app does not require Xcode.

已打包 App 不需要安装 Xcode。

FFmpeg is required for `ogg`, `opus`, `flac`, and `p3` in v1:

v1 播放 `ogg`, `opus`, `flac`, `p3` 需要 FFmpeg：

```bash
brew install ffmpeg
```

## Usage / 使用

Open AudioX, import audio files or drag files/folders into the window, then select a track to play.

打开 AudioX 后，可以导入音频，也可以将文件或文件夹拖入窗口，然后选择音频播放。

Click the waveform button on playlist rows to compare tracks.

点击列表行的波形按钮可加入波形对比。

## Development / 开发

Development, build, pull request, and release instructions are in [CONTRIBUTING.md](CONTRIBUTING.md).

开发、构建、Pull Request 和发布说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## Status / 状态

AudioX v1 is macOS-only. iOS requires a separate target.

AudioX v1 仅支持 macOS。iOS 需要独立 target。

## License / 许可

No license has been selected yet.

当前尚未选择开源许可证。
