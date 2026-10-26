import SwiftUI

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
