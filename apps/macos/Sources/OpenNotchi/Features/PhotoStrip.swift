import AppKit
import CoreImage
import SwiftUI

/// Look of a photobox strip.
enum StripStyle: String, CaseIterable, Identifiable {
    // Trending looks first.
    case classic, receipt, social, player, scrapbook, coquette, desktop
    case film, polaroid, y2k, midnight, sakura, retro, newspaper, neon, pastel, love, album

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .receipt: return "Receipt"
        case .social: return "Social Post"
        case .player: return "Player"
        case .scrapbook: return "Scrapbook"
        case .coquette: return "Coquette"
        case .desktop: return "Retro PC"
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
        case .receipt: return [Color(red: 0.97, green: 0.96, blue: 0.94), Color(white: 0.3)]
        case .social: return [.white, Color(red: 0.93, green: 0.29, blue: 0.4)]
        case .player: return [Color(red: 0.2, green: 0.75, blue: 0.4), Color(white: 0.08)]
        case .scrapbook: return [Color(red: 0.91, green: 0.86, blue: 0.77), Color(red: 0.55, green: 0.8, blue: 0.7)]
        case .coquette: return [Color(red: 0.97, green: 0.84, blue: 0.88), Color(red: 0.76, green: 0.1, blue: 0.36)]
        case .desktop: return [Color(red: 0, green: 0.5, blue: 0.5), Color(white: 0.75)]
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

/// Output shape: the classic tall strip, or a fixed size for a social post or story.
enum StripFormat: String, CaseIterable, Identifiable {
    case strip, story, post, square

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strip: return "Photo strip"
        case .story: return "Story 9:16"
        case .post: return "Post 4:5"
        case .square: return "Square 1:1"
        }
    }

    var icon: String {
        switch self {
        case .strip: return "rectangle.split.1x2"
        case .story: return "iphone"
        case .post: return "rectangle.portrait"
        case .square: return "square"
        }
    }

    /// Height ÷ width, or nil when the height grows with the number of photos.
    var heightRatio: CGFloat? {
        switch self {
        case .strip: return nil
        case .story: return 16 / 9
        case .post: return 5 / 4
        case .square: return 1
        }
    }
}

/// Photos per photobox session.
enum StripShots {
    static let choices = [1, 2, 3, 4, 6]
}

/// What's printed on the strip besides the photos.
struct StripInfo {
    /// The user's own text; replaces the style's title when set.
    var caption: String?
    var date = Date.now
    var songTitle: String?
    var artist: String?
    var artwork: NSImage?
    /// Where the song is, for the Player style's progress bar.
    var songPosition: Double?
    var songDuration: Double?
    var isPlaying = true

    /// The song that's playing now. `sample` fills in a placeholder song for previews when nothing plays.
    @MainActor
    init(caption: String? = nil, media: MediaManager, sample: Bool = false) {
        self.caption = caption
        if let song = media.info {
            songTitle = song.title
            artist = song.artist
            artwork = media.artwork
            songPosition = song.position(at: .now)
            songDuration = song.duration > 0 ? song.duration : nil
            isPlaying = song.isPlaying
        } else if sample {
            songTitle = "Midnight Drive"
            artist = "The Placeholders"
        }
    }

    init(caption: String? = nil, date: Date = .now, songTitle: String? = nil, artist: String? = nil, artwork: NSImage? = nil) {
        self.caption = caption
        self.date = date
        self.songTitle = songTitle
        self.artist = artist
        self.artwork = artwork
    }
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

