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

    private var top: Color { song.palette?.backgroundTop ?? Color(red: 0.16, green: 0.12, blue: 0.24) }
    private var bottom: Color { song.palette?.backgroundBottom ?? Color(red: 0.05, green: 0.05, blue: 0.09) }
    private var flat: Color { Color(nsColor: (song.palette?.primary ?? .systemIndigo).adjusted(minSaturation: 0.35, minBrightness: 0.45, maxBrightness: 0.85)) }

    private var ink: Color {
        if backdrop != nil, style != .polaroid, style != .receipt { return .white }
        switch style {
        case .aura, .player, .vhs, .cassette, .vinyl, .glass: return .white
        case .polaroid: return Color(red: 0.15, green: 0.13, blue: 0.12)
        case .solid: return .white
        case .paper: return Color(red: 0.13, green: 0.11, blue: 0.10)
        case .receipt: return Color.black.opacity(0.85)
        }
    }

    private var lyricSize: CGFloat {
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

    @ViewBuilder private var background: some View {
        if let backdrop {
            ZStack {
                Image(nsImage: backdrop)
                    .resizable()
                    .scaledToFill()
                    .frame(width: aspectRatio.size.width + backdropBlur * 4, height: aspectRatio.size.height + backdropBlur * 4)
                    .scaleEffect(backdropZoom)
                    .blur(radius: backdropBlur, opaque: true)
                LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                if style == .vhs {
                    VHSScanlines(offset: activeLineIndex != nil ? CGFloat(Int(elapsed * 45) % 4) : 0)
                    Grain(opacity: 0.12, dark: false)
                }
            }
        } else {
            styleBackground
        }
    }

    @ViewBuilder private var styleBackground: some View {
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
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
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
                LinearGradient(colors: [Color(red: 0.12, green: 0.11, blue: 0.13), Color(red: 0.04, green: 0.04, blue: 0.05)], startPoint: .top, endPoint: .bottom)
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
                LinearGradient(colors: [Color(red: 0.93, green: 0.89, blue: 0.83), Color(red: 0.86, green: 0.81, blue: 0.74)], startPoint: .top, endPoint: .bottom)
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

    private var defaultLayout: some View {
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

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = song.artwork {
                    Image(nsImage: artwork).resizable().scaledToFill()
                } else {
                    Rectangle().fill(ink.opacity(0.15)).overlay(Image(systemName: "music.note").foregroundStyle(ink.opacity(0.6)))
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

    private var lyricsBlock: some View {
        VStack(alignment: .leading, spacing: lyricSize * 0.38) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isCurrent = activeLineIndex == nil || activeLineIndex == index
                VStack(alignment: .leading, spacing: 3) {
                    Text(line)
                        .font(lyricFont.font(.system(size: lyricSize, weight: isCurrent ? .bold : .medium, design: style == .paper ? .serif : .rounded), size: lyricSize, weight: isCurrent ? .bold : .medium))
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
                            .font(lyricFont.font(.system(size: lyricSize * 0.55, weight: .medium, design: style == .paper ? .serif : .rounded), size: lyricSize * 0.55, weight: .medium))
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

    // MARK: - Player Style

    private var playerLayout: some View {
        VStack(spacing: 0) {
            artworkImage
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                .padding(.top, 4)

            VStack(spacing: 2) {
                Text(song.title).font(.system(size: 14, weight: .bold, design: .rounded))
                Text(song.artist).font(.system(size: 11.5, weight: .medium, design: .rounded)).opacity(0.65)
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.top, 10)

            Spacer(minLength: 8)
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line)
                        .font(lyricFont.font(.system(size: min(lyricSize, 21 * fontScale), weight: isCurrent ? .bold : .medium, design: .rounded), size: min(lyricSize, 21 * fontScale), weight: isCurrent ? .bold : .medium))
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? .white : .white.opacity(0.35))
                        .shadow(color: isCurrent && activeLineIndex != nil ? .white.opacity(0.6) : .clear, radius: 8)
                }
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)

            Spacer(minLength: 12)
            progress
            transport.padding(.top, 8)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
    }

    private var progress: some View {
        let position = time ?? 0
        let total = duration ?? song.duration
        let fraction = total > 0 ? min(position / total, 1) : 0.35
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(.white).frame(width: geo.size.width * fraction)
                    Circle().fill(.white).frame(width: 9, height: 9)
                        .offset(x: geo.size.width * fraction - 4.5)
                }
            }
            .frame(height: 4)
            HStack {
                Text(formatTime(position))
                Spacer()
                Text(total > 0 ? "-" + formatTime(max(0, total - position)) : "")
            }
            .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Image(systemName: "shuffle").font(.system(size: 12, weight: .semibold)).opacity(0.6)
            Image(systemName: "backward.fill").font(.system(size: 16))
            Image(systemName: "pause.fill")
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(Circle().fill(.white))
            Image(systemName: "forward.fill").font(.system(size: 16))
            Image(systemName: "heart.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.pink)
        }
        .foregroundStyle(.white)
    }

    // MARK: - VHS Style

    private var vhsLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity((Int(elapsed * 2) % 2 == 0) ? 1.0 : 0.25)
                    Text("REC")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Text("SP")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "battery.75percent")
                    Text("AUTO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)

            let tcSecs = Int(elapsed)
            let tcMillis = Int((elapsed - Double(tcSecs)) * 100)
            Text(String(format: "%02d:%02d:%02d.%02d", tcSecs / 3600, (tcSecs % 3600) / 60, tcSecs % 60, tcMillis))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
                .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.6), radius: 4)
                .padding(.top, 4)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line.uppercased())
                        .font(lyricFont.font(.system(size: lyricSize, weight: .heavy, design: .monospaced), size: lyricSize, weight: .heavy))
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                        .shadow(color: isCurrent ? Color.cyan.opacity(0.7) : .clear, radius: 6)
                }
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                    Text(song.artist.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("PLAY ▶")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
            }
            .foregroundStyle(.white)
        }
        .padding(24)
    }

    // MARK: - Cassette Style

    private var cassetteLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )

                VStack(spacing: 8) {
                    HStack {
                        Text("SIDE A")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Spacer()
                        Text(song.title)
                            .font(.custom("Bradley Hand", size: 13).weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("C-60")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 52)

                        HStack(spacing: 36) {
                            CassetteSpool(rotation: elapsed * 120)
                            Rectangle().fill(Color(red: 0.35, green: 0.18, blue: 0.12)).frame(width: 36, height: 16)
                            CassetteSpool(rotation: elapsed * 120)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                .background(Color(red: 0.94, green: 0.92, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8)
            }
            .frame(height: 120)

            Spacer(minLength: 10)
            lyricsBlock
            Spacer(minLength: 10)
            footer
        }
        .padding(22)
    }

    // MARK: - Vinyl Style

    private var vinylLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 14)

            HStack(spacing: -24) {
                artworkImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: -4, y: 4)
                    .zIndex(2)

                VinylDisc(artwork: song.artwork, rotation: elapsed * 90)
                    .frame(width: 116, height: 116)
                    .zIndex(1)
            }
            .padding(.vertical, 6)

            Spacer(minLength: 12)
            lyricsBlock
            Spacer(minLength: 12)
            footer
        }
        .padding(22)
    }

    // MARK: - Glass Style

    private var glassLayout: some View {
        VStack(spacing: 0) {
            glassPillHeader
            Spacer(minLength: 16)
            glassLyricsBox
            Spacer(minLength: 16)
            footer
        }
        .padding(22)
    }

    private var glassPillHeader: some View {
        HStack(spacing: 10) {
            glassArtwork
            glassSongMeta
            Spacer()
            glassWaveform
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(.black.opacity(0.75)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    @ViewBuilder
    private var glassArtwork: some View {
        if let artwork = song.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
        }
    }

    private var glassSongMeta: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(song.title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
            Text(song.artist)
                .font(.system(size: 9.5, weight: .medium))
                .opacity(0.6)
                .lineLimit(1)
        }
    }

    private var glassWaveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: waveformBarHeight(index: i))
            }
        }
    }

    private func waveformBarHeight(index: Int) -> CGFloat {
        let wave = sin(elapsed * 5.0 + Double(index) * 1.5)
        return CGFloat(6.0 + wave * 5.0)
    }

    private var glassLyricsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isCurrent = activeLineIndex == nil || activeLineIndex == index
                Text(line)
                    .font(lyricFont.font(.system(size: lyricSize, weight: .bold, design: .rounded), size: lyricSize, weight: .bold))
                    .lyricAlignment(textAlign)
                    .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                    .shadow(color: isCurrent && activeLineIndex != nil ? Color.accentColor.opacity(0.9) : .clear, radius: 10)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.8), Color.purple.opacity(0.6), Color.white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }

    // MARK: - Receipt Style

    private var receiptLayout: some View {
        VStack(spacing: 0) {
            ReceiptPerforation()
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 8)

            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("*** OPENNOTCHI ARCHIVE ***")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    HStack {
                        Text("AUDIO #1024")
                        Spacer()
                        if activeLineIndex != nil {
                            Text("TIME: \(formatTime(elapsed))")
                                .foregroundStyle(Color.red)
                        } else {
                            Text("TRACK CASSETTE")
                        }
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .opacity(0.7)
                    Text("------------------------------------")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.35)
                    HStack {
                        Text(song.title.uppercased())
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(song.artist.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    }
                    Text("------------------------------------")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.35)
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        HStack(alignment: .top, spacing: 6) {
                            Text(isCurrent && activeLineIndex != nil ? "►" : String(format: "%02d", index + 1))
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(isCurrent && activeLineIndex != nil ? Color.red : Color.black.opacity(0.45))
                            Text(line)
                                .font(lyricFont.font(.system(size: min(lyricSize, 15 * fontScale), weight: isCurrent ? .bold : .regular, design: .monospaced), size: min(lyricSize, 15 * fontScale), weight: isCurrent ? .bold : .regular))
                                .lyricAlignment(textAlign)
                                .foregroundStyle(isCurrent ? Color.black : Color.black.opacity(0.35))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isCurrent && activeLineIndex != nil ? Color.black.opacity(0.06) : Color.clear)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 6)

                VStack(spacing: 3) {
                    BarcodePattern(animatedOffset: activeLineIndex != nil ? elapsed : 0)
                        .frame(height: 28)
                    Text("THANK YOU FOR LISTENING")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.95, blue: 0.92))
            .foregroundStyle(Color.black.opacity(0.85))

            ReceiptPerforation(inverted: true)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    // MARK: - Polaroid Style

    private var polaroidLayout: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                artworkImage
                    .frame(width: 220, height: 175)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 4) {
                            Text(song.title.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .lineLimit(1)
                            if activeLineIndex != nil {
                                Text("• \(formatTime(elapsed))")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.55))
                        .padding(7)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.prefix(4).enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        Text(line)
                            .font(lyricFont.font(.custom("Bradley Hand", size: min(lyricSize * 0.62, 16 * fontScale)).weight(isCurrent ? .bold : .medium), size: min(lyricSize * 0.62, 16 * fontScale), weight: isCurrent ? .bold : .medium))
                            .lyricAlignment(textAlign)
                            .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                            .scaleEffect(isCurrent && activeLineIndex != nil ? 1.02 : 1.0, anchor: .leading)
                    }
                    Text("— \(song.artist)")
                        .font(.custom("Bradley Hand", size: 11))
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.top, 2)
                }
                .foregroundStyle(ink)
                .minimumScaleFactor(0.5)
                .frame(width: 220, alignment: .topLeading)
            }
            .padding(12)
            .background(Color(red: 0.99, green: 0.98, blue: 0.96))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            .rotationEffect(.degrees(-2.5 + (activeLineIndex != nil ? sin(elapsed * 1.5) * 0.8 : 0)))

            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder private var artworkImage: some View {
        if let artwork = song.artwork {
            Image(nsImage: artwork).resizable().scaledToFill()
        } else {
            Rectangle().fill(.white.opacity(0.15)).overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6)))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 10, weight: .bold))
            Text("OpenNotchi")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle((backdrop != nil ? Color.white : ink).opacity(0.6))
    }
}
