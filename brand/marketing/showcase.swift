import AppKit

let dir = CommandLine.arguments[1]
let out = CommandLine.arguments[2]
/// `og` renders the 1200×630 link preview (drawn at 2x) instead of the full showcase.
let isOG = CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "og"
let W: CGFloat = 2400, H: CGFloat = isOG ? 1260 : 1350

func load(_ name: String) -> NSBitmapImageRep {
    NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: "\(dir)/\(name).png")))!
}

/// Crops a screenshot to its visible (non-transparent) pixels, keeping a little room for the shadow.
func trimmed(_ name: String, pad: Int = 24) -> NSImage {
    let rep = load(name)
    var minX = rep.pixelsWide, minY = rep.pixelsHigh, maxX = 0, maxY = 0
    for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.6 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    let rect = CGRect(x: max(0, minX - pad), y: max(0, minY), width: min(rep.pixelsWide, maxX + pad) - max(0, minX - pad), height: min(rep.pixelsHigh, maxY + pad) - minY)
    let cg = rep.cgImage!.cropping(to: rect)!
    return NSImage(cgImage: cg, size: NSSize(width: rect.width, height: rect.height))
}

func rounded(_ size: CGFloat, _ weight: NSFont.Weight = .bold) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
}

func text(_ string: String, font: NSFont, color: NSColor, center x: CGFloat, top y: CGFloat) -> CGFloat {
    let attr = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
    let size = attr.size()
    attr.draw(at: NSPoint(x: x - size.width / 2, y: y))
    return size.width
}

func drawBackground() {
    // Background: graphite gradient so the black notch UI stands out, plus soft light from the top.
    NSGradient(colors: [NSColor(white: 0.20, alpha: 1), NSColor(white: 0.07, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
    NSGradient(colors: [NSColor(white: 1, alpha: 0.12), NSColor(white: 1, alpha: 0)])!
        .draw(fromCenter: NSPoint(x: W / 2, y: 0), radius: 0, toCenter: NSPoint(x: W / 2, y: 0), radius: 1200, options: [])

}

/// Link preview: hero notch, wordmark, tagline and a feature line. Text stays large so it reads in a feed.
func drawOG() {
    drawBackground()
    let hero = trimmed("home", pad: 40)
    let heroW: CGFloat = 1640
    let heroH = hero.size.height * heroW / hero.size.width
    hero.draw(in: NSRect(x: (W - heroW) / 2, y: 0, width: heroW, height: heroH))

    var y = heroH + 150
    let mark = NSAttributedString(string: "Open", attributes: [.font: rounded(170, .heavy), .foregroundColor: NSColor.white])
    let notchi = NSAttributedString(string: "Notchi", attributes: [.font: rounded(170, .heavy), .foregroundColor: NSColor(white: 0.56, alpha: 1)])
    let total = mark.size().width + notchi.size().width
    mark.draw(at: NSPoint(x: (W - total) / 2, y: y))
    notchi.draw(at: NSPoint(x: (W - total) / 2 + mark.size().width, y: y))
    y += 235
    _ = text("Your notch, but alive.", font: rounded(64, .semibold), color: NSColor(white: 0.88, alpha: 1), center: W / 2, top: y)
    y += 120
    _ = text("Music · Lyrics · YouTube · AirDrop · Markets · Clipboard · Timer", font: NSFont.systemFont(ofSize: 40, weight: .medium), color: NSColor(white: 0.55, alpha: 1), center: W / 2, top: y)
    y += 76
    _ = text("Free & open source for macOS", font: NSFont.systemFont(ofSize: 40, weight: .semibold), color: NSColor(white: 0.75, alpha: 1), center: W / 2, top: y)
}

func drawShowcase() {
    drawBackground()

    // Hero: the open notch hanging from the top edge.
    let hero = trimmed("home", pad: 40)
    let heroW: CGFloat = 1500
    let heroH = hero.size.height * heroW / hero.size.width
    hero.draw(in: NSRect(x: (W - heroW) / 2, y: 0, width: heroW, height: heroH))

    // Wordmark + tagline.
    var y = heroH + 50
    let mark = NSAttributedString(string: "Open", attributes: [.font: rounded(120, .heavy), .foregroundColor: NSColor.white])
    let notchi = NSAttributedString(string: "Notchi", attributes: [.font: rounded(120, .heavy), .foregroundColor: NSColor(white: 0.56, alpha: 1)])
    let total = mark.size().width + notchi.size().width
    mark.draw(at: NSPoint(x: (W - total) / 2, y: y))
    notchi.draw(at: NSPoint(x: (W - total) / 2 + mark.size().width, y: y))
    y += 150
    _ = text("Your notch, but alive.", font: rounded(44, .semibold), color: NSColor(white: 0.85, alpha: 1), center: W / 2, top: y)
    y += 64
    _ = text("Free & open source for macOS  ·  opennotchi.vercel.app", font: NSFont.systemFont(ofSize: 28, weight: .medium), color: NSColor(white: 0.5, alpha: 1), center: W / 2, top: y)

    // Three feature cards.
    y += 110
    let cards: [(String, String, String)] = [
        ("lyrics", "Synced lyrics", "Flip the player into lyrics mode"),
        ("markets", "Markets", "IDX & global stocks, crypto, FX"),
        ("timer", "Focus timer", "Countdown that stays beside the notch"),
    ]
    let cardW: CGFloat = 720, gap: CGFloat = 60
    let startX = (W - (cardW * 3 + gap * 2)) / 2
    var maxCardH: CGFloat = 0
    for (i, card) in cards.enumerated() {
        let image = trimmed(card.0, pad: 30)
        let h = image.size.height * cardW / image.size.width
        maxCardH = max(maxCardH, h)
        let x = startX + CGFloat(i) * (cardW + gap)
        image.draw(in: NSRect(x: x, y: y, width: cardW, height: h))
    }
    for (i, card) in cards.enumerated() {
        let x = startX + CGFloat(i) * (cardW + gap) + cardW / 2
        _ = text(card.1, font: rounded(34, .bold), color: .white, center: x, top: y + maxCardH + 18)
        _ = text(card.2, font: NSFont.systemFont(ofSize: 24, weight: .regular), color: NSColor(white: 0.55, alpha: 1), center: x, top: y + maxCardH + 64)
    }

    // Live activities strip.
    y += maxCardH + 210
    let peeks = ["closed-music", "peek-charging", "peek-airpods", "peek-volume"].map { trimmed($0, pad: 6) }
    let peekH: CGFloat = 50
    let widths = peeks.map { $0.size.width * peekH / $0.size.height }
    let peekGap: CGFloat = 60
    var x = (W - widths.reduce(0, +) - peekGap * CGFloat(peeks.count - 1)) / 2
    _ = text("Live activities beside the notch", font: rounded(30, .bold), color: NSColor(white: 0.85, alpha: 1), center: W / 2, top: y - 66)
    for (image, w) in zip(peeks, widths) {
        image.draw(in: NSRect(x: x, y: y, width: w, height: peekH))
        x += w + peekGap
    }
}

let canvas = NSImage(size: NSSize(width: W, height: H), flipped: true) { _ in
    isOG ? drawOG() : drawShowcase()
    return true
}

let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
