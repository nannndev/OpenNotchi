import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var vm: NotchViewModel
    @Environment(\.notchAccent) private var accent

    var body: some View {
        if vm.musicSearchOpen {
            MusicSearchView { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { vm.musicSearchOpen = false } }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else {
            player
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var player: some View {
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
