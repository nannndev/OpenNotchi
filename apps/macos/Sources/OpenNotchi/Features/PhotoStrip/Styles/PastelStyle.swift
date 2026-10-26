import AppKit

/// The Pastel strip style.
extension PhotoStripComposer {
    static func pastelPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 20
        withShadow(
            color: NSColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 0.14), blur: 12,
            offset: CGSize(width: 0, height: 4)
        ) {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
        }
        let photoFrame = cell.insetBy(dx: 14, dy: 14)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8).addClip()
        drawAspectFill(photo, in: photoFrame)
        NSGraphicsContext.restoreGraphicsState()

        let tapes: [NSColor] = [
            NSColor(red: 0.98, green: 0.78, blue: 0.82, alpha: 0.85),
            NSColor(red: 0.72, green: 0.9, blue: 0.82, alpha: 0.85),
            NSColor(red: 0.98, green: 0.92, blue: 0.65, alpha: 0.85),
            NSColor(red: 0.82, green: 0.84, blue: 0.98, alpha: 0.85),
        ]
        tapes[index % tapes.count].setFill()
        let tapeW: CGFloat = 110
        let tapeH: CGFloat = 26
        let tapeRect = CGRect(x: cell.midX - tapeW / 2, y: cell.minY - 4, width: tapeW, height: tapeH)
        NSBezierPath(roundedRect: tapeRect, xRadius: 4, yRadius: 4).fill()
    }

    static func pastelBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.92, green: 0.97, blue: 0.94, alpha: 1))
        let gridColor = NSColor(red: 0.65, green: 0.82, blue: 0.75, alpha: 0.35)
        gridColor.setStroke()
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 1
        for x in stride(from: 24.0, to: canvas.width, by: 32) {
            gridPath.move(to: CGPoint(x: x, y: 0))
            gridPath.line(to: CGPoint(x: x, y: canvas.height))
        }
        for y in stride(from: 24.0, to: canvas.height, by: 32) {
            gridPath.move(to: CGPoint(x: 0, y: y))
            gridPath.line(to: CGPoint(x: canvas.width, y: y))
        }
        gridPath.stroke()
    }

    static func pastelDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        let stickers = ["sparkle", "heart.fill", "cloud.fill", "sun.max.fill", "star.fill"]
        let colors = [
            NSColor(red: 0.98, green: 0.72, blue: 0.78, alpha: 0.75),
            NSColor(red: 0.65, green: 0.82, blue: 0.75, alpha: 0.75),
            NSColor(red: 0.98, green: 0.88, blue: 0.55, alpha: 0.75),
            NSColor(red: 0.75, green: 0.82, blue: 0.98, alpha: 0.75),
        ]
        for _ in 0..<16 {
            symbol(
                stickers.randomElement(using: &rng)!, color: colors.randomElement(using: &rng)!,
                at: scatter(canvas, cells, &rng), size: .random(in: 18...34, using: &rng))
        }
    }

    static func pastelFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 22
        let green = NSColor(red: 0.12, green: 0.45, blue: 0.35, alpha: 1)
        y += centered(footer.title("core memories ♡"), font: rounded(64, .heavy), color: green, x: center, y: y) + 2
        draw(
            "— today was pure magic ✨ —",
            font: NSFont(name: "Noteworthy-Bold", size: 26) ?? .systemFont(ofSize: 26),
            color: green.withAlphaComponent(0.8), at: CGPoint(x: center - 150, y: y))
        y += 36
        centered(
            footer.dateString("EEEE, d MMMM yyyy"), font: rounded(24, .semibold), color: green.withAlphaComponent(0.7),
            x: center, y: y)
    }
}
