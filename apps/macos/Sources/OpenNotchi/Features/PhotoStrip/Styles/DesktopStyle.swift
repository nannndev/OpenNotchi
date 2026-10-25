import AppKit

/// The Desktop strip style.
extension PhotoStripComposer {
    static func desktopPhoto(_ photo: CGImage, in cell: CGRect, index: Int) {
        drawWindow(photo, in: cell, title: "photo_\(index + 1).jpg")
    }

    static func desktopBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0, green: 0.5, blue: 0.5, alpha: 1))
        // Taskbar along the bottom.
        let bar = CGRect(x: 0, y: canvas.maxY - 76, width: canvas.width, height: 76)
        fill(bar, NSColor(white: 0.75, alpha: 1))
        fill(CGRect(x: 0, y: bar.minY, width: canvas.width, height: 3), .white)
        let start = CGRect(x: 12, y: bar.minY + 12, width: 150, height: 52)
        bevel(start, raised: true)
        draw(
            "▦ Start", font: .systemFont(ofSize: 28, weight: .heavy), color: .black,
            at: CGPoint(x: start.minX + 18, y: start.minY + 9))
        let clock = CGRect(x: canvas.width - 162, y: bar.minY + 12, width: 150, height: 52)
        bevel(clock, raised: false)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        draw(
            f.string(from: info.date), font: .monospacedDigitSystemFont(ofSize: 26, weight: .medium), color: .black,
            at: CGPoint(x: clock.minX + 38, y: clock.minY + 11))
    }

    static func desktopFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let caption = footer.custom
        let y = rect.minY + 34
        centered(
            caption ?? "my_memories.exe",
            font: NSFont(name: "Courier New Bold", size: 54) ?? .monospacedSystemFont(ofSize: 50, weight: .bold),
            color: .white, x: rect.midX, y: y, shadow: NSColor.black.withAlphaComponent(0.6))
    }

    /// A Windows-98-style window with the photo inside.
    static func drawWindow(_ photo: CGImage, in cell: CGRect, title: String) {
        bevel(cell, raised: true)
        let inner = cell.insetBy(dx: 6, dy: 6)
        let titleBar = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: 46)
        NSGradient(colors: [
            NSColor(red: 0, green: 0, blue: 0.5, alpha: 1), NSColor(red: 0.06, green: 0.52, blue: 0.82, alpha: 1),
        ])!.draw(in: titleBar, angle: 0)
        draw(
            title, font: .systemFont(ofSize: 24, weight: .bold), color: .white,
            at: CGPoint(x: titleBar.minX + 14, y: titleBar.minY + 9))
        for (i, glyph) in ["_", "□", "×"].enumerated() {
            let button = CGRect(x: titleBar.maxX - CGFloat(3 - i) * 42 - 4, y: titleBar.minY + 7, width: 36, height: 32)
            bevel(button, raised: true)
            draw(
                glyph, font: .systemFont(ofSize: 22, weight: .heavy), color: .black,
                at: CGPoint(x: button.minX + 10, y: button.minY + 1))
        }
        let photoRect = CGRect(
            x: inner.minX + 4, y: titleBar.maxY + 6, width: inner.width - 8, height: inner.maxY - titleBar.maxY - 10)
        bevel(photoRect.insetBy(dx: -3, dy: -3), raised: false)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: photoRect).addClip()
        drawAspectFill(photo, in: photoRect)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Classic 3D bevel: light top-left, dark bottom-right (reversed when sunken).
    static func bevel(_ rect: CGRect, raised: Bool) {
        fill(rect, NSColor(white: 0.75, alpha: 1))
        let light = NSColor.white
        let dark = NSColor(white: 0.35, alpha: 1)
        let (topLeft, bottomRight) = raised ? (light, dark) : (dark, light)
        fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 3), topLeft)
        fill(CGRect(x: rect.minX, y: rect.minY, width: 3, height: rect.height), topLeft)
        fill(CGRect(x: rect.minX, y: rect.maxY - 3, width: rect.width, height: 3), bottomRight)
        fill(CGRect(x: rect.maxX - 3, y: rect.minY, width: 3, height: rect.height), bottomRight)
    }
}
