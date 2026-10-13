import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent

    var body: some View {
        // YouTube videos get a landscape preview and no lyrics button (videos rarely have lyrics).
        let isVideo = media.info?.videoID != nil
        let lyricsAvailable = settings.lyricsEnabled && media.info != nil && !isVideo
        // Lyrics mode swaps the player for lyrics and moves the controls to the side.
        let showLyrics = lyricsAvailable && settings.homeLyricsMode

        ZStack {
            if settings.ambientAuraEnabled && media.info != nil {
                AmbientMusicAuraView(palette: media.palette, isPlaying: media.info?.isPlaying ?? false)
            }

            HStack(spacing: NotchLayout.columnSpacing) {
                artwork
                    .frame(width: isVideo ? 112 * 16 / 9 : 112, height: 112)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    .frame(width: isVideo ? 112 * 16 / 9 : NotchLayout.sideColumn, alignment: .leading)

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
                            .padding(8)
                            .frame(width: 112, height: 112)
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.05))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.12), lineWidth: 0.5))
                            }
                            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
                    } else if settings.calendarEnabled {
                        CalendarWidget()
                    } else if settings.audioDeckEnabled {
                        AudioDeckCard()
                    } else {
                        Color.clear
                            .frame(width: 112, height: 112)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        settings.calendarEnabled = true
                                    }
                                } label: {
                                    Label("Show Calendar Widget", systemImage: "calendar")
                                }
                            }
                    }
                }
                .frame(width: NotchLayout.sideColumn, alignment: .trailing)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showLyrics)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isVideo)
    }
}

/// Small round button on the artwork that switches Home into lyrics mode.
struct LyricsToggle: View {
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
        let isVideo = media.info?.videoID != nil
        let lyricsAvailable = settings.lyricsEnabled && media.info != nil && !isVideo

        if settings.videoPreviewEnabled, let info = media.info, let videoID = info.videoID {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VideoPreview(videoID: videoID, position: info.position(at: context.date), isPlaying: info.isPlaying)
            }
            .background(ArtworkView(image: media.artwork, cornerRadius: 16))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // Keeps clicks for the notch (the web view would swallow them).
            .overlay(Color.clear.contentShape(Rectangle()))
        } else if media.info != nil {
            PlayerArtworkView(
                image: media.artwork,
                style: settings.artworkStyle,
                isPlaying: media.info?.isPlaying ?? false,
                lyricsAvailable: lyricsAvailable,
                isLyricsMode: $settings.homeLyricsMode
            )
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
                Button {
                    media.toggleLove()
                } label: {
                    Image(systemName: (info.isLoved ?? false) ? "heart.fill" : "heart")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle((info.isLoved ?? false) ? .pink : .secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help((info.isLoved ?? false) ? "Favorited" : "Favorite")

                Spacer()

                PlayerVolumeBar()
            }
            .padding(.horizontal, 4)
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

struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(accent.isNeutral ? AnyShapeStyle(.white) : AnyShapeStyle(accent.color))
                    .frame(width: 32, height: 32)
                    .shadow(color: (accent.isNeutral ? Color.white : accent.color).opacity(hovering ? 0.45 : 0.2), radius: 6)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent.isNeutral ? .black : .white)
                    .offset(x: isPlaying ? 0 : 1)
            }
            .scaleEffect(hovering ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hovering)
    }
}

struct TransportAuxButton: View {
    let systemName: String
    let isActive: Bool
    let size: CGFloat
    let action: () -> Void
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? (accent.isNeutral ? .white.opacity(0.2) : accent.color.opacity(0.25)) : (hovering ? .white.opacity(0.1) : .clear))
                    .frame(width: size + 12, height: size + 12)

                Image(systemName: systemName)
                    .font(.system(size: size, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? (accent.isNeutral ? .white : accent.color) : (hovering ? .white : .secondary))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .scaleEffect(hovering ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: hovering)
    }
}

struct PlayerVolumeBar: View {
    @State private var volume: Float = SystemAudio.volume ?? 0.5
    @State private var isMuted: Bool = SystemAudio.isMuted
    @State private var dragFraction: Double?
    @State private var isHovering = false
    @Environment(\.notchAccent) private var accent

