import AppKit
import SwiftUI

struct LyricCard: View {
    let song: SharedSong
    let lines: [String]
    var aspectRatio: CardAspectRatio = .portrait
    var time: Double?
    var duration: Double?
    var elapsed: Double = 0
    var activeLineIndex: Int?
    let translations: [String: String]
    let style: LyricCardStyle
    var backdrop: NSImage?
    var backdropBlur: CGFloat = 0
    var backdropZoom: CGFloat = 1
    var lyricFont: LyricFont = .auto
    var fontScale: CGFloat = 1
    var textAlign: TextAlignment?

    var top: Color { song.palette?.backgroundTop ?? Color(red: 0.16, green: 0.12, blue: 0.24) }
    var bottom: Color { song.palette?.backgroundBottom ?? Color(red: 0.05, green: 0.05, blue: 0.09) }
    var flat: Color {
        Color(
            nsColor: (song.palette?.primary ?? .systemIndigo).adjusted(
                minSaturation: 0.35, minBrightness: 0.45, maxBrightness: 0.85))
    }

    var ink: Color {
        if backdrop != nil, style != .polaroid, style != .receipt { return .white }
        switch style {
        case .aura, .player, .vhs, .cassette, .vinyl, .glass: return .white
        case .polaroid: return Color(red: 0.15, green: 0.13, blue: 0.12)
        case .solid: return .white
        case .paper: return Color(red: 0.13, green: 0.11, blue: 0.10)
        case .receipt: return Color.black.opacity(0.85)
        }
    }

    var lyricSize: CGFloat {
        let count = lines.joined().count
        let base: CGFloat
        switch count {
        case ..<40: base = 28
        case ..<90: base = 23
        case ..<160: base = 19
        default: base = 16
        }
        return base * fontScale
    }

