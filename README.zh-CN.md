# AudioX

[English](README.md)

AudioX 是一个 macOS 音频播放器，支持通用音频和 xiaozhi/乐鑫 `.p3` 文件，提供列表播放、拖拽导入、循环播放、快速波形预览和多音频波形对比。

## 功能

- 原生播放：`mp3`, `wav`, `aac`, `m4a`, `aif`, `aiff`, `caf`
- FFmpeg fallback：`ogg`, `opus`, `flac`, `p3`, 裸 `pcm`
- xiaozhi/乐鑫 P3 帧封装 Opus 专用解析链路
- 批量导入、文件夹拖拽、去重、移除和列表排序
- 支持 EN / 中文语言切换
- 列表循环播放，并自动跟随当前播放项
- 多音频波形对比，先显示快速预览，再更新完整指标

## 安装

需要 macOS 15.0 或更高版本。

从 GitHub Releases 页面下载最新 DMG，打开后将 `AudioX.app` 拖入 `Applications`。

根据 Mac 架构选择安装包：
- `AudioX-<version>-arm64.dmg` 用于 Apple Silicon Mac。
- `AudioX-<version>-intel.dmg` 用于 Intel Mac。
- `AudioX-<version>-universal.dmg` 同时支持两种架构。

已打包 App 内置 FFmpeg，不需要安装 Xcode，也不需要单独安装 FFmpeg。

源码运行时，播放 `ogg`, `opus`, `flac`, `p3` 和裸 `pcm` 需要安装 FFmpeg：

```bash
brew install ffmpeg
```

## 使用

打开 AudioX 后，可以导入音频，也可以将文件或文件夹拖入窗口，然后选择音频播放。

点击列表行的波形按钮可加入波形对比。

对于较长音频，AudioX 会先显示轻量级波形预览，完整分析完成后再更新完整波形和指标。

## 样本

`samples/` 中提供了支持格式的样本文件。

这些样本来自 CC0 音频源，包含 `wav`, `mp3`, `m4a`, `aac`, `flac`, `ogg`, `opus`, `p3`, `aiff`, `caf` 和裸 `pcm`。来源见 [samples/SOURCES.md](samples/SOURCES.md)。

## 开发

开发、构建、Pull Request 和发布说明见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 构建

当 `Resources/new.png` 变化时，先生成 App 图标：

```bash
scripts/generate_app_icon.sh
```

构建带版本号的 DMG：

```bash
scripts/package_dmg.sh arm64 --version 1.0.4
scripts/package_dmg.sh intel --version 1.0.4
scripts/package_dmg.sh universal --version 1.0.4
```

输出：

```text
dist/AudioX-1.0.4-arm64.dmg
dist/AudioX-1.0.4-intel.dmg
dist/AudioX-1.0.4-universal.dmg
```

## 状态

AudioX v1 仅支持 macOS。iOS 需要独立 target。

## 许可

AudioX 使用 [MIT License](LICENSE) 发布。
