import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent

    var body: some View {
        // Lyrics mode swaps the player for lyrics and moves the controls to the side.
        let showLyrics = settings.lyricsEnabled && settings.homeLyricsMode && media.info != nil

        HStack(spacing: NotchLayout.columnSpacing) {
            artwork
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                .overlay(alignment: .bottomTrailing) {
                    if settings.lyricsEnabled && media.info != nil {
                        LyricsToggle(isOn: $settings.homeLyricsMode)
                            .padding(6)
                    }
                }
                .frame(width: NotchLayout.sideColumn, alignment: .leading)

            Group {
                if let info = media.info {
                    if showLyrics {
                        LyricsContent(info: info)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        PlayerView(info: info)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                } else {
                    StoppedView()
                }
            }
            .frame(maxWidth: .infinity)

            Group {
                if showLyrics {
                    MiniPlayerColumn()
                } else if settings.calendarEnabled {
                    CalendarWidget()
                } else {
                    WaveformView(isPlaying: media.info?.isPlaying ?? false, barCount: 5, maxHeight: 28, color: accent.color)
                }
            }
            .frame(width: NotchLayout.sideColumn, alignment: showLyrics || !settings.calendarEnabled ? .trailing : .leading)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showLyrics)
    }
}

/// Small round button on the artwork that switches Home into lyrics mode.
private struct LyricsToggle: View {
    @Binding var isOn: Bool
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button { isOn.toggle() } label: {
            Image(systemName: isOn ? "quote.bubble.fill" : "quote.bubble")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn ? (accent.isNeutral ? .black : .white) : .white)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(isOn ? AnyShapeStyle(accent.isNeutral ? .white : accent.color) : AnyShapeStyle(.black.opacity(0.55)))
                )
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                .scaleEffect(hovering ? 1.1 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Show player" : "Show lyrics")
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25), value: hovering)
    }
}

extension HomeView {
    /// Album art, or a live muted copy of the YouTube video when one is playing.
    @ViewBuilder
    var artwork: some View {
        if settings.videoPreviewEnabled, let info = media.info, let videoID = info.videoID {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VideoPreview(videoID: videoID, position: info.position(at: context.date), isPlaying: info.isPlaying)
            }
            .background(ArtworkView(image: media.artwork, cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // Keeps clicks for the notch (the web view would swallow them).
            .overlay(Color.clear.contentShape(Rectangle()))
        } else {
            ArtworkView(image: media.artwork, cornerRadius: 16)
        }
    }
}

private struct PlayerView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent
    let info: NowPlayingInfo

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(info.title.isEmpty ? "Unknown title" : info.title)
                    .font(.system(size: 15, weight: .semibold))
                // Shows the current lyric line in place of the artist while it's sung.
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let line = settings.lyricsOnHome ? lyrics.currentLine(at: info.position(at: context.date)) : nil
                    Text(line ?? info.artist)
                        .font(.system(size: 13, weight: line == nil ? .regular : .medium))
                        .foregroundStyle(line == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(accent.isNeutral ? .white : accent.color))
                        .id(line ?? info.artist)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: line)
                }
            }
            .lineLimit(1)

            ProgressBar(info: info)

            HStack(spacing: 28) {
                ControlButton(systemName: "backward.fill", size: 18) { media.previousTrack() }
                ControlButton(systemName: info.isPlaying ? "pause.fill" : "play.fill", size: 26) { media.playPause() }
                ControlButton(systemName: "forward.fill", size: 18) { media.nextTrack() }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProgressBar: View {
    @EnvironmentObject private var media: MediaManager
    @Environment(\.notchAccent) private var accent
    let info: NowPlayingInfo
    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = info.position(at: context.date)
            let fraction = dragFraction ?? (info.duration > 0 ? position / info.duration : 0)

            HStack(spacing: 8) {
                Text(format(dragFraction.map { $0 * info.duration } ?? position))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(accent.color)
                            .frame(width: geo.size.width * min(max(fraction, 0), 1))
                    }
                    .frame(height: dragFraction == nil ? 4 : 6)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { dragFraction = min(max($0.location.x / geo.size.width, 0), 1) }
                            .onEnded { _ in
                                if let f = dragFraction, info.duration > 0 { media.seek(to: f * info.duration) }
                                dragFraction = nil
                            }
                    )
                }
                .frame(height: 12)
                Text(info.duration > 0 ? format(info.duration) : "--:--")
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func format(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct StoppedView: View {
    @EnvironmentObject private var media: MediaManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Music stopped.")
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 18) {
                ForEach(media.installedProviders, id: \.id) { provider in
                    AppLauncherButton(icon: provider.icon, name: provider.displayName) {
                        provider.launch()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppLauncherButton: View {
    let icon: NSImage?
    let name: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "music.note")
                }
            }
            .frame(width: 52, height: 52)
            .scaleEffect(hovering ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .help("Open \(name)")
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25), value: hovering)
    }
}

struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .frame(width: size + 16, height: size + 16)
                .background(Circle().fill(.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.white.opacity(0.1))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                GeometryReader { geo in
                    Image(systemName: "music.note")
                        .font(.system(size: geo.size.width * 0.35))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .animation(.easeInOut(duration: 0.25), value: image)
    }
}

struct WaveformView: View {
    let isPlaying: Bool
    let barCount: Int
    let maxHeight: CGFloat
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = t * (3 + Double(i) * 0.7) + Double(i) * 1.3
                    let amp = isPlaying ? (0.35 + 0.65 * abs(sin(phase))) : 0
                    Capsule()
                        .fill(isPlaying ? color.opacity(0.9) : .white.opacity(0.35))
                        .frame(width: isPlaying ? 3 : 10, height: max(4, maxHeight * amp))
                }
            }
            .frame(height: maxHeight)
        }
    }
}
