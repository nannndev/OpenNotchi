import AppKit

/// The Polaroid strip style.
extension PhotoStripComposer {
    static func polaroidPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let bottomExtra: CGFloat = 46
        let card = cell
        withShadow(color: NSColor.black.withAlphaComponent(0.22), blur: 16, offset: CGSize(width: 1, height: 5)) {
            NSColor(red: 0.99, green: 0.985, blue: 0.97, alpha: 1).setFill()
            NSBezierPath(roundedRect: card, xRadius: 8, yRadius: 8).fill()
        }
        let photoArea = CGRect(
            x: card.minX + 16, y: card.minY + 16, width: card.width - 32, height: card.height - 32 - bottomExtra)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoArea, xRadius: 4, yRadius: 4).addClip()
        drawAspectFill(photo, in: photoArea)
        NSGraphicsContext.restoreGraphicsState()

        NSColor(white: 0, alpha: 0.15).setStroke()
        let pBorder = NSBezierPath(roundedRect: photoArea, xRadius: 4, yRadius: 4)
        pBorder.lineWidth = 1.2
        pBorder.stroke()

        // Seam line for chemical pod at the bottom
        NSColor(white: 0.85, alpha: 0.5).setStroke()
        let seam = NSBezierPath()
        seam.move(to: CGPoint(x: card.minX + 16, y: card.maxY - 14))
        seam.line(to: CGPoint(x: card.maxX - 16, y: card.maxY - 14))
        seam.lineWidth = 1
        seam.stroke()

        // Polaroid iconic 5-color rainbow block on bottom-right
        let rainbowColors: [NSColor] = [
            NSColor(red: 0.92, green: 0.22, blue: 0.21, alpha: 1),
            NSColor(red: 0.98, green: 0.52, blue: 0.16, alpha: 1),
            NSColor(red: 0.98, green: 0.82, blue: 0.18, alpha: 1),
            NSColor(red: 0.27, green: 0.72, blue: 0.38, alpha: 1),
            NSColor(red: 0.16, green: 0.62, blue: 0.88, alpha: 1),
        ]
        let barW: CGFloat = 4.5
        let barH: CGFloat = 16
        let rainbowX = card.maxX - 24 - CGFloat(rainbowColors.count) * barW
        let rainbowY = card.maxY - 32
        for (ci, c) in rainbowColors.enumerated() {
            c.setFill()
            NSBezierPath(rect: CGRect(x: rainbowX + CGFloat(ci) * barW, y: rainbowY, width: barW, height: barH))
                .fill()
        }
        draw(
            "SX-70 COLOR", font: .systemFont(ofSize: 13, weight: .bold), color: NSColor(white: 0.45, alpha: 0.65),
            at: CGPoint(x: card.minX + 20, y: card.maxY - 32))
    }

    static func polaroidBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.96, green: 0.945, blue: 0.91, alpha: 1))
    }

    static func polaroidFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let center = footer.center
        var y = rect.minY + 28
        let ink = NSColor(red: 0.12, green: 0.18, blue: 0.32, alpha: 1)
        let handFont =
            NSFont(name: "Marker Felt Wide", size: 66) ?? NSFont(name: "Noteworthy-Bold", size: 60)
            ?? rounded(60, .bold)
        y += centered(footer.title("good times ✌️"), font: handFont, color: ink, x: center, y: y) + 4
        centered(
            footer.dateString("d MMMM yyyy"),
            font: NSFont(name: "Noteworthy-Bold", size: 28) ?? .systemFont(ofSize: 28),
            color: ink.withAlphaComponent(0.75), x: center, y: y)
        y += 44
        draw(
            "★ POLAROID COLOR 600 FILM ★", font: .systemFont(ofSize: 18, weight: .bold),
            color: NSColor(white: 0.45, alpha: 0.7), at: CGPoint(x: center - 140, y: y))
    }
}