    private var speakerIcon: String {
        if isMuted || volume <= 0.001 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.fill"
        } else if volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Button {
                isMuted.toggle()
                SystemAudio.isMuted = isMuted
            } label: {
                Image(systemName: speakerIcon)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(isMuted ? 0.45 : 0.9)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help(isMuted ? "Unmute" : "Mute")

            GeometryReader { geo in
                let currentFraction = dragFraction ?? Double(volume)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                    Capsule()
                        .fill(isMuted ? .white.opacity(0.3) : accent.color)
                        .frame(width: geo.size.width * min(max(currentFraction, 0), 1))
                }
                .frame(height: (isHovering || dragFraction != nil) ? 5 : 3.5)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let frac = min(max(Double(value.location.x / geo.size.width), 0), 1)
                            dragFraction = frac
                            volume = Float(frac)
                            SystemAudio.volume = volume
                            if isMuted && frac > 0 {
                                isMuted = false
                                SystemAudio.isMuted = false
                            }
                        }
                        .onEnded { _ in
                            if let frac = dragFraction {
                                volume = Float(frac)
                                SystemAudio.volume = volume
                            }
                            dragFraction = nil
                        }
                )
            }
            .frame(width: 64, height: 12)
            .onHover { isHovering = $0 }

            Text("\(Int((isMuted ? 0 : (dragFraction ?? Double(volume))) * 100))%")
                .font(.system(size: 8, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .trailing)
        }
        .onAppear {
            volume = SystemAudio.volume ?? 0.5
            isMuted = SystemAudio.isMuted
        }
    }
}

struct PlayerArtworkView: View {
    let image: NSImage?
    let style: PlayerArtworkStyle
    let isPlaying: Bool
    let lyricsAvailable: Bool
    @Binding var isLyricsMode: Bool
    @EnvironmentObject private var media: MediaManager
    @Environment(\.notchAccent) private var accent
    @State private var isHovering = false

    // Sleeve drag gesture state
    @State private var sleeveDragOffset: CGFloat = 0
    @State private var isDraggingSleeve = false

    var body: some View {
        Group {
            switch style {
            case .standard:
                standardView
            case .vinylDisc:
                vinylDiscOnlyView
            case .vinylCoverCenter:
                vinylCoverCenterView
            case .vinylSleeve:
                vinylSleeveView
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Section("Artwork & Vinyl Style") {
                ForEach(PlayerArtworkStyle.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            AppSettings.shared.artworkStyle = item
                        }
                    } label: {
                        HStack {
                            Label(item.displayName, systemImage: item.icon)
                            if style == item {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleScratchSeek(_ deltaSeconds: Double) {
        guard let info = media.info else { return }
        let currentPos = info.position
        let maxDuration = info.duration > 0 ? info.duration : 9999
        let target = max(0, min(maxDuration, currentPos + deltaSeconds))
        media.seek(to: target)
    }

    private func handleTapToggle() {
        media.playPause()
    }

    // 1. Standard Album Cover (Square)
    private var standardView: some View {
        ArtworkView(image: image, cornerRadius: 14)
            .frame(width: 104, height: 104)
            .overlay(alignment: .bottomTrailing) {
                if lyricsAvailable {
                    LyricsToggle(isOn: $isLyricsMode)
                        .padding(5)
                }
            }
            .onTapGesture { handleTapToggle() }
            .help("Click to play/pause • Right-click to change style")
    }

    // 2. Full Vinyl Disc Only (Turntable with Tonearm)
    private var vinylDiscOnlyView: some View {
        ZStack(alignment: .topTrailing) {
            VinylDiscView(
                image: image,
                isPlaying: isPlaying,
                size: 104,
                centerLabelSize: 46,
                interactive: true,
                onScratchSeek: { handleScratchSeek($0) },
                onTapToggle: { handleTapToggle() }
            )
            .shadow(color: .black.opacity(0.48), radius: 8, x: 0, y: 3)
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHovering)

            // Realistic Tonearm with Stylus Needle
            TurntableTonearmView(isPlaying: isPlaying, size: 104)

            // Lyrics button at bottom-trailing
            if lyricsAvailable {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        LyricsToggle(isOn: $isLyricsMode)
                            .padding(4)
                    }
                }
            }
        }
        .frame(width: 104, height: 104)
        .help("Click to play/pause • Drag to scratch / spin record")
    }

    // 3. Album Cover centered inside spinning Vinyl Platter (Halo)
    private var vinylCoverCenterView: some View {
        ZStack {
            // Spinning outer vinyl ring halo (interactive scratch)
            VinylDiscView(
                image: nil,
                isPlaying: isPlaying,
                size: 106,
                centerLabelSize: 0,
                showCenterImage: false,
                interactive: true,
                onScratchSeek: { handleScratchSeek($0) },
                onTapToggle: { handleTapToggle() }
            )
            .shadow(color: .black.opacity(0.38), radius: 6, x: 0, y: 2)

            // Center square album art floating over the vinyl platter
            ArtworkView(image: image, cornerRadius: 10)
                .frame(width: 68, height: 68)
                .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                )
                .onTapGesture { handleTapToggle() }
        }
        .overlay(alignment: .bottomTrailing) {
            if lyricsAvailable {
                LyricsToggle(isOn: $isLyricsMode)
                    .padding(3)
            }
        }
        .frame(width: 108, height: 108)
        .help("Click to play/pause • Drag vinyl ring to spin")
    }

    // 4. Vinyl Sleeve (Interactive Slide-out)
    private var vinylSleeveView: some View {
        let baseOffset: CGFloat = (isPlaying || isHovering) ? 36 : 6
        let effectiveOffset = max(6, min(54, baseOffset + sleeveDragOffset))

        return ZStack(alignment: .leading) {
            // Vinyl Record Disc (pull out with drag gesture or click)
            VinylDiscView(
                image: image,
                isPlaying: isPlaying,
                size: 88,
                centerLabelSize: 38,
                interactive: true,
                onScratchSeek: { handleScratchSeek($0) },
                onTapToggle: { handleTapToggle() }
            )
            .offset(x: effectiveOffset)
            .scaleEffect((isPlaying || isHovering) ? 1.0 : 0.95)
            .shadow(color: .black.opacity(0.45), radius: 5, x: 2, y: 2)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        isDraggingSleeve = true
                        sleeveDragOffset = val.translation.width
                    }
                    .onEnded { val in
                        isDraggingSleeve = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            if val.translation.width > 18 {
                                if !isPlaying { media.playPause() }
                            } else if val.translation.width < -18 {
                                if isPlaying { media.playPause() }
                            }
                            sleeveDragOffset = 0
                        }
                    }
            )

            // Album Jacket Sleeve
            ZStack(alignment: .trailing) {
                ArtworkView(image: image, cornerRadius: 10)
                    .frame(width: 88, height: 88)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 2)
                    }
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 5)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(width: 88, height: 88)
            .shadow(color: .black.opacity(0.35), radius: 6, x: -1, y: 2)
            .onTapGesture { handleTapToggle() }
            .overlay(alignment: .bottomTrailing) {
                if lyricsAvailable {
                    LyricsToggle(isOn: $isLyricsMode)
                        .padding(4)
                }
            }
        }
        .frame(width: 124, height: 88, alignment: .leading)
        .animation(.spring(response: 0.45, dampingFraction: 0.76), value: isPlaying)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isHovering)
        .help("Click to play/pause • Drag vinyl to pull out")
    }
}

