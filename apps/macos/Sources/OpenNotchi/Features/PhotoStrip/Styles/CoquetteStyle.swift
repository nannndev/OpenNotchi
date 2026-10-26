import AppKit

/// The Coquette strip style.
extension PhotoStripComposer {
    static func coquettePhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        withShadow(
            color: NSColor(red: 0.6, green: 0.2, blue: 0.3, alpha: 0.25), blur: 14,
            offset: CGSize(width: 0, height: 4)
        ) {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: cell, xRadius: 30, yRadius: 30).fill()
        }
        let frame = cell.insetBy(dx: 14, dy: 14)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: frame, xRadius: 20, yRadius: 20).addClip()
        drawAspectFill(photo, in: frame)
        NSGraphicsContext.restoreGraphicsState()
        emoji("🎀", size: 84, center: CGPoint(x: cell.midX, y: cell.minY + 6))
    }

    static func coquetteBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.97, green: 0.84, blue: 0.88, alpha: 1))
        // Gingham: translucent white bands both ways.
        NSColor.white.withAlphaComponent(0.32).setFill()
        for x in stride(from: 0.0, to: canvas.width, by: 80) {
            NSBezierPath(rect: CGRect(x: x, y: 0, width: 40, height: canvas.height)).fill()
        }
        for y in stride(from: 0.0, to: canvas.height, by: 80) {
            NSBezierPath(rect: CGRect(x: 0, y: y, width: canvas.width, height: 40)).fill()
        }
    }

    static func coquetteDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        for _ in 0..<22 {
            symbol(
                "heart.fill", color: NSColor.white.withAlphaComponent(.random(in: 0.5...0.9, using: &rng)),
                at: scatter(canvas, cells, &rng), size: .random(in: 16...34, using: &rng))
        }
    }

    static func coquetteFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let caption = footer.custom
        let f = DateFormatter()
        let rose = NSColor(red: 0.76, green: 0.1, blue: 0.36, alpha: 1)
        var y = rect.minY + 30
        y += centered(
            caption ?? "lovely", font: NSFont(name: "Snell Roundhand Bold", size: 96) ?? rounded(70, .bold),
            color: rose, x: rect.midX, y: y)
        f.dateFormat = "dd · MM · yyyy"
        centered(
            "🎀  " + f.string(from: info.date) + "  🎀", font: rounded(28, .semibold),
            color: rose.withAlphaComponent(0.8), x: rect.midX, y: y)
    }

    static func emoji(_ text: String, size: CGFloat, center: CGPoint) {
        let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size)])
        let s = string.size()
        string.draw(at: CGPoint(x: center.x - s.width / 2, y: center.y - s.height / 2))
    }
}
