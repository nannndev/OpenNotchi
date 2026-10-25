import AppKit

/// The Retro strip style.
extension PhotoStripComposer {
    static func retroPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 26
        withShadow(
            color: NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 0.22), blur: 14,
            offset: CGSize(width: 0, height: 5)
        ) {
            NSColor(red: 0.99, green: 0.96, blue: 0.9, alpha: 1).setFill()
            NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
        }
        let photoFrame = cell.insetBy(dx: 14, dy: 14)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6).addClip()
        drawAspectFill(photo, in: photoFrame)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 0.85).setStroke()
        let pRing = NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6)
        pRing.lineWidth = 3
        pRing.stroke()
    }

    static func retroBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.96, green: 0.93, blue: 0.84, alpha: 1))
        let retroColors = [
            NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1),
            NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 1),
            NSColor(red: 0.72, green: 0.18, blue: 0.14, alpha: 1),
            NSColor(red: 0.38, green: 0.18, blue: 0.10, alpha: 1),
        ]
        let stripeW: CGFloat = 10
        for (i, c) in retroColors.enumerated() {
            fill(CGRect(x: 18 + CGFloat(i) * stripeW, y: 0, width: stripeW, height: canvas.height), c)
            fill(
                CGRect(
                    x: canvas.width - 18 - CGFloat(4 - i) * stripeW, y: 0, width: stripeW, height: canvas.height), c
            )
        }
    }

    static func retroFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 20
        let brown = NSColor(red: 0.42, green: 0.2, blue: 0.1, alpha: 1)
        let orange = NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 1)
        let retroFont =
            NSFont(name: "Futura-CondensedExtraBold", size: 88) ?? NSFont(name: "Avenir-Black", size: 80)
            ?? rounded(80, .black)
        centered(footer.title("GROOVY"), font: retroFont, color: brown, x: center, y: y, shadow: orange)
        y += 92
        draw(
            "☀  SUPER 8 SOUND  ☀  CALIFORNIA 1978",
            font: NSFont(name: "Futura-Medium", size: 24) ?? .systemFont(ofSize: 24, weight: .bold), color: orange,
            at: CGPoint(x: center - 210, y: y))
        y += 34
        centered(
            footer.dateString("MMMM d, yyyy").uppercased(),
            font: NSFont(name: "Futura-Medium", size: 22) ?? .systemFont(ofSize: 22),
            color: brown.withAlphaComponent(0.8), x: center, y: y)
    }
}