struct TurntableTonearmView: View {
    let isPlaying: Bool
    var size: CGFloat = 104

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Tonearm assembly pivoted at top right
            VStack(alignment: .trailing, spacing: 0) {
                // Pivot Base Cylinder
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(white: 0.8),
                                    Color(white: 0.4),
                                    Color(white: 0.15)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 8
                            )
                        )
                        .frame(width: 15, height: 15)
                        .shadow(color: .black.opacity(0.55), radius: 3, x: 1, y: 1)

                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        .frame(width: 15, height: 15)

                    // Pivot Center Screw
                    Circle()
                        .fill(Color(white: 0.22))
                        .frame(width: 4.5, height: 4.5)
                }
                .frame(width: 15, height: 15)

                // Arm Rod & Cartridge with Needle
                ZStack(alignment: .top) {
                    // Brushed Metallic Arm Rod
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.88),
                                    Color(white: 0.6),
                                    Color(white: 0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 2.2, height: size * 0.46)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: -1, y: 1)

                    // Headshell / Cartridge & Stylus
                    VStack(spacing: 0) {
                        Spacer()
                        ZStack(alignment: .bottom) {
                            // Angled Cartridge
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                                .frame(width: 5, height: 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                                )

                            // Stylus Ruby Needle
                            Circle()
                                .fill(Color(red: 0.95, green: 0.28, blue: 0.25))
                                .frame(width: 2.5, height: 2.5)
                                .offset(y: 2)
                        }
                    }
                    .frame(height: size * 0.46)
                }
                .offset(x: -6, y: -2)
                .rotationEffect(.degrees(isPlaying ? 28 : 2), anchor: .top)
                .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isPlaying)
            }
        }
        .frame(width: size, height: size, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

struct VinylDiscView: View {
    let image: NSImage?
    let isPlaying: Bool
    var size: CGFloat = 104
    var centerLabelSize: CGFloat = 44
    var showCenterImage: Bool = true
    var interactive: Bool = true
    var onScratchSeek: ((Double) -> Void)? = nil
    var onTapToggle: (() -> Void)? = nil

    @State private var dragRotation: Double = 0
    @State private var lastDragAngle: Double = 0
    @State private var isDragging: Bool = false
    @State private var accumulatedScrubAngle: Double = 0
    @State private var lastHapticAngle: Double = 0

    var body: some View {
        TimelineView(.animation(paused: !isPlaying && !isDragging)) { context in
            let baseAngle = (context.date.timeIntervalSinceReferenceDate * 45).truncatingRemainder(dividingBy: 360)
            let totalAngle = baseAngle + dragRotation

            ZStack {
                // Outer Vinyl Disc Body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.14, green: 0.14, blue: 0.16),
                                Color(red: 0.06, green: 0.06, blue: 0.07)
                            ],
                            center: .center,
                            startRadius: size * 0.18,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)

                // Microgroove Concentric Rings
                Group {
                    Circle().stroke(Color.white.opacity(0.04), lineWidth: 1.0).frame(width: size * 0.94, height: size * 0.94)
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.8).frame(width: size * 0.86, height: size * 0.86)
                    Circle().stroke(Color.white.opacity(0.05), lineWidth: 0.9).frame(width: size * 0.78, height: size * 0.78)
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.8).frame(width: size * 0.70, height: size * 0.70)
                    Circle().stroke(Color.white.opacity(0.05), lineWidth: 0.9).frame(width: size * 0.62, height: size * 0.62)
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.8).frame(width: size * 0.54, height: size * 0.54)
                }

                // Specular Light Reflections across grooves (vinyl shine)
                AngularGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.12),
                        .clear,
                        .white.opacity(0.04),
                        .clear,
                        .white.opacity(0.12),
                        .clear
                    ]),
                    center: .center
                )
                .frame(width: size, height: size)
                .clipShape(Circle())

                // Center Label
                if showCenterImage && centerLabelSize > 0 {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.22))
                            .frame(width: centerLabelSize, height: centerLabelSize)

                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: centerLabelSize - 2, height: centerLabelSize - 2)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: centerLabelSize * 0.35))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                            .frame(width: centerLabelSize, height: centerLabelSize)

                        // Spindle Hole
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                    }
                }
            }
            .rotationEffect(.degrees(totalAngle))
            .gesture(interactive ? interactiveGesture : nil)
        }
        .frame(width: size, height: size)
    }

    private var interactiveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: size / 2, y: size / 2)
                let currentAngle = angle(from: center, to: value.location)

                if !isDragging {
                    isDragging = true
                    lastDragAngle = currentAngle
                    accumulatedScrubAngle = 0
                    lastHapticAngle = 0
                } else {
                    var delta = currentAngle - lastDragAngle
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }

                    dragRotation += delta
                    accumulatedScrubAngle += delta
                    lastDragAngle = currentAngle

                    // Haptic tick every ~30 degrees of manual spin
                    if abs(accumulatedScrubAngle - lastHapticAngle) >= 30 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        lastHapticAngle = accumulatedScrubAngle
                    }
                }
            }
            .onEnded { _ in
                let totalMoved = abs(accumulatedScrubAngle)
                isDragging = false

                if totalMoved > 14 {
                    // DJ Scratch Scrub
                    let secondsDelta = (accumulatedScrubAngle / 360.0) * 4.0
                    onScratchSeek?(secondsDelta)
                } else {
                    // Tap to play/pause
                    onTapToggle?()
                }
            }
    }

    private func angle(from center: CGPoint, to point: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let rad = atan2(dy, dx)
        var deg = rad * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }
}

struct AmbientMusicAuraView: View {
    let palette: ArtworkPalette?
    let isPlaying: Bool
    @Environment(\.notchAccent) private var accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = sin(t * 0.8) * 0.08
            let primaryColor = palette?.backgroundTop ?? accent.color.opacity(0.3)
            let accentColor = palette?.accent ?? accent.color

            ZStack {
                // Left orb behind artwork
                Circle()
                    .fill(primaryColor.opacity(0.35 + pulse))
                    .frame(width: 170, height: 170)
                    .offset(x: -160, y: 10)
                    .blur(radius: 50)

                // Center-right orb behind player
                Ellipse()
                    .fill(accentColor.opacity(0.28 - pulse))
                    .frame(width: 240, height: 140)
                    .offset(x: 40, y: -5)
                    .blur(radius: 55)
            }
            .allowsHitTesting(false)
        }
    }
}
