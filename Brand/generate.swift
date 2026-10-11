// Generates every OpenNotchi brand asset from one set of shapes and colors.
// Usage: swift Brand/generate.swift   (run from the repo root, or `make brand`)
// Writes PNG + SVG into Brand/ and Resources/AppIcon.icns.

import AppKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - Brand palette (monochrome)

struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }
    func cg(_ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var ns: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    var hex: String { String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255)) }
}

enum Brand {
    static let white = RGB(0xFFFFFF)
    static let snow = RGB(0xF5F5F7)
    static let mist = RGB(0xE5E5EA)
    static let silver = RGB(0xD1D1D6)
    static let ash = RGB(0x8E8E93)
    static let graphite = RGB(0x3A3A3C)
    static let charcoal = RGB(0x1C1C1E)
    static let black = RGB(0x000000)
}

/// Light or dark version of the icon.
enum Tone: String, CaseIterable {
    case light, dark

    var tile: [RGB] { self == .light ? [Brand.white, RGB(0xD6D6DB)] : [Brand.graphite, RGB(0x0E0E10)] }
    var sheen: CGFloat { self == .light ? 0.7 : 0.14 }
    var notch: [RGB] { self == .light ? [RGB(0x2C2C2E), Brand.black] : [Brand.charcoal, Brand.black] }
    var rimAlpha: CGFloat { self == .light ? 0.10 : 0.18 }
    var bars: [RGB] { [Brand.white, Brand.mist, Brand.silver] }
    var hairline: CGFloat { self == .light ? 0.9 : 0.12 }
    /// Color for decorations drawn on the tile.
    var ink: RGB { self == .light ? Brand.black : Brand.white }
    /// Scales decoration opacity so both tones feel equally quiet.
    var inkStrength: CGFloat { self == .light ? 0.45 : 1 }
}

// MARK: - Geometry (shared by PNG and SVG output, y axis points down)

struct Path {
    let cg = CGMutablePath()
    var d = ""

    private func f(_ v: CGFloat) -> String {
        let s = String(format: "%.2f", v)
        return s.hasSuffix(".00") ? String(s.dropLast(3)) : s
    }

    mutating func move(_ x: CGFloat, _ y: CGFloat) { cg.move(to: CGPoint(x: x, y: y)); d += "M\(f(x)) \(f(y)) " }
    mutating func line(_ x: CGFloat, _ y: CGFloat) { cg.addLine(to: CGPoint(x: x, y: y)); d += "L\(f(x)) \(f(y)) " }
    mutating func quad(_ x: CGFloat, _ y: CGFloat, _ cx: CGFloat, _ cy: CGFloat) {
        cg.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
        d += "Q\(f(cx)) \(f(cy)) \(f(x)) \(f(y)) "
    }
    mutating func close() { cg.closeSubpath(); d += "Z " }

    mutating func roundedRect(_ r: CGRect, _ radius: CGFloat) {
        move(r.minX + radius, r.minY)
        line(r.maxX - radius, r.minY); quad(r.maxX, r.minY + radius, r.maxX, r.minY)
        line(r.maxX, r.maxY - radius); quad(r.maxX - radius, r.maxY, r.maxX, r.maxY)
        line(r.minX + radius, r.maxY); quad(r.minX, r.maxY - radius, r.minX, r.maxY)
        line(r.minX, r.minY + radius); quad(r.minX + radius, r.minY, r.minX, r.minY)
        close()
    }
}

/// The OpenNotchi notch: flat top, outward ears, rounded bottom. Same curve as the app.
func notchPath(x: CGFloat, y: CGFloat, width w: CGFloat, height h: CGFloat, ear: CGFloat, bottom b: CGFloat, closed: Bool = true) -> Path {
    var p = Path()
    p.move(x, y)
    p.quad(x + ear, y + ear, x + ear, y)
    p.line(x + ear, y + h - b)
    p.quad(x + ear + b, y + h, x + ear, y + h)
    p.line(x + w - ear - b, y + h)
    p.quad(x + w - ear, y + h - b, x + w - ear, y + h)
    p.line(x + w - ear, y + ear)
    p.quad(x + w, y, x + w - ear, y)
    if closed { p.close() }
    return p
}

