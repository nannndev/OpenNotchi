import AppKit

/// What a style's footer gets: the area to draw in plus the strip's text, already cleaned up.
struct StripFooter {
    let rect: CGRect
    let info: StripInfo
    var date: Date { info.date }
    var center: CGFloat { rect.midX }
    /// The user's caption, trimmed; nil when empty.
    var custom: String? { info.caption?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

    func title(_ fallback: String) -> String { custom ?? fallback }

    func dateString(_ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: date)
    }
}

/// Routes each drawing step to the style's own file in `Styles/`.
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

    static func drawBackground(_ style: StripStyle, canvas: CGRect, info: StripInfo, photos: [CGImage]) {
        switch style {
        case .classic: classicBackground(canvas, info: info, photos: photos)
        case .receipt: receiptBackground(canvas, info: info, photos: photos)
        case .social: socialBackground(canvas, info: info, photos: photos)
        case .player: playerBackground(canvas, info: info, photos: photos)
        case .postcard: postcardBackground(canvas, info: info, photos: photos)
        case .scrapbook: scrapbookBackground(canvas, info: info, photos: photos)
        case .coquette: coquetteBackground(canvas, info: info, photos: photos)
        case .desktop: desktopBackground(canvas, info: info, photos: photos)
        case .film: filmBackground(canvas, info: info, photos: photos)
        case .polaroid: polaroidBackground(canvas, info: info, photos: photos)
        case .y2k: y2kBackground(canvas, info: info, photos: photos)
        case .midnight: midnightBackground(canvas, info: info, photos: photos)
        case .sakura: sakuraBackground(canvas, info: info, photos: photos)
        case .retro: retroBackground(canvas, info: info, photos: photos)
        case .newspaper: newspaperBackground(canvas, info: info, photos: photos)
        case .neon: neonBackground(canvas, info: info, photos: photos)
        case .pastel: pastelBackground(canvas, info: info, photos: photos)
        case .love: loveBackground(canvas, info: info, photos: photos)
        case .album: albumBackground(canvas, info: info, photos: photos)
        }
    }

    static func drawPhoto(_ photo: CGImage, in cell: CGRect, style: StripStyle, index: Int) {
        switch style {
        case .receipt, .social: plainPhoto(photo, in: cell)
        case .classic: classicPhoto(photo, in: cell, index: index)
        case .player: playerPhoto(photo, in: cell, index: index)
        case .postcard: postcardPhoto(photo, in: cell, index: index)
        case .scrapbook: scrapbookPhoto(photo, in: cell, index: index)
        case .coquette: coquettePhoto(photo, in: cell, index: index)
        case .desktop: desktopPhoto(photo, in: cell, index: index)
        case .film: filmPhoto(photo, in: cell, index: index)
        case .polaroid: polaroidPhoto(photo, in: cell, index: index)
        case .y2k: y2kPhoto(photo, in: cell, index: index)
        case .midnight: midnightPhoto(photo, in: cell, index: index)
        case .sakura: sakuraPhoto(photo, in: cell, index: index)
        case .retro: retroPhoto(photo, in: cell, index: index)
        case .newspaper: newspaperPhoto(photo, in: cell, index: index)
        case .neon: neonPhoto(photo, in: cell, index: index)
        case .pastel: pastelPhoto(photo, in: cell, index: index)
        case .love: lovePhoto(photo, in: cell, index: index)
        case .album: albumPhoto(photo, in: cell, index: index)
        }
    }

    /// Edge-to-edge photo with no frame (Receipt, Social).
    static func plainPhoto(_ photo: CGImage, in cell: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: cell).addClip()
        drawAspectFill(photo, in: cell)
        NSGraphicsContext.restoreGraphicsState()
    }

    static func drawDecorations(_ style: StripStyle, canvas: CGRect, avoid cells: [CGRect]) {
        var rng = SeededRandom(seed: 7)
        switch style {
        case .scrapbook: scrapbookDecorations(canvas, avoid: cells, rng: &rng)
        case .coquette: coquetteDecorations(canvas, avoid: cells, rng: &rng)
        case .sakura: sakuraDecorations(canvas, avoid: cells, rng: &rng)
        case .love: loveDecorations(canvas, avoid: cells, rng: &rng)
        case .film: filmDecorations(canvas, avoid: cells, rng: &rng)
        case .neon: neonDecorations(canvas, avoid: cells, rng: &rng)
        case .midnight: midnightDecorations(canvas, avoid: cells, rng: &rng)
        case .pastel: pastelDecorations(canvas, avoid: cells, rng: &rng)
        case .y2k: y2kDecorations(canvas, avoid: cells, rng: &rng)
        default: break
        }
    }

    static func drawFooter(_ style: StripStyle, rect: CGRect, info: StripInfo) {
        maxTextWidth = rect.width - 60
        let footer = StripFooter(rect: rect, info: info)
        switch style {
        case .classic: classicFooter(footer)
        case .receipt: receiptFooter(footer)
        case .social: socialFooter(footer)
        case .player: playerFooter(footer)
        case .postcard: postcardFooter(footer)
        case .scrapbook: scrapbookFooter(footer)
        case .coquette: coquetteFooter(footer)
        case .desktop: desktopFooter(footer)
        case .film: filmFooter(footer)
        case .polaroid: polaroidFooter(footer)
        case .y2k: y2kFooter(footer)
        case .midnight: midnightFooter(footer)
        case .sakura: sakuraFooter(footer)
        case .retro: retroFooter(footer)
        case .newspaper: newspaperFooter(footer)
        case .neon: neonFooter(footer)
        case .pastel: pastelFooter(footer)
        case .love: loveFooter(footer)
        case .album: albumFooter(footer)
        }
    }
}
