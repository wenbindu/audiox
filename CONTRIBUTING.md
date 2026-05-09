# Contributing / 贡献指南

## Setup / 环境准备

Requirements:

依赖：

- macOS 15.0+
- Xcode Command Line Tools or Xcode
- Swift 6.1+
- FFmpeg for source runs and bundled release packaging. Release DMGs include FFmpeg.

```bash
brew install ffmpeg
./scripts/validate_env.sh
```

## Development / 本地开发

Run from source:

源码运行：

```bash
swift build
swift run AudioX
```

Run with a local file:

携带本地音频启动：

```bash
open -n dist/AudioX.app --args ~/Downloads/example.p3
```

## Build / 构建

Build the current Mac app:

构建当前机器架构的 App：

```bash
scripts/generate_app_icon.sh
scripts/package_app.sh
```

Build macOS DMGs:

构建 macOS DMG：

```bash
scripts/generate_app_icon.sh
scripts/package_dmg.sh arm64 --version 1.0.4
scripts/package_dmg.sh intel --version 1.0.4
scripts/package_dmg.sh universal --version 1.0.4
```

Other targets:

其他目标：

```bash
scripts/package_dmg.sh arm64
scripts/package_dmg.sh intel
```

## Pull request / 提交 PR

Before opening a PR:

提交 PR 前：

- Keep changes focused.
- 保持改动聚焦。
- Run `swift build`.
- 执行 `swift build`。
- Update docs if behavior changes.
- 行为变化时同步更新文档。
- Do not commit `dist/`, `.build/`, `.app`, or `.dmg` files.
- 不要提交 `dist/`、`.build/`、`.app` 或 `.dmg` 文件。

Suggested flow:

推荐流程：

```bash
git checkout -b feature/your-change
swift build
git add .
git commit -m "Describe your change"
git push -u origin feature/your-change
```

Then open a pull request on GitHub.

然后在 GitHub 上创建 Pull Request。

## Release / 发布

Releases are built by GitHub Actions.

Release 由 GitHub Actions 构建。

Create and push a version tag:

创建并推送版本 tag：

```bash
git tag v1.0.4
git push origin v1.0.4
```

The workflow builds `arm64`, `intel`, and `universal` DMGs with bundled FFmpeg and uploads them to GitHub Releases.

Workflow 会构建带内置 FFmpeg 的 `arm64`、`intel` 和 `universal` 三个 DMG，并上传到 GitHub Releases。

If the tag was pushed before the workflow existed, open GitHub Actions and run `Release DMG` manually with the same tag.

如果 tag 早于 workflow 推送，请在 GitHub Actions 页面手动运行 `Release DMG`，并填写同一个 tag。

## License / 许可证

By contributing, you agree that your contribution is licensed under the MIT License.

提交贡献即表示你同意相关贡献以 MIT License 授权。
