import AppKit
import SwiftUI

/// Dominant colors pulled from the current album artwork.
struct ArtworkPalette: Equatable {
    let primary: NSColor
    let secondary: NSColor

    /// Bright, saturated version of the primary color, readable on dark backgrounds.
    var accent: Color { Color(nsColor: primary.adjusted(minSaturation: 0.4, minBrightness: 0.8)) }

    /// Dark versions for backgrounds behind white text.
    var backgroundTop: Color { Color(nsColor: primary.adjusted(maxBrightness: 0.38)) }
    var backgroundBottom: Color { Color(nsColor: secondary.adjusted(maxBrightness: 0.22)) }

    static func extract(from image: NSImage) -> ArtworkPalette? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let size = 32
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        // Bucket pixels into a coarse 8×8×8 color cube.
        var buckets: [Int: (count: Int, r: Double, g: Double, b: Double)] = [:]
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
            let key = (Int(r * 7.99) << 6) | (Int(g * 7.99) << 3) | Int(b * 7.99)
            let current = buckets[key] ?? (0, 0, 0, 0)
            buckets[key] = (current.count + 1, current.r + r, current.g + g, current.b + b)
        }

        // Prefer common colors, but favor saturated ones over greys, black and white.
        let scored: [(color: NSColor, score: Double)] = buckets.values.map { bucket in
            let n = Double(bucket.count)
            let color = NSColor(srgbRed: bucket.r / n, green: bucket.g / n, blue: bucket.b / n, alpha: 1)
            let s = Double(color.saturationComponent), v = Double(color.brightnessComponent)
            var weight = 0.15 + s
            if v < 0.15 { weight *= 0.1 }
            if v > 0.92 && s < 0.12 { weight *= 0.2 }
            return (color, n * weight)
        }.sorted { $0.score > $1.score }

        guard let primary = scored.first?.color else { return nil }
        let secondary = scored.dropFirst().first { abs($0.color.hueComponent - primary.hueComponent) > 0.08 }?.color
            ?? primary.adjusted(maxBrightness: 0.5)
        return ArtworkPalette(primary: primary, secondary: secondary)
    }
}

extension NSColor {
    func adjusted(minSaturation: CGFloat = 0, minBrightness: CGFloat = 0, maxBrightness: CGFloat = 1) -> NSColor {
        let rgb = usingColorSpace(.sRGB) ?? self
        let saturation = rgb.saturationComponent < 0.08 ? rgb.saturationComponent : max(rgb.saturationComponent, minSaturation)
        let brightness = min(max(rgb.brightnessComponent, minBrightness), maxBrightness)
        return NSColor(hue: rgb.hueComponent, saturation: saturation, brightness: brightness, alpha: 1)
    }
}
