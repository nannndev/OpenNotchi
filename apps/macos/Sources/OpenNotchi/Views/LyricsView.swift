import SwiftUI

/// Lyrics for the current song, shown in the center of Home in lyrics mode.
struct LyricsContent: View {
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings
    let info: NowPlayingInfo

    var body: some View {
        Group {
            switch lyrics.state {
            case .idle, .loading:
                ProgressView().controlSize(.small)
            case .synced:
                SyncedLyricsView(info: info)
            case .plain:
                PlainLyricsView(info: info, text: lyrics.plainText ?? "")
                    .overlay(alignment: .bottom) {
                        Text("Not time-synced")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
            case .instrumental:
                message("Instrumental", icon: "pianokeys")
            case .notFound:
                message("No lyrics found for this song", icon: "quote.bubble")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Own column beside the lyrics: never covers a line and stays clear of the notch's rounded corners.
        .safeAreaInset(edge: .trailing, spacing: 6) {
            if lyrics.state == .synced || lyrics.state == .plain {
                VStack(spacing: 6) {
                    PlayerChip(icon: "translate", isOn: settings.lyricsTranslate,
                               help: lyrics.translationIssue ?? (settings.lyricsTranslate ? "Stop translating" : "Translate lyrics")) {
                        settings.lyricsTranslate.toggle()
                    }
                    PlayerChip(icon: "pip", isOn: settings.lyricsOverlayEnabled,
                               help: settings.lyricsOverlayEnabled ? "Hide desktop lyrics" : "Show desktop lyrics") {
                        settings.lyricsOverlayEnabled.toggle()
                    }
                    PlayerChip(icon: "square.and.arrow.up", help: "Share lyrics as an image") {
                        LyricsShare.open()
                    }
                }
                .padding(3)
                .background(Capsule().fill(.black.opacity(0.25)))
                .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 0.5))
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear { lyrics.retryIfNeeded() }
    }

    private func message(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22, weight: .light))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.secondary)
    }
}

/// Compact transport controls and progress, used in the side column in lyrics mode.
struct MiniPlayerColumn: View {
    @EnvironmentObject private var media: MediaManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ControlButton(systemName: "backward.fill", size: 12) { media.previousTrack() }
                PlayPauseButton(isPlaying: media.info?.isPlaying ?? false) { media.playPause() }
                ControlButton(systemName: "forward.fill", size: 12) { media.nextTrack() }
            }
            if let info = media.info {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = info.position(at: context.date)
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.15))
                                Capsule().fill(accent.color)
                                    .frame(width: info.duration > 0 ? geo.size.width * min(position / info.duration, 1) : 0)
                            }
                        }
                        .frame(height: 3)
                        HStack {
                            Text(formatTime(position))
                            Spacer()
                            Text(info.duration > 0 ? formatTime(info.duration) : "--:--")
                        }
                        .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            }
            PlayerVolumeBar()
        }
        .disabled(media.info == nil)
        .opacity(media.info == nil ? 0.4 : 1)
    }
}

/// Fades lines toward the top and bottom edges.
private let edgeFade = LinearGradient(
    stops: [
        .init(color: .clear, location: 0),
        .init(color: .black, location: 0.25),
        .init(color: .black, location: 0.75),
        .init(color: .clear, location: 1),
    ],
    startPoint: .top,
    endPoint: .bottom
)

