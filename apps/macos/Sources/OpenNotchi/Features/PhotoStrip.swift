import AppKit
import CoreImage
import SwiftUI

/// Look of a photobox strip.
enum StripStyle: String, CaseIterable, Identifiable {
    case classic, midnight, film, polaroid, y2k, sakura, retro, newspaper, neon, pastel, love, album

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .film: return "Film"
        case .polaroid: return "Polaroid"
        case .y2k: return "Y2K"
        case .sakura: return "Sakura"
        case .retro: return "Retro"
        case .newspaper: return "Newspaper"
        case .neon: return "Neon"
        case .pastel: return "Pastel Grid"
        case .love: return "Love"
        case .album: return "Now Playing"
        }
    }

    /// Two colors for the picker swatch.
    var swatch: [Color] {
        switch self {
        case .classic: return [.white, Color(white: 0.85)]
        case .midnight: return [Color(white: 0.2), .black]
        case .film: return [Color(red: 0.91, green: 0.64, blue: 0.23), Color(white: 0.08)]
        case .polaroid: return [Color(red: 0.96, green: 0.94, blue: 0.9), Color(red: 0.17, green: 0.23, blue: 0.4)]
        case .y2k: return [Color(red: 1, green: 0.54, blue: 0.85), Color(red: 0.54, green: 0.48, blue: 1)]
        case .sakura: return [Color(red: 1, green: 0.89, blue: 0.93), Color(red: 0.83, green: 0.42, blue: 0.55)]
        case .retro: return [Color(red: 0.91, green: 0.64, blue: 0.23), Color(red: 0.85, green: 0.34, blue: 0.17)]
        case .newspaper: return [Color(red: 0.93, green: 0.92, blue: 0.89), Color(white: 0.15)]
        case .neon: return [.cyan, Color(red: 1, green: 0.2, blue: 0.75)]
        case .pastel: return [Color(red: 0.81, green: 0.96, blue: 0.91), Color(red: 0.98, green: 0.85, blue: 0.75)]
        case .love: return [Color(red: 0.9, green: 0.22, blue: 0.27), .pink]
        case .album: return [.purple, .orange]
        }
    }

    var isGrid: Bool { self == .pastel }
}

/// What's printed on the strip besides the photos.
struct StripInfo {
    /// The user's own text; replaces the style's title when set.
    var caption: String?
    var date = Date.now
    var songTitle: String?
    var artist: String?
    var artwork: NSImage?
}

/// Lays four photos out as a photobox strip (or a 2×2 grid) in one of the `StripStyle`s.
enum PhotoStripComposer {
    private static let ciContext = CIContext()

