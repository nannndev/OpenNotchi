import SwiftUI

struct NotchRootView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var timer: TimerManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var airDrop: AirDropService
    @EnvironmentObject private var stats: SystemStatsManager
    @EnvironmentObject private var aiUsage: AIUsageManager

    private var isNetworkSpeedVisible: Bool {
        settings.showLiveActivity && settings.networkLiveActivity && stats.isNetworkActive
    }

    private var isAIMeterVisible: Bool {
        settings.showLiveActivity && settings.aiEnabled && settings.aiClosedMeter && aiUsage.closedMeter != nil
    }

    private var showActivity: Bool {
        guard !vm.isOpen else { return false }
        if vm.peek != nil || airDrop.isTransferring { return true }
        return settings.showLiveActivity && (timer.isActive || (media.info?.isPlaying ?? false) || isNetworkSpeedVisible || isAIMeterVisible || isMascotVisible)
    }

    /// Notchi fills the slot only when nothing else would: no music, timer, network or AI meter.
    private var isMascotVisible: Bool {
        settings.showLiveActivity && settings.showMascot && !timer.isActive && !(media.info?.isPlaying ?? false)
            && !isNetworkSpeedVisible && !isAIMeterVisible
    }

    private var bodySize: CGSize {
        if vm.isOpen { return vm.openSize }
        var size = vm.notchSize
        if showActivity, vm.peek?.isBanner == true {
            // Banners grow below the notch with room for a title and a button.
            return CGSize(width: max(size.width + 2 * (size.height + 40), 400), height: size.height + BannerView.contentHeight)
        }
        if showActivity, vm.peek?.isDeviceCard == true {
            // AirPods & Bluetooth cards drop down into an elegant Dynamic Island card
            return CGSize(width: max(size.width + 2 * (size.height + 48), 380), height: size.height + DeviceBannerView.contentHeight)
        }
        if showActivity {
            // HUD peeks need room for a level bar on the right. Network speed needs room for text.
            let isNetOnly = (isNetworkSpeedVisible || isAIMeterVisible || isMascotVisible) && !timer.isActive && !(media.info?.isPlaying ?? false) && vm.peek == nil && !airDrop.isTransferring
            let extraForSleeve: CGFloat = (settings.artworkStyle == .vinylSleeve && (media.info?.isPlaying ?? false)) ? 6 : 0
            // Notchi only needs a square on each side, like music artwork; text-heavy activities need more.
            let notchiOnly = isMascotVisible && !isNetworkSpeedVisible && !isAIMeterVisible
            let side = vm.peek?.isHUD == true ? size.height + 76 : notchiOnly && isNetOnly ? size.height + 12 : isNetOnly ? size.height + 44 : size.height + 8 + extraForSleeve
            size.width += 2 * side
        }
        return size
    }

    private var isIsland: Bool { !vm.hasPhysicalNotch }

    /// Notchi sits in the closed notch's left slot and can be hovered and petted.
    private var isNotchiInteractive: Bool {
        showActivity && isMascotVisible && vm.peek == nil && !airDrop.isTransferring
    }

    /// Catches the pointer a little above the closed notch so it opens easily. Over Notchi it leaves a gap,
    /// so Notchi itself gets the hover and clicks instead of the notch opening.
    private var hoverStrip: some View {
        let catcher = Color.clear
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { vm.hoverChanged(true) }
            }
        return HStack(spacing: 0) {
            if isNotchiInteractive {
                catcher.frame(width: isIsland ? 12 : topRadius + 6)
                Color.clear.frame(width: vm.notchSize.height + 6).allowsHitTesting(false)
            }
            catcher
        }
        .frame(width: bodySize.width + (isIsland ? 0 : 2 * topRadius), height: isIsland ? 28 : vm.notchSize.height + 4)
        .offset(y: isIsland ? -8 : 0)
    }

    private var topRadius: CGFloat {
        if isIsland { return vm.isOpen ? settings.cornerRadius : 16 }
        return vm.isOpen ? 14 : 6
    }
    private var bottomRadius: CGFloat {
        if isIsland { return vm.isOpen ? settings.cornerRadius : 16 }
        if vm.isOpen { return settings.cornerRadius }
        if showActivity && (vm.peek?.isBanner == true || vm.peek?.isDeviceCard == true) { return 20 }
        return 10
    }

    private var card3DAngle: Double {
        guard settings.openAnimation.is3D else { return 0 }
        if vm.isOpen || showActivity { return 0 }
        return settings.openAnimation.tiltAngle
    }

    private var card3DScale: CGFloat {
        guard settings.openAnimation.is3D else { return 1.0 }
        if vm.isOpen || showActivity { return 1.0 }
        return settings.openAnimation.scale3D
    }

    var body: some View {
        let accent = ResolvedAccent.resolve(settings.accent, palette: media.palette)

        VStack(spacing: 0) {
            if settings.openAnimation.is3D {
                // 3D STAGE: Full card swings in true 3D perspective without 2D height clipping!
                ZStack(alignment: .top) {
                    if vm.isOpen {
                        expandedCard3D(accent: accent)
                            .transition(settings.openAnimation.openCardTransition)
                    } else {
                        closedCard3D(accent: accent)
                            .transition(.opacity)
                    }
                }
                .padding(.top, isIsland ? 8 : 0)
                .animation(settings.openAnimation.springAnimation, value: vm.isOpen)
                .animation(vm.isResizing ? nil : settings.openAnimation.springAnimation, value: vm.openSize.height)
                .onHover { vm.hoverChanged($0) }
                .overlay(alignment: .top) {
                    if !vm.isOpen { hoverStrip }
                }
                .onDrop(of: [.fileURL], isTargeted: $vm.isDropTargeted) { providers in
                    tray.handleDrop(providers)
                }
            } else {
                // CLASSIC 2D STAGE: Fluid, Bouncy, Waterfall, Snappy, Pop, Gentle
                let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, isIsland: isIsland)
                let borderShape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, closed: false, isIsland: isIsland)

                ZStack(alignment: .top) {
                    if vm.isOpen {
                        ExpandedView()
                            .padding(.horizontal, isIsland ? 24 : topRadius + 18)
                            .padding(.bottom, 14)
                            .transition(settings.openAnimation.contentTransition)
                    } else if showActivity {
                        ClosedActivityView(height: vm.notchSize.height)
                            .padding(.horizontal, isIsland ? 12 : topRadius + 6)
                            .transition(.opacity)
                    }
                }
                .frame(width: bodySize.width + (isIsland ? 0 : 2 * topRadius), height: bodySize.height, alignment: .top)
                .background {
                    NotchBackground(theme: settings.theme, isOpen: vm.isOpen || isIsland, shape: shape, artwork: media.artwork, palette: media.palette)
                }
                .clipShape(shape)
                .overlay {
                    NotchBorder(
                        style: settings.borderStyle,
                        width: settings.borderWidth,
                        shape: borderShape,
                        accent: accent,
                        palette: media.palette
                    )
                    .opacity(vm.isOpen ? 1 : 0)
                }
                .overlay {
                    // Subtle island pill border when closed on an external display without physical notch
                    if isIsland && !vm.isOpen {
                        shape
                            .stroke(.white.opacity(0.14), lineWidth: 0.5)
                    }
                }
                .contentShape(shape)
                .shadow(color: .black.opacity(vm.isOpen ? 0.45 : (isIsland ? 0.32 : 0)), radius: isIsland ? 10 : 14, y: isIsland ? 3 : 4)
                .padding(.top, isIsland ? 8 : 0)
                .animation(settings.openAnimation.springAnimation, value: vm.isOpen)
                .animation(vm.isResizing ? nil : settings.openAnimation.springAnimation, value: vm.openSize.height)
                .onHover { vm.hoverChanged($0) }
                .overlay(alignment: .top) {
                    if !vm.isOpen { hoverStrip }
                }
                .onDrop(of: [.fileURL], isTargeted: $vm.isDropTargeted) { providers in
                    tray.handleDrop(providers)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .environment(\.notchAccent, accent)
        .animation(.easeInOut(duration: 0.6), value: accent)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.peek?.isHUD)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.peek?.isBanner)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.peek?.isDeviceCard)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showActivity)
        .animation(settings.openAnimation.springAnimation, value: vm.isOpen)
    }

    private func expandedCard3D(accent: ResolvedAccent) -> some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, isIsland: isIsland)
        let borderShape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, closed: false, isIsland: isIsland)

        return VStack(spacing: 0) {
            ExpandedView()
                .padding(.horizontal, isIsland ? 24 : topRadius + 18)
                .padding(.bottom, 14)
        }
        .frame(width: vm.openSize.width + (isIsland ? 0 : 2 * topRadius), height: vm.openSize.height, alignment: .top)
        .background {
            NotchBackground(theme: settings.theme, isOpen: true, shape: shape, artwork: media.artwork, palette: media.palette)
        }
        .clipShape(shape)
        .overlay {
            NotchBorder(
                style: settings.borderStyle,
                width: settings.borderWidth,
                shape: borderShape,
                accent: accent,
                palette: media.palette
            )
        }
        .overlay(alignment: .top) {
            // Specular glass highlight reflection along top edge
            LinearGradient(
                colors: [
                    .white.opacity(0.35),
                    .white.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8)
            .clipShape(shape)
            .allowsHitTesting(false)
        }
        .contentShape(shape)
        .shadow(color: .black.opacity(0.50), radius: 16, y: 6)
    }

    private func closedCard3D(accent: ResolvedAccent) -> some View {
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius, isIsland: isIsland)

        return ZStack(alignment: .top) {
            if showActivity {
                ClosedActivityView(height: vm.notchSize.height)
                    .padding(.horizontal, isIsland ? 12 : topRadius + 6)
            }
        }
        .frame(width: bodySize.width + (isIsland ? 0 : 2 * topRadius), height: bodySize.height, alignment: .top)
        .background {
            NotchBackground(theme: settings.theme, isOpen: isIsland, shape: shape, artwork: media.artwork, palette: media.palette)
        }
        .clipShape(shape)
        .overlay {
            if isIsland {
                shape
                    .stroke(.white.opacity(0.14), lineWidth: 0.5)
            }
        }
        .contentShape(shape)
        .shadow(color: .black.opacity(isIsland ? 0.32 : 0), radius: 10, y: 3)
    }
}

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
                Image(systemName: !timer.isRunning ? "pause.fill" : timer.pomodoro && timer.phase != .focus ? "cup.and.saucer.fill" : "timer")
                    .font(.system(size: height * 0.45, weight: .semibold))
                    .foregroundStyle(accent.highlight)
                    .frame(width: height - 10)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(formatCountdown(timer.remaining(at: context.date)))
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(accent.highlight)
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
            } else if settings.aiEnabled && settings.aiClosedMeter && !(media.info?.isPlaying ?? false), let meter = aiUsage.closedMeter {
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
                Group {
                    // Notchi puts its headphones on and bops along instead of the waveform.
                    if settings.showMascot && isPlaying {
                        NotchiLive(size: height - 4)
                    } else {
                        WaveformView(isPlaying: isPlaying, barCount: 4, maxHeight: height - 16, color: accent.color)
                    }
                }
                    .frame(width: height - 10)
                    .contentShape(Rectangle())
                    .onTapGesture { media.playPause() }
                    .help(isPlaying ? "Pause music" : "Play music")
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
                                Color(red: 0.05, green: 0.05, blue: 0.06)
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
                        .clear
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

/// A reminder below the notch: icon and badge beside the camera, title and an action underneath.
struct BannerView: View {
    static let contentHeight: CGFloat = 56

    @EnvironmentObject private var vm: NotchViewModel
    let banner: Banner
    let height: CGFloat
    @State private var appeared = false
    @State private var shownAt = Date.now

    /// Attention banners pulse until dismissed; the rest settle after one bounce.
    private var pulses: Bool { banner.kind == .attention }

    var body: some View {
        VStack(spacing: 0) {
            // Beside the notch: a tinted badge on the right; the icon moves down into the card.
            HStack {
                Circle()
                    .fill(banner.tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: banner.tint, radius: 4)
                    .opacity(pulses ? (appeared ? 1 : 0.3) : 1)
                    .animation(pulses ? .easeInOut(duration: 0.7).repeatForever() : .default, value: appeared)
                    .frame(width: height - 6)
                Spacer()
                Text(banner.badge)
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(banner.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(banner.tint.opacity(0.18)))
            }
            .frame(height: height)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [banner.tint.opacity(0.55), banner.tint.opacity(0.12)], center: .center, startRadius: 2, endRadius: 22))
                    Circle().stroke(banner.tint.opacity(0.5), lineWidth: 1)
                    Image(systemName: banner.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: appeared)
                }
                .frame(width: 36, height: 36)
                .scaleEffect(appeared ? 1 : 0.4)
                .shadow(color: banner.tint.opacity(0.6), radius: appeared ? 8 : 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(banner.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .lineLimit(1)
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .offset(x: appeared ? 0 : -8)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 4)
                if let title = banner.actionTitle {
                    Button {
                        if banner.actionType == .triggerUpdate {
                            AppDelegate.shared?.updater.checkForUpdates()
                        } else if let url = banner.actionURL {
                            NSWorkspace.shared.open(url)
                        }
                        vm.dismissPeek()
                    } label: {
                        Label(title, systemImage: banner.actionType == .triggerUpdate ? "arrow.triangle.2.circlepath" : banner.actionURL?.isFileURL == true ? "arrow.up.forward.app" : "video.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(banner.tint.gradient))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    vm.dismissPeek()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            }
            .padding(.leading, 6)
            .frame(height: Self.contentHeight - 8)

            // Time left before the banner closes itself.
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                let left = max(0, 1 - context.date.timeIntervalSince(shownAt) / banner.duration)
                GeometryReader { geo in
                    Capsule()
                        .fill(banner.tint.opacity(0.7))
                        .frame(width: geo.size.width * left, height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 24)
        }
        // A soft glow in the banner's color from the bottom edge.
        .background(alignment: .bottom) {
            Ellipse()
                .fill(banner.tint.opacity(appeared ? 0.22 : 0))
                .frame(height: 40)
                .blur(radius: 18)
                .offset(y: 14)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            vm.dismissPeek()
            vm.open()
        }
        .onAppear {
            shownAt = .now
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { appeared = true }
        }
    }
}

/// An AirPods / Bluetooth connection drop-down card in the Dynamic Island.
struct DeviceBannerView: View {
    static let contentHeight: CGFloat = 46

    let name: String
    let symbol: String
    let battery: Int?
    let info: DeviceBatteryInfo?
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Upper row beside the physical notch
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                        .font(.system(size: height * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.35), radius: 4)
                        .frame(width: height - 6)
                }

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.95, blue: 0.4))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.green.opacity(0.8), radius: 4)
                    Text("Connected")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.2, green: 0.95, blue: 0.4))
                }
            }
            .frame(height: height)

            // Lower card underneath the physical notch
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Battery indicators
                if let info, info.isAirPods {
                    HStack(spacing: 7) {
                        if let l = info.left {
                            batteryPill(label: "L", level: l, icon: "airpod.left")
                        }
                        if let r = info.right {
                            batteryPill(label: "R", level: r, icon: "airpod.right")
                        }
                        if let c = info.caseBattery {
                            batteryPill(label: "Case", level: c, icon: "airpodspro.chargingcase.wireless.fill")
                        }
                    }
                } else if let b = battery ?? info?.primaryBattery {
                    HStack(spacing: 5) {
                        Image(systemName: batteryIcon(for: b))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(b <= 20 ? .red : .green)
                        Text("\(b)%")
                            .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(b <= 20 ? .red : .white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.12)))
                }
            }
            .padding(.horizontal, 4)
            .frame(height: Self.contentHeight)
        }
    }

    private var subtitleText: String {
        if symbol.contains("airpod") { return "Spatial Audio Active" }
        if symbol.contains("keyboard") { return "Bluetooth Keyboard" }
        if symbol.contains("mouse") { return "Bluetooth Mouse" }
        if symbol.contains("trackpad") { return "Bluetooth Trackpad" }
        return "Bluetooth Connected"
    }

    private func batteryPill(label: String, level: Int, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text("\(level)%")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(level <= 20 ? .red : .white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Capsule().fill(.white.opacity(0.12)))
    }

    private func batteryIcon(for level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }
}

