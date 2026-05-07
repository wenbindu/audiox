# Build Targets / 构建目标

AudioX v1 is a macOS app. The packaged app does not require Xcode or a separate FFmpeg install at runtime.

AudioX v1 是 macOS App。运行已打包 App 不需要 Xcode，也不需要单独安装 FFmpeg。

## macOS / macOS

Native build for the current Mac:

构建当前 Mac 原生架构：

```bash
scripts/package_dmg.sh
```

Apple Silicon:

```bash
scripts/package_dmg.sh arm64 --version 1.0.2
```

Intel:

```bash
scripts/package_dmg.sh intel --version 1.0.2
```

Universal:

```bash
scripts/package_dmg.sh universal --version 1.0.2
```

`universal` contains both `arm64` and `x86_64`.

`universal` 同时包含 `arm64` 和 `x86_64`。

## iOS / iOS

iOS is not exported as a DMG.

iOS 不导出 DMG。

To support iOS, AudioX needs a separate iOS target because the current app uses macOS-only AppKit APIs.

如果要支持 iOS，需要新增独立 iOS target，因为当前 App 使用 macOS 专属 AppKit API。

Recommended direction:

推荐方向：

- Reuse `Domain` and `Application`.
- 复用 `Domain` 和 `Application`。
- Replace AppKit file picking with iOS document picking.
- 将 AppKit 文件选择替换为 iOS 文档选择。
- Decide how to handle FFmpeg or native codec libraries on iOS.
- 单独决定 iOS 上 FFmpeg 或原生解码库的方案。