/// Five waveform bars centered on (cx, cy).
func barsPath(cx: CGFloat, cy: CGFloat, barWidth: CGFloat, gap: CGFloat, heights: [CGFloat]) -> Path {
    var p = Path()
    let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    var x = cx - total / 2
    for h in heights {
        p.roundedRect(CGRect(x: x, y: cy - h / 2, width: barWidth, height: h), barWidth / 2)
        x += barWidth + gap
    }
    return p
}

let barHeights: [CGFloat] = [0.37, 0.72, 1.0, 0.65, 0.44]

// MARK: - Icon layout (1024 canvas, Apple's macOS icon grid)

enum IconLayout {
    static let canvas: CGFloat = 1024
    static let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let tileRadius: CGFloat = 186
    static let notch = (x: CGFloat(282), y: CGFloat(100), w: CGFloat(460), h: CGFloat(264), ear: CGFloat(36), bottom: CGFloat(98))
    static let barsCenter = CGPoint(x: 512, y: 238)
    static let barWidth: CGFloat = 30
    static let barGap: CGFloat = 24
    static let barMax: CGFloat = 172
    static var notchBottom: CGFloat { notch.y + notch.h }
}

// MARK: - Rendering helpers

func makeContext(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    // Flip to a y-down coordinate system to match the SVG geometry.
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    return ctx
}

func gradient(_ colors: [RGB], alphas: [CGFloat]? = nil) -> CGGradient {
    let cgColors = colors.enumerated().map { $0.element.cg(alphas?[$0.offset] ?? 1) }
    return CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cgColors as CFArray, locations: nil)!
}

func radialGlow(_ ctx: CGContext, center: CGPoint, radius: CGFloat, color: RGB, alpha: CGFloat) {
    ctx.drawRadialGradient(gradient([color, color], alphas: [alpha, 0]),
                           startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

func fill(_ ctx: CGContext, _ path: Path, _ color: CGColor) {
    ctx.addPath(path.cg); ctx.setFillColor(color); ctx.fillPath()
}

func savePNG(_ ctx: CGContext, _ url: URL) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func drawSymbol(_ ctx: CGContext, _ name: String, in rect: CGRect, color: NSColor) {
    let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    let s = image.size
    let scale = min(rect.width / s.width, rect.height / s.height)
    let fitted = CGRect(x: rect.midX - s.width * scale / 2, y: rect.midY - s.height * scale / 2,
                        width: s.width * scale, height: s.height * scale)
    image.draw(in: fitted, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
}

func roundedFont(_ size: CGFloat) -> CTFont {
    let base = NSFont.systemFont(ofSize: size, weight: .bold)
    let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return (NSFont(descriptor: descriptor, size: size) ?? base) as CTFont
}

/// Draws a single line of text with its baseline at `y` in the flipped context.
@discardableResult
func drawText(_ ctx: CGContext, _ string: String, x: CGFloat, baseline y: CGFloat, font: CTFont, color: CGColor) -> CGFloat {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color]))
    ctx.saveGState()
    ctx.textMatrix = .identity
    ctx.translateBy(x: x, y: y)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

func textWidth(_ string: String, font: CTFont) -> CGFloat {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: [.font: font]))
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

// MARK: - Icon center artwork options

enum IconVariant: String, CaseIterable {
    case plain, ripple, player, orb, waves

    var title: String {
        switch self {
        case .plain: return "A · Plain"
        case .ripple: return "B · Ripple"
        case .player: return "C · Mini Player"
        case .orb: return "D · Glass Orb"
        case .waves: return "E · Soft Waves"
        }
    }
}

