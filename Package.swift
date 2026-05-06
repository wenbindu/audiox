// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AudioX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AudioX",
            targets: ["AudioX"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AudioX",
            path: "Sources/AudioX"
        )
    ]
)
