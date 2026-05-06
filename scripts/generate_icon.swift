#!/usr/bin/env swift

import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : root.appendingPathComponent("Resources/AppIcon.icns")
let sourcePNGURL = root.appendingPathComponent("Resources/new.png")
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
    if FileManager.default.fileExists(atPath: sourcePNGURL.path),
       let sourceImage = NSImage(contentsOf: sourcePNGURL) {
        return renderSourceIcon(sourceImage, size: size)
    }

    return renderFallbackIcon(size: size)
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

func renderFallbackIcon(size: Int) -> NSImage {
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

    let background = NSBezierPath(
        roundedRect: rect.insetBy(dx: CGFloat(size) * 0.035, dy: CGFloat(size) * 0.035),
        xRadius: CGFloat(size) * 0.22,
        yRadius: CGFloat(size) * 0.22
    )
    NSColor(calibratedRed: 0.76, green: 0.43, blue: 0.30, alpha: 1).setFill()
    background.fill()

    let glow = NSBezierPath(ovalIn: NSRect(
        x: CGFloat(size) * 0.08,
        y: CGFloat(size) * 0.58,
        width: CGFloat(size) * 0.58,
        height: CGFloat(size) * 0.34
    ))
    NSColor(calibratedRed: 0.96, green: 0.77, blue: 0.58, alpha: 0.33).setFill()
    glow.fill()

    let baseShadow = NSBezierPath(
        roundedRect: NSRect(
            x: CGFloat(size) * 0.19,
            y: CGFloat(size) * 0.22,
            width: CGFloat(size) * 0.62,
            height: CGFloat(size) * 0.52
        ),
        xRadius: CGFloat(size) * 0.12,
        yRadius: CGFloat(size) * 0.12
    )
    NSColor(calibratedWhite: 0.10, alpha: 0.16).setFill()
    baseShadow.fill()

    drawSpeaker(size: CGFloat(size))
    drawWaveform(size: CGFloat(size))
    drawHighlight(size: CGFloat(size))

    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(rep)
    return image
}

func drawSpeaker(size: CGFloat) {
    let bodyRect = NSRect(
        x: size * 0.21,
        y: size * 0.36,
        width: size * 0.18,
        height: size * 0.24
    )
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: size * 0.045, yRadius: size * 0.045)

    let horn = NSBezierPath()
    horn.move(to: NSPoint(x: size * 0.37, y: size * 0.37))
    horn.line(to: NSPoint(x: size * 0.55, y: size * 0.25))
    horn.line(to: NSPoint(x: size * 0.55, y: size * 0.71))
    horn.line(to: NSPoint(x: size * 0.37, y: size * 0.59))
    horn.close()

    NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.73, alpha: 1).setFill()
    body.fill()
    horn.fill()

    NSColor(calibratedRed: 0.33, green: 0.18, blue: 0.14, alpha: 0.35).setStroke()
    body.lineWidth = size * 0.014
    horn.lineWidth = size * 0.014
    body.stroke()
    horn.stroke()
}

func drawWaveform(size: CGFloat) {
    let path = NSBezierPath()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = size * 0.035

    let points = [
        NSPoint(x: size * 0.59, y: size * 0.42),
        NSPoint(x: size * 0.64, y: size * 0.58),
        NSPoint(x: size * 0.70, y: size * 0.32),
        NSPoint(x: size * 0.76, y: size * 0.66),
        NSPoint(x: size * 0.82, y: size * 0.44)
    ]

    path.move(to: points[0])
    for point in points.dropFirst() {
        path.line(to: point)
    }

    NSColor(calibratedRed: 0.24, green: 0.12, blue: 0.10, alpha: 0.94).setStroke()
    path.stroke()

    let dot = NSBezierPath(ovalIn: NSRect(
        x: size * 0.615,
        y: size * 0.675,
        width: size * 0.06,
        height: size * 0.06
    ))
    NSColor(calibratedRed: 1.00, green: 0.90, blue: 0.71, alpha: 0.92).setFill()
    dot.fill()
}

func drawHighlight(size: CGFloat) {
    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: size * 0.18, y: size * 0.76))
    highlight.curve(
        to: NSPoint(x: size * 0.49, y: size * 0.83),
        controlPoint1: NSPoint(x: size * 0.25, y: size * 0.88),
        controlPoint2: NSPoint(x: size * 0.39, y: size * 0.87)
    )
    highlight.lineCapStyle = .round
    highlight.lineWidth = size * 0.022
    NSColor(calibratedRed: 1.00, green: 0.87, blue: 0.68, alpha: 0.40).setStroke()
    highlight.stroke()
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
