import AppKit

/// The Receipt strip style.
extension PhotoStripComposer {
    static func receiptBackground(_ canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        fill(canvas, NSColor(red: 0.86, green: 0.85, blue: 0.82, alpha: 1))
        // Paper with torn, zigzag ends.
        let paper = canvas.insetBy(dx: 50, dy: 0)
        let tooth: CGFloat = 22
        let path = NSBezierPath()
        path.move(to: CGPoint(x: paper.minX, y: paper.minY + tooth))
        var x = paper.minX
        var up = true
        while x < paper.maxX {
            x = min(x + tooth, paper.maxX)
            path.line(to: CGPoint(x: x, y: paper.minY + (up ? 0 : tooth)))
            up.toggle()
        }
        path.line(to: CGPoint(x: paper.maxX, y: paper.maxY - tooth))
        up = true
        while x > paper.minX {
            x = max(x - tooth, paper.minX)
            path.line(to: CGPoint(x: x, y: paper.maxY - (up ? 0 : tooth)))
            up.toggle()
        }
        path.close()
        withShadow(color: NSColor.black.withAlphaComponent(0.2), blur: 16, offset: CGSize(width: 0, height: 4)) {
            NSColor(red: 0.985, green: 0.98, blue: 0.965, alpha: 1).setFill()
            path.fill()
        }
    }

    static func receiptFooter(_ footer: StripFooter) {
        let rect = footer.rect
        let info = footer.info
        let caption = footer.custom
        let f = DateFormatter()
        let mono = NSFont(name: "Menlo", size: 29) ?? .monospacedSystemFont(ofSize: 29, weight: .regular)
        let bold = NSFont(name: "Menlo-Bold", size: 29) ?? .monospacedSystemFont(ofSize: 29, weight: .bold)
        let ink = NSColor(white: 0.12, alpha: 1)
        let columns = 32
        func line(_ left: String, _ right: String = "") -> String {
            left + String(repeating: " ", count: max(1, columns - left.count - right.count)) + right
        }
        f.dateFormat = "dd/MM/yyyy"
        let date = f.string(from: info.date)
        f.dateFormat = "HH:mm"
        let time = f.string(from: info.date)
        var y = rect.minY + 34
        y +=
            centered(
                "★ " + (caption ?? "PHOTOBOX").uppercased() + " ★",
                font: .monospacedSystemFont(ofSize: 42, weight: .heavy), color: ink, x: rect.midX, y: y) + 6
        for (text, font) in [
            ("OPEN DAILY · NO REFUNDS ON VIBES", mono),
            (line(date, time), mono),
            (String(repeating: "-", count: columns), mono),
            (line("4x CORE MEMORY", "PRICELESS"), mono),
            (line("1x GOOD VIBES", "FREE"), mono),
            (line("1x INSIDE JOKE", "FREE"), mono),
            (String(repeating: "-", count: columns), mono),
            (line("TOTAL", "PRICELESS"), bold),
        ] {
            y += centered(text, font: font, color: ink, x: rect.midX, y: y) + 2
        }
        // Barcode.
        var rng = SeededRandom(seed: UInt64(info.date.timeIntervalSince1970) / 60)
        var x = rect.midX - 200
        ink.setFill()
        while x < rect.midX + 200 {
            let w = CGFloat.random(in: 2...7, using: &rng)
            NSBezierPath(rect: CGRect(x: x, y: y + 18, width: w, height: 70)).fill()
            x += w + .random(in: 2...6, using: &rng)
        }
        centered("THANK YOU, COME AGAIN ♡", font: mono, color: ink, x: rect.midX, y: y + 100)
    }
}