/// The combination used for the real app icon.
let selectedTone: Tone = .dark
let selectedVariant: IconVariant = .waves

/// Decoration in the open area below the notch (drawn before the notch).
func drawCenter(_ ctx: CGContext, variant: IconVariant, tone: Tone) {
    let ink = tone.ink
    let k = tone.inkStrength
    let notchBottom = IconLayout.notchBottom

    switch variant {
    case .plain:
        break

    case .ripple:
        // Sound rings spreading out from the notch.
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: notchBottom + 18, width: 1024, height: 1024))
        for (i, radius) in [CGFloat(190), 300, 410, 520].enumerated() {
            ctx.addEllipse(in: CGRect(x: 512 - radius, y: notchBottom - radius, width: radius * 2, height: radius * 2))
            ctx.setStrokeColor(ink.cg([0.5, 0.34, 0.22, 0.12][i] * k))
            ctx.setLineWidth([16, 13, 10, 8][i])
            ctx.strokePath()
        }
        ctx.restoreGState()

    case .player:
        // A frosted now-playing card, like the expanded notch.
        let card = CGRect(x: 232, y: 480, width: 560, height: 300)
        var cardPath = Path(); cardPath.roundedRect(card, 72)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 36, color: CGColor(gray: 0, alpha: tone == .light ? 0.12 : 0.4))
        fill(ctx, cardPath, tone == .light ? Brand.white.cg(0.85) : Brand.white.cg(0.1))
        ctx.restoreGState()
        ctx.addPath(cardPath.cg); ctx.setStrokeColor(ink.cg(0.18 * k)); ctx.setLineWidth(3); ctx.strokePath()

        let art = CGRect(x: card.minX + 44, y: card.minY + 50, width: 200, height: 200)
        var artPath = Path(); artPath.roundedRect(art, 44)
        ctx.saveGState()
        ctx.addPath(artPath.cg); ctx.clip()
        let artColors = tone == .light ? [Brand.graphite, Brand.black] : [Brand.white, Brand.silver]
        ctx.drawLinearGradient(gradient(artColors), start: art.origin, end: CGPoint(x: art.maxX, y: art.maxY), options: [])
        ctx.restoreGState()
        drawSymbol(ctx, "music.note", in: art.insetBy(dx: 52, dy: 52), color: tone == .light ? .white : .black)

        let tx = art.maxX + 40
        var line1 = Path(); line1.roundedRect(CGRect(x: tx, y: card.minY + 74, width: 220, height: 30), 15)
        var line2 = Path(); line2.roundedRect(CGRect(x: tx, y: card.minY + 124, width: 150, height: 26), 13)
        fill(ctx, line1, ink.cg(tone == .light ? 0.85 : 0.95))
        fill(ctx, line2, ink.cg(tone == .light ? 0.3 : 0.5))
        var track = Path(); track.roundedRect(CGRect(x: tx, y: card.minY + 196, width: 220, height: 16), 8)
        var progress = Path(); progress.roundedRect(CGRect(x: tx, y: card.minY + 196, width: 130, height: 16), 8)
        fill(ctx, track, ink.cg(tone == .light ? 0.12 : 0.25))
        fill(ctx, progress, ink.cg(tone == .light ? 0.85 : 1))

    case .orb:
        // A beam from the notch into a glossy orb holding a note.
        let center = CGPoint(x: 512, y: 650)
        let r: CGFloat = 178
        ctx.saveGState()
        ctx.move(to: CGPoint(x: 400, y: notchBottom - 10)); ctx.addLine(to: CGPoint(x: 624, y: notchBottom - 10))
        ctx.addLine(to: CGPoint(x: 680, y: center.y)); ctx.addLine(to: CGPoint(x: 344, y: center.y)); ctx.closePath()
        ctx.clip()
        ctx.drawLinearGradient(gradient([ink, ink], alphas: [tone == .light ? 0.12 : 0.28, 0]),
                               start: CGPoint(x: 0, y: notchBottom), end: CGPoint(x: 0, y: center.y), options: [])
        ctx.restoreGState()

        let orbRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 24), blur: 50, color: CGColor(gray: 0, alpha: tone == .light ? 0.3 : 0.6))
        ctx.addEllipse(in: orbRect); ctx.setFillColor(Brand.graphite.cg()); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addEllipse(in: orbRect); ctx.clip()
        ctx.drawRadialGradient(gradient([Brand.white, Brand.ash, Brand.charcoal]),
                               startCenter: CGPoint(x: center.x - 60, y: center.y - 70), startRadius: 0,
                               endCenter: center, endRadius: r * 1.05, options: [.drawsAfterEndLocation])
        ctx.addEllipse(in: CGRect(x: center.x - 110, y: center.y - 150, width: 150, height: 80))
        ctx.setFillColor(CGColor(gray: 1, alpha: 0.5)); ctx.fillPath()
        ctx.restoreGState()
        ctx.addEllipse(in: orbRect)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.45)); ctx.setLineWidth(3); ctx.strokePath()
        drawSymbol(ctx, "music.note", in: CGRect(x: center.x - 80, y: center.y - 70, width: 160, height: 160), color: NSColor(white: 1, alpha: 0.95))

    case .waves:
        // Layered soft sound waves rolling across the bottom.
        func wave(baseline: CGFloat, amplitude: CGFloat, phase: CGFloat, alpha: CGFloat) {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 1024))
            p.addLine(to: CGPoint(x: 0, y: baseline))
            var x: CGFloat = 0
            while x <= 1024 {
                p.addLine(to: CGPoint(x: x, y: baseline + sin((x / 1024) * .pi * 2.4 + phase) * amplitude))
                x += 8
            }
            p.addLine(to: CGPoint(x: 1024, y: 1024)); p.closeSubpath()
            ctx.addPath(p); ctx.setFillColor(ink.cg(alpha * k)); ctx.fillPath()
        }
        wave(baseline: 600, amplitude: 46, phase: 0.4, alpha: 0.07)
        wave(baseline: 690, amplitude: 54, phase: 2.2, alpha: 0.1)
        wave(baseline: 790, amplitude: 40, phase: 4.0, alpha: 0.14)
        let sparkle = tone == .light ? NSColor(white: 0, alpha: 0.45) : NSColor(white: 1, alpha: 0.8)
        drawSymbol(ctx, "sparkle", in: CGRect(x: 690, y: 430, width: 90, height: 90), color: sparkle)
        drawSymbol(ctx, "sparkle", in: CGRect(x: 250, y: 500, width: 52, height: 52), color: sparkle.withAlphaComponent(sparkle.alphaComponent * 0.7))
    }
}

