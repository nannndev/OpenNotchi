import AppKit
import SwiftUI

/// Spotify-style lyric cards: pick a few lines, pick a look, then copy, save or share a 1080×1350 image.
enum LyricsShare {
    private static var window: NSWindow?

    static func open(startAt line: String? = nil) {
        guard let app = AppDelegate.shared, let info = app.media.info else { return }
        let lyrics = app.lyrics
        // Synced lyrics keep their timestamps so the card's progress bar matches the chosen lines.
        let timed: [(text: String, time: Double?)] = (lyrics.state == .synced
            ? lyrics.lines.map { ($0.text, Optional($0.time)) }
            : (lyrics.plainText ?? "").components(separatedBy: .newlines).map { ($0, nil) })
            .map { ($0.0.trimmingCharacters(in: .whitespaces), $0.1) }
            .filter { !$0.0.isEmpty }
        let lines = timed.map(\.text)
        guard !lines.isEmpty else { return }

        let position = info.position(at: .now)
        let current = line ?? lyrics.currentLine(at: position) ?? lines[0]
        let song = SharedSong(
            title: info.title,
            artist: info.artist,
            artwork: app.media.artwork,
            palette: app.media.palette,
            lines: lines,
            times: timed.map(\.time),
            duration: info.duration,
            translations: lyrics.translations
        )

        let start = lines.firstIndex(of: current) ?? 0
        let hosting = NSHostingController(rootView: LyricsShareView(song: song, selection: start...start))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Share Lyrics"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        Self.window?.close()
        Self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Everything the card needs, frozen when the window opens so a track change doesn't swap it.
struct SharedSong {
    let title: String
    let artist: String
    let artwork: NSImage?
    let palette: ArtworkPalette?
    let lines: [String]
    /// Start time of each line in seconds; nil for unsynced lyrics.
    let times: [Double?]
    let duration: Double
    let translations: [String: String]
}

enum LyricCardStyle: String, CaseIterable, Identifiable {
    case aura, player, polaroid, solid, paper
    var id: String { rawValue }
    var name: String {
        switch self {
        case .aura: return "Aura"
        case .player: return "Player"
        case .polaroid: return "Polaroid"
        case .solid: return "Solid"
        case .paper: return "Paper"
        }
    }
}

private struct LyricsShareView: View {
    let song: SharedSong
    /// Always a run of consecutive lines, like Spotify.
    @State var selection: ClosedRange<Int>
    @State private var style: LyricCardStyle = .aura
    @State private var showTranslation = false
    @State private var toast: String?

    private static let maxLines = 5
    private var chosen: [String] { selection.map { song.lines[$0] } }
    private var hasTranslations: Bool { chosen.contains { song.translations[$0] != nil } }

    private var card: some View {
        LyricCard(song: song, lines: chosen, time: song.times[selection.lowerBound],
                  translations: showTranslation ? song.translations : [:], style: style)
    }

    var body: some View {
        HStack(spacing: 0) {
            linePicker
                .frame(width: 260)
                .background(.black.opacity(0.15))

            VStack(spacing: 16) {
                card
                    .frame(width: LyricCard.size.width, height: LyricCard.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                    .overlay(alignment: .bottom) {
                        if let toast {
                            Text(toast)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(.black.opacity(0.75)))
                                .foregroundStyle(.white)
                                .padding(12)
                                .transition(.opacity)
                        }
                    }

                Picker("Style", selection: $style) {
                    ForEach(LyricCardStyle.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 380)

                Toggle("Include translation", isOn: $showTranslation)
                    .disabled(!hasTranslations)

                HStack(spacing: 10) {
                    Button { copy() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    Button { save() } label: { Label("Save", systemImage: "square.and.arrow.down") }
                    Button { share() } label: { Label("Share", systemImage: "square.and.arrow.up") }
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .frame(width: 760, height: 640)
    }

    private var linePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tap a line, then the lines next to it (up to \(Self.maxLines))")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 36)
            ScrollViewReader { proxy in
                ScrollView {
                    // No gaps, so a run of selected lines reads as one block.
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(song.lines.indices, id: \.self) { index in
                            let isOn = selection.contains(index)
                            Button { toggle(index) } label: {
                                // Same weight either way, so selecting never reflows the text.
                                Text(song.lines[index])
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(isOn ? .primary : .secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectionShape(index).fill(isOn ? Color.accentColor.opacity(0.28) : .clear))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .onAppear { proxy.scrollTo(selection.lowerBound, anchor: .center) }
            }
        }
    }

    /// Rounded only at the ends of the selected run.
    private func selectionShape(_ index: Int) -> UnevenRoundedRectangle {
        let top: CGFloat = index == selection.lowerBound ? 7 : 0
        let bottom: CGFloat = index == selection.upperBound ? 7 : 0
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    private func toggle(_ index: Int) {
        selection = Self.nextSelection(selection, tapping: index, maxLines: Self.maxLines) ?? {
            flash("Up to \(Self.maxLines) lines")
            return selection
        }()
    }

    /// Next to the run grows it, an end of the run shrinks it, anywhere else starts a new run.
    /// Nil when the run is already at its maximum length.
    static func nextSelection(_ range: ClosedRange<Int>, tapping index: Int, maxLines: Int) -> ClosedRange<Int>? {
        if index == range.lowerBound - 1 || index == range.upperBound + 1 {
            return range.count < maxLines ? min(index, range.lowerBound)...max(index, range.upperBound) : nil
        }
        if range.count > 1, index == range.lowerBound { return (index + 1)...range.upperBound }
        if range.count > 1, index == range.upperBound { return range.lowerBound...(index - 1) }
        return index...index
    }

    // MARK: - Export

    @MainActor private func render() -> NSImage? {
        let renderer = ImageRenderer(content: card.frame(width: LyricCard.size.width, height: LyricCard.size.height))
        renderer.scale = 1080 / LyricCard.size.width
        return renderer.nsImage
    }

    @MainActor private func copy() {
        guard let image = render() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        NSSound(named: "Pop")?.play()
        flash("Copied")
    }

    @MainActor private func save() {
        guard let url = saveFile() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        flash("Saved to Pictures › OpenNotchi")
    }

    @MainActor private func share() {
        guard let url = saveFile(), let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: NSRect(x: view.bounds.width - 120, y: 20, width: 1, height: 1), of: view, preferredEdge: .minY)
    }

    @MainActor private func saveFile() -> URL? {
        guard let image = render(), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return MirrorPhotos.save(cg, name: "Lyrics – \(song.title)")
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation { toast = nil }
        }
    }
}

/// The card itself, laid out at 360×450 points and rendered at 3× (1080×1350, Instagram 4:5).
struct LyricCard: View {
    static let size = CGSize(width: 360, height: 450)

    let song: SharedSong
    let lines: [String]
    /// Song position of the first chosen line, for the Player style's progress bar.
    var time: Double?
    let translations: [String: String]
    let style: LyricCardStyle

    private var top: Color { song.palette?.backgroundTop ?? Color(red: 0.16, green: 0.12, blue: 0.24) }
    private var bottom: Color { song.palette?.backgroundBottom ?? Color(red: 0.05, green: 0.05, blue: 0.09) }
    private var flat: Color { Color(nsColor: (song.palette?.primary ?? .systemIndigo).adjusted(minSaturation: 0.35, minBrightness: 0.45, maxBrightness: 0.85)) }
    /// Dark text on light flat colors, like Spotify's cards.
    private var flatIsLight: Bool {
        let c = (song.palette?.primary ?? .systemIndigo).adjusted(minSaturation: 0.35, minBrightness: 0.45, maxBrightness: 0.85).usingColorSpace(.sRGB) ?? .black
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.62
    }

    private var ink: Color {
        switch style {
        case .aura, .player: return .white
        case .polaroid: return Color(red: 0.15, green: 0.13, blue: 0.12)
        case .solid: return flatIsLight ? Color(white: 0.08) : .white
        case .paper: return Color(red: 0.13, green: 0.11, blue: 0.10)
        }
    }

    private var lyricSize: CGFloat {
        let characters = lines.joined().count + (translations.isEmpty ? 0 : lines.compactMap { translations[$0] }.joined().count / 2)
        switch characters {
        case ..<40: return 30
        case ..<90: return 25
        case ..<160: return 21
        default: return 18
        }
    }

    var body: some View {
        Group {
            switch style {
            case .player: playerLayout
            case .polaroid: polaroidLayout
            default:
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 16)
                    lyricsBlock
                    Spacer(minLength: 16)
                    footer
                }
                .padding(26)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        // In a background so the oversized blurred artwork can't stretch the layout.
        .background { background.frame(width: Self.size.width, height: Self.size.height).clipped() }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .aura, .player:
            ZStack {
                LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let artwork = song.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: Self.size.width * 1.6, height: Self.size.height * 1.6)
                        .blur(radius: 60)
                        .opacity(0.75)
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.07)
            }
        case .solid:
            flat
        case .polaroid:
            ZStack {
                LinearGradient(colors: [Color(red: 0.93, green: 0.89, blue: 0.83), Color(red: 0.86, green: 0.81, blue: 0.74)],
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
        VStack(alignment: .leading, spacing: lyricSize * 0.35) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 3) {
                    Text(line)
                        .font(.system(size: lyricSize, weight: style == .paper ? .regular : .bold, design: style == .paper ? .serif : .rounded))
                        .foregroundStyle(ink)
                    if let translation = translations[line] {
                        Text(translation)
                            .font(.system(size: lyricSize * 0.55, weight: .medium, design: style == .paper ? .serif : .rounded))
                            .italic()
                            .foregroundStyle(style == .aura ? TranslatedLine.color : ink.opacity(0.6))
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .topLeading) {
            if style == .paper {
                Text("“")
                    .font(.system(size: 80, weight: .regular, design: .serif))
                    .foregroundStyle(ink.opacity(0.12))
                    .offset(x: -10, y: -52)
            }
        }
    }

    // MARK: - Player style

    private var playerLayout: some View {
        VStack(spacing: 0) {
            artworkImage
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                .padding(.top, 6)

            VStack(spacing: 2) {
                Text(song.title).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(song.artist).font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.65)
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.top, 14)

            Spacer(minLength: 8)
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    VStack(spacing: 2) {
                        Text(line)
                            .font(.system(size: min(lyricSize, 22), weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        if let translation = translations[line] {
                            Text(translation)
                                .font(.system(size: min(lyricSize, 22) * 0.58, weight: .medium, design: .rounded))
                                .italic()
                                .foregroundStyle(TranslatedLine.color)
                        }
                    }
                }
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)
            Spacer(minLength: 14)

            progress
            transport.padding(.top, 10)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var progress: some View {
        let position = time ?? 0
        let fraction = song.duration > 0 ? min(position / song.duration, 1) : 0.35
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
                Text(song.duration > 0 ? "-" + formatTime(song.duration - position) : "")
            }
            .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var transport: some View {
        HStack(spacing: 30) {
            Image(systemName: "shuffle").font(.system(size: 13, weight: .semibold)).opacity(0.6)
            Image(systemName: "backward.fill").font(.system(size: 18))
            Image(systemName: "pause.fill")
                .font(.system(size: 18))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white))
            Image(systemName: "forward.fill").font(.system(size: 18))
            Image(systemName: "heart.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.pink)
        }
        .foregroundStyle(.white)
    }

    // MARK: - Polaroid style

    private var polaroidLayout: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                artworkImage
                    .frame(width: 236, height: 196)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        Text(song.title.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.black.opacity(0.45))
                            .padding(8)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.custom("Bradley Hand", size: min(lyricSize * 0.62, 17)).weight(.bold))
                        if let translation = translations[line] {
                            Text(translation)
                                .font(.custom("Bradley Hand", size: min(lyricSize * 0.62, 17) * 0.75))
                                .foregroundStyle(ink.opacity(0.6))
                        }
                    }
                    Text("— \(song.artist)")
                        .font(.custom("Bradley Hand", size: 11))
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.top, 2)
                }
                .foregroundStyle(ink)
                .minimumScaleFactor(0.5)
                .frame(width: 236, height: 110, alignment: .topLeading)
            }
            .padding(12)
            .background(Color(red: 0.99, green: 0.98, blue: 0.96))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            .rotationEffect(.degrees(-2.5))

            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 30)
        .padding(.bottom, 22)
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
        .foregroundStyle(ink.opacity(0.55))
    }
}

/// Film-grain texture; seeded so every export of the same card looks identical.
private struct Grain: View {
    let opacity: Double
    var dark = false

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(1 << 31)
            }
            for _ in 0..<2600 {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 0.8, height: 0.8)
                context.fill(Path(rect), with: .color((dark ? Color.black : .white).opacity(opacity * (0.4 + next()))))
            }
        }
        .allowsHitTesting(false)
    }
}
