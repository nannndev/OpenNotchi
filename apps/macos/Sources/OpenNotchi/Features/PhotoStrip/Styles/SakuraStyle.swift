import AppKit

/// The Sakura strip style.
extension PhotoStripComposer {
    static func sakuraPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 24
        withShadow(
            color: NSColor(red: 0.9, green: 0.45, blue: 0.6, alpha: 0.22), blur: 14,
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

        NSColor(red: 0.9, green: 0.55, blue: 0.68, alpha: 0.6).setStroke()
        let sBorder = NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8)
        sBorder.lineWidth = 1.5
        sBorder.stroke()

        petal(at: CGPoint(x: cell.maxX - 10, y: cell.minY + 12), size: 24, angle: 35)
    }

    static func sakuraBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        NSGradient(colors: [
            NSColor(red: 1, green: 0.95, blue: 0.97, alpha: 1),
            NSColor(red: 1, green: 0.86, blue: 0.92, alpha: 1),
        ])!.draw(in: canvas, angle: -90)
    }

    static func sakuraDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        for _ in 0..<30 {
            let p = scatter(canvas, cells, &rng)
            petal(at: p, size: .random(in: 18...34, using: &rng), angle: .random(in: 0...360, using: &rng))
        }
    }

    static func sakuraFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 20
        let pink = NSColor(red: 0.78, green: 0.25, blue: 0.45, alpha: 1)
        let scriptFont = NSFont(name: "Snell Roundhand Bold", size: 84) ?? rounded(64, .bold)
        y += centered(footer.title("sakura days"), font: scriptFont, color: pink, x: center, y: y)

        draw(
            "桜の季節  ·  SPRINGTIME MEMORIES", font: .systemFont(ofSize: 22, weight: .semibold),
            color: pink.withAlphaComponent(0.85), at: CGPoint(x: center - 170, y: y))
        y += 34

        let sealRect = CGRect(x: center - 22, y: y, width: 44, height: 44)
        NSColor(red: 0.82, green: 0.2, blue: 0.2, alpha: 0.9).setFill()
        NSBezierPath(roundedRect: sealRect, xRadius: 8, yRadius: 8).fill()
        draw(
            "桜", font: .boldSystemFont(ofSize: 24), color: .white,
            at: CGPoint(x: sealRect.minX + 10, y: sealRect.minY + 8))
        y += 52

        centered(
            footer.dateString("yyyy . MM . dd"), font: rounded(24, .semibold), color: pink.withAlphaComponent(0.75),
            x: center, y: y)
    }
}
