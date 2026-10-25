import AppKit

/// The Love strip style.
extension PhotoStripComposer {
    static func lovePhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 22
        withShadow(
            color: NSColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 0.25), blur: 16,
            offset: CGSize(width: 0, height: 4)
        ) {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
        }
        let photoFrame = cell.insetBy(dx: 12, dy: 12)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8).addClip()
        drawAspectFill(photo, in: photoFrame)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(red: 0.88, green: 0.2, blue: 0.3, alpha: 0.7).setStroke()
        let lBorder = NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8)
        lBorder.lineWidth = 1.5
        lBorder.stroke()

        symbol(
            "heart.fill", color: NSColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 0.8),
            at: CGPoint(x: cell.maxX - 16, y: cell.maxY - 16), size: 18)
    }

    static func loveBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        NSGradient(colors: [
            NSColor(red: 0.58, green: 0.08, blue: 0.16, alpha: 1),
            NSColor(red: 0.35, green: 0.04, blue: 0.09, alpha: 1),
        ])!.draw(in: canvas, angle: -90)
    }

    static func loveDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        for _ in 0..<28 {
            symbol(
                "heart.fill",
                color: NSColor(red: 1, green: 0.75, blue: 0.8, alpha: .random(in: 0.6...1, using: &rng)),
                at: scatter(canvas, cells, &rng), size: .random(in: 20...50, using: &rng))
        }
    }

    static func loveFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 18
        let loveFont = NSFont(name: "Snell Roundhand Bold", size: 88) ?? rounded(68, .bold)
        y += centered(
            footer.title("mon amour ♡"), font: loveFont, color: .white, x: center, y: y,
            shadow: NSColor(red: 0.5, green: 0, blue: 0.1, alpha: 0.6))

        let sealRect = CGRect(x: center - 26, y: y, width: 52, height: 52)
        withShadow(color: NSColor.black.withAlphaComponent(0.3), blur: 8, offset: CGSize(width: 0, height: 2)) {
            NSColor(red: 0.65, green: 0.1, blue: 0.15, alpha: 1).setFill()
            NSBezierPath(ovalIn: sealRect).fill()
        }
        symbol(
            "heart.fill", color: NSColor(red: 1, green: 0.85, blue: 0.6, alpha: 1),
            at: CGPoint(x: sealRect.midX, y: sealRect.midY), size: 24)
        y += 62

        draw(
            "PARIS  ·  AVEC AMOUR  ·  " + footer.dateString("yyyy"), font: .systemFont(ofSize: 22, weight: .semibold),
            color: .white.withAlphaComponent(0.9), at: CGPoint(x: center - 165, y: y))
    }
}