// MARK: - Icon

func drawIcon(_ ctx: CGContext, size: CGFloat, variant: IconVariant = selectedVariant, tone: Tone = selectedTone) {
    let L = IconLayout.self
    ctx.saveGState()
    ctx.scaleBy(x: size / L.canvas, y: size / L.canvas)

    var tile = Path()
    tile.roundedRect(L.tile, L.tileRadius)

    // Soft neutral drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 20, color: CGColor(gray: 0, alpha: 0.2))
    fill(ctx, tile, tone.tile[1].cg())
    ctx.restoreGState()

    // Background: brushed gradient with a soft top sheen.
    ctx.saveGState()
    ctx.addPath(tile.cg); ctx.clip()
    ctx.drawLinearGradient(gradient(tone.tile), start: CGPoint(x: 300, y: 100), end: CGPoint(x: 724, y: 924),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    radialGlow(ctx, center: CGPoint(x: 512, y: 380), radius: 460, color: Brand.white, alpha: tone.sheen)

    drawCenter(ctx, variant: variant, tone: tone)

    // Notch with depth shadow.
    let n = L.notch
    let notch = notchPath(x: n.x, y: n.y, width: n.w, height: n.h, ear: n.ear, bottom: n.bottom)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 44, color: CGColor(gray: 0, alpha: tone == .light ? 0.28 : 0.6))
    fill(ctx, notch, Brand.black.cg())
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(notch.cg); ctx.clip()
    ctx.drawLinearGradient(gradient(tone.notch), start: CGPoint(x: 0, y: n.y), end: CGPoint(x: 0, y: n.y + n.h), options: [])
    ctx.restoreGState()
    let rim = notchPath(x: n.x, y: n.y, width: n.w, height: n.h, ear: n.ear, bottom: n.bottom, closed: false)
    ctx.addPath(rim.cg); ctx.setStrokeColor(CGColor(gray: 1, alpha: tone.rimAlpha)); ctx.setLineWidth(3); ctx.strokePath()

    // Waveform with a soft white glow.
    let bars = barsPath(cx: L.barsCenter.x, cy: L.barsCenter.y, barWidth: L.barWidth, gap: L.barGap,
                        heights: barHeights.map { $0 * L.barMax })
    let box = bars.cg.boundingBox
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 26, color: CGColor(gray: 1, alpha: 0.45))
    fill(ctx, bars, Brand.white.cg())
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bars.cg); ctx.clip()
    ctx.drawLinearGradient(gradient(tone.bars), start: CGPoint(x: box.minX, y: 0), end: CGPoint(x: box.maxX, y: 0), options: [])
    ctx.restoreGState()

    ctx.restoreGState() // tile clip

    // Hairline edge.
    ctx.addPath(tile.cg)
    ctx.setStrokeColor(tone == .light ? CGColor(gray: 0, alpha: 0.08) : CGColor(gray: 1, alpha: tone.hairline))
    ctx.setLineWidth(2); ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Mark & lockup

