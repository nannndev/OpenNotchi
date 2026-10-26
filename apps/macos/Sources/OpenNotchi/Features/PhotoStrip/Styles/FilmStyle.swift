import AppKit

/// The Film strip style.
extension PhotoStripComposer {
    static func filmPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        NSColor.black.setFill()
        NSBezierPath(rect: cell).fill()
        let frame = cell.insetBy(dx: 4, dy: 4)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: frame).addClip()
        drawAspectFill(photo, in: frame)
        NSGraphicsContext.restoreGraphicsState()

        let amber = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 0.9)
        amber.setStroke()
        let frameBorder = NSBezierPath(rect: cell.insetBy(dx: -2, dy: -2))
        frameBorder.lineWidth = 1
        frameBorder.stroke()

        let reg: CGFloat = 8
        for pt in [
            CGPoint(x: cell.minX - 6, y: cell.minY - 6),
            CGPoint(x: cell.maxX + 6, y: cell.minY - 6),
            CGPoint(x: cell.minX - 6, y: cell.maxY + 6),
            CGPoint(x: cell.maxX + 6, y: cell.maxY + 6),
        ] {
            let signX: CGFloat = pt.x < cell.midX ? 1 : -1
            let signY: CGFloat = pt.y < cell.midY ? 1 : -1
            let p = NSBezierPath()
            p.move(to: CGPoint(x: pt.x, y: pt.y + reg * signY))
            p.line(to: pt)
            p.line(to: CGPoint(x: pt.x + reg * signX, y: pt.y))
            p.lineWidth = 1.5
            p.stroke()
        }
    }

    static func filmBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1))
        NSColor(red: 0.92, green: 0.91, blue: 0.88, alpha: 1).setFill()
        var y: CGFloat = 24
        while y < canvas.height - 30 {
            for x in [34.0, canvas.width - 34 - 36] {
                let spRect = CGRect(x: x, y: y, width: 36, height: 50)
                NSBezierPath(roundedRect: spRect, xRadius: 8, yRadius: 8).fill()
            }
            y += 82
        }
        let amber = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 0.9)
        let leaderFont =
            NSFont(name: "Courier New Bold", size: 18) ?? .monospacedSystemFont(ofSize: 18, weight: .bold)
        draw(
            "▶ KODAK PORTRA 400  ·  5094  ·  SAFETY FILM  ·  ISO 400/27°", font: leaderFont, color: amber,
            at: CGPoint(x: 120, y: 16))
    }

    static func filmDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        let color = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1)
        let font = NSFont(name: "Courier New Bold", size: 22) ?? .monospacedSystemFont(ofSize: 22, weight: .bold)
        for (i, cell) in cells.dropLast().enumerated() {
            draw("\(i + 1)  ▸  \(i + 1)A", font: font, color: color, at: CGPoint(x: cell.minX, y: cell.maxY + 4))
            drawRotated(
                "PORTRA 400  ▸", font: font, color: color.withAlphaComponent(0.8),
                center: CGPoint(x: canvas.width - 105, y: cell.midY))
        }
    }

    static func filmFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 24
        let amber = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1)
        let font = NSFont(name: "Courier New Bold", size: 48) ?? .monospacedSystemFont(ofSize: 46, weight: .bold)
        y += centered(footer.title("KODAK PORTRA 400"), font: font, color: amber, x: center, y: y) + 4
        draw(
            "EXPOSURE: 36 EXP  ·  C-41 PROCESS  ·  COLOR NEGATIVE", font: font.withSize(21),
            color: amber.withAlphaComponent(0.8), at: CGPoint(x: center - 260, y: y))
        y += 32
        let ledFont = NSFont(name: "Courier New Bold", size: 30) ?? .monospacedSystemFont(ofSize: 30, weight: .bold)
        centered(
            "’26  10  12", font: ledFont, color: NSColor(red: 1, green: 0.45, blue: 0.15, alpha: 1), x: center,
            y: y, shadow: NSColor(red: 1, green: 0.3, blue: 0.1, alpha: 0.6))
    }
}
