import SwiftUI

/// Lyrics for the current song, shown in the center of Home in lyrics mode.
struct LyricsContent: View {
    @EnvironmentObject private var lyrics: LyricsManager
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
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ControlButton(systemName: "backward.fill", size: 13) { media.previousTrack() }
                ControlButton(systemName: (media.info?.isPlaying ?? false) ? "pause.fill" : "play.fill", size: 20) { media.playPause() }
                ControlButton(systemName: "forward.fill", size: 13) { media.nextTrack() }
            }
            if let info = media.info {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = info.position(at: context.date)
                    VStack(spacing: 4) {
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
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                }
            }
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
                            LyricLineView(line: line, distance: current.map { abs(line.id - $0) } ?? 3, accent: accent)
                                .onTapGesture { media.seek(to: line.time) }
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
    /// How many lines away from the one being sung.
    let distance: Int
    let accent: ResolvedAccent

    private var isCurrent: Bool { distance == 0 }

    private var opacity: Double {
        switch distance {
        case 0: return 1
        case 1: return 0.5
        case 2: return 0.3
        default: return 0.18
        }
    }

    var body: some View {
        Text(line.text.isEmpty ? "♪" : line.text)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(isCurrent && !accent.isNeutral ? accent.color : .white)
            .opacity(opacity)
            .blur(radius: distance >= 2 ? min(Double(distance - 1) * 0.6, 1.8) : 0)
            // Inset before scaling so the enlarged current line never clips at the edges.
            .padding(.horizontal, 18)
            .scaleEffect(isCurrent ? 1.06 : 0.94)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: distance)
    }
}

/// Unsynced lyrics: scrolls along with song progress as a best guess.
private struct PlainLyricsView: View {
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
                            Text(lines[index].isEmpty ? " " : lines[index])
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.75))
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
