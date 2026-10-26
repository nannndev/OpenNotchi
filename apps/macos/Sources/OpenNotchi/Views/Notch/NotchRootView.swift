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
                    NotchBackground(theme: settings.theme, isOpen: vm.isOpen, shape: shape, artwork: media.artwork, palette: media.palette)
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
            NotchBackground(theme: settings.theme, isOpen: false, shape: shape, artwork: media.artwork, palette: media.palette)
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
