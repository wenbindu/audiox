#!/usr/bin/env swift

import AppKit
import Foundation

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/dmg-background.png"
let outputURL = URL(fileURLWithPath: outputPath)
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSourceURL = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2])
    : root.appendingPathComponent("Resources/new.png")

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let width = 720
let height = 440
let image = NSImage(size: NSSize(width: width, height: height))
let palette = Palette.from(iconSourceURL: iconSourceURL)

image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: width, height: height)

let gradient = NSGradient(colors: [
    palette.backgroundStart,
    palette.backgroundEnd
])
gradient?.draw(in: rect, angle: 28)

palette.lightOrb.setFill()
NSBezierPath(ovalIn: NSRect(x: 420, y: 230, width: 360, height: 260)).fill()
palette.darkOrb.setFill()
NSBezierPath(ovalIn: NSRect(x: -100, y: -80, width: 320, height: 240)).fill()

let title = "AudioX"
let subtitle = "Drag AudioX into Applications"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 42, weight: .bold),
    .foregroundColor: palette.text
]
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .medium),
    .foregroundColor: palette.secondaryText
]
title.draw(at: NSPoint(x: 44, y: 350), withAttributes: titleAttrs)
subtitle.draw(at: NSPoint(x: 46, y: 322), withAttributes: subtitleAttrs)

let arrow = NSBezierPath()
arrow.lineWidth = 8
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 260, y: 198))
arrow.line(to: NSPoint(x: 455, y: 198))
arrow.move(to: NSPoint(x: 428, y: 226))
arrow.line(to: NSPoint(x: 456, y: 198))
arrow.line(to: NSPoint(x: 428, y: 170))
palette.arrow.setStroke()
arrow.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to render DMG background")
}

try png.write(to: outputURL)
print(outputURL.path)

struct Palette {
    let backgroundStart: NSColor
    let backgroundEnd: NSColor
    let lightOrb: NSColor
    let darkOrb: NSColor
    let text: NSColor
    let secondaryText: NSColor
    let arrow: NSColor

    static func from(iconSourceURL: URL) -> Palette {
        guard let image = NSImage(contentsOf: iconSourceURL),
              let bitmap = image.bitmapRepresentation else {
            return fallback
        }

        let center = bitmap.averageColor(in: 0.30...0.70, y: 0.30...0.70)
        let edge = bitmap.averageColor(in: 0.00...1.00, y: 0.00...1.00)
        let start = center.adjust(saturation: 0.90, brightness: 1.08)
        let end = edge.adjust(saturation: 0.55, brightness: 1.30)
        let text = center.contrastingText

        return Palette(
            backgroundStart: start,
            backgroundEnd: end,
            lightOrb: NSColor(calibratedWhite: text.isLight ? 0 : 1, alpha: 0.12),
            darkOrb: NSColor(calibratedWhite: text.isLight ? 1 : 0, alpha: 0.08),
            text: text,
            secondaryText: text.withAlphaComponent(0.78),
            arrow: text.withAlphaComponent(0.70)
        )
    }

    static let fallback = Palette(
        backgroundStart: NSColor(calibratedRed: 0.78, green: 0.49, blue: 0.35, alpha: 1),
        backgroundEnd: NSColor(calibratedRed: 0.96, green: 0.78, blue: 0.58, alpha: 1),
        lightOrb: NSColor(calibratedWhite: 1, alpha: 0.16),
        darkOrb: NSColor(calibratedWhite: 0, alpha: 0.08),
        text: NSColor(calibratedRed: 0.20, green: 0.11, blue: 0.09, alpha: 1),
        secondaryText: NSColor(calibratedRed: 0.30, green: 0.17, blue: 0.13, alpha: 0.86),
        arrow: NSColor(calibratedRed: 0.24, green: 0.12, blue: 0.10, alpha: 0.72)
    )
}

extension NSImage {
    var bitmapRepresentation: NSBitmapImageRep? {
        guard let tiff = tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiff)
    }
}

extension NSBitmapImageRep {
    func averageColor(in xRange: ClosedRange<Double>, y yRange: ClosedRange<Double>) -> NSColor {
        let minX = max(0, Int(Double(pixelsWide) * xRange.lowerBound))
        let maxX = min(pixelsWide - 1, Int(Double(pixelsWide) * xRange.upperBound))
        let minY = max(0, Int(Double(pixelsHigh) * yRange.lowerBound))
        let maxY = min(pixelsHigh - 1, Int(Double(pixelsHigh) * yRange.upperBound))
        let step = max(1, min(pixelsWide, pixelsHigh) / 48)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var count: CGFloat = 0

        for y in stride(from: minY, through: maxY, by: step) {
            for x in stride(from: minX, through: maxX, by: step) {
                guard let color = colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                red += color.redComponent
                green += color.greenComponent
                blue += color.blueComponent
                count += 1
            }
        }

        guard count > 0 else {
            return NSColor(calibratedWhite: 0.5, alpha: 1)
        }

        return NSColor(
            calibratedRed: red / count,
            green: green / count,
            blue: blue / count,
            alpha: 1
        )
    }
}

extension NSColor {
    var luminance: CGFloat {
        guard let color = usingColorSpace(.deviceRGB) else { return 0.5 }
        return 0.2126 * color.redComponent
            + 0.7152 * color.greenComponent
            + 0.0722 * color.blueComponent
    }

    var isLight: Bool {
        luminance > 0.55
    }

    var contrastingText: NSColor {
        isLight
            ? NSColor(calibratedWhite: 0.10, alpha: 1)
            : NSColor(calibratedWhite: 0.96, alpha: 1)
    }

    func adjust(saturation: CGFloat, brightness: CGFloat) -> NSColor {
        guard let color = usingColorSpace(.deviceRGB) else { return self }
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bri: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        return NSColor(
            calibratedHue: hue,
            saturation: min(max(sat * saturation, 0), 1),
            brightness: min(max(bri * brightness, 0), 1),
            alpha: alpha
        )
    }
}