    /// Lays out every photo given (one per cell) in `format`.
    static func compose(_ photos: [CGImage], style: StripStyle, format: StripFormat = .strip, info: StripInfo) -> CGImage? {
        guard !photos.isEmpty else { return nil }
        let photos = photos.map { filtered($0, style: style) }
        let count = photos.count

        let width: CGFloat = 1200
        let side: CGFloat
        switch style {
        case .film: side = 120
        case .social: side = 0
        case .receipt: side = 100
        default: side = 70
        }
        let header: CGFloat = style == .social ? 150 : 0
        var footer = footerHeight(style)
        let gap: CGFloat = style == .film ? 26 : style == .social ? 6 : 34
        var footerScale: CGFloat = 1.3
        var cells: [CGRect] = []
        let height: CGFloat

        if let ratio = format.heightRatio {
            // Fixed canvas: the footer gives up space if needed, then the photos share the rest in the
            // grid whose cells come closest to the camera's 4:3.
            height = (width * ratio).rounded()
            let fit = min(1, height * 0.3 / footer)
            footer *= fit
            footerScale *= fit
            let area = CGRect(x: side, y: header + side, width: width - 2 * side, height: height - header - footer - side - (style == .social ? 0 : 10))
            let columns = (1...min(3, count)).filter { count % $0 == 0 }.min { a, b in
                abs(log(cellAspect(area, count: count, columns: a, gap: gap) / (4 / 3))) < abs(log(cellAspect(area, count: count, columns: b, gap: gap) / (4 / 3)))
            } ?? 1
            cells = grid(area, count: count, columns: columns, gap: gap)
        } else {
            // Classic strip: 4:3 photos, one column (two for grid styles), as tall as it needs to be.
            let columns = style.isGrid && count % 2 == 0 ? 2 : 1
            let rows = count / columns
            let cellW = (width - 2 * side - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let cellH = cellW * 3 / 4
            let area = CGRect(x: side, y: header + side, width: width - 2 * side, height: CGFloat(rows) * cellH + CGFloat(rows - 1) * gap)
            cells = grid(area, count: count, columns: columns, gap: gap)
            height = area.maxY + footer
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

        drawBackground(style, canvas: canvas, cells: cells, info: info, photos: photos)
        for (i, cell) in cells.enumerated() {
            drawPhoto(photos[i % photos.count], in: cell, style: style, index: i)
        }
        if style == .social {
            drawSocialHeader(avatar: photos[0], width: width, caption: info.caption)
        }
        // Keep decorations off the photos and the footer text.
        let textArea = CGRect(x: 120, y: footerRect.minY + 20, width: width - 240, height: footerRect.height - 20)
        drawDecorations(style, canvas: canvas, avoid: cells + [textArea])

        // Footer text is laid out at a base size and scaled up so it reads well on a phone.
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
        drawFooter(style, rect: scaledFooter, info: info, photos: photos)
        cg.restoreGState()

        return cg.makeImage()
    }

    private static func grid(_ area: CGRect, count: Int, columns: Int, gap: CGFloat) -> [CGRect] {
        let rows = max(1, count / columns)
        let w = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let h = (area.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        return (0..<count).map { i in
            CGRect(x: area.minX + CGFloat(i % columns) * (w + gap), y: area.minY + CGFloat(i / columns) * (h + gap), width: w, height: h)
        }
    }

    private static func cellAspect(_ area: CGRect, count: Int, columns: Int, gap: CGFloat) -> CGFloat {
        let rows = max(1, count / columns)
        let w = (area.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let h = (area.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
        return max(w, 1) / max(h, 1)
    }

    // MARK: - Photos

    private static func filtered(_ photo: CGImage, style: StripStyle) -> CGImage {
        let image = CIImage(cgImage: photo)
        let output: CIImage
        switch style {
        case .newspaper:
            output = image.applyingFilter("CIPhotoEffectNoir").applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.15])
        case .receipt:
            // Thermal-print look: grayscale, punchy, a little faded.
            output = image.applyingFilter("CIPhotoEffectMono")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.35, kCIInputBrightnessKey: 0.06])
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
        if drawTrendPhoto(photo, in: cell, style: style, index: index) { return }
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
        case .receipt, .social, .player, .scrapbook, .coquette, .desktop: radius = 0 // drawn by drawTrendPhoto
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

    private static func drawBackground(_ style: StripStyle, canvas: CGRect, cells: [CGRect], info: StripInfo, photos: [CGImage]) {
        switch style {
        case .receipt, .social, .player, .scrapbook, .coquette, .desktop:
            drawTrendBackground(style, canvas: canvas, photos: photos, info: info)
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
        case .scrapbook:
            let ink = NSColor(red: 0.23, green: 0.18, blue: 0.18, alpha: 0.75)
            let doodles = ["star", "heart", "sparkle", "sun.max", "scribble", "music.note", "camera"]
            for _ in 0..<18 {
                symbol(doodles.randomElement(using: &rng)!, color: ink, at: scatter(canvas, cells, &rng), size: .random(in: 22...40, using: &rng))
            }
        case .coquette:
            for _ in 0..<22 {
                symbol("heart.fill", color: NSColor.white.withAlphaComponent(.random(in: 0.5...0.9, using: &rng)), at: scatter(canvas, cells, &rng), size: .random(in: 16...34, using: &rng))
            }
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

    private static func drawFooter(_ style: StripStyle, rect: CGRect, info: StripInfo, photos: [CGImage]) {
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
        case .receipt, .social, .player, .scrapbook, .coquette, .desktop:
            drawTrendFooter(style, rect: rect, info: info, caption: custom)
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

// MARK: - Trending styles

extension PhotoStripComposer {
    static func footerHeight(_ style: StripStyle) -> CGFloat {
        switch style {
        case .receipt: return 880
        case .social: return 430
        case .player: return 560
        case .desktop: return 300
        case .pastel: return 340
        default: return 430
        }
    }

    /// Photos for the trending styles. Returns false for the classic ones.
    fileprivate static func drawTrendPhoto(_ photo: CGImage, in cell: CGRect, style: StripStyle, index: Int) -> Bool {
        switch style {
        case .receipt, .social:
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: cell).addClip()
            drawAspectFill(photo, in: cell)
            NSGraphicsContext.restoreGraphicsState()

        case .player:
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: cell, xRadius: 26, yRadius: 26).addClip()
            drawAspectFill(photo, in: cell)
            NSGraphicsContext.restoreGraphicsState()

        case .coquette:
            withShadow(color: NSColor(red: 0.6, green: 0.2, blue: 0.3, alpha: 0.25), blur: 14, offset: CGSize(width: 0, height: 4)) {
                NSColor.white.setFill()
                NSBezierPath(roundedRect: cell, xRadius: 30, yRadius: 30).fill()
            }
            let frame = cell.insetBy(dx: 14, dy: 14)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: frame, xRadius: 20, yRadius: 20).addClip()
            drawAspectFill(photo, in: frame)
            NSGraphicsContext.restoreGraphicsState()
            emoji("🎀", size: 84, center: CGPoint(x: cell.midX, y: cell.minY + 6))

        case .scrapbook:
            // Printed photos, slightly crooked, held down with washi tape.
            let angles: [CGFloat] = [-2.2, 1.8, -1.3, 2.4]
            guard let cg = NSGraphicsContext.current?.cgContext else { return true }
            cg.saveGState()
            cg.translateBy(x: cell.midX, y: cell.midY)
            cg.rotate(by: angles[index % angles.count] * .pi / 180)
            cg.translateBy(x: -cell.midX, y: -cell.midY)
            let paper = cell.insetBy(dx: 18, dy: 12)
            withShadow(color: NSColor.black.withAlphaComponent(0.25), blur: 12, offset: CGSize(width: 2, height: 5)) {
                NSColor(white: 0.99, alpha: 1).setFill()
                NSBezierPath(rect: paper).fill()
            }
            let frame = paper.insetBy(dx: 18, dy: 18)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: frame).addClip()
            drawAspectFill(photo, in: frame)
            NSGraphicsContext.restoreGraphicsState()
            let tapes: [NSColor] = [
                NSColor(red: 0.62, green: 0.86, blue: 0.78, alpha: 0.8),
                NSColor(red: 0.98, green: 0.72, blue: 0.78, alpha: 0.8),
                NSColor(red: 0.98, green: 0.88, blue: 0.55, alpha: 0.8),
                NSColor(red: 0.7, green: 0.78, blue: 0.98, alpha: 0.8),
            ]
            cg.translateBy(x: paper.midX, y: paper.minY + 4)
            cg.rotate(by: (index % 2 == 0 ? -6 : 5) * .pi / 180)
            tapes[index % tapes.count].setFill()
            NSBezierPath(rect: CGRect(x: -100, y: -24, width: 200, height: 48)).fill()
            cg.restoreGState()

        case .desktop:
            drawWindow(photo, in: cell, title: "photo_\(index + 1).jpg")

        default:
            return false
        }
        return true
    }

    fileprivate static func drawTrendBackground(_ style: StripStyle, canvas: CGRect, photos: [CGImage], info: StripInfo) {
        switch style {
        case .receipt:
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

        case .social:
            fill(canvas, .white)

        case .player:
            // Backdrop tinted like a music app's now playing screen: from the cover art, else the photos.
            let cover = info.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            let tint = averageColor(cover ?? photos.first) ?? NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1)
            NSGradient(colors: [tint.blended(withFraction: 0.35, of: .black) ?? tint, NSColor(white: 0.06, alpha: 1)])!
                .draw(in: canvas, angle: -90)

        case .scrapbook:
            fill(canvas, NSColor(red: 0.91, green: 0.86, blue: 0.77, alpha: 1))
            NSColor(red: 0.8, green: 0.72, blue: 0.6, alpha: 0.5).setFill()
            for y in stride(from: 24.0, to: canvas.height, by: 40) {
                for x in stride(from: 24.0, to: canvas.width, by: 40) {
                    NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 5, height: 5)).fill()
                }
            }

        case .coquette:
            fill(canvas, NSColor(red: 0.97, green: 0.84, blue: 0.88, alpha: 1))
            // Gingham: translucent white bands both ways.
            NSColor.white.withAlphaComponent(0.32).setFill()
            for x in stride(from: 0.0, to: canvas.width, by: 80) {
                NSBezierPath(rect: CGRect(x: x, y: 0, width: 40, height: canvas.height)).fill()
            }
            for y in stride(from: 0.0, to: canvas.height, by: 80) {
                NSBezierPath(rect: CGRect(x: 0, y: y, width: canvas.width, height: 40)).fill()
            }

        case .desktop:
            fill(canvas, NSColor(red: 0, green: 0.5, blue: 0.5, alpha: 1))
            // Taskbar along the bottom.
            let bar = CGRect(x: 0, y: canvas.maxY - 76, width: canvas.width, height: 76)
            fill(bar, NSColor(white: 0.75, alpha: 1))
            fill(CGRect(x: 0, y: bar.minY, width: canvas.width, height: 3), .white)
            let start = CGRect(x: 12, y: bar.minY + 12, width: 150, height: 52)
            bevel(start, raised: true)
            draw("▦ Start", font: .systemFont(ofSize: 28, weight: .heavy), color: .black, at: CGPoint(x: start.minX + 18, y: start.minY + 9))
            let clock = CGRect(x: canvas.width - 162, y: bar.minY + 12, width: 150, height: 52)
            bevel(clock, raised: false)
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            draw(f.string(from: .now), font: .monospacedDigitSystemFont(ofSize: 26, weight: .medium), color: .black, at: CGPoint(x: clock.minX + 38, y: clock.minY + 11))

        default:
            break
        }
    }

