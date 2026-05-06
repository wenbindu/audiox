# AudioX Build Targets

## macOS targets

AudioX v1 is a macOS app. The packaged app does not require Xcode at runtime.

Build native app for the current Mac:

```bash
scripts/package_app.sh
```

Build native DMG for the current Mac:

```bash
scripts/package_dmg.sh
```

Build Apple Silicon app and DMG:

```bash
scripts/package_app.sh arm
scripts/package_dmg.sh arm
scripts/package_app.sh arm64
scripts/package_dmg.sh arm64
```

Output:

```text
dist/AudioX-1.0.0-arm64.app
dist/AudioX-1.0.0-arm64.dmg
```

Build Intel app and DMG:

```bash
scripts/package_app.sh intel
scripts/package_dmg.sh intel
```

Output:

```text
dist/AudioX-1.0.0-intel.app
dist/AudioX-1.0.0-intel.dmg
```

Build universal macOS app and DMG:

```bash
scripts/package_app.sh universal
scripts/package_dmg.sh universal
```

Output:

```text
dist/AudioX-1.0.0-universal.app
dist/AudioX-1.0.0-universal.dmg
```

Notes:

- `universal` means one macOS binary containing both `arm64` and `x86_64`.
- Cross-building Intel from Apple Silicon normally works for pure Swift/AppKit code with the macOS SDK.
- If native libraries are added later, each architecture must provide matching binaries.
- FFmpeg is not bundled in v1. It is discovered from the user's machine at runtime.

## iOS target

iOS is not exported as a DMG.

To support iOS, AudioX needs a separate iOS app target because the current app uses macOS-only AppKit capabilities:

- `NSOpenPanel`
- `NSApplicationDelegate`
- macOS `.app` bundle layout
- DMG packaging

Recommended iOS plan:

1. Keep `Domain` and `Application` shared.
2. Keep decoders behind `AudioDecoderStrategy`.
3. Create an iOS `Presentation` layer using SwiftUI + `UIDocumentPickerViewController`.
4. Replace AppKit lifecycle with iOS `@main App` lifecycle.
5. Decide FFmpeg strategy for iOS: bundle a compliant FFmpeg build, replace with native codecs, or disable fallback formats.
6. Build through Xcode archive, then export an `.ipa`.

Typical iOS archive command after an iOS target exists:

```bash
xcodebuild archive \
  -scheme AudioX-iOS \
  -destination "generic/platform=iOS" \
  -archivePath dist/AudioX-iOS.xcarchive
```

Typical IPA export command after signing is configured:

```bash
xcodebuild -exportArchive \
  -archivePath dist/AudioX-iOS.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath dist/ios
```

The current v1 deliverable is macOS-only.
