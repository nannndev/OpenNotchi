import AppKit
import CoreImage
import SwiftUI

/// Look of a photobox strip.
enum StripStyle: String, CaseIterable, Identifiable {
    // Trending looks first.
    case classic, receipt, social, player, postcard, scrapbook, coquette, desktop
    case film, polaroid, y2k, midnight, sakura, retro, newspaper, neon, pastel, love, album

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .receipt: return "Receipt"
        case .social: return "Social Post"
        case .player: return "Player"
        case .postcard: return "Postcard"
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
        case .postcard: return [Color(red: 0.85, green: 0.22, blue: 0.22), Color(red: 0.13, green: 0.32, blue: 0.62)]
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

/// Output shape: the classic tall strip, or a fixed size for a social post, story or postcard.
enum StripFormat: String, CaseIterable, Identifiable {
    case strip, story, post, postcard, square

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strip: return "Photo strip"
        case .story: return "Story 9:16"
        case .post: return "Post 4:5"
        case .postcard: return "Postcard 3:2"
        case .square: return "Square 1:1"
        }
    }

    var icon: String {
        switch self {
        case .strip: return "rectangle.split.1x2"
        case .story: return "iphone"
        case .post: return "rectangle.portrait"
        case .postcard: return "envelope"
        case .square: return "square"
        }
    }

    /// Height ÷ width, or nil when the height grows with the number of photos.
    var heightRatio: CGFloat? {
        switch self {
        case .strip: return nil
        case .story: return 16 / 9
        case .post: return 5 / 4
        case .postcard: return 3 / 2
        case .square: return 1
        }
    }
}

/// Photos per photobox session.
enum StripShots {
    static let choices = [1, 2, 3, 4, 6]
}

/// A sticker or stamp placed on the photo strip canvas.
struct PlacedSticker: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Emoji string, SF symbol name, or badge text.
    var content: String
    /// If true, rendered as an authentic rubber stamp badge with double border.
    var isBadge: Bool = false
    /// Color for badge ("red", "pink", "green", "black", "gold", "blue", "purple").
    var badgeColor: String = "red"
    /// Normalized horizontal position (0.0 ... 1.0).
    var x: CGFloat = 0.5
    /// Normalized vertical position (0.0 ... 1.0).
    var y: CGFloat = 0.5
    /// Relative scale multiplier (default 1.0).
    var scale: CGFloat = 1.0
    /// Rotation angle in degrees (-180 ... 180).
    var rotation: Double = 0.0
}

enum StickerPresets {
    static let cute: [String] = ["🎀", "💖", "✨", "🌸", "🐱", "🍒", "🍓", "🧸", "✌️", "🍰", "🪞", "🌷", "💄", "🐰"]
    static let y2k: [String] = ["⭐", "✦", "💿", "⚡", "🕶️", "👾", "🛸", "🔥", "🎧", "🦋", "🎱", "💎", "🛹", "💫"]
    static let mood: [String] = ["💌", "💋", "🍀", "🫧", "🌙", "☁️", "🍿", "☕", "🎞️", "📸", "💐", "🎉", "🕊️", "🐾"]

    struct StampItem: Identifiable {
        var id: String { text }
        let text: String
        let color: String
    }

    static let stamps: [StampItem] = [
        StampItem(text: "APPROVED", color: "red"),
        StampItem(text: "BESTIES ♡", color: "pink"),
        StampItem(text: "MEMORIES", color: "green"),
        StampItem(text: "TOP SECRET", color: "black"),
        StampItem(text: "100% CUTE", color: "pink"),
        StampItem(text: "PHOTO ID", color: "black"),
        StampItem(text: "LUCKY ✦", color: "blue"),
        StampItem(text: "HARU FILM", color: "black"),
        StampItem(text: "VINTAGE", color: "gold"),
        StampItem(text: "『極上』", color: "red"),
        StampItem(text: "『最高』", color: "red"),
        StampItem(text: "XOXO", color: "pink")
    ]
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
    static func compose(
        _ photos: [CGImage],
        style: StripStyle,
        format: StripFormat = .strip,
        info: StripInfo,
        stickers: [PlacedSticker] = []
    ) -> CGImage? {
        guard !photos.isEmpty else { return nil }
        let photos = photos.map { filtered($0, style: style) }
        let count = photos.count

        let width: CGFloat = 1200
        let side: CGFloat
        switch style {
        case .film: side = 120
        case .social: side = 0
        case .receipt: side = 100
        case .postcard: side = 65
        case .newspaper: side = 80
        case .classic: side = 70
        case .polaroid: side = 65
        default: side = 70
        }
        let header: CGFloat
        switch style {
        case .social: header = 150
        case .postcard: header = 85
        case .newspaper: header = 125
        case .classic: header = 65
        case .film: header = 50
        default: header = 0
        }
        var footer = footerHeight(style)
        let gap: CGFloat
        switch style {
        case .film: gap = 28
        case .social: gap = 6
        case .newspaper: gap = 44
        case .polaroid: gap = 30
        default: gap = 34
        }
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

        // Draw user stickers & stamps placed in the photobox studio!
        drawStickers(stickers, canvas: canvas)

        return cg.makeImage()
    }

    private static func drawStickers(_ stickers: [PlacedSticker], canvas: CGRect) {
        guard !stickers.isEmpty else { return }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        for sticker in stickers {
            let posX = sticker.x * canvas.width
            let posY = sticker.y * canvas.height

            ctx.saveGState()
            ctx.translateBy(x: posX, y: posY)
            ctx.rotate(by: CGFloat(sticker.rotation * .pi / 180.0))
            let s = sticker.scale * 1.6
            ctx.scaleBy(x: s, y: s)

            if sticker.isBadge {
                drawStampBadge(sticker)
            } else {
                let font = NSFont.systemFont(ofSize: 64)
                let str = NSAttributedString(string: sticker.content, attributes: [
                    .font: font,
                    .shadow: {
                        let sh = NSShadow()
                        sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
                        sh.shadowOffset = NSSize(width: 0, height: -3)
                        sh.shadowBlurRadius = 8
                        return sh
                    }()
                ])
                let size = str.size()
                str.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
            }

            ctx.restoreGState()
        }
    }

    private static func drawStampBadge(_ sticker: PlacedSticker) {
        let font = NSFont.systemFont(ofSize: 22, weight: .black)
        let color: NSColor
        switch sticker.badgeColor.lowercased() {
        case "pink": color = NSColor(red: 0.95, green: 0.25, blue: 0.60, alpha: 1)
        case "green": color = NSColor(red: 0.12, green: 0.55, blue: 0.35, alpha: 1)
        case "black": color = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        case "gold": color = NSColor(red: 0.90, green: 0.60, blue: 0.12, alpha: 1)
        case "blue": color = NSColor(red: 0.18, green: 0.55, blue: 0.92, alpha: 1)
        case "purple": color = NSColor(red: 0.65, green: 0.32, blue: 0.88, alpha: 1)
        default: color = NSColor(red: 0.88, green: 0.18, blue: 0.18, alpha: 1) // red
        }

        let str = NSAttributedString(string: sticker.content.uppercased(), attributes: [
            .font: font,
            .foregroundColor: color,
            .kern: 1.8
        ])
        let textSize = str.size()
        let padX: CGFloat = 16
        let padY: CGFloat = 8
        let badgeRect = CGRect(x: -textSize.width / 2 - padX, y: -textSize.height / 2 - padY, width: textSize.width + 2 * padX, height: textSize.height + 2 * padY)

        // Drop shadow for realistic physical stamp feel
        withShadow(color: NSColor.black.withAlphaComponent(0.2), blur: 6, offset: CGSize(width: 0, height: 2)) {
            color.withAlphaComponent(0.08).setFill()
            let bgPath = NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7)
            bgPath.fill()
        }

