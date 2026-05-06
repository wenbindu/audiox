# AudioX

AudioX is a macOS audio player for common audio files and xiaozhi/ESP `.p3` files. It supports playlist management, drag-and-drop import, loop playback, and waveform comparison.

AudioX 是一个 macOS 音频播放器，面向通用音频和 xiaozhi/乐鑫 `.p3` 文件，支持列表管理、拖拽导入、循环播放和波形对比。

## Features / 功能

- Play `mp3`, `wav`, `aac`, `m4a` natively.
- 使用系统能力原生播放 `mp3`, `wav`, `aac`, `m4a`。
- Play `ogg`, `opus`, `flac`, `p3` through FFmpeg fallback.
- 通过 FFmpeg fallback 播放 `ogg`, `opus`, `flac`, `p3`。
- Parse xiaozhi/ESP P3 framed Opus files.
- 支持解析 xiaozhi/乐鑫 P3 帧封装的 Opus 音频。
- Batch import, folder drag-and-drop, de-duplication, removal, and internal reordering.
- 支持批量导入、文件夹拖拽、去重、移除和列表内排序。
- Loop through the playlist and keep the selected row aligned with the current track.
- 支持列表循环播放，并自动同步当前播放项的选中状态。
- Compare multiple audio waveforms.
- 支持多音频波形对比。

## Install / 安装

Download the latest DMG from GitHub Releases, open it, then drag `AudioX.app` into `Applications`.

从 GitHub Releases 下载最新 DMG，打开后将 `AudioX.app` 拖入 `Applications`。

```text
https://github.com/YOUR_NAME/audiox/releases/latest
```

The packaged app does not require Xcode.

已打包的 App 不需要安装 Xcode。

For `ogg`, `opus`, `flac`, and `p3`, install FFmpeg:

播放 `ogg`, `opus`, `flac`, `p3` 需要安装 FFmpeg：

```bash
brew install ffmpeg
```

## Usage / 使用

Open the app, import audio files or drag files/folders into the window, then select a track to play.

打开 App 后，可通过导入按钮选择音频，也可以直接将文件或文件夹拖入窗口，然后选择音频播放。

To compare waveforms, click the waveform button on playlist rows.

如需对比波形，点击列表行里的波形按钮。

## Supported formats / 支持格式

- Native / 原生：`mp3`, `wav`, `aac`, `m4a`
- FFmpeg fallback：`ogg`, `opus`, `flac`
- Dedicated P3 path / P3 专用链路：`p3`

## Development / 开发

See [CONTRIBUTING.md](CONTRIBUTING.md) for development, build, pull request, and release steps.

开发、构建、Pull Request 和发布流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## License / 许可

No license has been selected yet.

当前尚未选择开源许可证。
