import AppKit

/// The Scrapbook strip style.
extension PhotoStripComposer {
    static func scrapbookPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        // Printed photos, slightly crooked, held down with washi tape.
        let angles: [CGFloat] = [-2.2, 1.8, -1.3, 2.4]
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.translateBy(x: cell.midX, y: cell.midY)
        cg.rotate(by: angles[index % angles.count] * .pi / 180)
        cg.translateBy(x: -cell.midX, y: -cell.midY)
        let paper = cell.insetBy(dx: 18, dy: 12)
        withShadow(color: NSColor.black.withAlphaComponent(0.25), blur: 12, offset: CGSize(width: 2, height: 5)) {
            NSColor(white: 0.99, alpha: 1).setFill()
            NSBezierPath(rect: paper).fill()
        }
        let frame = paper.insetBy(dx: 18, dy: 18)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: frame).addClip()
        drawAspectFill(photo, in: frame)
        NSGraphicsContext.restoreGraphicsState()
        let tapes: [NSColor] = [
            NSColor(red: 0.62, green: 0.86, blue: 0.78, alpha: 0.8),
            NSColor(red: 0.98, green: 0.72, blue: 0.78, alpha: 0.8),
            NSColor(red: 0.98, green: 0.88, blue: 0.55, alpha: 0.8),
            NSColor(red: 0.7, green: 0.78, blue: 0.98, alpha: 0.8),
        ]
        cg.translateBy(x: paper.midX, y: paper.minY + 4)
        cg.rotate(by: (index % 2 == 0 ? -6 : 5) * .pi / 180)
        tapes[index % tapes.count].setFill()
        NSBezierPath(rect: CGRect(x: -100, y: -24, width: 200, height: 48)).fill()
        cg.restoreGState()
    }

    static func scrapbookBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.91, green: 0.86, blue: 0.77, alpha: 1))
        NSColor(red: 0.8, green: 0.72, blue: 0.6, alpha: 0.5).setFill()
        for y in stride(from: 24.0, to: canvas.height, by: 40) {
            for x in stride(from: 24.0, to: canvas.width, by: 40) {
                NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 5, height: 5)).fill()
            }
        }
    }

    static func scrapbookDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        let ink = NSColor(red: 0.23, green: 0.18, blue: 0.18, alpha: 0.75)
        let doodles = ["star", "heart", "sparkle", "sun.max", "scribble", "music.note", "camera"]
        for _ in 0..<18 {
            symbol(
                doodles.randomElement(using: &rng)!, color: ink, at: scatter(canvas, cells, &rng),
                size: .random(in: 22...40, using: &rng))
        }
    }

    static func scrapbookFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let caption = footer.custom
        let f = DateFormatter()
        let ink = NSColor(red: 0.23, green: 0.18, blue: 0.18, alpha: 1)
        var y = rect.minY + 40
        y += centered(
            caption ?? "our little adventure",
            font: NSFont(name: "Marker Felt Wide", size: 64) ?? rounded(56, .bold), color: ink, x: rect.midX, y: y)
        f.dateFormat = "dd.MM.yy"
        centered(
            "— " + f.string(from: info.date) + " —",
            font: NSFont(name: "Noteworthy-Bold", size: 30) ?? .systemFont(ofSize: 28),
            color: ink.withAlphaComponent(0.7), x: rect.midX, y: y + 10)
    }
}
