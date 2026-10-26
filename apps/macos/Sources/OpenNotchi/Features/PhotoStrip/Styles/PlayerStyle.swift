import AppKit
import CoreImage

/// The Player strip style.
extension PhotoStripComposer {
    static func playerPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: cell, xRadius: 26, yRadius: 26).addClip()
        drawAspectFill(photo, in: cell)
        NSGraphicsContext.restoreGraphicsState()
    }

    static func playerBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        // Backdrop tinted like a music app's now playing screen: from the cover art, else the photos.
        let cover = info.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        let tint = averageColor(cover ?? photos.first) ?? NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1)
        NSGradient(colors: [tint.blended(withFraction: 0.35, of: .black) ?? tint, NSColor(white: 0.06, alpha: 1)])!
            .draw(in: canvas, angle: -90)
    }

    static func playerFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let caption = footer.custom
        // The song that was playing when the strip was taken; your text becomes the "playing from" line.
        let x = rect.minX + 54
        let width = rect.width - 108
        var y = rect.minY + 30
        let title = info.songTitle ?? caption ?? "our little moments"
        let artist = info.artist ?? "you & me"
        if info.songTitle != nil, let caption {
            draw(
                "PLAYING FROM  " + caption.uppercased(), font: .systemFont(ofSize: 20, weight: .bold),
                color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: x, y: y), maxWidth: width)
            y += 34
        }
        var textX = x
        if let artwork = info.artwork {
            let thumb = CGRect(x: x, y: y + 4, width: 96, height: 96)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: thumb, xRadius: 10, yRadius: 10).addClip()
            artwork.draw(
                in: thumb, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
            textX += 116
        }
        draw(
            title, font: .systemFont(ofSize: 46, weight: .bold), color: .white, at: CGPoint(x: textX, y: y),
            maxWidth: x + width - 70 - textX)
        symbol(
            "heart.fill", color: NSColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1),
            at: CGPoint(x: x + width - 20, y: y + 32), size: 40)
        y += 60
        draw(
            artist, font: .systemFont(ofSize: 30, weight: .medium), color: NSColor(white: 1, alpha: 0.6),
            at: CGPoint(x: textX, y: y), maxWidth: x + width - 70 - textX)
        y += 82
        let duration = info.songDuration ?? 225
        let position = min(info.songPosition ?? 84, duration)
        let fraction = CGFloat(position / duration)
        fill(CGRect(x: x, y: y, width: width, height: 6), NSColor(white: 1, alpha: 0.25))
        fill(CGRect(x: x, y: y, width: width * fraction, height: 6), .white)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: x + width * fraction - 10, y: y - 7, width: 20, height: 20)).fill()
        y += 20
        func clock(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
        draw(
            clock(position), font: .monospacedDigitSystemFont(ofSize: 22, weight: .medium),
            color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: x, y: y))
        draw(
            "-" + clock(duration - position), font: .monospacedDigitSystemFont(ofSize: 22, weight: .medium),
            color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: x + width - 62, y: y))
        y += 90
        let controls: [(String, CGFloat)] = [
            ("shuffle", 32), ("backward.fill", 44), ("", 0), ("forward.fill", 44), ("repeat", 32),
        ]
        for (i, control) in controls.enumerated() {
            let center = CGPoint(x: x + 16 + (width - 32) * CGFloat(i) / 4, y: y)
            if control.0.isEmpty {
                // Play button: white disc with a dark pause glyph.
                NSColor.white.setFill()
                NSBezierPath(ovalIn: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92)).fill()
                symbol(
                    info.isPlaying ? "pause.fill" : "play.fill", color: NSColor(white: 0.1, alpha: 1), at: center,
                    size: 38)
            } else {
                symbol(control.0, color: .white, at: center, size: control.1)
            }
        }
    }

    static func averageColor(_ image: CGImage?) -> NSColor? {
        guard let image else { return nil }
        let ci = CIImage(cgImage: image)
        let average = ci.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: ci.extent)])
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return NSColor(
            srgbRed: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }
}
