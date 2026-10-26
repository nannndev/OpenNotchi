import AppKit

/// The Y2K strip style.
extension PhotoStripComposer {
    static func y2kPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        let r: CGFloat = 28
        withShadow(
            color: NSColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 0.3), blur: 16,
            offset: CGSize(width: 0, height: 5)
        ) {
            NSColor.white.setFill()
            NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
        }
        let photoFrame = cell.insetBy(dx: 10, dy: 10)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8).addClip()
        drawAspectFill(photo, in: photoFrame)

        // Camcorder OSD Overlay
        NSColor(red: 1, green: 0.15, blue: 0.2, alpha: 1).setFill()
        NSBezierPath(ovalIn: CGRect(x: photoFrame.minX + 16, y: photoFrame.minY + 16, width: 14, height: 14)).fill()
        draw(
            "REC", font: .boldSystemFont(ofSize: 15), color: .white,
            at: CGPoint(x: photoFrame.minX + 36, y: photoFrame.minY + 14))
        draw(
            "SP  00:0\(index + 1):28", font: .monospacedDigitSystemFont(ofSize: 14, weight: .bold), color: .white,
            at: CGPoint(x: photoFrame.minX + 78, y: photoFrame.minY + 15))

        draw(
            "HQ 4:3  [▮▮▯]", font: .boldSystemFont(ofSize: 14), color: .white,
            at: CGPoint(x: photoFrame.maxX - 110, y: photoFrame.minY + 14))

        let fSize: CGFloat = 22
        let fColor = NSColor.white.withAlphaComponent(0.7)
        fColor.setStroke()
        let reticle = NSBezierPath()
        reticle.move(to: CGPoint(x: photoFrame.midX - fSize, y: photoFrame.midY))
        reticle.line(to: CGPoint(x: photoFrame.midX + fSize, y: photoFrame.midY))
        reticle.move(to: CGPoint(x: photoFrame.midX, y: photoFrame.midY - fSize))
        reticle.line(to: CGPoint(x: photoFrame.midX, y: photoFrame.midY + fSize))
        reticle.lineWidth = 1.5
        reticle.stroke()

        draw(
            "'04 10 12", font: .monospacedDigitSystemFont(ofSize: 16, weight: .bold),
            color: NSColor(red: 1, green: 0.65, blue: 0.15, alpha: 0.95),
            at: CGPoint(x: photoFrame.minX + 16, y: photoFrame.maxY - 26))

        NSGraphicsContext.restoreGraphicsState()
    }

    static func y2kBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        NSGradient(colors: [
            NSColor(red: 1, green: 0.58, blue: 0.88, alpha: 1),
            NSColor(red: 0.64, green: 0.52, blue: 1, alpha: 1),
            NSColor(red: 0.48, green: 0.86, blue: 1, alpha: 1),
        ])!.draw(in: canvas, angle: -70)
    }

    static func y2kDecorations(_ canvas: CGRect, avoid cells: [CGRect], rng: inout SeededRandom) {
        for _ in 0..<26 {
            let size = CGFloat.random(in: 22...54, using: &rng)
            symbol(
                Bool.random(using: &rng) ? "sparkle" : "star.fill", color: .white, at: scatter(canvas, cells, &rng),
                size: size)
        }
    }

    static func y2kFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let center = footer.center
        let custom = footer.custom
        var y = rect.minY + 24
        let y2kTitle = custom.map { "✦ \($0) ✦" } ?? "✦ cyber besties ✦"
        y +=
            centered(
                y2kTitle, font: rounded(68, .black), color: .white, x: center, y: y,
                shadow: NSColor(red: 0.5, green: 0.2, blue: 0.9, alpha: 0.8)) + 4

        let barRect = CGRect(x: center - 210, y: y, width: 420, height: 40)
        NSColor(white: 1, alpha: 0.25).setFill()
        NSBezierPath(roundedRect: barRect, xRadius: 20, yRadius: 20).fill()
        let songName = info.songTitle ?? "Favorite Track"
        draw(
            "● ONLINE  ·  ♪ \(songName)", font: .systemFont(ofSize: 17, weight: .bold), color: .white,
            at: CGPoint(x: barRect.minX + 20, y: barRect.minY + 10), maxWidth: 380)
        y += 50
        centered(
            footer.dateString("MM/dd/yyyy") + "  [SP 00:24:12]", font: rounded(24, .bold),
            color: .white.withAlphaComponent(0.9), x: center, y: y)
    }
}