let markNotch = notchPath(x: 16, y: 136, width: 480, height: 270, ear: 38, bottom: 100)
let markBars = barsPath(cx: 256, cy: 136 + 270 / 2 + 6, barWidth: 30, gap: 24, heights: barHeights.map { $0 * 170 })

/// Standalone mark: black notch with white bars. `mono` cuts the bars out instead.
func drawMark(_ ctx: CGContext, size: CGFloat, mono: Bool = false, inverted: Bool = false) {
    ctx.saveGState()
    ctx.scaleBy(x: size / 512, y: size / 512)
    if mono {
        let combined = CGMutablePath()
        combined.addPath(markNotch.cg); combined.addPath(markBars.cg)
        ctx.addPath(combined); ctx.setFillColor(CGColor(gray: 0, alpha: 1)); ctx.fillPath(using: .evenOdd)
    } else {
        ctx.saveGState()
        ctx.addPath(markNotch.cg); ctx.clip()
        let colors = inverted ? [Brand.white, Brand.mist] : [Brand.graphite, Brand.black]
        ctx.drawLinearGradient(gradient(colors), start: CGPoint(x: 0, y: 136), end: CGPoint(x: 0, y: 406), options: [])
        ctx.restoreGState()
        fill(ctx, markBars, inverted ? Brand.black.cg() : Brand.white.cg())
    }
    ctx.restoreGState()
}

/// "Open" in full strength, "Notchi" in a quieter grey.
func lockupColors(dark: Bool) -> (open: RGB, notchi: RGB, background: RGB?) {
    dark ? (Brand.white, Brand.ash, Brand.black) : (Brand.black, Brand.ash, nil)
}

func lockupWidth(height: CGFloat) -> CGFloat {
    let markSize = height * 0.72
    return (height * 0.18 + markSize + height * 0.08 + textWidth("OpenNotchi", font: roundedFont(height * 0.36)) + height * 0.18).rounded()
}