    /// Placeholder portraits for previews: soft silhouettes on colorful backdrops.
    static let samplePhotos: [CGImage] = [(0.02, 0.08), (0.55, 0.62), (0.9, 0.97), (0.33, 0.42)].compactMap { hues in
        let w = 800, h = 600
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: [
                  NSColor(hue: hues.0, saturation: 0.45, brightness: 0.95, alpha: 1).cgColor,
                  NSColor(hue: hues.1, saturation: 0.6, brightness: 0.55, alpha: 1).cgColor,
              ] as CFArray, locations: nil) else { return nil }
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])
        ctx.setFillColor(NSColor(white: 1, alpha: 0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: 310, y: 230, width: 180, height: 210))  // head
        ctx.fillEllipse(in: CGRect(x: 200, y: -170, width: 400, height: 380)) // shoulders
        return ctx.makeImage()
    }

    static func compose(_ photos: [CGImage], style: StripStyle, info: StripInfo) -> CGImage? {
        guard !photos.isEmpty else { return nil }
        let photos = photos.map { filtered($0, style: style) }

        let width: CGFloat = 1200
        let side: CGFloat = style == .film ? 120 : 70
        let footer: CGFloat = style.isGrid ? 340 : 430
        let gap: CGFloat = style == .film ? 26 : 34
        var cells: [CGRect] = []
        let height: CGFloat
        if style.isGrid {
            let cellW = (width - 2 * side - gap) / 2
            let cellH = cellW * 3 / 4
            for i in 0..<4 {
                cells.append(CGRect(x: side + CGFloat(i % 2) * (cellW + gap), y: side + CGFloat(i / 2) * (cellH + gap), width: cellW, height: cellH))
            }
            height = side + 2 * cellH + gap + footer
        } else {
            let cellW = width - 2 * side
            let cellH = cellW * 3 / 4
            for i in 0..<4 {
                cells.append(CGRect(x: side, y: side + CGFloat(i) * (cellH + gap), width: cellW, height: cellH))
            }
            height = side + 4 * cellH + 3 * gap + footer
        }
        let canvas = CGRect(x: 0, y: 0, width: width, height: height)
        let footerRect = CGRect(x: 0, y: height - footer, width: width, height: footer)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                                 space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // Top-left origin, like the layout above.
        cg.translateBy(x: 0, y: height)
        cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }

        drawBackground(style, canvas: canvas, cells: cells, info: info)
        for (i, cell) in cells.enumerated() {
            drawPhoto(photos[i % photos.count], in: cell, style: style, index: i)
        }
        // Keep decorations off the photos and the footer text.
        let textArea = CGRect(x: 120, y: footerRect.minY + 20, width: width - 240, height: footerRect.height - 20)
        drawDecorations(style, canvas: canvas, avoid: cells + [textArea])

        // Footer text is laid out at a base size and scaled up so it reads well on a phone.
        let footerScale: CGFloat = 1.3
        cg.saveGState()
        cg.translateBy(x: footerRect.midX, y: footerRect.minY)
        cg.scaleBy(x: footerScale, y: footerScale)
        cg.translateBy(x: -footerRect.midX, y: -footerRect.minY)
        let scaledFooter = CGRect(
            x: footerRect.midX - footerRect.width / footerScale / 2,
            y: footerRect.minY,
            width: footerRect.width / footerScale,
            height: footerRect.height / footerScale
        )
        drawFooter(style, rect: scaledFooter, info: info)
        cg.restoreGState()

        return cg.makeImage()
    }

    // MARK: - Photos

    private static func filtered(_ photo: CGImage, style: StripStyle) -> CGImage {
        let image = CIImage(cgImage: photo)
        let output: CIImage
        switch style {
        case .newspaper:
            output = image.applyingFilter("CIPhotoEffectNoir").applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.15])
        case .retro:
            output = image.applyingFilter("CIPhotoEffectTransfer")
        case .film:
            output = image.applyingFilter("CIPhotoEffectChrome").applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.6, kCIInputRadiusKey: 1.8])
        default:
            return photo
        }
        return ciContext.createCGImage(output.cropped(to: image.extent), from: image.extent) ?? photo
    }

    private static func drawPhoto(_ photo: CGImage, in cell: CGRect, style: StripStyle, index: Int) {
        var frame = cell
        let radius: CGFloat
        switch style {
        case .classic: radius = 8
        case .midnight: radius = 14
        case .film, .newspaper: radius = 2
        case .polaroid: radius = 0
        case .y2k: radius = 30
        case .sakura, .pastel: radius = 24
        case .retro: radius = 26
        case .neon: radius = 18
        case .love: radius = 20
        case .album: radius = 16
        }

        // Frames and glows drawn behind the photo.
        switch style {
        case .polaroid:
            let paper = cell.insetBy(dx: 4, dy: 4)
            withShadow(color: NSColor.black.withAlphaComponent(0.25), blur: 18, offset: CGSize(width: 0, height: 6)) {
                NSColor.white.setFill()
                NSBezierPath(rect: paper).fill()
            }
            frame = paper.insetBy(dx: 22, dy: 22)
        case .y2k, .sakura, .love:
            let border: CGFloat = style == .y2k ? 8 : 10
            withShadow(color: NSColor.black.withAlphaComponent(0.18), blur: 14, offset: CGSize(width: 0, height: 4)) {
                NSColor.white.setFill()
                NSBezierPath(roundedRect: cell, xRadius: radius + border, yRadius: radius + border).fill()
            }
            frame = cell.insetBy(dx: border, dy: border)
        case .neon:
            let glow: NSColor = index % 2 == 0 ? .cyan : NSColor(red: 1, green: 0.2, blue: 0.75, alpha: 1)
            withShadow(color: glow, blur: 30, offset: .zero) {
                glow.setStroke()
                let path = NSBezierPath(roundedRect: cell, xRadius: radius, yRadius: radius)
                path.lineWidth = 6
                path.stroke()
            }
            frame = cell.insetBy(dx: 7, dy: 7)
        default:
            break
        }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius).addClip()
        drawAspectFill(photo, in: frame)
        NSGraphicsContext.restoreGraphicsState()

        switch style {
        case .midnight, .album:
            NSColor.white.withAlphaComponent(style == .album ? 0.4 : 0.14).setStroke()
            let path = NSBezierPath(roundedRect: frame.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
            path.lineWidth = 2
            path.stroke()
        case .newspaper:
            NSColor.black.setStroke()
            let path = NSBezierPath(rect: frame)
            path.lineWidth = 3
            path.stroke()
        default:
            break
        }
    }

    private static func drawAspectFill(_ image: CGImage, in rect: CGRect) {
        let size = CGSize(width: image.width, height: image.height)
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let target = CGRect(x: rect.midX - drawn.width / 2, y: rect.midY - drawn.height / 2, width: drawn.width, height: drawn.height)
        NSImage(cgImage: image, size: size).draw(in: target, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
    }

    // MARK: - Background

    private static func drawBackground(_ style: StripStyle, canvas: CGRect, cells: [CGRect], info: StripInfo) {
        switch style {
        case .classic:
            fill(canvas, NSColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1))
        case .midnight:
            NSGradient(colors: [NSColor(white: 0.1, alpha: 1), NSColor(white: 0.02, alpha: 1)])!.draw(in: canvas, angle: -90)
        case .film:
            fill(canvas, NSColor(white: 0.07, alpha: 1))
            // Sprocket holes down both edges.
            NSColor(white: 0.93, alpha: 1).setFill()
            var y: CGFloat = 30
            while y < canvas.height - 40 {
                for x in [38.0, canvas.width - 38 - 34] {
                    NSBezierPath(roundedRect: CGRect(x: x, y: y, width: 34, height: 46), xRadius: 6, yRadius: 6).fill()
                }
                y += 82
            }
        case .polaroid:
            fill(canvas, NSColor(red: 0.96, green: 0.94, blue: 0.9, alpha: 1))
        case .y2k:
            NSGradient(colors: [
                NSColor(red: 1, green: 0.54, blue: 0.85, alpha: 1),
                NSColor(red: 0.62, green: 0.5, blue: 1, alpha: 1),
                NSColor(red: 0.45, green: 0.85, blue: 1, alpha: 1),
            ])!.draw(in: canvas, angle: -70)
        case .sakura:
            NSGradient(colors: [NSColor(red: 1, green: 0.92, blue: 0.95, alpha: 1), NSColor(red: 1, green: 0.84, blue: 0.9, alpha: 1)])!.draw(in: canvas, angle: -90)
        case .retro:
            fill(canvas, NSColor(red: 0.95, green: 0.89, blue: 0.76, alpha: 1))
            // Seventies stripes behind the footer.
            let colors = [NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1), NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 1), NSColor(red: 0.48, green: 0.23, blue: 0.12, alpha: 1)]
            for (i, color) in colors.enumerated() {
                fill(CGRect(x: 0, y: canvas.height - 120 + CGFloat(i) * 40, width: canvas.width, height: 40), color)
            }
        case .newspaper:
            fill(canvas, NSColor(red: 0.93, green: 0.92, blue: 0.89, alpha: 1))
        case .neon:
            NSGradient(colors: [NSColor(red: 0.04, green: 0.03, blue: 0.13, alpha: 1), NSColor(red: 0.1, green: 0.04, blue: 0.23, alpha: 1)])!.draw(in: canvas, angle: -90)
        case .pastel:
            fill(canvas, NSColor(red: 0.81, green: 0.96, blue: 0.91, alpha: 1))
            NSColor.white.withAlphaComponent(0.55).setFill()
            for y in stride(from: 20.0, to: canvas.height, by: 46) {
                for x in stride(from: (Int(y) / 46) % 2 == 0 ? 20.0 : 43.0, to: canvas.width, by: 46) {
                    NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 9, height: 9)).fill()
                }
            }
        case .love:
            NSGradient(colors: [NSColor(red: 0.93, green: 0.27, blue: 0.33, alpha: 1), NSColor(red: 0.78, green: 0.12, blue: 0.22, alpha: 1)])!.draw(in: canvas, angle: -90)
        case .album:
            if let artwork = info.artwork, let cg = artwork.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let blurred = CIImage(cgImage: cg)
                    .clampedToExtent()
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: Double(max(cg.width, cg.height)) / 12])
                    .cropped(to: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
                if let output = ciContext.createCGImage(blurred, from: blurred.extent) {
                    drawAspectFill(output, in: canvas)
                }
                fill(canvas, NSColor.black.withAlphaComponent(0.45))
            } else {
                NSGradient(colors: [NSColor.systemPurple, NSColor.systemOrange])!.draw(in: canvas, angle: -60)
            }
        }
    }

    // MARK: - Decorations

    private static func drawDecorations(_ style: StripStyle, canvas: CGRect, avoid cells: [CGRect]) {
        var rng = SeededRandom(seed: 7)
        switch style {
        case .y2k:
            for _ in 0..<26 {
                let size = CGFloat.random(in: 22...54, using: &rng)
                symbol(Bool.random(using: &rng) ? "sparkle" : "star.fill", color: .white, at: scatter(canvas, cells, &rng), size: size)
            }
        case .sakura:
            for _ in 0..<30 {
                let p = scatter(canvas, cells, &rng)
                petal(at: p, size: .random(in: 18...34, using: &rng), angle: .random(in: 0...360, using: &rng))
            }
        case .love:
            for _ in 0..<28 {
                symbol("heart.fill", color: NSColor(red: 1, green: 0.75, blue: 0.8, alpha: .random(in: 0.6...1, using: &rng)), at: scatter(canvas, cells, &rng), size: .random(in: 20...50, using: &rng))
            }
        case .film:
            // Edge print and frame numbers, like a contact sheet.
            let color = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1)
            let font = NSFont(name: "Courier New Bold", size: 22) ?? .monospacedSystemFont(ofSize: 22, weight: .bold)
            for (i, cell) in cells.dropLast().enumerated() {
                draw("\(i + 1)  ▸  \(i + 1)A", font: font, color: color, at: CGPoint(x: cell.minX, y: cell.maxY + 1))
                drawRotated("FILM 400  ▸", font: font, color: color.withAlphaComponent(0.8), center: CGPoint(x: canvas.width - 105, y: cell.midY))
            }
        case .neon:
            for _ in 0..<14 {
                symbol("sparkle", color: Bool.random(using: &rng) ? .cyan : NSColor(red: 1, green: 0.3, blue: 0.8, alpha: 1), at: scatter(canvas, cells, &rng), size: .random(in: 16...30, using: &rng))
            }
        default:
            break
        }
    }

    /// A random point in the margins, never on a photo.
    private static func scatter(_ canvas: CGRect, _ cells: [CGRect], _ rng: inout SeededRandom) -> CGPoint {
        for _ in 0..<40 {
            let p = CGPoint(x: .random(in: 10...(canvas.width - 10), using: &rng), y: .random(in: 10...(canvas.height - 10), using: &rng))
            if !cells.contains(where: { $0.insetBy(dx: -24, dy: -24).contains(p) }) { return p }
        }
        return CGPoint(x: 30, y: 30)
    }

    private static func symbol(_ name: String, color: NSColor, at center: CGPoint, size: CGFloat) {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: .bold).applying(.init(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
        image.draw(in: CGRect(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2, width: image.size.width, height: image.size.height),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private static func petal(at center: CGPoint, size: CGFloat, angle: CGFloat) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: angle * .pi / 180)
        NSColor(red: 1, green: 0.66, blue: 0.78, alpha: 0.85).setFill()
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 0, y: -size / 2))
        path.curve(to: CGPoint(x: 0, y: size / 2), controlPoint1: CGPoint(x: size * 0.6, y: -size / 3), controlPoint2: CGPoint(x: size * 0.4, y: size / 3))
        path.curve(to: CGPoint(x: 0, y: -size / 2), controlPoint1: CGPoint(x: -size * 0.4, y: size / 3), controlPoint2: CGPoint(x: -size * 0.6, y: -size / 3))
        path.fill()
        cg.restoreGState()
    }

    // MARK: - Footer

    private static func drawFooter(_ style: StripStyle, rect: CGRect, info: StripInfo) {
        let date = info.date
        func dateString(_ format: String) -> String {
            let f = DateFormatter()
            f.dateFormat = format
            return f.string(from: date)
        }
        let center = rect.midX
        var y = rect.minY + 50
        let custom = info.caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        func title(_ fallback: String) -> String { custom ?? fallback }
        maxTextWidth = rect.width - 60

        switch style {
        case .classic:
            y += centered(title("photobooth"), font: rounded(64, .heavy), color: NSColor(white: 0.12, alpha: 1), x: center, y: y)
            centered(dateString("dd · MM · yyyy"), font: .systemFont(ofSize: 30, weight: .medium), color: NSColor(white: 0.45, alpha: 1), x: center, y: y + 14)
        case .midnight:
            // The one style that carries the app's wordmark.
            if let custom {
                centered(custom, font: rounded(64, .heavy), color: .white, x: center, y: y)
            } else {
                let open = NSAttributedString(string: "Open", attributes: [.font: rounded(64, .heavy), .foregroundColor: NSColor.white])
                let notchi = NSAttributedString(string: "Notchi", attributes: [.font: rounded(64, .heavy), .foregroundColor: NSColor(white: 0.55, alpha: 1)])
                let total = open.size().width + notchi.size().width
                open.draw(at: CGPoint(x: center - total / 2, y: y))
                notchi.draw(at: CGPoint(x: center - total / 2 + open.size().width, y: y))
            }
            centered(dateString("dd.MM.yyyy  ·  HH:mm"), font: .monospacedDigitSystemFont(ofSize: 28, weight: .medium), color: NSColor(white: 0.5, alpha: 1), x: center, y: y + 100)
        case .film:
            let font = NSFont(name: "Courier New Bold", size: 44) ?? .monospacedSystemFont(ofSize: 44, weight: .bold)
            y += centered(title("FILM  400"), font: font, color: NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1), x: center, y: y)
            centered(dateString("yy  MM  dd"), font: font.withSize(30), color: NSColor(red: 1, green: 0.45, blue: 0.2, alpha: 1), x: center, y: y + 14)
        case .polaroid:
            let ink = NSColor(red: 0.17, green: 0.23, blue: 0.4, alpha: 1)
            y += centered(title("good times ✌️"), font: NSFont(name: "Marker Felt Wide", size: 66) ?? NSFont(name: "Noteworthy-Bold", size: 60) ?? rounded(60, .bold), color: ink, x: center, y: y)
            centered(dateString("d MMMM yyyy"), font: NSFont(name: "Noteworthy-Bold", size: 32) ?? .systemFont(ofSize: 30), color: ink.withAlphaComponent(0.7), x: center, y: y + 8)
        case .y2k:
            y += centered(custom.map { "✦ \($0) ✦" } ?? "✦ besties ✦", font: rounded(70, .black), color: .white, x: center, y: y, shadow: NSColor(red: 0.4, green: 0.2, blue: 0.8, alpha: 0.6))
            centered(dateString("MM/dd/yyyy"), font: rounded(32, .bold), color: .white.withAlphaComponent(0.9), x: center, y: y + 10)
        case .sakura:
            let pink = NSColor(red: 0.83, green: 0.42, blue: 0.55, alpha: 1)
            y += centered(title("sakura days"), font: NSFont(name: "Snell Roundhand Bold", size: 84) ?? rounded(64, .bold), color: pink, x: center, y: y - 10)
            centered(dateString("yyyy.MM.dd"), font: rounded(30, .semibold), color: pink.withAlphaComponent(0.75), x: center, y: y)
        case .retro:
            let brown = NSColor(red: 0.48, green: 0.23, blue: 0.12, alpha: 1)
            centered(title("GROOVY"), font: NSFont(name: "Futura-CondensedExtraBold", size: 92) ?? rounded(80, .black), color: brown, x: center, y: y - 30)
            centered(dateString("MMM d, yyyy").uppercased(), font: NSFont(name: "Futura-Medium", size: 28) ?? .systemFont(ofSize: 28), color: brown.withAlphaComponent(0.8), x: center, y: y + 80)
        case .newspaper:
            NSColor.black.setFill()
            NSBezierPath(rect: CGRect(x: rect.minX + 30, y: rect.minY + 30, width: rect.width - 60, height: 4)).fill()
            y += centered(title("THE DAILY MOOD").uppercased(), font: NSFont(name: "Didot-Bold", size: 78) ?? NSFont(name: "Times New Roman Bold", size: 76) ?? .boldSystemFont(ofSize: 70), color: .black, x: center, y: y)
            NSBezierPath(rect: CGRect(x: rect.minX + 30, y: y + 6, width: rect.width - 60, height: 1.5)).fill()
            centered(dateString("EEEE, MMMM d, yyyy").uppercased() + "  ·  NO. 1  ·  FREE", font: NSFont(name: "Times New Roman", size: 24) ?? .systemFont(ofSize: 24), color: NSColor(white: 0.2, alpha: 1), x: center, y: y + 20)
        case .neon:
            let pink = NSColor(red: 1, green: 0.3, blue: 0.8, alpha: 1)
            y += centered(title("main character"), font: rounded(74, .heavy), color: pink, x: center, y: y, shadow: pink)
            centered(dateString("dd.MM.yyyy"), font: rounded(30, .bold), color: .cyan, x: center, y: y + 10, shadow: .cyan)
        case .pastel:
            let green = NSColor(red: 0.12, green: 0.42, blue: 0.33, alpha: 1)
            y += centered(title("core memories"), font: rounded(62, .heavy), color: green, x: center, y: y - 10)
            centered(dateString("dd MMM yyyy").lowercased(), font: rounded(30, .semibold), color: green.withAlphaComponent(0.7), x: center, y: y + 6)
        case .love:
            y += centered(title("with love"), font: NSFont(name: "Snell Roundhand Bold", size: 92) ?? rounded(70, .bold), color: .white, x: center, y: y - 16)
            centered(dateString("dd · MM · yyyy"), font: rounded(30, .semibold), color: .white.withAlphaComponent(0.85), x: center, y: y)
        case .album:
            let thumb: CGFloat = 130
            let text = info.songTitle ?? "Nothing playing"
            let sub = info.artist ?? dateString("dd MMM yyyy")
            let titleFont = rounded(46, .heavy)
            let titleWidth = min(NSAttributedString(string: text, attributes: [.font: titleFont]).size().width, rect.width - thumb - 220)
            let startX = center - (thumb + 30 + titleWidth) / 2
            if let artwork = info.artwork {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(roundedRect: CGRect(x: startX, y: y, width: thumb, height: thumb), xRadius: 14, yRadius: 14).addClip()
                artwork.draw(in: CGRect(x: startX, y: y, width: thumb, height: thumb), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                NSGraphicsContext.restoreGraphicsState()
            }
            let textX = startX + (info.artwork == nil ? 0 : thumb + 30)
            draw(custom ?? "♪ NOW PLAYING", font: rounded(22, .bold), color: .white.withAlphaComponent(0.7), at: CGPoint(x: textX, y: y + 4), maxWidth: rect.width - thumb - 100)
            draw(text, font: titleFont, color: .white, at: CGPoint(x: textX, y: y + 34), maxWidth: titleWidth)
            draw(sub, font: rounded(28, .medium), color: .white.withAlphaComponent(0.75), at: CGPoint(x: textX, y: y + 92), maxWidth: titleWidth)
        }

    }

    // MARK: - Drawing helpers

    /// Widest a footer line may be; set per strip.
    private static var maxTextWidth: CGFloat = .greatestFiniteMagnitude

    private static func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        return NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size) ?? base
    }

    private static func fill(_ rect: CGRect, _ color: NSColor) {
        color.setFill()
        NSBezierPath(rect: rect).fill()
    }

    private static func withShadow(color: NSColor, blur: CGFloat, offset: CGSize, _ body: () -> Void) {
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
    private static func centered(_ text: String, font: NSFont, color: NSColor, x: CGFloat, y: CGFloat, shadow: NSColor? = nil) -> CGFloat {
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

    private static func draw(_ text: String, font: NSFont, color: NSColor, at point: CGPoint, maxWidth: CGFloat? = nil) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        let size = string.size()
        string.draw(in: CGRect(x: point.x, y: point.y, width: maxWidth ?? size.width + 1, height: size.height))
    }

    private static func drawRotated(_ text: String, font: NSFont, color: NSColor, center: CGPoint) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let size = string.size()
        cg.saveGState()
        cg.translateBy(x: center.x, y: center.y)
        cg.rotate(by: .pi / 2)
        string.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        cg.restoreGState()
    }
}

