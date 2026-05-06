# AudioX

[English](README.md)

AudioX 是一个 macOS 音频播放器，支持通用音频和 xiaozhi/乐鑫 `.p3` 文件，提供列表播放、拖拽导入、循环播放和波形对比。

## 功能

- 原生播放：`mp3`, `wav`, `aac`, `m4a`
- FFmpeg fallback：`ogg`, `opus`, `flac`, `p3`
- xiaozhi/乐鑫 P3 帧封装 Opus 专用解析链路
- 批量导入、文件夹拖拽、去重、移除和列表排序
- 列表循环播放，并自动跟随当前播放项
- 多音频波形对比

## 安装

需要 macOS 26.0 或更高版本。

从 GitHub Releases 页面下载最新 DMG，打开后将 `AudioX.app` 拖入 `Applications`。

已打包 App 不需要安装 Xcode。

v1 播放 `ogg`, `opus`, `flac`, `p3` 需要 FFmpeg：

```bash
brew install ffmpeg
```

## 使用

打开 AudioX 后，可以导入音频，也可以将文件或文件夹拖入窗口，然后选择音频播放。

点击列表行的波形按钮可加入波形对比。

## 开发

开发、构建、Pull Request 和发布说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 状态

AudioX v1 仅支持 macOS。iOS 需要独立 target。

## 许可

当前尚未选择开源许可证。
