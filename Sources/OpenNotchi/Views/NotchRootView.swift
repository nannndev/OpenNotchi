import SwiftUI

struct NotchRootView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var timer: TimerManager
    @EnvironmentObject private var settings: AppSettings

    private var showActivity: Bool {
        !vm.isOpen && settings.showLiveActivity && (timer.isActive || (media.info?.isPlaying ?? false))
    }

    private var bodySize: CGSize {
        if vm.isOpen { return vm.openSize }
        var size = vm.notchSize
        if showActivity { size.width += 2 * (size.height + 8) }
        return size
    }

    private var topRadius: CGFloat { vm.isOpen ? 14 : 6 }
    private var bottomRadius: CGFloat { vm.isOpen ? settings.cornerRadius : 10 }

    var body: some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)
        let accent = ResolvedAccent.resolve(settings.accent, palette: media.palette)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if vm.isOpen {
                    ExpandedView()
                        .padding(.horizontal, topRadius + 18)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else if showActivity {
                    ClosedActivityView(height: vm.notchSize.height)
                        .padding(.horizontal, topRadius + 6)
                        .transition(.opacity)
                }
            }
            .frame(width: bodySize.width + 2 * topRadius, height: bodySize.height, alignment: .top)
            .background {
                NotchBackground(theme: settings.theme, isOpen: vm.isOpen, shape: shape, artwork: media.artwork, palette: media.palette)
            }
            .clipShape(shape)
            .overlay {
                NotchBorder(
                    style: settings.borderStyle,
                    width: settings.borderWidth,
                    shape: NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, closed: false),
                    accent: accent,
                    palette: media.palette
                )
                .opacity(vm.isOpen ? 1 : 0)
            }
            .contentShape(shape)
            .shadow(color: .black.opacity(vm.isOpen ? 0.45 : 0), radius: 14, y: 4)
            .onHover { vm.hoverChanged($0) }
            .onDrop(of: [.fileURL], isTargeted: $vm.isDropTargeted) { providers in
                tray.handleDrop(providers)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .environment(\.notchAccent, accent)
        .animation(.easeInOut(duration: 0.6), value: accent)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.isOpen)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showActivity)
    }
}

/// Compact "live activity" shown beside the physical notch.
/// A running timer takes priority over music.
struct ClosedActivityView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var timer: TimerManager
    @Environment(\.notchAccent) private var accent
    let height: CGFloat

    var body: some View {
        HStack {
            if timer.isActive {
                Image(systemName: timer.isRunning ? "timer" : "pause.fill")
                    .font(.system(size: height * 0.45, weight: .semibold))
                    .foregroundStyle(accent.highlight)
                    .frame(width: height - 10)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatCountdown(timer.remaining(at: context.date)))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(accent.highlight)
                }
            } else {
                ArtworkView(image: media.artwork, cornerRadius: 5)
                    .frame(width: height - 10, height: height - 10)
                Spacer()
                WaveformView(isPlaying: true, barCount: 4, maxHeight: height - 16, color: accent.color)
                    .frame(width: height - 10)
            }
        }
        .frame(height: height)
    }
}

/// Shared measurements so every tab lines up the same way:
/// equal side columns with the main content centered between them.
enum NotchLayout {
    static let sideColumn: CGFloat = 124
    static let columnSpacing: CGFloat = 18
}

func formatTime(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return String(format: "%d:%02d", s / 60, s % 60)
}

func formatCountdown(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    return s >= 3600
        ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
        : String(format: "%d:%02d", s / 60, s % 60)
}

struct ExpandedView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let tab = settings.visibleTabs.contains(vm.tab) ? vm.tab : .home

        VStack(spacing: 4) {
            HeaderView()
                .frame(height: max(vm.notchSize.height, 28))

            Group {
                switch tab {
                case .home: HomeView()
                case .lyrics: LyricsView()
                case .tray: TrayView()
                case .clipboard: ClipboardView()
                case .timer: TimerView()
                case .mirror: MirrorView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