func drawLockup(_ ctx: CGContext, width: CGFloat, height: CGFloat, dark: Bool) {
    let colors = lockupColors(dark: dark)
    if let bg = colors.background {
        ctx.setFillColor(bg.cg()); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    let markSize = height * 0.72
    ctx.saveGState()
    ctx.translateBy(x: height * 0.18, y: (height - markSize) / 2)
    drawMark(ctx, size: markSize, inverted: dark)
    ctx.restoreGState()

    let font = roundedFont(height * 0.36)
    let x = height * 0.18 + markSize + height * 0.08
    let baseline = height * 0.5 + height * 0.36 * 0.34
    let openWidth = drawText(ctx, "Open", x: x, baseline: baseline, font: font, color: colors.open.cg())
    drawText(ctx, "Notchi", x: x + openWidth, baseline: baseline, font: font, color: colors.notchi.cg())
}

// MARK: - SVG output

func stops(_ colors: [RGB]) -> String {
    colors.enumerated().map { i, c in
        "<stop offset=\"\(Int(Double(i) / Double(max(colors.count - 1, 1)) * 100))%\" stop-color=\"\(c.hex)\"/>"
    }.joined()
}

/// SVG of the icon base (tile, notch, waveform). Center artwork is PNG-only.
func iconSVG(tone: Tone) -> String {
    let L = IconLayout.self
    var tile = Path(); tile.roundedRect(L.tile, L.tileRadius)
    let n = L.notch
    let notch = notchPath(x: n.x, y: n.y, width: n.w, height: n.h, ear: n.ear, bottom: n.bottom)
    let rim = notchPath(x: n.x, y: n.y, width: n.w, height: n.h, ear: n.ear, bottom: n.bottom, closed: false)
    let bars = barsPath(cx: L.barsCenter.x, cy: L.barsCenter.y, barWidth: L.barWidth, gap: L.barGap, heights: barHeights.map { $0 * L.barMax })
    let box = bars.cg.boundingBox
    let hairline = tone == .light ? "stroke=\"#000\" stroke-opacity=\".08\"" : "stroke=\"#fff\" stroke-opacity=\"\(tone.hairline)\""
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
      <defs>
        <linearGradient id="bg" x1="300" y1="100" x2="724" y2="924" gradientUnits="userSpaceOnUse">\(stops(tone.tile))</linearGradient>
        <radialGradient id="sheen" cx="512" cy="380" r="460" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff" stop-opacity="\(tone.sheen)"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
        <linearGradient id="notch" x1="0" y1="\(n.y)" x2="0" y2="\(n.y + n.h)" gradientUnits="userSpaceOnUse">\(stops(tone.notch))</linearGradient>
        <linearGradient id="wave" x1="\(box.minX)" y1="0" x2="\(box.maxX)" y2="0" gradientUnits="userSpaceOnUse">\(stops(tone.bars))</linearGradient>
        <clipPath id="tile"><path d="\(tile.d)"/></clipPath>
        <filter id="tileShadow" x="-10%" y="-10%" width="120%" height="130%"><feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#000" flood-opacity=".2"/></filter>
        <filter id="notchShadow" x="-20%" y="-20%" width="140%" height="160%"><feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#000" flood-opacity="\(tone == .light ? 0.28 : 0.6)"/></filter>
        <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="13"/></filter>
      </defs>
      <path d="\(tile.d)" fill="\(tone.tile[1].hex)" filter="url(#tileShadow)"/>
      <g clip-path="url(#tile)">
        <path d="\(tile.d)" fill="url(#bg)"/>
        <rect width="1024" height="1024" fill="url(#sheen)"/>
        <path d="\(notch.d)" fill="url(#notch)" filter="url(#notchShadow)"/>
        <path d="\(rim.d)" fill="none" stroke="#fff" stroke-opacity="\(tone.rimAlpha)" stroke-width="3"/>
        <path d="\(bars.d)" fill="#fff" opacity=".45" filter="url(#glow)"/>
        <path d="\(bars.d)" fill="url(#wave)"/>
      </g>
      <path d="\(tile.d)" fill="none" \(hairline) stroke-width="2"/>
    </svg>
    """
}

func markSVG(mono: Bool) -> String {
    if mono {
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
          <path d="\(markNotch.d)\(markBars.d)" fill="currentColor" fill-rule="evenodd"/>
        </svg>
        """
    }
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
      <defs><linearGradient id="m" x1="0" y1="136" x2="0" y2="406" gradientUnits="userSpaceOnUse">\(stops([Brand.graphite, Brand.black]))</linearGradient></defs>
      <path d="\(markNotch.d)" fill="url(#m)"/>
      <path d="\(markBars.d)" fill="#fff"/>
    </svg>
    """
}

func lockupSVG(dark: Bool, width: CGFloat) -> String {
    let colors = lockupColors(dark: dark)
    let w = Int(width)
    let notchFill = dark ? [Brand.white, Brand.mist] : [Brand.graphite, Brand.black]
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(w) 400" width="\(w)" height="400">
      <defs><linearGradient id="m" x1="0" y1="136" x2="0" y2="406" gradientUnits="userSpaceOnUse">\(stops(notchFill))</linearGradient></defs>
      \(colors.background.map { "<rect width=\"\(w)\" height=\"400\" fill=\"\($0.hex)\"/>" } ?? "")
      <g transform="translate(72 56) scale(0.5625)">
        <path d="\(markNotch.d)" fill="url(#m)"/>
        <path d="\(markBars.d)" fill="\(dark ? "#000" : "#fff")"/>
      </g>
      <text x="392" y="249" font-family="'SF Pro Rounded', ui-rounded, 'Nunito', system-ui, sans-serif" font-weight="700" font-size="144" fill="\(colors.open.hex)">Open<tspan fill="\(colors.notchi.hex)">Notchi</tspan></text>
    </svg>
    """
}

