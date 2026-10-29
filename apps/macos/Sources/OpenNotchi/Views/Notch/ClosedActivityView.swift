import SwiftUI

/// Compact "live activity" shown beside the physical notch.
/// Priority: a peek (charger, device, HUD), then an AirDrop transfer, then a running timer, then music.
struct ClosedActivityView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var airDrop: AirDropService
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var timer: TimerManager
    @EnvironmentObject private var stats: SystemStatsManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var aiUsage: AIUsageManager
    @EnvironmentObject private var ciMonitor: CIBuildMonitor
    @EnvironmentObject private var ambient: AmbientSoundManager
    @Environment(\.notchAccent) private var accent
    let height: CGFloat

    var body: some View {
        if case .banner(let banner) = vm.peek {
            BannerView(banner: banner, height: height)
        } else if case .device(let name, let symbol, let battery, let info) = vm.peek, vm.peek?.isDeviceCard == true {
            DeviceBannerView(name: name, symbol: symbol, battery: battery, info: info, height: height)
        } else {
            row
        }
    }

    private var row: some View {
        HStack {
            if let peek = vm.peek {
                PeekView(peek: peek, height: height)
            } else if airDrop.isTransferring {
                Image(systemName: "airplayaudio")
                    .symbolVariant(.circle.fill)
                    .font(.system(size: height * 0.5))
                    .foregroundStyle(.blue)
                    .frame(width: height - 10)
                Spacer()
                Group {
                    switch airDrop.state {
                    case .sending(_, let progress?):
                        AirDropProgressRing(progress: progress, lineWidth: 2.5)
                    case .sent:
                        Image(systemName: "checkmark.circle.fill").resizable().foregroundStyle(.green)
                    case .failed:
                        Image(systemName: "exclamationmark.circle.fill").resizable().foregroundStyle(.orange)
                    default:
                        ProgressView().controlSize(.mini)
                    }
                }
                .frame(width: height - 14, height: height - 14)
            } else if timer.isActive {
                ClosedTimerView(height: height)
            } else if settings.ciLiveActivity,
                !(media.info?.isPlaying ?? false),
                let ciSummary = ciMonitor.closedActivitySummary
            {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.75)
                    Text(ciSummary.leftLabel)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                .frame(width: height + 36, alignment: .leading)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: ciSummary.isLocal ? "hammer.fill" : "arrow.triangle.branch")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.orange)
                    Text(ciSummary.rightLabel)
                        .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: height + 36, alignment: .trailing)
            } else if ambient.isPlaying && !(media.info?.isPlaying ?? false) {
                HStack(spacing: 3) {
                    Image(systemName: ambient.activeSounds.first?.icon ?? "waveform")
                        .font(.system(size: height * 0.42, weight: .semibold))
                        .foregroundStyle(accent.highlight)
                }
                .frame(width: height - 10)
                .contentShape(Rectangle())
                .onTapGesture { ambient.toggleMuteAll() }
                .help("Pause Focus Soundscapes")
                Spacer()
                if settings.showMascot {
                    NotchiLive(size: height - 4)
                } else {
                    WaveformView(isPlaying: true, barCount: 4, maxHeight: height - 16, color: accent.color)
                        .frame(width: height - 10)
                        .contentShape(Rectangle())
                        .onTapGesture { ambient.toggleMuteAll() }
                        .help("Pause Focus Soundscapes")
                }
            } else if settings.networkLiveActivity && stats.isNetworkActive && !(media.info?.isPlaying ?? false) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.green)
                    Text(stats.formattedDown)
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: height + 36, alignment: .leading)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text(stats.formattedUp)
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white)
                }
                .frame(width: height + 36, alignment: .trailing)
            } else if settings.aiEnabled && settings.aiClosedMeter && !(media.info?.isPlaying ?? false),
                let meter = aiUsage.closedMeter
            {
                Group {
                    if settings.showMascot {
                        NotchiLive(size: height - 4)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: height * 0.38, weight: .semibold))
                            .foregroundStyle(meter.hot ? .orange : accent.highlight)
                    }
                }
                .frame(width: height + 36, alignment: .leading)
                Spacer()
                HStack(spacing: 4) {
                    Text(meter.label)
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(meter.hot ? .orange : .white)
                    ProgressView(value: min(1, max(0, meter.fraction)))
                        .progressViewStyle(.linear)
                        .tint(meter.hot ? .orange : accent.highlight)
                        .frame(width: 18)
                }
                .frame(width: height + 36, alignment: .trailing)
            } else if settings.showMascot && !(media.info?.isPlaying ?? false) {
                NotchiIdleRow(height: height)
            } else {
                let isPlaying = media.info?.isPlaying ?? false
                CompactArtworkView(
                    image: media.artwork,
                    style: settings.artworkStyle,
                    isPlaying: isPlaying,
                    size: height - 10
                )
                .contentShape(Rectangle())
                .onTapGesture { media.playPause() }
                .help(isPlaying ? "Pause music" : "Play music")
                Spacer()
                if settings.showMascot && isPlaying {
                    // Notchi puts its headphones on, bops along, and stays fully interactive on the right!
                    NotchiLive(size: height - 4)
                } else {
                    WaveformView(isPlaying: isPlaying, barCount: 4, maxHeight: height - 16, color: accent.color)
                        .frame(width: height - 10)
                        .contentShape(Rectangle())
                        .onTapGesture { media.playPause() }
                        .help(isPlaying ? "Pause music" : "Play music")
                }
            }
        }
        .frame(height: height)
    }
}

