import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent
    let info: NowPlayingInfo

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(info.title.isEmpty ? "Unknown title" : info.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .lineLimit(1)
                // Shows the current lyric line in place of the artist while it's sung.
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let line = settings.lyricsOnHome ? lyrics.currentLine(at: info.position(at: context.date)) : nil
                    Text(line ?? info.artist)
                        .font(.system(size: 12, weight: line == nil ? .regular : .medium))
                        .foregroundStyle(line == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(accent.isNeutral ? .white : accent.color))
                        .id(line ?? info.artist)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: line)
                }
                .lineLimit(1)
            }

            if let device = info.remoteDevice {
                Label("Playing on \(device)", systemImage: "hifispeaker.and.homepod.fill")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .padding(.top, -4)
            }

            ProgressBar(info: info)

            HStack(spacing: 16) {
                TransportAuxButton(
                    systemName: "shuffle",
                    isActive: info.isShuffled ?? false,
                    size: 12,
                    action: { media.toggleShuffle() }
                )
                .help("Shuffle")

                ControlButton(systemName: "backward.fill", size: 16) { media.previousTrack() }

                PlayPauseButton(isPlaying: info.isPlaying) { media.playPause() }

                ControlButton(systemName: "forward.fill", size: 16) { media.nextTrack() }

                TransportAuxButton(
                    systemName: "repeat",
                    isActive: info.isRepeating ?? false,
                    size: 12,
                    action: { media.toggleRepeat() }
                )
                .help("Repeat")
            }

            HStack(spacing: 8) {
                PlayerChip(icon: "heart", isOn: info.isLoved ?? false, onColor: .pink,
                           help: (info.isLoved ?? false) ? "Favorited" : "Favorite") {
                    media.toggleLove()
                }

                PlayerChip(icon: "arrow.up.left.and.arrow.down.right", help: "Full-screen player") {
                    vm.close()
                    AppDelegate.shared?.nowPlayingScreen?.show()
                }

                if MusicSearchView.isAvailable(settings) {
                    PlayerChip(icon: "magnifyingglass", help: "Search music") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { vm.musicSearchOpen = true }
                    }
                }

                if settings.lyricsEnabled && info.videoID == nil {
                    PlayerChip(icon: "pip", isOn: settings.lyricsOverlayEnabled,
                               help: settings.lyricsOverlayEnabled ? "Hide desktop lyrics" : "Show desktop lyrics") {
                        settings.lyricsOverlayEnabled.toggle()
                    }
                }

                Spacer()

                PlayerVolumeBar()
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProgressBar: View {
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

struct StoppedView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 12) {
            Text("Music stopped.")
                .font(.system(size: 15, weight: .semibold))

            if MusicSearchView.isAvailable(settings) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { vm.musicSearchOpen = true }
                } label: {
                    Label("Search a song to play", systemImage: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }

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

struct AppLauncherButton: View {
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