// MARK: - Main

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let fm = FileManager.default
let brandDir = root.appendingPathComponent("Brand")
let iconDir = brandDir.appendingPathComponent("icon")
let logoDir = brandDir.appendingPathComponent("logo")
let optionsDir = iconDir.appendingPathComponent("options")
try? fm.removeItem(at: optionsDir)
for dir in [iconDir, logoDir, optionsDir] { try? fm.createDirectory(at: dir, withIntermediateDirectories: true) }

// Options: every tone × variant, plus an overview sheet.
let cell: CGFloat = 360, header: CGFloat = 70, rowLabel: CGFloat = 120
let variants = IconVariant.allCases, tones = Tone.allCases
let sheetW = rowLabel + cell * CGFloat(variants.count), sheetH = header + cell * CGFloat(tones.count)
let sheet = makeContext(Int(sheetW), Int(sheetH))
sheet.setFillColor(Brand.snow.cg()); sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
for (col, variant) in variants.enumerated() {
    let font = roundedFont(24)
    let title = variant.title
    drawText(sheet, title, x: rowLabel + CGFloat(col) * cell + (cell - textWidth(title, font: font)) / 2, baseline: 46, font: font, color: Brand.charcoal.cg())
}
for (row, tone) in tones.enumerated() {
    let font = roundedFont(24)
    drawText(sheet, tone.rawValue.capitalized, x: 24, baseline: header + CGFloat(row) * cell + cell / 2 + 8, font: font, color: Brand.ash.cg())
    for (col, variant) in variants.enumerated() {
        let c = makeContext(1024, 1024); drawIcon(c, size: 1024, variant: variant, tone: tone)
        savePNG(c, optionsDir.appendingPathComponent("AppIcon-\(tone.rawValue)-\(variant.rawValue).png"))
        sheet.saveGState()
        sheet.translateBy(x: rowLabel + CGFloat(col) * cell, y: header + CGFloat(row) * cell)
        drawIcon(sheet, size: cell, variant: variant, tone: tone)
        sheet.restoreGState()
    }
}
savePNG(sheet, optionsDir.appendingPathComponent("overview.png"))