private struct SyncedLyricsView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @Environment(\.notchAccent) private var accent
    let info: NowPlayingInfo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            let current = lyrics.currentIndex(at: info.position(at: context.date))

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(lyrics.lines) { line in
                            LyricLineView(line: line, translation: lyrics.translations[line.text], distance: current.map { abs(line.id - $0) } ?? 3, accent: accent)
                                .onTapGesture { media.seek(to: line.time) }
                                .contextMenu {
                                    Button { LyricsShare.open(startAt: line.text) } label: { Label("Share This Line…", systemImage: "square.and.arrow.up") }
                                }
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, 60)
                    .frame(maxWidth: .infinity)
                }
                .mask(edgeFade)
                .onAppear { proxy.scrollTo(current ?? 0, anchor: .center) }
                .onChange(of: current) { _, index in
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        proxy.scrollTo(index ?? 0, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct LyricLineView: View {
    let line: LyricLine
    let translation: String?
    /// How many lines away from the one being sung.
    let distance: Int
    let accent: ResolvedAccent
    @State private var hovering = false

    private var isCurrent: Bool { distance == 0 }

    private var opacity: Double {
        if isCurrent { return 1.0 }
        if hovering { return 0.85 }
        switch distance {
        case 1: return 0.52
        case 2: return 0.32
        default: return 0.18
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if hovering && !isCurrent {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(accent.color)
                    .transition(.opacity)
            }
            VStack(spacing: 2) {
                Text(line.text.isEmpty ? "♪" : line.text)
                    .font(.system(size: isCurrent ? 16 : 14.5, weight: isCurrent ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isCurrent && !accent.isNeutral ? accent.color : (hovering ? .white : .white))
                    .shadow(color: isCurrent ? (accent.isNeutral ? Color.white.opacity(0.3) : accent.color.opacity(0.45)) : .clear, radius: 8)
                if let translation {
                    TranslatedLine(text: translation, size: isCurrent ? 12 : 11)
                }
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(hovering ? Color.white.opacity(0.08) : Color.clear)
        )
        .opacity(opacity)
        .blur(radius: (distance >= 2 && !hovering) ? min(Double(distance - 1) * 0.6, 1.8) : 0)
        .scaleEffect(isCurrent ? 1.06 : (hovering ? 1.02 : 0.95))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: distance)
        .animation(.spring(response: 0.25), value: hovering)
    }
}

/// Translations are amber, italic and marked with a small icon so they never pass for the original lyrics.
struct TranslatedLine: View {
    static let color = Color(red: 1.0, green: 0.78, blue: 0.38)
    let text: String
    let size: CGFloat

    var body: some View {
        (Text(Image(systemName: "translate")).font(.system(size: size * 0.8)) + Text(" " + text))
            .font(.system(size: size, weight: .medium, design: .rounded))
            .italic()
            .foregroundStyle(Self.color.opacity(0.9))
    }
}

/// The small round button used for every secondary player action, so they all line up and match.
struct PlayerChip: View {
    let icon: String
    var isOn = false
    /// Color of the icon while on; the accent by default.
    var onColor: Color?
    let help: String
    let action: () -> Void
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .symbolVariant(isOn ? .fill : .none)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(isOn ? (onColor ?? (accent.isNeutral ? .white : accent.color)) : .white.opacity(hovering ? 0.9 : 0.55))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.white.opacity(isOn ? 0.16 : (hovering ? 0.12 : 0.06))))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

/// Unsynced lyrics: scrolls along with song progress as a best guess.
private struct PlainLyricsView: View {
    @EnvironmentObject private var lyrics: LyricsManager
    let info: NowPlayingInfo
    let text: String

    private var lines: [String] {
        text.components(separatedBy: .newlines)
    }

    var body: some View {
        let lines = self.lines
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let progress = info.duration > 0 ? info.position(at: context.date) / info.duration : 0
            let target = min(lines.count - 1, max(0, Int(progress * Double(lines.count))))

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(lines.indices, id: \.self) { index in
                            VStack(spacing: 2) {
                                Text(lines[index].isEmpty ? " " : lines[index])
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.75))
                                if let translation = lyrics.translations[lines[index]] {
                                    TranslatedLine(text: translation, size: 11)
                                }
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .id(index)
                        }
                    }
                    .padding(.vertical, 60)
                }
                .mask(edgeFade)
                .onAppear { proxy.scrollTo(target, anchor: .center) }
                .onChange(of: target) { _, index in
                    withAnimation(.easeInOut(duration: 1.2)) { proxy.scrollTo(index, anchor: .center) }
                }
            }
        }
    }
}
