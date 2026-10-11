import AppKit

/// The OpenNotchi mark (notch with waveform cut out), drawn in code so the
/// menu bar icon stays crisp at any scale. Geometry matches Brand/generate.swift.
enum BrandMark {
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 14), flipped: true) { rect in
            let path = notchPath(in: rect)
            path.append(barsPath(in: rect))
            path.windingRule = .evenOdd
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "OpenNotchi"
        return image
    }

    private static func notchPath(in rect: NSRect) -> NSBezierPath {
        let x = rect.minX, y = rect.minY, w = rect.width, h = rect.height
        let ear: CGFloat = 1.6, b: CGFloat = 5
        let p = NSBezierPath()
        p.move(to: NSPoint(x: x, y: y))
        p.curve(to: NSPoint(x: x + ear, y: y + ear), controlPoint1: NSPoint(x: x + ear, y: y), controlPoint2: NSPoint(x: x + ear, y: y))
        p.line(to: NSPoint(x: x + ear, y: y + h - b))
        p.curve(to: NSPoint(x: x + ear + b, y: y + h), controlPoint1: NSPoint(x: x + ear, y: y + h), controlPoint2: NSPoint(x: x + ear, y: y + h))
        p.line(to: NSPoint(x: x + w - ear - b, y: y + h))
        p.curve(to: NSPoint(x: x + w - ear, y: y + h - b), controlPoint1: NSPoint(x: x + w - ear, y: y + h), controlPoint2: NSPoint(x: x + w - ear, y: y + h))
        p.line(to: NSPoint(x: x + w - ear, y: y + ear))
        p.curve(to: NSPoint(x: x + w, y: y), controlPoint1: NSPoint(x: x + w - ear, y: y), controlPoint2: NSPoint(x: x + w - ear, y: y))
        p.close()
        return p
    }

    private static func barsPath(in rect: NSRect) -> NSBezierPath {
        let heights: [CGFloat] = [0.37, 0.72, 1.0, 0.65, 0.44]
        let barWidth: CGFloat = 1.6, gap: CGFloat = 1.3, maxHeight: CGFloat = 8
        let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
        var x = rect.midX - total / 2
        let cy = rect.minY + rect.height / 2 + 0.5
        let p = NSBezierPath()
        for h in heights {
            let barHeight = max(barWidth, h * maxHeight)
            p.append(NSBezierPath(roundedRect: NSRect(x: x, y: cy - barHeight / 2, width: barWidth, height: barHeight),
                                  xRadius: barWidth / 2, yRadius: barWidth / 2))
            x += barWidth + gap
        }
        return p
    }
}