// The real app icon.
var ctx = makeContext(1024, 1024); drawIcon(ctx, size: 1024)
savePNG(ctx, iconDir.appendingPathComponent("AppIcon-1024.png"))
let svgURL = iconDir.appendingPathComponent("AppIcon.svg")
if selectedVariant == .plain {
    try! iconSVG(tone: selectedTone).write(to: svgURL, atomically: true, encoding: .utf8)
} else {
    try? fm.removeItem(at: svgURL)
    print("Note: AppIcon.svg covers the plain icon only; using the PNG for the \(selectedVariant.rawValue) variant.")
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let c = makeContext(px, px); drawIcon(c, size: CGFloat(px))
        savePNG(c, iconset.appendingPathComponent("icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"))
    }
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! iconutil.run(); iconutil.waitUntilExit()

// Mark
ctx = makeContext(512, 512); drawMark(ctx, size: 512); savePNG(ctx, logoDir.appendingPathComponent("mark.png"))
ctx = makeContext(512, 512); drawMark(ctx, size: 512, mono: true); savePNG(ctx, logoDir.appendingPathComponent("mark-mono.png"))
try! markSVG(mono: false).write(to: logoDir.appendingPathComponent("mark.svg"), atomically: true, encoding: .utf8)
try! markSVG(mono: true).write(to: logoDir.appendingPathComponent("mark-mono.svg"), atomically: true, encoding: .utf8)

// Lockups
let lockupW = lockupWidth(height: 400)
for dark in [true, false] {
    let name = "lockup-\(dark ? "dark" : "light")"
    let c = makeContext(Int(lockupW), 400); drawLockup(c, width: lockupW, height: 400, dark: dark)
    savePNG(c, logoDir.appendingPathComponent("\(name).png"))
    try! lockupSVG(dark: dark, width: lockupW).write(to: logoDir.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
}

// Social card (Open Graph, 1200×630)
let socialDir = brandDir.appendingPathComponent("social")
try? fm.createDirectory(at: socialDir, withIntermediateDirectories: true)
let og = makeContext(1200, 630)
og.setFillColor(Brand.black.cg()); og.fill(CGRect(x: 0, y: 0, width: 1200, height: 630))
radialGlow(og, center: CGPoint(x: 600, y: 0), radius: 700, color: Brand.white, alpha: 0.12)
// A wide notch hanging from the top edge, like the real thing.
fill(og, notchPath(x: 380, y: 0, width: 440, height: 120, ear: 22, bottom: 44), Brand.charcoal.cg())
let ogBars = barsPath(cx: 600, cy: 60, barWidth: 14, gap: 11, heights: barHeights.map { $0 * 70 })
og.saveGState(); og.setShadow(offset: .zero, blur: 16, color: CGColor(gray: 1, alpha: 0.5)); fill(og, ogBars, Brand.white.cg()); og.restoreGState()
let ogFont = roundedFont(96)
let ogWidth = textWidth("OpenNotchi", font: ogFont)
let openW = drawText(og, "Open", x: (1200 - ogWidth) / 2, baseline: 360, font: ogFont, color: Brand.white.cg())
drawText(og, "Notchi", x: (1200 - ogWidth) / 2 + openW, baseline: 360, font: ogFont, color: Brand.ash.cg())
let tagFont = CTFontCreateWithName("SF Pro Text" as CFString, 34, nil)
let tagline = "The free, open-source Dynamic Notch for macOS"
drawText(og, tagline, x: (1200 - textWidth(tagline, font: tagFont)) / 2, baseline: 430, font: tagFont, color: Brand.silver.cg())
let pillFont = roundedFont(24)
let pill = "Music · Lyrics · AirDrop · Clipboard · Timer"
drawText(og, pill, x: (1200 - textWidth(pill, font: pillFont)) / 2, baseline: 520, font: pillFont, color: Brand.ash.cg())
savePNG(og, socialDir.appendingPathComponent("og.png"))

print("Brand assets written to Brand/ and Resources/AppIcon.icns")
