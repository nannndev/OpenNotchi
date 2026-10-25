import AppKit

/// The Classic strip style.
extension PhotoStripComposer {
    static func classicPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let card = cell
        withShadow(color: NSColor.black.withAlphaComponent(0.12), blur: 12, offset: CGSize(width: 0, height: 3)) {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10).fill()
        }
        let photoFrame = card.insetBy(dx: 12, dy: 12)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: 6, yRadius: 6).addClip()
        drawAspectFill(photo, in: photoFrame)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(white: 0, alpha: 0.08).setStroke()
        let innerStroke = NSBezierPath(roundedRect: photoFrame, xRadius: 6, yRadius: 6)
        innerStroke.lineWidth = 1
        innerStroke.stroke()

        // 4 corner crosshair markers
        let crossSize: CGFloat = 6
        let crossColor = NSColor(white: 0.4, alpha: 0.35)
        crossColor.setStroke()
        for pt in [
            CGPoint(x: card.minX + 6, y: card.minY + 6),
            CGPoint(x: card.maxX - 6, y: card.minY + 6),
            CGPoint(x: card.minX + 6, y: card.maxY - 6),
            CGPoint(x: card.maxX - 6, y: card.maxY - 6),
        ] {
            let p = NSBezierPath()
            p.move(to: CGPoint(x: pt.x - crossSize, y: pt.y))
            p.line(to: CGPoint(x: pt.x + crossSize, y: pt.y))
            p.move(to: CGPoint(x: pt.x, y: pt.y - crossSize))
            p.line(to: CGPoint(x: pt.x, y: pt.y + crossSize))
            p.lineWidth = 1
            p.stroke()
        }
    }

    static func classicBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.985, green: 0.982, blue: 0.975, alpha: 1))
        let innerCard = canvas.insetBy(dx: 20, dy: 20)
        NSColor(white: 0, alpha: 0.08).setStroke()
        let borderPath = NSBezierPath(roundedRect: innerCard, xRadius: 10, yRadius: 10)
        borderPath.lineWidth = 1.2
        borderPath.stroke()

        let studioFont = NSFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
        let studioStr = NSAttributedString(
            string: "✦  KOREA SELF PHOTO BOOTH  ·  AUTOMATIC STUDIO  ✦",
            attributes: [
                .font: studioFont,
                .foregroundColor: NSColor(white: 0.35, alpha: 0.8),
                .kern: 2.0,
            ])
        let sSize = studioStr.size()
        studioStr.draw(at: CGPoint(x: canvas.midX - sSize.width / 2, y: innerCard.minY + 16))
    }

    static func classicFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let center = footer.center
        var y = rect.minY + 28
        let titleFont =
            NSFont(name: "Avenir-Black", size: 60) ?? NSFont(name: "Helvetica-Bold", size: 58)
            ?? rounded(58, .heavy)
        let titleText = footer.title("LIFE FOUR CUTS").uppercased()
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(white: 0.1, alpha: 1),
            .kern: 3.5,
        ]
        let tStr = NSAttributedString(string: titleText, attributes: titleAttr)
        let tW = min(tStr.size().width, rect.width - 80)
        tStr.draw(at: CGPoint(x: center - tW / 2, y: y))
        y += 66

        draw(
            "MEMORIES OF THE DAY · HARU PHOTO STUDIO", font: .systemFont(ofSize: 20, weight: .semibold),
            color: NSColor(white: 0.45, alpha: 1), at: CGPoint(x: center - 215, y: y))
        y += 30

        centered(
            footer.dateString("yyyy.MM.dd  ·  HH:mm"), font: .monospacedDigitSystemFont(ofSize: 21, weight: .medium),
            color: NSColor(white: 0.5, alpha: 1), x: center, y: y)
        y += 34

        // Authentic Photobooth Barcode
        let ink = NSColor(white: 0.15, alpha: 1)
        ink.setFill()
        var rng = SeededRandom(seed: UInt64(info.date.timeIntervalSince1970) / 100)
        var bx = center - 160
        while bx < center + 160 {
            let bw = CGFloat.random(in: 2...6, using: &rng)
            NSBezierPath(rect: CGRect(x: bx, y: y, width: bw, height: 40)).fill()
            bx += bw + .random(in: 2...5, using: &rng)
        }
        draw(
            "PHOTO ID: #042918 · AUTOMATIC SYSTEM", font: .monospacedSystemFont(ofSize: 13, weight: .bold),
            color: NSColor(white: 0.4, alpha: 0.8), at: CGPoint(x: center - 138, y: y + 46))
    }
}
