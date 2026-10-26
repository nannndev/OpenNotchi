import AppKit

/// The Midnight strip style.
extension PhotoStripComposer {
    static func midnightPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 16
        withShadow(color: NSColor.black.withAlphaComponent(0.4), blur: 20, offset: CGSize(width: 0, height: 6)) {
            NSColor(white: 0.08, alpha: 1).setFill()
            NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
        }
        let photoFrame = cell.insetBy(dx: 6, dy: 6)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: r - 4, yRadius: r - 4).addClip()
        drawAspectFill(photo, in: photoFrame)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.28).setStroke()
        let rim = NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r)
        rim.lineWidth = 1.5
        rim.stroke()

        draw(
            "[ ARCHIVE // 0\(index + 1) ]", font: .monospacedSystemFont(ofSize: 12, weight: .bold),
            color: NSColor(white: 1, alpha: 0.65), at: CGPoint(x: cell.minX + 16, y: cell.minY + 12))
    }

    static func midnightBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        NSGradient(colors: [
            NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1),
            NSColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1),
        ])!
        .draw(in: canvas, angle: -90)
        let rim = canvas.insetBy(dx: 18, dy: 18)
        NSColor.white.withAlphaComponent(0.12).setStroke()
        let rPath = NSBezierPath(roundedRect: rim, xRadius: 8, yRadius: 8)
        rPath.lineWidth = 1
        rPath.stroke()
    }

    static func midnightDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        for _ in 0..<16 {
            symbol(
                "sparkle", color: NSColor.white.withAlphaComponent(.random(in: 0.2...0.6, using: &rng)),
                at: scatter(canvas, cells, &rng), size: .random(in: 14...24, using: &rng))
        }
    }

    static func midnightFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        let custom = footer.custom
        var y = rect.minY + 28
        let luxuryFont =
            NSFont(name: "Didot-Bold", size: 56) ?? NSFont(name: "Times New Roman Bold", size: 54)
            ?? rounded(52, .heavy)
        let mainTitle = custom ?? "OPENNOTCHI ARCHIVE"
        let attr: [NSAttributedString.Key: Any] = [
            .font: luxuryFont,
            .foregroundColor: NSColor.white,
            .kern: 3.5,
        ]
        let str = NSAttributedString(string: mainTitle, attributes: attr)
        let w = min(str.size().width, rect.width - 80)
        str.draw(at: CGPoint(x: center - w / 2, y: y))
        y += 68

        draw(
            "COLLECTION N° 01  ·  PRIVATE EXHIBITION", font: .systemFont(ofSize: 20, weight: .semibold),
            color: NSColor(white: 0.65, alpha: 1), at: CGPoint(x: center - 190, y: y))
        y += 30
        draw(
            "№ 0084 / LIMITED EDITION", font: .monospacedSystemFont(ofSize: 17, weight: .bold),
            color: NSColor(white: 0.5, alpha: 1), at: CGPoint(x: center - 110, y: y))
        y += 28
        centered(
            footer.dateString("yyyy.MM.dd  ·  HH:mm:ss") + " UTC",
            font: .monospacedDigitSystemFont(ofSize: 19, weight: .medium), color: NSColor(white: 0.45, alpha: 1),
            x: center, y: y)
    }
}
