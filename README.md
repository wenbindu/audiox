# AudioX v1

AudioX 是一个 macOS 桌面音频播放器，使用 SwiftUI + AppKit 构建，面向通用音频和乐鑫/xiaozhi `.p3` 音频文件的快速加载、播放、排序和波形对比。

## v1 功能

- 通用音频：`mp3`, `wav`, `aac`, `m4a`
- FFmpeg 转码音频：`ogg`, `opus`, `flac`
- 乐鑫/xiaozhi P3：解析 P3 帧流，提取 Opus payload，封装为临时 Ogg Opus 后转为 WAV 播放
- 批量加载：文件选择器支持多选
- 拖拽加载：支持拖入音频文件或文件夹，文件夹会递归导入已识别音频
- 项目列表：去重、内部拖拽排序、多选移除、批量清空
- 播放控制：单曲播放、上一首、下一首、播放/暂停、停止、列表循环
- 自动跟随：循环播放进入下一首时，列表选中态和滚动位置自动跟随当前播放项
- 波形对比：可将多个音频加入对比，展示分行波形图
- 关闭行为：关闭最后一个窗口即停止播放并退出 App
- 运行引导：播放需要 FFmpeg 的格式时，如果本机缺少 FFmpeg，会提示 `brew install ffmpeg`

## 架构

AudioX 采用分层端口架构，目标是高内聚、低耦合、可替换。

- `Domain`：领域模型、播放状态、端口协议
- `Application`：播放用例、播放状态机、列表业务规则
- `Infrastructure`：AVFoundation 播放、AppKit 文件选择、FFmpeg/P3 解码、波形分析、依赖检查
- `Presentation`：SwiftUI 页面和 `PlayerViewModel`
- `App`：SwiftUI App 入口、AppKit 生命周期和文件打开回调

扩展点：

- 新音频格式接入 `AudioDecoderStrategy`
- 新波形算法接入 `WaveformAnalyzingPort`
- 新平台能力接入 `AudioFilePickerPort` 或 `DependencyCheckingPort`

## P3 支持说明

AudioX v1 的 `.p3` 支持面向 xiaozhi/乐鑫常见 P3 文件。

- P3 不是普通媒体容器，不能直接交给 FFmpeg 当作输入文件
- 每帧使用 4 字节头，格式为 big-endian `type/reserved/payload_size`
- 音频 payload 是 Opus frame
- v1 解码链路为 `P3 -> Opus packets -> temporary Ogg Opus -> temporary WAV -> AVAudioPlayer`
- 默认按 16kHz mono 处理，Ogg Opus granule 使用 48kHz 时间基

## 运行和构建依赖

运行已打包的 `AudioX.app` 不需要 Xcode。

运行依赖：

- macOS 13+
- FFmpeg，用于 `ogg`, `opus`, `flac`, `p3`

源码构建依赖：

- Xcode Command Line Tools 或完整 Xcode
- Swift 6.1+

安装 FFmpeg：

```bash
brew install ffmpeg
```

源码构建环境校验：

```bash
./scripts/validate_env.sh
```

## 开发运行

```bash
swift build
swift run AudioX
```

直接启动打包后的 App，并传入一个音频文件：

```bash
open -n dist/AudioX.app --args ~/Downloads/example.p3
```

## 构建 App

```bash
scripts/package_app.sh
```

输出：

```text
dist/AudioX.app
```

## 构建 DMG 安装包

```bash
scripts/package_dmg.sh
```

输出：

```text
dist/AudioX-1.0.0.dmg
```

说明：当前 DMG 是本地未签名安装包，适合开发和手工分发验证。正式分发还需要 Developer ID 签名和 notarization。

## 多架构构建

```bash
scripts/package_dmg.sh arm
scripts/package_dmg.sh arm64
scripts/package_dmg.sh intel
scripts/package_dmg.sh universal
```

更多说明见 [docs/BUILD_TARGETS.md](docs/BUILD_TARGETS.md)。

## GitHub Release

推送 tag 后自动构建 universal DMG 并上传到 GitHub Release：

```bash
git tag v1.0.0
git push origin v1.0.0
```

更多说明见 [docs/GITHUB_RELEASE.md](docs/GITHUB_RELEASE.md)。

## 验证方案

详细清单见 [docs/V1_RELEASE.md](docs/V1_RELEASE.md)。

最小验证：

1. 导入 `mp3`, `wav`, `m4a` 后播放、暂停、seek、停止。
2. 导入 `ogg`, `opus`, `flac`，确认 FFmpeg 转码链路可播放。
3. 导入 xiaozhi/乐鑫 `.p3`，确认可播放且可生成波形。
4. 拖入文件夹，确认递归导入和重复文件跳过。
5. 列表拖拽排序，播放末尾自动进入下一首，蓝底选中态跟随当前播放项。
6. 加入多个音频到波形对比，确认分行波形展示。
7. 点击红色关闭按钮，确认播放停止且 App 退出。

## 版本

- 当前版本：`1.0.0`
- v1 发布说明：见 [docs/V1_RELEASE.md](docs/V1_RELEASE.md)
- 后续计划：见 [docs/TODO.md](docs/TODO.md)