/// Deterministic random numbers, so a style's decorations are laid out the same way every time.
private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// Small renders of every style for pickers, shared by Settings and the Mirror tab.
@MainActor
final class StripPreviews: ObservableObject {
    static let shared = StripPreviews()

    @Published private(set) var images: [StripStyle: NSImage] = [:]
    private var key: String?
    private var task: Task<Void, Never>?

    /// Re-renders when the caption or the song changes; cheap to call repeatedly.
    func update(caption: String, info: StripInfo) {
        let newKey = "\(caption)|\(info.songTitle ?? "")|\(info.artist ?? "")"
        guard newKey != key else { return }
        key = newKey
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(250)) // debounce typing
            guard !Task.isCancelled else { return }
            var info = info
            info.caption = caption
            let rendered = await Task.detached(priority: .userInitiated) { [info] () -> [StripStyle: NSImage] in
                var result: [StripStyle: NSImage] = [:]
                for style in StripStyle.allCases {
                    guard let full = PhotoStripComposer.compose(PhotoStripComposer.samplePhotos, style: style, info: info),
                          let small = Self.downscaled(full, width: 400) else { continue }
                    result[style] = NSImage(cgImage: small, size: NSSize(width: small.width, height: small.height))
                }
                return result
            }.value
            guard !Task.isCancelled else { return }
            images = rendered
        }
    }

    nonisolated private static func downscaled(_ image: CGImage, width: Int) -> CGImage? {
        let height = Int(Double(image.height) * Double(width) / Double(image.width))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}

/// Asks for the text printed on photobox strips. The notch panel is a poor place to type, so it's a small alert.
@MainActor
enum StripCaptionPrompt {
    static func ask(_ settings: AppSettings) {
        let alert = NSAlert()
        alert.messageText = "Text on your photobox strip"
        alert.informativeText = "Leave it empty to use each style's own title."
        let field = NSTextField(string: settings.stripCaption)
        field.placeholderString = "e.g. bestie day out ✨"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            settings.stripCaption = String(field.stringValue.prefix(40))
        }
    }
}
