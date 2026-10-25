import AppKit

extension PhotoStripComposer {
    // MARK: - Drawing helpers

    /// Widest a footer line may be; set per strip.
    static var maxTextWidth: CGFloat = .greatestFiniteMagnitude

    static func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
    }

    static func fill(_ rect: CGRect, _ color: NSColor) {
        color.setFill()
        NSBezierPath(rect: rect).fill()
    }

    static func withShadow(color: NSColor, blur: CGFloat, offset: CGSize, _ body: () -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowBlurRadius = blur
        // NSShadow offsets are in unflipped coordinates.
        shadow.shadowOffset = CGSize(width: offset.width, height: -offset.height)
        shadow.set()
        body()
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Draws centered text and returns its height.
    @discardableResult
    static func centered(
        _ text: String, font: NSFont, color: NSColor, x: CGFloat, y: CGFloat, shadow: NSColor? = nil
    ) -> CGFloat {
        var string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        // Long custom text shrinks to fit the strip.
        if string.size().width > maxTextWidth {
            let smaller = font.withSize(font.pointSize * maxTextWidth / string.size().width)
            string = NSAttributedString(string: text, attributes: [.font: smaller, .foregroundColor: color])
        }
        let size = string.size()
        let draw = { string.draw(at: CGPoint(x: x - size.width / 2, y: y)) }
        if let shadow {
            withShadow(color: shadow, blur: 18, offset: .zero, draw)
        } else {
            draw()
        }
        return size.height
    }

    static func draw(_ text: String, font: NSFont, color: NSColor, at point: CGPoint, maxWidth: CGFloat? = nil) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let string = NSAttributedString(
            string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        let size = string.size()
        string.draw(in: CGRect(x: point.x, y: point.y, width: maxWidth ?? size.width + 1, height: size.height))
    }

    static func drawRotated(_ text: String, font: NSFont, color: NSColor, center: CGPoint) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let size = string.size()
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: .pi / 2)
        string.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        cg.restoreGState()
    }

    /// A random point in the margins, never on a photo.
    static func scatter(_ canvas: CGRect, _ cells: [CGRect], _ rng: inout SeededRandom) -> CGPoint {
        for _ in 0..<40 {
            let p = CGPoint(
                x: .random(in: 10...(canvas.width - 10), using: &rng),
                y: .random(in: 10...(canvas.height - 10), using: &rng))
            if !cells.contains(where: { $0.insetBy(dx: -24, dy: -24).contains(p) }) { return p }
        }
        return CGPoint(x: 30, y: 30)
    }

    static func symbol(_ name: String, color: NSColor, at center: CGPoint, size: CGFloat) {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .bold).applying(.init(paletteColors: [color]))
        guard
            let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        else { return }
        image.draw(
            in: CGRect(
                x: center.x - image.size.width / 2, y: center.y - image.size.height / 2, width: image.size.width,
                height: image.size.height),
            from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    static func petal(at center: CGPoint, size: CGFloat, angle: CGFloat) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: angle * .pi / 180)
        NSColor(red: 1, green: 0.66, blue: 0.78, alpha: 0.85).setFill()
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: -size / 2))
        path.curve(
            to: CGPoint(x: 0, y: size / 2), controlPoint1: CGPoint(x: size * 0.6, y: -size / 3),
            controlPoint2: CGPoint(x: size * 0.4, y: size / 3))
        path.curve(
            to: CGPoint(x: 0, y: -size / 2), controlPoint1: CGPoint(x: -size * 0.4, y: size / 3),
            controlPoint2: CGPoint(x: -size * 0.6, y: -size / 3))
        path.fill()
        cg.restoreGState()
    }

}

/// Deterministic random numbers, so a style's decorations are laid out the same way every time.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
