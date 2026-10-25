import AppKit

/// The Neon strip style.
extension PhotoStripComposer {
    static func neonPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 20
        let tubeColor: NSColor = index % 2 == 0 ? .cyan : NSColor(red: 1, green: 0.2, blue: 0.75, alpha: 1)
        let frame = cell.insetBy(dx: 8, dy: 8)

        withShadow(color: tubeColor, blur: 28, offset: .zero) {
            tubeColor.setStroke()
            let path = NSBezierPath(roundedRect: frame, xRadius: r, yRadius: r)
            path.lineWidth = 5
            path.stroke()
        }

        NSColor.white.setStroke()
        let core = NSBezierPath(roundedRect: frame, xRadius: r, yRadius: r)
        core.lineWidth = 1.8
        core.stroke()

        let inner = frame.insetBy(dx: 7, dy: 7)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: inner, xRadius: r - 6, yRadius: r - 6).addClip()
        drawAspectFill(photo, in: inner)
        NSGraphicsContext.restoreGraphicsState()
    }

    static func neonBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        NSGradient(colors: [
            NSColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 1),
            NSColor(red: 0.09, green: 0.04, blue: 0.22, alpha: 1),
        ])!.draw(in: canvas, angle: -90)
    }

    static func neonDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        for _ in 0..<14 {
            symbol(
                "sparkle",
                color: Bool.random(using: &rng) ? .cyan : NSColor(red: 1, green: 0.3, blue: 0.8, alpha: 1),
                at: scatter(canvas, cells, &rng), size: .random(in: 16...30, using: &rng))
        }
    }

    static func neonFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 24
        let pink = NSColor(red: 1, green: 0.25, blue: 0.8, alpha: 1)
        let cyan = NSColor.cyan
        let neonFont = rounded(72, .heavy)
        y += centered(footer.title("main character"), font: neonFont, color: pink, x: center, y: y, shadow: pink) + 4
        draw(
            "ネオン  ·  TOKYO NIGHTS 2026", font: .systemFont(ofSize: 24, weight: .bold), color: cyan,
            at: CGPoint(x: center - 160, y: y), maxWidth: 360)
        y += 36
        centered(
            footer.dateString("dd.MM.yyyy") + "  22:50:00", font: rounded(24, .bold), color: .white, x: center, y: y,
            shadow: cyan)
    }
}