    var body: some View {
        Group {
            switch style {
            case .player: playerLayout
            case .polaroid: polaroidLayout
            case .vhs: vhsLayout
            case .cassette: cassetteLayout
            case .vinyl: vinylLayout
            case .glass: glassLayout
            case .receipt: receiptLayout
            default: defaultLayout
            }
        }
        .frame(width: aspectRatio.size.width, height: aspectRatio.size.height)
        .background { background.frame(width: aspectRatio.size.width, height: aspectRatio.size.height).clipped() }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder var background: some View {
        if let backdrop {
            ZStack {
                Image(nsImage: backdrop)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: aspectRatio.size.width + backdropBlur * 4,
                        height: aspectRatio.size.height + backdropBlur * 4
                    )
                    .scaleEffect(backdropZoom)
                    .blur(radius: backdropBlur, opaque: true)
                LinearGradient(
                    colors: [.black.opacity(0.2), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                if style == .vhs {
                    VHSScanlines(offset: activeLineIndex != nil ? CGFloat(Int(elapsed * 45) % 4) : 0)
                    Grain(opacity: 0.12, dark: false)
                }
            }
        } else {
            styleBackground
        }
    }

    @ViewBuilder var styleBackground: some View {
        switch style {
        case .aura, .player, .glass:
            ZStack {
                LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let artwork = song.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: aspectRatio.size.width * 1.5, height: aspectRatio.size.height * 1.5)
                        .blur(radius: 60)
                        .opacity(0.75)
                        .rotationEffect(.degrees(activeLineIndex != nil ? elapsed * 12 : 0))
                        .scaleEffect(activeLineIndex != nil ? (1.0 + sin(elapsed * 2.5) * 0.05) : 1.0)
                }
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.07)
            }
        case .vhs:
            ZStack {
                Color.black
                VHSScanlines(offset: activeLineIndex != nil ? CGFloat(Int(elapsed * 45) % 4) : 0)
                Grain(opacity: 0.12, dark: false)
            }
        case .cassette:
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.12)
                Grain(opacity: 0.08)
            }
        case .vinyl:
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.12, green: 0.11, blue: 0.13), Color(red: 0.04, green: 0.04, blue: 0.05)],
                    startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.07)
            }
        case .receipt:
            Color(red: 0.15, green: 0.15, blue: 0.18)
        case .solid:
            ZStack {
                flat
                if activeLineIndex != nil {
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.18)],
                        startPoint: UnitPoint(x: 0.5 + cos(elapsed * 1.5) * 0.5, y: 0.5 + sin(elapsed * 1.5) * 0.5),
                        endPoint: UnitPoint(x: 0.5 - cos(elapsed * 1.5) * 0.5, y: 0.5 - sin(elapsed * 1.5) * 0.5)
                    )
                }
                Grain(opacity: 0.06)
            }
        case .polaroid:
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.89, blue: 0.83), Color(red: 0.86, green: 0.81, blue: 0.74)],
                    startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.1, dark: true)
            }
        case .paper:
            ZStack {
                Color(red: 0.96, green: 0.93, blue: 0.87)
                Grain(opacity: 0.09, dark: true)
            }
        }
    }

    // MARK: - Layouts

    var defaultLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header
                Spacer()
                if activeLineIndex != nil {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text(formatTime(elapsed))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 16)
            lyricsBlock
            Spacer(minLength: 16)
            footer
        }
        .padding(26)
    }

    var header: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = song.artwork {
                    Image(nsImage: artwork).resizable().scaledToFill()
                } else {
                    Rectangle().fill(ink.opacity(0.15)).overlay(
                        Image(systemName: "music.note").foregroundStyle(ink.opacity(0.6)))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: style == .paper ? 3 : 8))
            .shadow(color: .black.opacity(style == .paper ? 0.25 : 0.3), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: .bold, design: style == .paper ? .serif : .rounded))
                Text(song.artist)
                    .font(.system(size: 12, weight: .medium, design: style == .paper ? .serif : .rounded))
                    .opacity(0.7)
            }
            .lineLimit(1)
            .foregroundStyle(ink)
        }
    }

    var lyricsBlock: some View {
        VStack(alignment: .leading, spacing: lyricSize * 0.38) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isCurrent = activeLineIndex == nil || activeLineIndex == index
                VStack(alignment: .leading, spacing: 3) {
                    Text(line)
                        .font(
                            lyricFont.font(
                                .system(
                                    size: lyricSize, weight: isCurrent ? .bold : .medium,
                                    design: style == .paper ? .serif : .rounded), size: lyricSize,
                                weight: isCurrent ? .bold : .medium)
                        )
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                        .shadow(color: isCurrent && activeLineIndex != nil ? ink.opacity(0.6) : .clear, radius: 8)
                        .scaleEffect(isCurrent && activeLineIndex != nil ? 1.02 : 1.0, anchor: .leading)
                        .padding(.horizontal, style == .paper && isCurrent && activeLineIndex != nil ? 4 : 0)
                        .background(
                            style == .paper && isCurrent && activeLineIndex != nil
                                ? RoundedRectangle(cornerRadius: 3).fill(Color.yellow.opacity(0.28))
                                : nil
                        )
                    if let translation = translations[line] {
                        Text(translation)
                            .font(
                                lyricFont.font(
                                    .system(
                                        size: lyricSize * 0.55, weight: .medium,
                                        design: style == .paper ? .serif : .rounded), size: lyricSize * 0.55,
                                    weight: .medium)
                            )
                            .lyricAlignment(textAlign)
                            .italic()
                            .foregroundStyle(style == .aura ? TranslatedLine.color : ink.opacity(0.6))
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder var artworkImage: some View {
        if let artwork = song.artwork {
            Image(nsImage: artwork).resizable().scaledToFill()
        } else {
            Rectangle().fill(.white.opacity(0.15)).overlay(
                Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6)))
        }
    }

    var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 10, weight: .bold))
            Text("OpenNotchi")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle((backdrop != nil ? Color.white : ink).opacity(0.6))
    }
}