        // Outer border
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: 7, yRadius: 7)
        path.lineWidth = 3
        color.withAlphaComponent(0.9).setStroke()
        path.stroke()

        // Inner hairline border
        let inner = badgeRect.insetBy(dx: 3.5, dy: 3.5)
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: 4.5, yRadius: 4.5)
        innerPath.lineWidth = 1
        color.withAlphaComponent(0.45).setStroke()
        innerPath.stroke()

        str.draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2 + 1))
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
            output = image.applyingFilter("CIPhotoEffectNoir")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.3, kCIInputBrightnessKey: 0.02])
        case .receipt:
            // Thermal-print look: grayscale, punchy, a little faded.
            output = image.applyingFilter("CIPhotoEffectMono")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.35, kCIInputBrightnessKey: 0.06])
        case .retro:
            output = image.applyingFilter("CIPhotoEffectTransfer")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.15])
        case .postcard:
            output = image.applyingFilter("CIPhotoEffectInstant")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.08, kCIInputSaturationKey: 1.1])
        case .polaroid:
            output = image.applyingFilter("CIPhotoEffectInstant")
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.1, kCIInputSaturationKey: 1.05, kCIInputBrightnessKey: 0.02])
        case .film:
            output = image.applyingFilter("CIPhotoEffectChrome")
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.55, kCIInputRadiusKey: 1.8])
        case .midnight:
            output = image.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.15, kCIInputSaturationKey: 0.95])
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.4, kCIInputRadiusKey: 1.9])
        case .sakura:
            output = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.12, kCIInputBrightnessKey: 0.03, kCIInputContrastKey: 1.02])
        case .y2k:
            output = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.25, kCIInputContrastKey: 1.12])
        case .classic:
            output = image.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.05, kCIInputSaturationKey: 1.02])
        default:
            return photo
        }
        return ciContext.createCGImage(output.cropped(to: image.extent), from: image.extent) ?? photo
    }

    private static func drawPhoto(_ photo: CGImage, in cell: CGRect, style: StripStyle, index: Int) {
        if drawTrendPhoto(photo, in: cell, style: style, index: index) { return }

        switch style {
        case .classic:
            let card = cell
            withShadow(color: NSColor.black.withAlphaComponent(0.12), blur: 12, offset: CGSize(width: 0, height: 3)) {
                NSColor.white.setFill()
                NSBezierPath(roundedRect: card, xRadius: 10, yRadius: 10).fill()
            }
            let photoFrame = card.insetBy(dx: 12, dy: 12)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: 6, yRadius: 6).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(white: 0, alpha: 0.08).setStroke()
            let innerStroke = NSBezierPath(roundedRect: photoFrame, xRadius: 6, yRadius: 6)
            innerStroke.lineWidth = 1
            innerStroke.stroke()

            // 4 corner crosshair markers
            let crossSize: CGFloat = 6
            let crossColor = NSColor(white: 0.4, alpha: 0.35)
            crossColor.setStroke()
            for pt in [
                CGPoint(x: card.minX + 6, y: card.minY + 6),
                CGPoint(x: card.maxX - 6, y: card.minY + 6),
                CGPoint(x: card.minX + 6, y: card.maxY - 6),
                CGPoint(x: card.maxX - 6, y: card.maxY - 6)
            ] {
                let p = NSBezierPath()
                p.move(to: CGPoint(x: pt.x - crossSize, y: pt.y))
                p.line(to: CGPoint(x: pt.x + crossSize, y: pt.y))
                p.move(to: CGPoint(x: pt.x, y: pt.y - crossSize))
                p.line(to: CGPoint(x: pt.x, y: pt.y + crossSize))
                p.lineWidth = 1
                p.stroke()
            }

        case .polaroid:
            let bottomExtra: CGFloat = 46
            let card = cell
            withShadow(color: NSColor.black.withAlphaComponent(0.22), blur: 16, offset: CGSize(width: 1, height: 5)) {
                NSColor(red: 0.99, green: 0.985, blue: 0.97, alpha: 1).setFill()
                NSBezierPath(roundedRect: card, xRadius: 8, yRadius: 8).fill()
            }
            let photoArea = CGRect(x: card.minX + 16, y: card.minY + 16, width: card.width - 32, height: card.height - 32 - bottomExtra)
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
                NSBezierPath(rect: CGRect(x: rainbowX + CGFloat(ci) * barW, y: rainbowY, width: barW, height: barH)).fill()
            }
            draw("SX-70 COLOR", font: .systemFont(ofSize: 13, weight: .bold), color: NSColor(white: 0.45, alpha: 0.65), at: CGPoint(x: card.minX + 20, y: card.maxY - 32))

        case .film:
            NSColor.black.setFill()
            NSBezierPath(rect: cell).fill()
            let frame = cell.insetBy(dx: 4, dy: 4)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: frame).addClip()
            drawAspectFill(photo, in: frame)
            NSGraphicsContext.restoreGraphicsState()

            let amber = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 0.9)
            amber.setStroke()
            let frameBorder = NSBezierPath(rect: cell.insetBy(dx: -2, dy: -2))
            frameBorder.lineWidth = 1
            frameBorder.stroke()

            let reg: CGFloat = 8
            for pt in [
                CGPoint(x: cell.minX - 6, y: cell.minY - 6),
                CGPoint(x: cell.maxX + 6, y: cell.minY - 6),
                CGPoint(x: cell.minX - 6, y: cell.maxY + 6),
                CGPoint(x: cell.maxX + 6, y: cell.maxY + 6)
            ] {
                let signX: CGFloat = pt.x < cell.midX ? 1 : -1
                let signY: CGFloat = pt.y < cell.midY ? 1 : -1
                let p = NSBezierPath()
                p.move(to: CGPoint(x: pt.x, y: pt.y + reg * signY))
                p.line(to: pt)
                p.line(to: CGPoint(x: pt.x + reg * signX, y: pt.y))
                p.lineWidth = 1.5
                p.stroke()
            }

        case .newspaper:
            withShadow(color: NSColor.black.withAlphaComponent(0.15), blur: 6, offset: CGSize(width: 1, height: 2)) {
                NSColor.white.setFill()
                NSBezierPath(rect: cell).fill()
            }
            let photoRect = cell.insetBy(dx: 4, dy: 4)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: photoRect).addClip()
            drawAspectFill(photo, in: photoRect)
            NSGraphicsContext.restoreGraphicsState()

            NSColor.black.setStroke()
            let nBorder = NSBezierPath(rect: cell)
            nBorder.lineWidth = 2.5
            nBorder.stroke()

            let capFont = NSFont(name: "Times-Italic", size: 16) ?? NSFont(name: "Times New Roman Italic", size: 16) ?? .systemFont(ofSize: 16)
            let figStr = "Fig. \(index + 1) — Special dispatch from the scene"
            draw(figStr, font: capFont, color: NSColor(white: 0.2, alpha: 0.9), at: CGPoint(x: cell.minX + 4, y: cell.maxY + 8))

        case .retro:
            let r: CGFloat = 26
            withShadow(color: NSColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 0.22), blur: 14, offset: CGSize(width: 0, height: 5)) {
                NSColor(red: 0.99, green: 0.96, blue: 0.9, alpha: 1).setFill()
                NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
            }
            let photoFrame = cell.insetBy(dx: 14, dy: 14)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 0.85).setStroke()
            let pRing = NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6)
            pRing.lineWidth = 3
            pRing.stroke()

        case .midnight:
            let r: CGFloat = 16
            withShadow(color: NSColor.black.withAlphaComponent(0.4), blur: 20, offset: CGSize(width: 0, height: 6)) {
                NSColor(white: 0.08, alpha: 1).setFill()
                NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
            }
            let photoFrame = cell.insetBy(dx: 6, dy: 6)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: r - 4, yRadius: r - 4).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            NSColor.white.withAlphaComponent(0.28).setStroke()
            let rim = NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r)
            rim.lineWidth = 1.5
            rim.stroke()

            draw("[ ARCHIVE // 0\(index + 1) ]", font: .monospacedSystemFont(ofSize: 12, weight: .bold), color: NSColor(white: 1, alpha: 0.65), at: CGPoint(x: cell.minX + 16, y: cell.minY + 12))

        case .y2k:
            let r: CGFloat = 28
            withShadow(color: NSColor(red: 0.6, green: 0.3, blue: 0.9, alpha: 0.3), blur: 16, offset: CGSize(width: 0, height: 5)) {
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
            draw("REC", font: .boldSystemFont(ofSize: 15), color: .white, at: CGPoint(x: photoFrame.minX + 36, y: photoFrame.minY + 14))
            draw("SP  00:0\(index + 1):28", font: .monospacedDigitSystemFont(ofSize: 14, weight: .bold), color: .white, at: CGPoint(x: photoFrame.minX + 78, y: photoFrame.minY + 15))

            draw("HQ 4:3  [▮▮▯]", font: .boldSystemFont(ofSize: 14), color: .white, at: CGPoint(x: photoFrame.maxX - 110, y: photoFrame.minY + 14))

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

            draw("'04 10 12", font: .monospacedDigitSystemFont(ofSize: 16, weight: .bold), color: NSColor(red: 1, green: 0.65, blue: 0.15, alpha: 0.95), at: CGPoint(x: photoFrame.minX + 16, y: photoFrame.maxY - 26))

            NSGraphicsContext.restoreGraphicsState()

        case .sakura:
            let r: CGFloat = 24
            withShadow(color: NSColor(red: 0.9, green: 0.45, blue: 0.6, alpha: 0.22), blur: 14, offset: CGSize(width: 0, height: 4)) {
                NSColor.white.setFill()
                NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
            }
            let photoFrame = cell.insetBy(dx: 12, dy: 12)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(red: 0.9, green: 0.55, blue: 0.68, alpha: 0.6).setStroke()
            let sBorder = NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8)
            sBorder.lineWidth = 1.5
            sBorder.stroke()

            petal(at: CGPoint(x: cell.maxX - 10, y: cell.minY + 12), size: 24, angle: 35)

        case .neon:
            let r: CGFloat = 20
            let tubeColor: NSColor = index % 2 == 0 ? .cyan : NSColor(red: 1, green: 0.2, blue: 0.75, alpha: 1)
            let frame = cell.insetBy(dx: 8, dy: 8)

            withShadow(color: tubeColor, blur: 28, offset: .zero) {
                tubeColor.setStroke()
                let path = NSBezierPath(roundedRect: frame, xRadius: r, yRadius: r)
                path.lineWidth = 5
                path.stroke()
            }

            NSColor.white.setStroke()
            let core = NSBezierPath(roundedRect: frame, xRadius: r, yRadius: r)
            core.lineWidth = 1.8
            core.stroke()

            let inner = frame.insetBy(dx: 7, dy: 7)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: inner, xRadius: r - 6, yRadius: r - 6).addClip()
            drawAspectFill(photo, in: inner)
            NSGraphicsContext.restoreGraphicsState()

        case .pastel:
            let r: CGFloat = 20
            withShadow(color: NSColor(red: 0.2, green: 0.4, blue: 0.3, alpha: 0.14), blur: 12, offset: CGSize(width: 0, height: 4)) {
                NSColor.white.setFill()
                NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
            }
            let photoFrame = cell.insetBy(dx: 14, dy: 14)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            let tapes: [NSColor] = [
                NSColor(red: 0.98, green: 0.78, blue: 0.82, alpha: 0.85),
                NSColor(red: 0.72, green: 0.9, blue: 0.82, alpha: 0.85),
                NSColor(red: 0.98, green: 0.92, blue: 0.65, alpha: 0.85),
                NSColor(red: 0.82, green: 0.84, blue: 0.98, alpha: 0.85),
            ]
            tapes[index % tapes.count].setFill()
            let tapeW: CGFloat = 110
            let tapeH: CGFloat = 26
            let tapeRect = CGRect(x: cell.midX - tapeW / 2, y: cell.minY - 4, width: tapeW, height: tapeH)
            NSBezierPath(roundedRect: tapeRect, xRadius: 4, yRadius: 4).fill()

        case .love:
            let r: CGFloat = 22
            withShadow(color: NSColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 0.25), blur: 16, offset: CGSize(width: 0, height: 4)) {
                NSColor.white.setFill()
                NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
            }
            let photoFrame = cell.insetBy(dx: 12, dy: 12)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(red: 0.88, green: 0.2, blue: 0.3, alpha: 0.7).setStroke()
            let lBorder = NSBezierPath(roundedRect: photoFrame, xRadius: r - 8, yRadius: r - 8)
            lBorder.lineWidth = 1.5
            lBorder.stroke()

            symbol("heart.fill", color: NSColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 0.8), at: CGPoint(x: cell.maxX - 16, y: cell.maxY - 16), size: 18)

        case .album:
            let r: CGFloat = 16
            withShadow(color: NSColor.black.withAlphaComponent(0.35), blur: 16, offset: CGSize(width: 0, height: 5)) {
                NSColor(white: 0.15, alpha: 0.9).setFill()
                NSBezierPath(roundedRect: cell, xRadius: r, yRadius: r).fill()
            }
            let photoFrame = cell.insetBy(dx: 8, dy: 8)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6).addClip()
            drawAspectFill(photo, in: photoFrame)
            NSGraphicsContext.restoreGraphicsState()

            NSColor.white.withAlphaComponent(0.3).setStroke()
            let aBorder = NSBezierPath(roundedRect: photoFrame, xRadius: r - 6, yRadius: r - 6)
            aBorder.lineWidth = 1.2
            aBorder.stroke()

            draw("TRACK 0\(index + 1)", font: .monospacedSystemFont(ofSize: 13, weight: .bold), color: NSColor.white.withAlphaComponent(0.7), at: CGPoint(x: cell.minX + 16, y: cell.minY + 12))

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
        case .receipt, .social, .player, .postcard, .scrapbook, .coquette, .desktop:
            drawTrendBackground(style, canvas: canvas, photos: photos, info: info)

        case .classic:
            fill(canvas, NSColor(red: 0.985, green: 0.982, blue: 0.975, alpha: 1))
            let innerCard = canvas.insetBy(dx: 20, dy: 20)
            NSColor(white: 0, alpha: 0.08).setStroke()
            let borderPath = NSBezierPath(roundedRect: innerCard, xRadius: 10, yRadius: 10)
            borderPath.lineWidth = 1.2
            borderPath.stroke()

            let studioFont = NSFont(name: "Avenir-Medium", size: 15) ?? .systemFont(ofSize: 15, weight: .medium)
            let studioStr = NSAttributedString(string: "✦  KOREA SELF PHOTO BOOTH  ·  AUTOMATIC STUDIO  ✦", attributes: [
                .font: studioFont,
                .foregroundColor: NSColor(white: 0.35, alpha: 0.8),
                .kern: 2.0
            ])
            let sSize = studioStr.size()
            studioStr.draw(at: CGPoint(x: canvas.midX - sSize.width / 2, y: innerCard.minY + 16))

        case .midnight:
            NSGradient(colors: [NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1), NSColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1)])!
                .draw(in: canvas, angle: -90)
            let rim = canvas.insetBy(dx: 18, dy: 18)
            NSColor.white.withAlphaComponent(0.12).setStroke()
            let rPath = NSBezierPath(roundedRect: rim, xRadius: 8, yRadius: 8)
            rPath.lineWidth = 1
            rPath.stroke()

        case .film:
            fill(canvas, NSColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1))
            NSColor(red: 0.92, green: 0.91, blue: 0.88, alpha: 1).setFill()
            var y: CGFloat = 24
            while y < canvas.height - 30 {
                for x in [34.0, canvas.width - 34 - 36] {
                    let spRect = CGRect(x: x, y: y, width: 36, height: 50)
                    NSBezierPath(roundedRect: spRect, xRadius: 8, yRadius: 8).fill()
                }
                y += 82
            }
            let amber = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 0.9)
            let leaderFont = NSFont(name: "Courier New Bold", size: 18) ?? .monospacedSystemFont(ofSize: 18, weight: .bold)
            draw("▶ KODAK PORTRA 400  ·  5094  ·  SAFETY FILM  ·  ISO 400/27°", font: leaderFont, color: amber, at: CGPoint(x: 120, y: 16))

        case .polaroid:
            fill(canvas, NSColor(red: 0.96, green: 0.945, blue: 0.91, alpha: 1))

        case .y2k:
            NSGradient(colors: [
                NSColor(red: 1, green: 0.58, blue: 0.88, alpha: 1),
                NSColor(red: 0.64, green: 0.52, blue: 1, alpha: 1),
                NSColor(red: 0.48, green: 0.86, blue: 1, alpha: 1),
            ])!.draw(in: canvas, angle: -70)

        case .sakura:
            NSGradient(colors: [
                NSColor(red: 1, green: 0.95, blue: 0.97, alpha: 1),
                NSColor(red: 1, green: 0.86, blue: 0.92, alpha: 1)
            ])!.draw(in: canvas, angle: -90)

        case .retro:
            fill(canvas, NSColor(red: 0.96, green: 0.93, blue: 0.84, alpha: 1))
            let retroColors = [
                NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1),
                NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 1),
                NSColor(red: 0.72, green: 0.18, blue: 0.14, alpha: 1),
                NSColor(red: 0.38, green: 0.18, blue: 0.10, alpha: 1),
            ]
            let stripeW: CGFloat = 10
            for (i, c) in retroColors.enumerated() {
                fill(CGRect(x: 18 + CGFloat(i) * stripeW, y: 0, width: stripeW, height: canvas.height), c)
                fill(CGRect(x: canvas.width - 18 - CGFloat(4 - i) * stripeW, y: 0, width: stripeW, height: canvas.height), c)
            }

        case .newspaper:
            fill(canvas, NSColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1))
            let mastheadFont = NSFont(name: "Didot-Bold", size: 48) ?? NSFont(name: "Times New Roman Bold", size: 46) ?? .boldSystemFont(ofSize: 44)
            let titleStr = NSAttributedString(string: "✦ THE DAILY CHRONICLE ✦", attributes: [
                .font: mastheadFont,
                .foregroundColor: NSColor.black,
                .kern: 3.0
            ])
            let tSize = titleStr.size()
            titleStr.draw(at: CGPoint(x: canvas.midX - tSize.width / 2, y: 16))

            NSColor.black.setFill()
            NSBezierPath(rect: CGRect(x: 40, y: 68, width: canvas.width - 80, height: 2.5)).fill()
            NSBezierPath(rect: CGRect(x: 40, y: 73, width: canvas.width - 80, height: 1.0)).fill()

            let subFont = NSFont(name: "Times New Roman", size: 15) ?? .systemFont(ofSize: 15)
            let subText = "VOL. CVIII · NO. 42  ·  SPECIAL PHOTO EDITION  ·  PRICE: TWO CENTS"
            draw(subText, font: subFont, color: NSColor(white: 0.2, alpha: 1), at: CGPoint(x: canvas.midX - 240, y: 78))

            NSBezierPath(rect: CGRect(x: 40, y: 98, width: canvas.width - 80, height: 1.5)).fill()

        case .neon:
            NSGradient(colors: [
                NSColor(red: 0.04, green: 0.03, blue: 0.12, alpha: 1),
                NSColor(red: 0.09, green: 0.04, blue: 0.22, alpha: 1)
            ])!.draw(in: canvas, angle: -90)

        case .pastel:
            fill(canvas, NSColor(red: 0.92, green: 0.97, blue: 0.94, alpha: 1))
            let gridColor = NSColor(red: 0.65, green: 0.82, blue: 0.75, alpha: 0.35)
            gridColor.setStroke()
            let gridPath = NSBezierPath()
            gridPath.lineWidth = 1
            for x in stride(from: 24.0, to: canvas.width, by: 32) {
                gridPath.move(to: CGPoint(x: x, y: 0))
                gridPath.line(to: CGPoint(x: x, y: canvas.height))
            }
            for y in stride(from: 24.0, to: canvas.height, by: 32) {
                gridPath.move(to: CGPoint(x: 0, y: y))
                gridPath.line(to: CGPoint(x: canvas.width, y: y))
            }
            gridPath.stroke()

        case .love:
            NSGradient(colors: [
                NSColor(red: 0.58, green: 0.08, blue: 0.16, alpha: 1),
                NSColor(red: 0.35, green: 0.04, blue: 0.09, alpha: 1)
            ])!.draw(in: canvas, angle: -90)

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
                fill(canvas, NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1))
                NSColor.white.withAlphaComponent(0.06).setStroke()
                let discRect = CGRect(x: canvas.midX - 350, y: -100, width: 700, height: 700)
                for dr in stride(from: 20.0, to: 320.0, by: 30.0) {
                    let ring = NSBezierPath(ovalIn: discRect.insetBy(dx: dr, dy: dr))
                    ring.lineWidth = 1.2
                    ring.stroke()
                }
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
            let color = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1)
            let font = NSFont(name: "Courier New Bold", size: 22) ?? .monospacedSystemFont(ofSize: 22, weight: .bold)
            for (i, cell) in cells.dropLast().enumerated() {
                draw("\(i + 1)  ▸  \(i + 1)A", font: font, color: color, at: CGPoint(x: cell.minX, y: cell.maxY + 4))
                drawRotated("PORTRA 400  ▸", font: font, color: color.withAlphaComponent(0.8), center: CGPoint(x: canvas.width - 105, y: cell.midY))
            }
        case .neon:
            for _ in 0..<14 {
                symbol("sparkle", color: Bool.random(using: &rng) ? .cyan : NSColor(red: 1, green: 0.3, blue: 0.8, alpha: 1), at: scatter(canvas, cells, &rng), size: .random(in: 16...30, using: &rng))
            }
        case .midnight:
            for _ in 0..<16 {
                symbol("sparkle", color: NSColor.white.withAlphaComponent(.random(in: 0.2...0.6, using: &rng)), at: scatter(canvas, cells, &rng), size: .random(in: 14...24, using: &rng))
            }
        case .pastel:
            let stickers = ["sparkle", "heart.fill", "cloud.fill", "sun.max.fill", "star.fill"]
            let colors = [
                NSColor(red: 0.98, green: 0.72, blue: 0.78, alpha: 0.75),
                NSColor(red: 0.65, green: 0.82, blue: 0.75, alpha: 0.75),
                NSColor(red: 0.98, green: 0.88, blue: 0.55, alpha: 0.75),
                NSColor(red: 0.75, green: 0.82, blue: 0.98, alpha: 0.75),
            ]
            for _ in 0..<16 {
                symbol(stickers.randomElement(using: &rng)!, color: colors.randomElement(using: &rng)!, at: scatter(canvas, cells, &rng), size: .random(in: 18...34, using: &rng))
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
        let custom = info.caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        func title(_ fallback: String) -> String { custom ?? fallback }
        maxTextWidth = rect.width - 60

        switch style {
        case .receipt, .social, .player, .postcard, .scrapbook, .coquette, .desktop:
            drawTrendFooter(style, rect: rect, info: info, caption: custom)
        case .classic:
            var y = rect.minY + 28
            let titleFont = NSFont(name: "Avenir-Black", size: 60) ?? NSFont(name: "Helvetica-Bold", size: 58) ?? rounded(58, .heavy)
            let titleText = title("LIFE FOUR CUTS").uppercased()
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: NSColor(white: 0.1, alpha: 1),
                .kern: 3.5
            ]
            let tStr = NSAttributedString(string: titleText, attributes: titleAttr)
            let tW = min(tStr.size().width, rect.width - 80)
            tStr.draw(at: CGPoint(x: center - tW / 2, y: y))
            y += 66

            draw("MEMORIES OF THE DAY · HARU PHOTO STUDIO", font: .systemFont(ofSize: 20, weight: .semibold), color: NSColor(white: 0.45, alpha: 1), at: CGPoint(x: center - 215, y: y))
            y += 30

            centered(dateString("yyyy.MM.dd  ·  HH:mm"), font: .monospacedDigitSystemFont(ofSize: 21, weight: .medium), color: NSColor(white: 0.5, alpha: 1), x: center, y: y)
            y += 34

            // Authentic Photobooth Barcode
            let ink = NSColor(white: 0.15, alpha: 1)
            ink.setFill()
            var rng = SeededRandom(seed: UInt64(info.date.timeIntervalSince1970) / 100)
            var bx = center - 160
            while bx < center + 160 {
                let bw = CGFloat.random(in: 2...6, using: &rng)
                NSBezierPath(rect: CGRect(x: bx, y: y, width: bw, height: 40)).fill()
                bx += bw + .random(in: 2...5, using: &rng)
            }
            draw("PHOTO ID: #042918 · AUTOMATIC SYSTEM", font: .monospacedSystemFont(ofSize: 13, weight: .bold), color: NSColor(white: 0.4, alpha: 0.8), at: CGPoint(x: center - 138, y: y + 46))

        case .midnight:
            var y = rect.minY + 28
            let luxuryFont = NSFont(name: "Didot-Bold", size: 56) ?? NSFont(name: "Times New Roman Bold", size: 54) ?? rounded(52, .heavy)
            let mainTitle = custom ?? "OPENNOTCHI ARCHIVE"
            let attr: [NSAttributedString.Key: Any] = [
                .font: luxuryFont,
                .foregroundColor: NSColor.white,
                .kern: 3.5
            ]
            let str = NSAttributedString(string: mainTitle, attributes: attr)
            let w = min(str.size().width, rect.width - 80)
            str.draw(at: CGPoint(x: center - w / 2, y: y))
            y += 68

            draw("COLLECTION N° 01  ·  PRIVATE EXHIBITION", font: .systemFont(ofSize: 20, weight: .semibold), color: NSColor(white: 0.65, alpha: 1), at: CGPoint(x: center - 190, y: y))
            y += 30
            draw("№ 0084 / LIMITED EDITION", font: .monospacedSystemFont(ofSize: 17, weight: .bold), color: NSColor(white: 0.5, alpha: 1), at: CGPoint(x: center - 110, y: y))
            y += 28
            centered(dateString("yyyy.MM.dd  ·  HH:mm:ss") + " UTC", font: .monospacedDigitSystemFont(ofSize: 19, weight: .medium), color: NSColor(white: 0.45, alpha: 1), x: center, y: y)

        case .film:
            var y = rect.minY + 24
            let amber = NSColor(red: 0.91, green: 0.64, blue: 0.23, alpha: 1)
            let font = NSFont(name: "Courier New Bold", size: 48) ?? .monospacedSystemFont(ofSize: 46, weight: .bold)
            y += centered(title("KODAK PORTRA 400"), font: font, color: amber, x: center, y: y) + 4
            draw("EXPOSURE: 36 EXP  ·  C-41 PROCESS  ·  COLOR NEGATIVE", font: font.withSize(21), color: amber.withAlphaComponent(0.8), at: CGPoint(x: center - 260, y: y))
            y += 32
            let ledFont = NSFont(name: "Courier New Bold", size: 30) ?? .monospacedSystemFont(ofSize: 30, weight: .bold)
            centered("’26  10  12", font: ledFont, color: NSColor(red: 1, green: 0.45, blue: 0.15, alpha: 1), x: center, y: y, shadow: NSColor(red: 1, green: 0.3, blue: 0.1, alpha: 0.6))

        case .polaroid:
            var y = rect.minY + 28
            let ink = NSColor(red: 0.12, green: 0.18, blue: 0.32, alpha: 1)
            let handFont = NSFont(name: "Marker Felt Wide", size: 66) ?? NSFont(name: "Noteworthy-Bold", size: 60) ?? rounded(60, .bold)
            y += centered(title("good times ✌️"), font: handFont, color: ink, x: center, y: y) + 4
            centered(dateString("d MMMM yyyy"), font: NSFont(name: "Noteworthy-Bold", size: 28) ?? .systemFont(ofSize: 28), color: ink.withAlphaComponent(0.75), x: center, y: y)
            y += 44
            draw("★ POLAROID COLOR 600 FILM ★", font: .systemFont(ofSize: 18, weight: .bold), color: NSColor(white: 0.45, alpha: 0.7), at: CGPoint(x: center - 140, y: y))

        case .y2k:
            var y = rect.minY + 24
            let y2kTitle = custom.map { "✦ \($0) ✦" } ?? "✦ cyber besties ✦"
            y += centered(y2kTitle, font: rounded(68, .black), color: .white, x: center, y: y, shadow: NSColor(red: 0.5, green: 0.2, blue: 0.9, alpha: 0.8)) + 4

            let barRect = CGRect(x: center - 210, y: y, width: 420, height: 40)
            NSColor(white: 1, alpha: 0.25).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 20, yRadius: 20).fill()
            let songName = info.songTitle ?? "Favorite Track"
            draw("● ONLINE  ·  ♪ \(songName)", font: .systemFont(ofSize: 17, weight: .bold), color: .white, at: CGPoint(x: barRect.minX + 20, y: barRect.minY + 10), maxWidth: 380)
            y += 50
            centered(dateString("MM/dd/yyyy") + "  [SP 00:24:12]", font: rounded(24, .bold), color: .white.withAlphaComponent(0.9), x: center, y: y)

        case .sakura:
            var y = rect.minY + 20
            let pink = NSColor(red: 0.78, green: 0.25, blue: 0.45, alpha: 1)
            let scriptFont = NSFont(name: "Snell Roundhand Bold", size: 84) ?? rounded(64, .bold)
            y += centered(title("sakura days"), font: scriptFont, color: pink, x: center, y: y)

            draw("桜の季節  ·  SPRINGTIME MEMORIES", font: .systemFont(ofSize: 22, weight: .semibold), color: pink.withAlphaComponent(0.85), at: CGPoint(x: center - 170, y: y))
            y += 34

            let sealRect = CGRect(x: center - 22, y: y, width: 44, height: 44)
            NSColor(red: 0.82, green: 0.2, blue: 0.2, alpha: 0.9).setFill()
            NSBezierPath(roundedRect: sealRect, xRadius: 8, yRadius: 8).fill()
            draw("桜", font: .boldSystemFont(ofSize: 24), color: .white, at: CGPoint(x: sealRect.minX + 10, y: sealRect.minY + 8))
            y += 52

            centered(dateString("yyyy . MM . dd"), font: rounded(24, .semibold), color: pink.withAlphaComponent(0.75), x: center, y: y)

        case .retro:
            var y = rect.minY + 20
            let brown = NSColor(red: 0.42, green: 0.2, blue: 0.1, alpha: 1)
            let orange = NSColor(red: 0.85, green: 0.34, blue: 0.17, alpha: 1)
            let retroFont = NSFont(name: "Futura-CondensedExtraBold", size: 88) ?? NSFont(name: "Avenir-Black", size: 80) ?? rounded(80, .black)
            centered(title("GROOVY"), font: retroFont, color: brown, x: center, y: y, shadow: orange)
            y += 92
            draw("☀  SUPER 8 SOUND  ☀  CALIFORNIA 1978", font: NSFont(name: "Futura-Medium", size: 24) ?? .systemFont(ofSize: 24, weight: .bold), color: orange, at: CGPoint(x: center - 210, y: y))
            y += 34
            centered(dateString("MMMM d, yyyy").uppercased(), font: NSFont(name: "Futura-Medium", size: 22) ?? .systemFont(ofSize: 22), color: brown.withAlphaComponent(0.8), x: center, y: y)

        case .newspaper:
            var y = rect.minY + 16
            NSColor.black.setFill()
            NSBezierPath(rect: CGRect(x: rect.minX + 30, y: y, width: rect.width - 60, height: 3)).fill()
            y += 8
            let titleFont = NSFont(name: "Didot-Bold", size: 66) ?? NSFont(name: "Times New Roman Bold", size: 62) ?? .boldSystemFont(ofSize: 58)
            y += centered(title("MOMENTS THAT MADE HISTORY").uppercased(), font: titleFont, color: .black, x: center, y: y) + 4

            NSBezierPath(rect: CGRect(x: rect.minX + 30, y: y, width: rect.width - 60, height: 1.5)).fill()
            y += 10
            centered(dateString("EEEE, MMMM d, yyyy").uppercased() + "  ·  CITY EDITION  ·  FREE", font: NSFont(name: "Times New Roman", size: 22) ?? .systemFont(ofSize: 22), color: NSColor(white: 0.2, alpha: 1), x: center, y: y)
            y += 34

            let bodyFont = NSFont(name: "Times New Roman", size: 16) ?? .systemFont(ofSize: 16)
            let colW = (rect.width - 100) / 2
            let col1 = "Eyewitnesses confirm today was one for the record books. Spirits remained extraordinary throughout, with genuine laughter echoed across every frame captured."
            let col2 = "Analysts predict these memories will remain timeless for decades to come. Special souvenir print issued by OpenNotchi Press."
            NSAttributedString(string: col1, attributes: [.font: bodyFont, .foregroundColor: NSColor(white: 0.25, alpha: 1)]).draw(in: CGRect(x: rect.minX + 40, y: y, width: colW - 10, height: 80))
            NSAttributedString(string: col2, attributes: [.font: bodyFont, .foregroundColor: NSColor(white: 0.25, alpha: 1)]).draw(in: CGRect(x: center + 10, y: y, width: colW - 10, height: 80))

        case .neon:
            var y = rect.minY + 24
            let pink = NSColor(red: 1, green: 0.25, blue: 0.8, alpha: 1)
            let cyan = NSColor.cyan
            let neonFont = rounded(72, .heavy)
            y += centered(title("main character"), font: neonFont, color: pink, x: center, y: y, shadow: pink) + 4
            draw("ネオン  ·  TOKYO NIGHTS 2026", font: .systemFont(ofSize: 24, weight: .bold), color: cyan, at: CGPoint(x: center - 160, y: y), maxWidth: 360)
            y += 36
            centered(dateString("dd.MM.yyyy") + "  22:50:00", font: rounded(24, .bold), color: .white, x: center, y: y, shadow: cyan)

        case .pastel:
            var y = rect.minY + 22
            let green = NSColor(red: 0.12, green: 0.45, blue: 0.35, alpha: 1)
            y += centered(title("core memories ♡"), font: rounded(64, .heavy), color: green, x: center, y: y) + 2
            draw("— today was pure magic ✨ —", font: NSFont(name: "Noteworthy-Bold", size: 26) ?? .systemFont(ofSize: 26), color: green.withAlphaComponent(0.8), at: CGPoint(x: center - 150, y: y))
            y += 36
            centered(dateString("EEEE, d MMMM yyyy"), font: rounded(24, .semibold), color: green.withAlphaComponent(0.7), x: center, y: y)

        case .love:
            var y = rect.minY + 18
            let loveFont = NSFont(name: "Snell Roundhand Bold", size: 88) ?? rounded(68, .bold)
            y += centered(title("mon amour ♡"), font: loveFont, color: .white, x: center, y: y, shadow: NSColor(red: 0.5, green: 0, blue: 0.1, alpha: 0.6))

            let sealRect = CGRect(x: center - 26, y: y, width: 52, height: 52)
            withShadow(color: NSColor.black.withAlphaComponent(0.3), blur: 8, offset: CGSize(width: 0, height: 2)) {
                NSColor(red: 0.65, green: 0.1, blue: 0.15, alpha: 1).setFill()
                NSBezierPath(ovalIn: sealRect).fill()
            }
            symbol("heart.fill", color: NSColor(red: 1, green: 0.85, blue: 0.6, alpha: 1), at: CGPoint(x: sealRect.midX, y: sealRect.midY), size: 24)
            y += 62

            draw("PARIS  ·  AVEC AMOUR  ·  " + dateString("yyyy"), font: .systemFont(ofSize: 22, weight: .semibold), color: .white.withAlphaComponent(0.9), at: CGPoint(x: center - 165, y: y))

        case .album:
            let y = rect.minY + 24
            let thumb: CGFloat = 130
            let text = info.songTitle ?? "Midnight Drive"
            let sub = info.artist ?? "The Placeholders"
            let titleFont = rounded(46, .heavy)
            let titleWidth = min(NSAttributedString(string: text, attributes: [.font: titleFont]).size().width, rect.width - thumb - 220)
            let startX = center - (thumb + 30 + titleWidth) / 2

            if let artwork = info.artwork {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(roundedRect: CGRect(x: startX, y: y, width: thumb, height: thumb), xRadius: 14, yRadius: 14).addClip()
                artwork.draw(in: CGRect(x: startX, y: y, width: thumb, height: thumb), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                let discRect = CGRect(x: startX, y: y, width: thumb, height: thumb)
                NSColor(white: 0.12, alpha: 1).setFill()
                NSBezierPath(ovalIn: discRect).fill()
                NSColor.white.withAlphaComponent(0.2).setStroke()
                for dr: CGFloat in [18, 32, 46] {
                    let p = NSBezierPath(ovalIn: discRect.insetBy(dx: dr, dy: dr))
                    p.lineWidth = 1
                    p.stroke()
                }
                NSColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1).setFill()
                NSBezierPath(ovalIn: discRect.insetBy(dx: 45, dy: 45)).fill()
                symbol("music.note", color: .white, at: CGPoint(x: discRect.midX, y: discRect.midY), size: 20)
            }

            let textX = startX + thumb + 26
            draw(custom ?? "♪ NOW PLAYING", font: rounded(20, .bold), color: .white.withAlphaComponent(0.7), at: CGPoint(x: textX, y: y + 2), maxWidth: rect.width - thumb - 100)
            draw(text, font: titleFont, color: .white, at: CGPoint(x: textX, y: y + 28), maxWidth: titleWidth)
            draw(sub, font: rounded(26, .medium), color: .white.withAlphaComponent(0.75), at: CGPoint(x: textX, y: y + 84), maxWidth: titleWidth)

            let badgeY = y + 140
            draw("[ HI-RES AUDIO · STEREO ]", font: .monospacedSystemFont(ofSize: 16, weight: .bold), color: NSColor(white: 1, alpha: 0.55), at: CGPoint(x: startX, y: badgeY))

            var wx = startX + 240
            NSColor(white: 1, alpha: 0.65).setFill()
            let heights: [CGFloat] = [12, 22, 16, 28, 34, 20, 14, 30, 24, 18, 26, 12]
            for h in heights {
                NSBezierPath(roundedRect: CGRect(x: wx, y: badgeY + 16 - h, width: 4, height: h), xRadius: 2, yRadius: 2).fill()
                wx += 8
            }
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
        case .postcard: return 520
        case .newspaper: return 500
        case .desktop: return 300
        case .scrapbook, .coquette: return 430
        case .pastel: return 380
        case .polaroid: return 440
        case .classic: return 440
        case .film: return 380
        case .midnight: return 400
        case .retro: return 440
        case .y2k: return 420
        case .sakura: return 420
        case .neon: return 400
        case .love: return 420
        case .album: return 460
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

        case .postcard:
            let shadowColor = NSColor.black.withAlphaComponent(0.2)
            withShadow(color: shadowColor, blur: 14, offset: CGSize(width: 0, height: 4)) {
                NSColor(white: 0.99, alpha: 1).setFill()
                NSBezierPath(roundedRect: cell, xRadius: 8, yRadius: 8).fill()
            }
            let photoBorder = cell.insetBy(dx: 14, dy: 14)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: photoBorder, xRadius: 5, yRadius: 5).addClip()
            drawAspectFill(photo, in: photoBorder)
            NSGraphicsContext.restoreGraphicsState()

            NSColor(white: 0.1, alpha: 0.1).setStroke()
            let innerBorder = NSBezierPath(roundedRect: photoBorder, xRadius: 5, yRadius: 5)
            innerBorder.lineWidth = 1.5
            innerBorder.stroke()

            // Photo mounting tabs on corners
            let cornerSize: CGFloat = 22
            NSColor(red: 0.82, green: 0.74, blue: 0.62, alpha: 0.9).setFill()
            for corner in [
                CGPoint(x: cell.minX + 8, y: cell.minY + 8),
                CGPoint(x: cell.maxX - 8, y: cell.minY + 8),
                CGPoint(x: cell.minX + 8, y: cell.maxY - 8),
                CGPoint(x: cell.maxX - 8, y: cell.maxY - 8)
            ] {
                let path = NSBezierPath()
                let signX: CGFloat = corner.x > cell.midX ? -1 : 1
                let signY: CGFloat = corner.y > cell.midY ? -1 : 1
                path.move(to: corner)
                path.line(to: CGPoint(x: corner.x + cornerSize * signX, y: corner.y))
                path.line(to: CGPoint(x: corner.x, y: corner.y + cornerSize * signY))
                path.close()
                path.fill()
            }

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

        case .postcard:
            fill(canvas, NSColor(red: 0.985, green: 0.97, blue: 0.94, alpha: 1))
            let borderWidth: CGFloat = 32
            let stripeWidth: CGFloat = 42
            let redColor = NSColor(red: 0.85, green: 0.22, blue: 0.22, alpha: 1)
            let blueColor = NSColor(red: 0.13, green: 0.32, blue: 0.62, alpha: 1)
            let whiteColor = NSColor.white
            drawAirmailBorder(canvas: canvas, borderWidth: borderWidth, stripeWidth: stripeWidth, red: redColor, blue: blueColor, white: whiteColor)

            let innerCard = canvas.insetBy(dx: borderWidth, dy: borderWidth)
            NSColor(red: 0.985, green: 0.97, blue: 0.94, alpha: 1).setFill()
            NSBezierPath(rect: innerCard).fill()

            NSColor(red: 0.75, green: 0.68, blue: 0.58, alpha: 0.6).setStroke()
            let innerFrame = innerCard.insetBy(dx: 10, dy: 10)
            let framePath = NSBezierPath(rect: innerFrame)
            framePath.lineWidth = 1.5
            framePath.stroke()

            let headerBadge = CGRect(x: innerFrame.minX + 20, y: innerFrame.minY + 14, width: 270, height: 40)
            blueColor.setFill()
            NSBezierPath(roundedRect: headerBadge, xRadius: 6, yRadius: 6).fill()
            let parAvionAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Helvetica-Bold", size: 16) ?? .boldSystemFont(ofSize: 16),
                .foregroundColor: NSColor.white,
                .kern: 1.5
            ]
            let parAvionStr = NSAttributedString(string: "✈  PAR AVION  ·  AIR MAIL", attributes: parAvionAttr)
            let paSize = parAvionStr.size()
            parAvionStr.draw(at: CGPoint(x: headerBadge.midX - paSize.width / 2, y: headerBadge.midY - paSize.height / 2))

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

        case .postcard:
            let ink = NSColor(red: 0.16, green: 0.2, blue: 0.28, alpha: 1)
            let red = NSColor(red: 0.85, green: 0.22, blue: 0.22, alpha: 1)
            f.dateFormat = "d MMMM yyyy"
            let dateStr = f.string(from: info.date)

            let dividerX = rect.midX
            let topY = rect.minY + 24
            let bottomY = rect.maxY - 24
            NSColor(red: 0.75, green: 0.7, blue: 0.64, alpha: 0.7).setStroke()
            let divLine = NSBezierPath()
            divLine.move(to: CGPoint(x: dividerX, y: topY + 40))
            divLine.line(to: CGPoint(x: dividerX, y: bottomY))
            divLine.lineWidth = 1.5
            divLine.stroke()

            let headerFont = NSFont(name: "Times New Roman Bold", size: 36) ?? .boldSystemFont(ofSize: 36)
            let headerAttr: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: NSColor(red: 0.25, green: 0.22, blue: 0.2, alpha: 0.9)
            ]
            let headerStr = NSAttributedString(string: "CARTE POSTALE  ★  POST CARD", attributes: headerAttr)
            let hSize = headerStr.size()
            headerStr.draw(at: CGPoint(x: dividerX - hSize.width / 2, y: topY))

            // Left Side: Message Area
            let msgLeft = rect.minX + 50
            let msgWidth = dividerX - msgLeft - 30
            var msgY = topY + 54

            draw("MESSAGE / CORRESPONDENCE:", font: .systemFont(ofSize: 18, weight: .bold), color: NSColor(white: 0.4, alpha: 0.8), at: CGPoint(x: msgLeft, y: msgY))
            msgY += 34

            let handFont = NSFont(name: "Marker Felt Wide", size: 38) ?? NSFont(name: "Noteworthy-Bold", size: 34) ?? rounded(34, .bold)
            let message = caption ?? "Greetings from OpenNotchi! Wishing you were here ♡"
            let msgBox = CGRect(x: msgLeft, y: msgY, width: msgWidth, height: 160)
            NSAttributedString(string: message, attributes: [.font: handFont, .foregroundColor: ink]).draw(in: msgBox)

            let dateY = bottomY - 35
            draw("Date: \(dateStr)", font: NSFont(name: "Noteworthy-Bold", size: 24) ?? .systemFont(ofSize: 24), color: ink.withAlphaComponent(0.8), at: CGPoint(x: msgLeft, y: dateY))

            // Right Side: Stamp, Postmark & Address Lines
            let rightX = dividerX + 35
            let stampW: CGFloat = 130
            let stampH: CGFloat = 160
            let stampRect = CGRect(x: rect.maxX - 50 - stampW, y: topY + 45, width: stampW, height: stampH)

            drawPerforatedStamp(stampRect, color: red)
            symbol("airplane", color: .white, at: CGPoint(x: stampRect.midX, y: stampRect.minY + 65), size: 48)
            draw("AIR MAIL", font: .boldSystemFont(ofSize: 16), color: .white, at: CGPoint(x: stampRect.midX - 35, y: stampRect.minY + 115))
            draw("50¢", font: .boldSystemFont(ofSize: 22), color: .white, at: CGPoint(x: stampRect.midX - 18, y: stampRect.minY + 20))

            let postmarkCenter = CGPoint(x: stampRect.minX - 10, y: stampRect.minY + 70)
            drawPostmark(center: postmarkCenter, dateString: f.string(from: info.date).uppercased())

            var addrY = stampRect.maxY + 35
            draw("ADDRESS / DESTINATAIRE:", font: .systemFont(ofSize: 18, weight: .bold), color: NSColor(white: 0.4, alpha: 0.8), at: CGPoint(x: rightX, y: addrY))
            addrY += 34

            for line in ["To: __________________________________",
                         "     __________________________________",
                         "     __________________________________",
                         "     OpenNotchi · Special Delivery ✈"] {
                draw(line, font: NSFont(name: "Courier New Bold", size: 22) ?? .monospacedSystemFont(ofSize: 22, weight: .bold), color: NSColor(white: 0.35, alpha: 0.85), at: CGPoint(x: rightX, y: addrY))
                addrY += 36
            }

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

    // MARK: - Postcard helpers

    private static func drawAirmailBorder(canvas: CGRect, borderWidth: CGFloat, stripeWidth: CGFloat, red: NSColor, blue: NSColor, white: NSColor) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()

        let outerPath = CGMutablePath()
        outerPath.addRect(canvas)
        let innerRect = canvas.insetBy(dx: borderWidth, dy: borderWidth)
        outerPath.addRect(innerRect)
        cg.addPath(outerPath)
        cg.clip(using: .evenOdd)

        white.setFill()
        cg.fill(canvas)

        let stripeGap = stripeWidth * 0.4
        let step = (stripeWidth + stripeGap) * 2
        var x = -canvas.height - 200
        while x < canvas.width + canvas.height + 200 {
            let rPath = NSBezierPath()
            rPath.move(to: CGPoint(x: x, y: 0))
            rPath.line(to: CGPoint(x: x + stripeWidth, y: 0))
            rPath.line(to: CGPoint(x: x + stripeWidth - canvas.height, y: canvas.height))
            rPath.line(to: CGPoint(x: x - canvas.height, y: canvas.height))
            rPath.close()
            red.setFill()
            rPath.fill()

            let bx = x + stripeWidth + stripeGap
            let bPath = NSBezierPath()
            bPath.move(to: CGPoint(x: bx, y: 0))
            bPath.line(to: CGPoint(x: bx + stripeWidth, y: 0))
            bPath.line(to: CGPoint(x: bx + stripeWidth - canvas.height, y: canvas.height))
            bPath.line(to: CGPoint(x: bx - canvas.height, y: canvas.height))
            bPath.close()
            blue.setFill()
            bPath.fill()

            x += step
        }

        cg.restoreGState()
    }

    private static func drawPerforatedStamp(_ rect: CGRect, color: NSColor) {
        guard let cg = NSGraphicsContext.current?.cgContext else { return }
        cg.saveGState()

        withShadow(color: NSColor.black.withAlphaComponent(0.2), blur: 8, offset: CGSize(width: 1, height: 2)) {
            NSColor(white: 0.99, alpha: 1).setFill()
            NSBezierPath(rect: rect).fill()
        }

        let inner = rect.insetBy(dx: 10, dy: 10)
        color.setFill()
        NSBezierPath(rect: inner).fill()

        let paperColor = NSColor(red: 0.985, green: 0.97, blue: 0.94, alpha: 1)
        paperColor.setFill()
        let r: CGFloat = 4.5
        var sx = rect.minX + 8
        while sx < rect.maxX {
            NSBezierPath(ovalIn: CGRect(x: sx - r, y: rect.minY - r, width: r * 2, height: r * 2)).fill()
            NSBezierPath(ovalIn: CGRect(x: sx - r, y: rect.maxY - r, width: r * 2, height: r * 2)).fill()
            sx += 12
        }
        var sy = rect.minY + 8
        while sy < rect.maxY {
            NSBezierPath(ovalIn: CGRect(x: rect.minX - r, y: sy - r, width: r * 2, height: r * 2)).fill()
            NSBezierPath(ovalIn: CGRect(x: rect.maxX - r, y: sy - r, width: r * 2, height: r * 2)).fill()
            sy += 12
        }

        cg.restoreGState()
    }

    private static func drawPostmark(center: CGPoint, dateString: String) {
        let postmarkInk = NSColor(red: 0.12, green: 0.18, blue: 0.3, alpha: 0.8)
        postmarkInk.setStroke()

        let circle1 = NSBezierPath(ovalIn: CGRect(x: center.x - 55, y: center.y - 55, width: 110, height: 110))
        circle1.lineWidth = 2.5
        circle1.stroke()

        let circle2 = NSBezierPath(ovalIn: CGRect(x: center.x - 47, y: center.y - 47, width: 94, height: 94))
        circle2.lineWidth = 1.2
        circle2.stroke()

        let stampFont = NSFont(name: "Helvetica-Bold", size: 10) ?? .boldSystemFont(ofSize: 10)
        draw("AIR MAIL POST", font: stampFont, color: postmarkInk, at: CGPoint(x: center.x - 38, y: center.y - 28))
        draw(dateString, font: NSFont(name: "Courier New Bold", size: 11) ?? .boldSystemFont(ofSize: 11), color: postmarkInk, at: CGPoint(x: center.x - 36, y: center.y - 6))
        draw("★ VERIFIED ★", font: stampFont, color: postmarkInk, at: CGPoint(x: center.x - 35, y: center.y + 16))

        let wavePath = NSBezierPath()
        for dy: CGFloat in [-16, 0, 16] {
            wavePath.move(to: CGPoint(x: center.x - 55, y: center.y + dy))
            wavePath.curve(to: CGPoint(x: center.x - 135, y: center.y + dy),
                           controlPoint1: CGPoint(x: center.x - 80, y: center.y + dy - 10),
                           controlPoint2: CGPoint(x: center.x - 110, y: center.y + dy + 10))
        }
        wavePath.lineWidth = 2
        wavePath.stroke()
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