/// Left icon + right detail for a peek. Content transitions between peeks.
private struct PeekView: View {
    let peek: Peek
    let height: CGFloat
    @Environment(\.notchAccent) private var accent

    var body: some View {
        Group {
            switch peek {
            case .charging(let level):
                Image(systemName: "bolt.fill")
                    .font(.system(size: height * 0.46, weight: .bold))
                    .foregroundStyle(Color(red: 0.2, green: 0.95, blue: 0.4))
                    .shadow(color: Color.green.opacity(0.6), radius: 6)
                    .frame(width: height - 8, alignment: .leading)
                Spacer()
                HStack(spacing: 6) {
                    FluidHUDLevelBar(level: Float(level) / 100.0, color: Color(red: 0.2, green: 0.95, blue: 0.4))
                    Text("\(level)%")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(red: 0.2, green: 0.95, blue: 0.4))
                        .frame(width: 32, alignment: .trailing)
                }

            case .device(let name, let symbol, let battery, _):
                Image(systemName: symbol)
                    .font(.system(size: height * 0.45, weight: .medium))
                    .frame(width: height - 10)
                    .help(name)
                Spacer()
                if let battery {
                    Text("\(battery)%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(battery <= 20 ? .red : .white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: height * 0.42))
                        .foregroundStyle(.green)
                }

            case .volume(let level, let muted):
                HStack(spacing: 5) {
                    if muted || level == 0 {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: height * 0.44, weight: .bold))
                            .foregroundStyle(.red)
                            .shadow(color: .red.opacity(0.5), radius: 4)
                    } else {
                        Image(systemName: level < 0.34 ? "speaker.wave.1.fill" : level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")
                            .font(.system(size: height * 0.44, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 4)
                    }
                }
                .frame(width: height - 4, alignment: .leading)

                Spacer()

                HStack(spacing: 6) {
                    FluidHUDLevelBar(
                        level: muted ? 0 : level,
                        color: muted ? .red : accent.color
                    )

                    if muted {
                        Text("MUTE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.red)
                            .frame(width: 32, alignment: .trailing)
                    } else {
                        Text("\(Int((level * 100).rounded()))%")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 32, alignment: .trailing)
                    }
                }

            case .brightness(let level):
                Image(systemName: level < 0.35 ? "sun.min.fill" : level < 0.7 ? "sun.haze.fill" : "sun.max.fill")
                    .font(.system(size: height * 0.46, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.25))
                    .shadow(color: Color.yellow.opacity(0.5), radius: 5)
                    .frame(width: height - 4, alignment: .leading)

                Spacer()

                HStack(spacing: 6) {
                    FluidHUDLevelBar(
                        level: level,
                        color: Color(red: 1.0, green: 0.85, blue: 0.25)
                    )

                    Text("\(Int((level * 100).rounded()))%")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 32, alignment: .trailing)
                }

            case .micMute(let muted):
                Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: height * 0.44, weight: .bold))
                    .foregroundStyle(muted ? .red : Color(red: 1.0, green: 0.6, blue: 0.2))
                    .shadow(color: muted ? .red.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
                    .frame(width: height - 4, alignment: .leading)

                Spacer()

                Text(muted ? "MUTED" : "ACTIVE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(muted ? .red : Color(red: 1.0, green: 0.6, blue: 0.2))

            case .privacy(let camera, let mic):
                HStack(spacing: 4) {
                    if camera { Image(systemName: "video.fill").foregroundStyle(.green) }
                    if mic { Image(systemName: "mic.fill").foregroundStyle(.orange) }
                }
                .font(.system(size: height * 0.4, weight: .bold))
                .frame(width: height + 4, alignment: .leading)

                Spacer()

                Text("IN USE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(camera ? .green : .orange)

            case .banner:
                EmptyView()
            }
        }
        .transition(.opacity)
    }
}

private struct FluidHUDLevelBar: View {
    let level: Float
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.85), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(min(max(level, 0), 1))))
                    .shadow(color: color.opacity(0.45), radius: 3, y: 0)
            }
        }
        .frame(width: 68, height: 7.5)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: level)
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
                case .tray: TrayView()
                case .prompter: PrompterView()
                case .clipboard: ClipboardView()
                case .timer: TimerView()
                case .mirror: MirrorView()
                case .markets: MarketsView()
                case .dev: DevToolsView()
                case .notes: NotesView()
                case .smarthome: SmarthomeView()
                case .ai: AIView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
