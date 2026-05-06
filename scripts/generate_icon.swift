#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : root.appendingPathComponent("Resources/AppIcon.icns")
let sourcePNGURL = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : root.appendingPathComponent("Resources/new.png")
let iconsetURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("AppIcon.iconset")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(
    at: iconsetURL,
    withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let sizes: [(name: String, points: Int, scale: Int)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for item in sizes {
    let pixels = item.points * item.scale
    let image = drawIcon(size: pixels, sourcePNGURL: sourcePNGURL)
    let pngURL = iconsetURL.appendingPathComponent(item.name)
    try writePNG(image: image, to: pngURL)
}

try? FileManager.default.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(
        domain: "AudioXIconGenerator",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
    )
}

try? FileManager.default.removeItem(at: iconsetURL)
print(outputURL.path)

func drawIcon(size: Int, sourcePNGURL: URL) -> NSImage {
    guard FileManager.default.fileExists(atPath: sourcePNGURL.path) else {
        fatalError("Missing icon source: \(sourcePNGURL.path)")
    }

    guard let sourceImage = NSImage(contentsOf: sourcePNGURL) else {
        fatalError("Cannot read icon source: \(sourcePNGURL.path)")
    }

    return renderSourceIcon(sourceImage, size: size)
}

func renderSourceIcon(_ sourceImage: NSImage, size: Int) -> NSImage {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    rect.fill()
    NSGraphicsContext.current?.imageInterpolation = .high

    sourceImage.draw(
        in: rect,
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .sourceOver,
        fraction: 1
    )

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func writePNG(image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "AudioXIconGenerator",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to render PNG"]
        )
    }

    try stripAncillaryPNGChunks(png).write(to: url)
}

func stripAncillaryPNGChunks(_ data: Data) -> Data {
    let signature = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    guard data.count >= signature.count,
          data.prefix(signature.count) == signature else {
        return data
    }

    var output = signature
    var offset = signature.count

    while offset + 12 <= data.count {
        let length = Int(data[offset]) << 24
            | Int(data[offset + 1]) << 16
            | Int(data[offset + 2]) << 8
            | Int(data[offset + 3])
        let chunkEnd = offset + 12 + length
        guard length >= 0, chunkEnd <= data.count else {
            return data
        }

        let typeStart = offset + 4
        let type = data[typeStart..<(typeStart + 4)]
        let isCriticalChunk = (type[type.startIndex] & 0x20) == 0
        if isCriticalChunk {
            output.append(data[offset..<chunkEnd])
        }

        offset = chunkEnd
    }

    return output
}