    fileprivate static func drawSocialHeader(avatar: CGImage, width: CGFloat, caption: String?) {
        let avatarRect = CGRect(x: 30, y: 30, width: 90, height: 90)
        // Story ring around the avatar.
        NSGradient(colors: [.systemYellow, .systemOrange, .systemPink, .systemPurple])!
            .draw(in: NSBezierPath(ovalIn: avatarRect.insetBy(dx: -6, dy: -6)), angle: 45)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: avatarRect.insetBy(dx: -2, dy: -2)).fill()
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: avatarRect).addClip()
        drawAspectFill(avatar, in: avatarRect)
        NSGraphicsContext.restoreGraphicsState()
        draw("bestie.diaries", font: .systemFont(ofSize: 34, weight: .bold), color: .black, at: CGPoint(x: 146, y: 32))
        draw("Original audio", font: .systemFont(ofSize: 26), color: NSColor(white: 0.45, alpha: 1), at: CGPoint(x: 146, y: 76))
        draw("•••", font: .systemFont(ofSize: 34, weight: .bold), color: .black, at: CGPoint(x: width - 90, y: 46))
    }

    fileprivate static func drawTrendFooter(_ style: StripStyle, rect: CGRect, info: StripInfo, caption: String?) {
        let f = DateFormatter()
        switch style {
        case .receipt:
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
            y += centered("★ " + (caption ?? "PHOTOBOX").uppercased() + " ★", font: .monospacedSystemFont(ofSize: 42, weight: .heavy), color: ink, x: rect.midX, y: y) + 6
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

        case .social:
            let x = rect.minX + 24
            var y = rect.minY + 20
            for (i, name) in ["heart.fill", "bubble.right", "paperplane"].enumerated() {
                symbol(name, color: i == 0 ? NSColor(red: 0.93, green: 0.22, blue: 0.33, alpha: 1) : .black, at: CGPoint(x: x + 20 + CGFloat(i) * 76, y: y + 24), size: 40)
            }
            symbol("bookmark", color: .black, at: CGPoint(x: rect.maxX - 44, y: y + 24), size: 40)
            y += 72
            draw("Liked by you and 1,024 others", font: .systemFont(ofSize: 30, weight: .semibold), color: .black, at: CGPoint(x: x, y: y))
            y += 44
            let text = NSMutableAttributedString(string: "bestie.diaries ", attributes: [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: NSColor.black])
            text.append(NSAttributedString(string: caption ?? "core memories unlocked ✨", attributes: [.font: NSFont.systemFont(ofSize: 30), .foregroundColor: NSColor.black]))
            text.draw(in: CGRect(x: x, y: y, width: rect.width - 48, height: 42))
            y += 44
            draw("View all 128 comments", font: .systemFont(ofSize: 27), color: NSColor(white: 0.5, alpha: 1), at: CGPoint(x: x, y: y))
            y += 40
            f.dateFormat = "d MMMM"
            draw(f.string(from: info.date).uppercased(), font: .systemFont(ofSize: 21, weight: .medium), color: NSColor(white: 0.55, alpha: 1), at: CGPoint(x: x, y: y))

        case .player:
            // The song that was playing when the strip was taken; your text becomes the "playing from" line.
            let x = rect.minX + 54
            let width = rect.width - 108
            var y = rect.minY + 30
            let title = info.songTitle ?? caption ?? "our little moments"
            let artist = info.artist ?? "you & me"
            if info.songTitle != nil, let caption {
                draw("PLAYING FROM  " + caption.uppercased(), font: .systemFont(ofSize: 20, weight: .bold), color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: x, y: y), maxWidth: width)
                y += 34
            }
            var textX = x
            if let artwork = info.artwork {
                let thumb = CGRect(x: x, y: y + 4, width: 96, height: 96)
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(roundedRect: thumb, xRadius: 10, yRadius: 10).addClip()
                artwork.draw(in: thumb, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                NSGraphicsContext.restoreGraphicsState()
                textX += 116
            }
            draw(title, font: .systemFont(ofSize: 46, weight: .bold), color: .white, at: CGPoint(x: textX, y: y), maxWidth: x + width - 70 - textX)
            symbol("heart.fill", color: NSColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1), at: CGPoint(x: x + width - 20, y: y + 32), size: 40)
            y += 60
            draw(artist, font: .systemFont(ofSize: 30, weight: .medium), color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: textX, y: y), maxWidth: x + width - 70 - textX)
            y += 82
            let duration = info.songDuration ?? 225
            let position = min(info.songPosition ?? 84, duration)
            let fraction = CGFloat(position / duration)
            fill(CGRect(x: x, y: y, width: width, height: 6), NSColor(white: 1, alpha: 0.25))
            fill(CGRect(x: x, y: y, width: width * fraction, height: 6), .white)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: CGRect(x: x + width * fraction - 10, y: y - 7, width: 20, height: 20)).fill()
            y += 20
            func clock(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
            draw(clock(position), font: .monospacedDigitSystemFont(ofSize: 22, weight: .medium), color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: x, y: y))
            draw("-" + clock(duration - position), font: .monospacedDigitSystemFont(ofSize: 22, weight: .medium), color: NSColor(white: 1, alpha: 0.6), at: CGPoint(x: x + width - 62, y: y))
            y += 90
            let controls: [(String, CGFloat)] = [("shuffle", 32), ("backward.fill", 44), ("", 0), ("forward.fill", 44), ("repeat", 32)]
            for (i, control) in controls.enumerated() {
                let center = CGPoint(x: x + 16 + (width - 32) * CGFloat(i) / 4, y: y)
                if control.0.isEmpty {
                    // Play button: white disc with a dark pause glyph.
                    NSColor.white.setFill()
                    NSBezierPath(ovalIn: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92)).fill()
                    symbol(info.isPlaying ? "pause.fill" : "play.fill", color: NSColor(white: 0.1, alpha: 1), at: center, size: 38)
                } else {
                    symbol(control.0, color: .white, at: center, size: control.1)
                }
            }

        case .scrapbook:
            let ink = NSColor(red: 0.23, green: 0.18, blue: 0.18, alpha: 1)
            var y = rect.minY + 40
            y += centered(caption ?? "our little adventure", font: NSFont(name: "Marker Felt Wide", size: 64) ?? rounded(56, .bold), color: ink, x: rect.midX, y: y)
            f.dateFormat = "dd.MM.yy"
            centered("— " + f.string(from: info.date) + " —", font: NSFont(name: "Noteworthy-Bold", size: 30) ?? .systemFont(ofSize: 28), color: ink.withAlphaComponent(0.7), x: rect.midX, y: y + 10)

        case .coquette:
            let rose = NSColor(red: 0.76, green: 0.1, blue: 0.36, alpha: 1)
            var y = rect.minY + 30
            y += centered(caption ?? "lovely", font: NSFont(name: "Snell Roundhand Bold", size: 96) ?? rounded(70, .bold), color: rose, x: rect.midX, y: y)
            f.dateFormat = "dd · MM · yyyy"
            centered("🎀  " + f.string(from: info.date) + "  🎀", font: rounded(28, .semibold), color: rose.withAlphaComponent(0.8), x: rect.midX, y: y)

        case .desktop:
            let y = rect.minY + 34
            centered(caption ?? "my_memories.exe", font: NSFont(name: "Courier New Bold", size: 54) ?? .monospacedSystemFont(ofSize: 50, weight: .bold), color: .white, x: rect.midX, y: y, shadow: NSColor.black.withAlphaComponent(0.6))

        default:
            break
        }
    }

    /// A Windows-98-style window with the photo inside.
    private static func drawWindow(_ photo: CGImage, in cell: CGRect, title: String) {
        bevel(cell, raised: true)
        let inner = cell.insetBy(dx: 6, dy: 6)
        let titleBar = CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: 46)
        NSGradient(colors: [NSColor(red: 0, green: 0, blue: 0.5, alpha: 1), NSColor(red: 0.06, green: 0.52, blue: 0.82, alpha: 1)])!.draw(in: titleBar, angle: 0)
        draw(title, font: .systemFont(ofSize: 24, weight: .bold), color: .white, at: CGPoint(x: titleBar.minX + 14, y: titleBar.minY + 9))
        for (i, glyph) in ["_", "□", "×"].enumerated() {
            let button = CGRect(x: titleBar.maxX - CGFloat(3 - i) * 42 - 4, y: titleBar.minY + 7, width: 36, height: 32)
            bevel(button, raised: true)
            draw(glyph, font: .systemFont(ofSize: 22, weight: .heavy), color: .black, at: CGPoint(x: button.minX + 10, y: button.minY + 1))
        }
        let photoRect = CGRect(x: inner.minX + 4, y: titleBar.maxY + 6, width: inner.width - 8, height: inner.maxY - titleBar.maxY - 10)
        bevel(photoRect.insetBy(dx: -3, dy: -3), raised: false)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: photoRect).addClip()
        drawAspectFill(photo, in: photoRect)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Classic 3D bevel: light top-left, dark bottom-right (reversed when sunken).
    private static func bevel(_ rect: CGRect, raised: Bool) {
        fill(rect, NSColor(white: 0.75, alpha: 1))
        let light = NSColor.white, dark = NSColor(white: 0.35, alpha: 1)
        let (topLeft, bottomRight) = raised ? (light, dark) : (dark, light)
        fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 3), topLeft)
        fill(CGRect(x: rect.minX, y: rect.minY, width: 3, height: rect.height), topLeft)
        fill(CGRect(x: rect.minX, y: rect.maxY - 3, width: rect.width, height: 3), bottomRight)
        fill(CGRect(x: rect.maxX - 3, y: rect.minY, width: 3, height: rect.height), bottomRight)
    }

    private static func emoji(_ text: String, size: CGFloat, center: CGPoint) {
        let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size)])
        let s = string.size()
        string.draw(at: CGPoint(x: center.x - s.width / 2, y: center.y - s.height / 2))
    }

    private static func averageColor(_ image: CGImage?) -> NSColor? {
        guard let image else { return nil }
        let ci = CIImage(cgImage: image)
        let average = ci.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: ci.extent)])
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(average, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
        return NSColor(srgbRed: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
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
    func update(caption: String, info: StripInfo, shots: Int = 4, format: StripFormat = .strip) {
        let newKey = "\(caption)|\(info.songTitle ?? "")|\(info.artist ?? "")|\(shots)|\(format.rawValue)"
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
                let samples = PhotoStripComposer.samplePhotos
                let photos = (0..<shots).map { samples[$0 % samples.count] }
                for style in StripStyle.allCases {
                    guard let full = PhotoStripComposer.compose(photos, style: style, format: format, info: info),
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