struct CompactArtworkView: View {
    let image: NSImage?
    let style: PlayerArtworkStyle
    let isPlaying: Bool
    let size: CGFloat
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            switch style {
            case .standard:
                ArtworkView(image: image, cornerRadius: 4.5)
                    .frame(width: size, height: size)

            case .vinylDisc:
                // Mini spinning turntable vinyl disc
                MiniSpinningVinylDisc(image: image, isPlaying: isPlaying, size: size)

            case .vinylCoverCenter:
                // Floating center cover surrounded by spinning vinyl platter
                ZStack {
                    MiniSpinningVinylDisc(image: nil, isPlaying: isPlaying, size: size, showCenter: false)
                    ArtworkView(image: image, cornerRadius: 2.5)
                        .frame(width: size * 0.65, height: size * 0.65)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                }
                .frame(width: size, height: size)

            case .vinylSleeve:
                // Mini album jacket with spinning vinyl disc peeking out
                let sleeveSize = size * 0.84
                let discSize = size * 0.84
                ZStack(alignment: .leading) {
                    MiniSpinningVinylDisc(image: image, isPlaying: isPlaying, size: discSize)
                        .offset(x: isPlaying ? 7 : 3)
                        .shadow(color: .black.opacity(0.4), radius: 1.5)

                    ArtworkView(image: image, cornerRadius: 2.5)
                        .frame(width: sleeveSize, height: sleeveSize)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
                .frame(width: size + 6, height: size, alignment: .leading)
            }
        }
        .contextMenu {
            Section("Artwork & Vinyl Style") {
                ForEach(PlayerArtworkStyle.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            settings.artworkStyle = item
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
}

/// Mini spinning turntable disc for the closed notch.
struct MiniSpinningVinylDisc: View {
    let image: NSImage?
    let isPlaying: Bool
    var size: CGFloat = 22
    var showCenter: Bool = true

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let angle = (context.date.timeIntervalSinceReferenceDate * 50).truncatingRemainder(dividingBy: 360)

            ZStack {
                // Outer Vinyl Body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.16, green: 0.16, blue: 0.18),
                                Color(red: 0.05, green: 0.05, blue: 0.06),
                            ],
                            center: .center,
                            startRadius: size * 0.15,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)

                // Groove ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                    .frame(width: size * 0.85, height: size * 0.85)

                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                    .frame(width: size * 0.68, height: size * 0.68)

                // Specular Shine
                AngularGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.18),
                        .clear,
                        .white.opacity(0.18),
                        .clear,
                    ]),
                    center: .center
                )
                .frame(width: size, height: size)
                .clipShape(Circle())

                // Circular Center Album Art & Spindle
                if showCenter {
                    let labelSize = size * 0.44
                    ZStack {
                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: labelSize, height: labelSize)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color(white: 0.25))
                                .frame(width: labelSize, height: labelSize)
                        }

                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                            .frame(width: labelSize, height: labelSize)

                        // Center spindle hole
                        Circle()
                            .fill(Color.black)
                            .frame(width: max(2.0, size * 0.1), height: max(2.0, size * 0.1))
                    }
                }
            }
            .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 2)
    }
}
