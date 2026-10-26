import AppKit
import CoreImage

/// The Album strip style.
extension PhotoStripComposer {
    static func albumPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 16
        withShadow(color: NSColor.black.withAlphaComponent(0.35), blur: 16, offset: CGSize(width: 0, height: 5)) {
            NSColor(white: 0.15, alpha: 0.9).setFill()
            NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
        }
        let photoFrame = cell.insetBy(dx: 8, dy: 8)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6).addClip()
        drawAspectFill(photo, in: photoFrame)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.3).setStroke()
        let aBorder = NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6)
        aBorder.lineWidth = 1.2
        aBorder.stroke()

        draw(
            "TRACK 0\(index + 1)", font: .monospacedSystemFont(ofSize: 13, weight: .bold),
            color: NSColor.white.withAlphaComponent(0.7), at: CGPoint(x: cell.minX + 16, y: cell.minY + 12))
    }

    static func albumBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        if let artwork = info.artwork, let cg = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let blurred = CIImage(cgImage: cg)
                .clampedToExtent()
                .applyingFilter(
                    "CIGaussianBlur", parameters: [kCIInputRadiusKey: Double(max(cg.width, cg.height)) / 12]
                )
                .cropped(to: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            if let output = ciContext.createCGImage(blurred, from: blurred.extent) {
                drawAspectFill(output, in: canvas)
            }
            fill(canvas, NSColor.black.withAlphaComponent(0.45))
        } else {
            fill(canvas, NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1))
            NSColor.white.withAlphaComponent(0.06).setStroke()
            let discRect = CGRect(x: canvas.midX - 350, y: -100, width: 700, height: 700)
            for dr in stride(from: 20.0, to: 320.0, by: 30.0) {
                let ring = NSBezierPath(ovalIn: discRect.insetBy(dx: dr, dy: dr))
                ring.lineWidth = 1.2
                ring.stroke()
            }
        }
    }

    static func albumFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let center = footer.center
        let custom = footer.custom
        let y = rect.minY + 24
        let thumb: CGFloat = 130
        let text = info.songTitle ?? "Midnight Drive"
        let sub = info.artist ?? "The Placeholders"
        let titleFont = rounded(46, .heavy)
        let titleWidth = min(
            NSAttributedString(string: text, attributes: [.font: titleFont]).size().width, rect.width - thumb - 220)
        let startX = center - (thumb + 30 + titleWidth) / 2

        if let artwork = info.artwork {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(
                roundedRect: CGRect(x: startX, y: y, width: thumb, height: thumb), xRadius: 14, yRadius: 14
            ).addClip()
            artwork.draw(
                in: CGRect(x: startX, y: y, width: thumb, height: thumb), from: .zero, operation: .sourceOver,
                fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            let discRect = CGRect(x: startX, y: y, width: thumb, height: thumb)
            NSColor(white: 0.12, alpha: 1).setFill()
            NSBezierPath(ovalIn: discRect).fill()
            NSColor.white.withAlphaComponent(0.2).setStroke()
            for dr: CGFloat in [18, 32, 46] {
                let p = NSBezierPath(ovalIn: discRect.insetBy(dx: dr, dy: dr))
                p.lineWidth = 1
                p.stroke()
            }
            NSColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1).setFill()
            NSBezierPath(ovalIn: discRect.insetBy(dx: 45, dy: 45)).fill()
            symbol("music.note", color: .white, at: CGPoint(x: discRect.midX, y: discRect.midY), size: 20)
        }

        let textX = startX + thumb + 26
        draw(
            custom ?? "♪ NOW PLAYING", font: rounded(20, .bold), color: .white.withAlphaComponent(0.7),
            at: CGPoint(x: textX, y: y + 2), maxWidth: rect.width - thumb - 100)
        draw(text, font: titleFont, color: .white, at: CGPoint(x: textX, y: y + 28), maxWidth: titleWidth)
        draw(
            sub, font: rounded(26, .medium), color: .white.withAlphaComponent(0.75),
            at: CGPoint(x: textX, y: y + 84), maxWidth: titleWidth)

        let badgeY = y + 140
        draw(
            "[ HI-RES AUDIO · STEREO ]", font: .monospacedSystemFont(ofSize: 16, weight: .bold),
            color: NSColor(white: 1, alpha: 0.55), at: CGPoint(x: startX, y: badgeY))

        var wx = startX + 240
        NSColor(white: 1, alpha: 0.65).setFill()
        let heights: [CGFloat] = [12, 22, 16, 28, 34, 20, 14, 30, 24, 18, 26, 12]
        for h in heights {
            NSBezierPath(
                roundedRect: CGRect(x: wx, y: badgeY + 16 - h, width: 4, height: h), xRadius: 2, yRadius: 2
            ).fill()
            wx += 8
        }
    }
}
