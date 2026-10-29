import AppKit
import SwiftUI

/// Coordinates NotchWindowController instances across displays according to AppSettings.displayTarget.
final class NotchScreenManager: ObservableObject {
    /// Lets scripts (and shortcuts) drive the notch:
    /// post `io.github.opennotchi.command` with object "open", "close", "toggle" or a tab name.
    static let commandNotification = Notification.Name("io.github.opennotchi.command")

    private(set) var controllers: [NotchWindowController] = []
    private var clickOutsideMonitor: Any?
    private var globalScrollMonitor: Any?
    private var localScrollMonitor: Any?
    private var cursorCheckTimer: Timer?
    private var lastCursorScreenID: CGDirectDisplayID?

    // Closed-notch gesture state
    private var lastProcessedScrollTimestamp: TimeInterval = 0
    private var lastScrollEventTime: Date = .distantPast
    private var swipeDeltaX: CGFloat = 0
    private var hasTriggeredSwipe = false
    private var lastSwipeTriggerTime: Date = .distantPast

    // Open-notch tab swipe gesture state
    private var lastProcessedTabScrollTimestamp: TimeInterval = 0
    private var lastTabScrollEventTime: Date = .distantPast
    private var openTabSwipeDeltaX: CGFloat = 0
    private var hasTriggeredOpenTabSwipe = false
    private var lastTabSwipeTriggerTime: Date = .distantPast
    private var globalSwipeMonitor: Any?
    private var localSwipeMonitor: Any?

    private let media: MediaManager
    private let tray: TrayStore
    private let battery: BatteryMonitor
    private let clipboard: ClipboardMonitor
    private let timer: TimerManager
    private let calendar: CalendarManager
    private let lyrics: LyricsManager
    private let weather: WeatherManager
    private let markets: MarketManager
    private let prayers: PrayerTimesManager
    private let settings: AppSettings
    private let updater: Updater

    init(
        media: MediaManager,
        tray: TrayStore,
        battery: BatteryMonitor,
        clipboard: ClipboardMonitor,
        timer: TimerManager,
        calendar: CalendarManager,
        lyrics: LyricsManager,
        weather: WeatherManager,
        markets: MarketManager,
        prayers: PrayerTimesManager,
        settings: AppSettings,
        updater: Updater
    ) {
        self.media = media
        self.tray = tray
        self.battery = battery
        self.clipboard = clipboard
        self.timer = timer
        self.calendar = calendar
        self.lyrics = lyrics
        self.weather = weather
        self.markets = markets
        self.prayers = prayers
        self.settings = settings
        self.updater = updater

        updateScreens()

        timer.onFinish = { [weak self] in
            guard let self else { return }
            let ctrl = self.activeController
            ctrl?.viewModel.tab = .timer
            ctrl?.viewModel.open()
        }

        // Clicks in other apps close any open notch (works without Accessibility permission).
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.clickedOutside()
        }

        // Two-finger scroll & swipe gestures on the notch (works both when OpenNotchi is in background and foreground).
        globalScrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            _ = self?.handleNotchScroll(event)
        }
        localScrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            if self?.handleNotchScroll(event) == true {
                return nil
            }
            return event
        }

        // Three-finger swipe gestures on the notch
        globalSwipeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .swipe) { [weak self] event in
            _ = self?.handleNotchSwipe(event)
        }
        localSwipeMonitor = NSEvent.addLocalMonitorForEvents(matching: .swipe) { [weak self] event in
            if self?.handleNotchSwipe(event) == true {
                return nil
            }
            return event
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleCommand(_:)),
            name: Self.commandNotification,
            object: nil
        )

        startCursorTracking()
    }

    deinit {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalScrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localScrollMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalSwipeMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localSwipeMonitor {
            NSEvent.removeMonitor(monitor)
        }
        cursorCheckTimer?.invalidate()
    }

    // MARK: - Multi-Display Management

    func updateScreens() {
        let targetScreens: [NSScreen]
        switch settings.displayTarget {
        case .builtIn:
            targetScreens = [NSScreen.preferredNotchScreen].compactMap { $0 }
        case .active:
            targetScreens = [NSScreen.screenWithCursor ?? NSScreen.preferredNotchScreen].compactMap { $0 }
        case .allScreens:
            targetScreens = NSScreen.screens
        }

        var newControllers: [NotchWindowController] = []
        var remainingTargets = targetScreens

        for controller in controllers {
            if let screen = controller.targetScreen,
               let matchIndex = remainingTargets.firstIndex(where: { $0.displayID == screen.displayID }) {
                controller.reposition(on: remainingTargets[matchIndex])
                newControllers.append(controller)
                remainingTargets.remove(at: matchIndex)
            } else if settings.displayTarget == .active, let first = remainingTargets.first {
                // In active mode, reuse single controller and move to target screen
                controller.reposition(on: first)
                newControllers.append(controller)
                remainingTargets.removeFirst()
            } else {
                controller.dismiss()
            }
        }

        for target in remainingTargets {
            let controller = NotchWindowController(
                screen: target,
                manager: self,
                media: media,
                tray: tray,
                battery: battery,
                clipboard: clipboard,
                timer: timer,
                calendar: calendar,
                lyrics: lyrics,
                weather: weather,
                markets: markets,
                prayers: prayers,
                settings: settings,
                updater: updater
            )
            newControllers.append(controller)
        }

        controllers = newControllers
    }

    private func startCursorTracking() {
        cursorCheckTimer?.invalidate()
        cursorCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, self.settings.displayTarget == .active else { return }
            guard let currentScreen = NSScreen.screenWithCursor,
                  let currentID = currentScreen.displayID else { return }

            if currentID != self.lastCursorScreenID {
                self.lastCursorScreenID = currentID
                if let controller = self.controllers.first, !controller.viewModel.isOpen, !controller.viewModel.isResizing {
                    controller.reposition(on: currentScreen)
                }
            }
        }
    }

    /// The controller on the screen where the user is currently working.
    var activeController: NotchWindowController? {
        let cursorScreen = NSScreen.screenWithCursor
        return controllers.first { $0.targetScreen?.displayID == cursorScreen?.displayID } ?? controllers.first
    }

    /// Closes all other notches when one expands, ensuring only one is open at a time.
    func controllerDidOpen(_ openedController: NotchWindowController) {
        for controller in controllers where controller !== openedController {
            controller.close()
        }
    }

    // MARK: - Actions

    func toggle() {
        if controllers.contains(where: { $0.viewModel.isOpen }) {
            closeAll()
        } else {
            activeController?.open()
        }
    }

    func open() {
        activeController?.open()
    }

    func closeAll() {
        for controller in controllers {
            controller.close()
        }
    }

    func clickedOutside() {
        for controller in controllers {
            controller.clickedOutside()
        }
    }

    /// What a scroll over the notch does. One answer per event, so gestures never overlap.
    enum NotchGesture: Equatable {
        case none
        /// Not ours: let the app or the view under the pointer have it.
        case passThrough
        case switchTab, skipTrack, volume, brightness
    }

    /// Picks the gesture for a scroll at `offsetFromMidX` / `distFromTop` (points) over a notch of `notchWidth`.
    /// - Open notch: only a clearly horizontal swipe inside the header row switches tabs; everything else
    ///   (vertical, or lower down where carousels and lyrics scroll) goes to the view.
    /// - Closed notch: only the notch itself and its live-activity wings count, not the menu bar beside them.
    ///   Horizontal skips tracks; vertical is volume on the left, brightness on the right.
    static func gesture(
        isOpen: Bool, offsetFromMidX: CGFloat, distFromTop: CGFloat, dx: CGFloat, dy: CGFloat,
        notchWidth: CGFloat, notchHeight: CGFloat, openWidth: CGFloat, openHeaderHeight: CGFloat,
        settings: (skip: Bool, volume: Bool, brightness: Bool, tabs: Bool)
    ) -> NotchGesture {
        let horizontal = abs(dx) > abs(dy) * 1.5
        if isOpen {
            let inHeader = distFromTop >= -4 && distFromTop <= openHeaderHeight && abs(offsetFromMidX) <= openWidth / 2
            guard settings.tabs, inHeader, horizontal, abs(dx) > 0.4 else { return .passThrough }
            return .switchTab
        }
        // The closed notch plus a wing each side for the live activity; the rest of the menu bar is the user's.
        let reach = notchWidth / 2 + notchHeight + 40
        guard distFromTop >= -4, distFromTop <= notchHeight + 6, abs(offsetFromMidX) <= reach else { return .passThrough }
        if horizontal { return settings.skip ? .skipTrack : .none }
        guard abs(dy) > 0.05 else { return .none }
        if offsetFromMidX < 0 { return settings.volume ? .volume : .none }
        return settings.brightness ? .brightness : .none
    }

    private var gestureSettings: (skip: Bool, volume: Bool, brightness: Bool, tabs: Bool) {
        (settings.gestureSkipTrack, settings.gestureVolume, settings.gestureBrightness, settings.gestureSwitchTabs)
    }

    /// Handles two-finger swipe / scroll:
    /// - When notch is OPEN: Two-finger horizontal swipe switches tabs with smooth animations.
    ///   Vertical scrolling is passed through to the subview content (lyrics, logs, timers).
    /// - When notch is CLOSED: Two-finger horizontal swipe skips track; two-finger vertical scroll
    ///   adjusts system volume (left side) or screen brightness (right side) with fluid Peek HUD.
    @discardableResult
    func handleNotchScroll(_ event: NSEvent) -> Bool {
        guard settings.closedNotchGesturesEnabled else { return false }

        let mouseLoc = NSEvent.mouseLocation
        guard let controller = controllers.first(where: {
            guard let s = $0.targetScreen else { return false }
            return NSMouseInRect(mouseLoc, s.frame, false)
        }), let screen = controller.targetScreen else {
            return false
        }

        let vm = controller.viewModel
        let distFromTop = screen.frame.maxY - mouseLoc.y
        let offsetFromMidX = mouseLoc.x - screen.frame.midX
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        let gesture = Self.gesture(
            isOpen: vm.isOpen, offsetFromMidX: offsetFromMidX, distFromTop: distFromTop, dx: dx, dy: dy,
            notchWidth: vm.notchSize.width, notchHeight: vm.notchSize.height, openWidth: vm.openSize.width,
            openHeaderHeight: vm.notchSize.height + 30, settings: gestureSettings)
        if gesture == .passThrough { return false }

        // ==========================================
        // 1. NOTCH IS OPEN: TAB SWITCHING GESTURES
        // ==========================================
        if vm.isOpen {
            // Deduplicate if both local and global monitors observe the same event
            guard event.timestamp != lastProcessedTabScrollTimestamp else { return true }
            lastProcessedTabScrollTimestamp = event.timestamp
            guard event.momentumPhase == [] else { return true }

            let now = Date()
            guard now.timeIntervalSince(lastTabSwipeTriggerTime) > 0.28 else { return true }

            if event.phase == .began || now.timeIntervalSince(lastTabScrollEventTime) > 0.3 {
                openTabSwipeDeltaX = 0
                hasTriggeredOpenTabSwipe = false
            }
            lastTabScrollEventTime = now
            openTabSwipeDeltaX += dx

            if !hasTriggeredOpenTabSwipe && abs(openTabSwipeDeltaX) >= 12 {
                hasTriggeredOpenTabSwipe = true
                lastTabSwipeTriggerTime = now

                // Trackpad scroll: swipe left moves to next tab, swipe right moves to previous tab
                let goNext = event.isDirectionInvertedFromDevice ? (openTabSwipeDeltaX < 0) : (openTabSwipeDeltaX > 0)
                if goNext {
                    vm.nextTab()
                } else {
                    vm.previousTab()
                }

                if settings.hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.hasTriggeredOpenTabSwipe = false
                    self?.openTabSwipeDeltaX = 0
                }
            }
            return true
        }

        // ==========================================
        // 2. NOTCH IS CLOSED: PEEK HUD GESTURES
        // ==========================================
        // Deduplicate if both local and global monitors observe the same event
        guard event.timestamp != lastProcessedScrollTimestamp else { return true }
        lastProcessedScrollTimestamp = event.timestamp

        // Suppress hover-open while scrolling closed notch
        vm.suppressOpenForGesture(duration: 1.0)

        let now = Date()
        if event.phase == .began || event.phase == .ended || event.phase == .cancelled || now.timeIntervalSince(lastScrollEventTime) > 0.35 {
            swipeDeltaX = 0
            if event.phase == .began || now.timeIntervalSince(lastScrollEventTime) > 0.35 {
                hasTriggeredSwipe = false
            }
        }
        lastScrollEventTime = now

        // A gesture that's turned off still claims the scroll, so it doesn't fall through as another one.
        if gesture == .none { return true }

        // Closed-Notch 1. Horizontal swipe -> Next / Previous track
        if gesture == .skipTrack {
            guard event.momentumPhase == [] else { return true }
            guard now.timeIntervalSince(lastSwipeTriggerTime) > 0.38 else { return true }

            swipeDeltaX += dx
            if !hasTriggeredSwipe && abs(swipeDeltaX) >= 18 {
                hasTriggeredSwipe = true
                lastSwipeTriggerTime = now

                let goNext = event.isDirectionInvertedFromDevice ? (swipeDeltaX < 0) : (swipeDeltaX > 0)
                let direction: TrackSkipDirection = goNext ? .next : .previous

                if goNext {
                    media.nextTrack()
                } else {
                    media.previousTrack()
                }

                if settings.hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }

                controller.showPeek(.trackSkip(direction: direction, title: nil))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self, weak controller] in
                    guard let self, let controller, case .trackSkip(let dir, _) = controller.viewModel.peek else { return }
                    if let title = self.media.info?.title, !title.isEmpty {
                        controller.showPeek(.trackSkip(direction: dir, title: title))
                    }
                }
            }
            return true
        }

        // Closed-Notch 2. Two-finger vertical scroll -> Left half: System Volume, Right half: Display Brightness
        let stepMultiplier: Float = event.hasPreciseScrollingDeltas ? 0.0038 : 0.038
        let rawDelta = Float(event.isDirectionInvertedFromDevice ? -dy : dy) * stepMultiplier

        if gesture == .volume {
            guard var volume = SystemAudio.volume else { return true }
            let previous = volume
            volume = min(max(volume + rawDelta, 0), 1)
            SystemAudio.volume = volume
            if volume > 0 && SystemAudio.isMuted {
                SystemAudio.isMuted = false
            } else if volume == 0 && !SystemAudio.isMuted {
                SystemAudio.isMuted = true
            }
            if settings.hapticsEnabled && ((previous > 0 && volume == 0) || (previous < 1 && volume == 1)) {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            controller.showPeek(.volume(level: volume, muted: SystemAudio.isMuted))
        } else {
            if var brightness = DisplayBrightness.level {
                let previous = brightness
                brightness = min(max(brightness + rawDelta, 0), 1)
                DisplayBrightness.level = brightness
                if settings.hapticsEnabled && ((previous > 0 && brightness == 0) || (previous < 1 && brightness == 1)) {
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                controller.showPeek(.brightness(level: brightness))
            }
            // No fallback to volume: on a display without brightness control the right side does nothing,
            // instead of quietly becoming a second volume knob.
        }
        return true
    }

    /// Handles 3-finger horizontal swipe gesture:
    /// - When notch is OPEN: switches tabs left or right.
    /// - When notch is CLOSED: skips next/previous track.
    @discardableResult
    func handleNotchSwipe(_ event: NSEvent) -> Bool {
        guard settings.closedNotchGesturesEnabled else { return false }

        let mouseLoc = NSEvent.mouseLocation
        guard let controller = controllers.first(where: {
            guard let s = $0.targetScreen else { return false }
            return NSMouseInRect(mouseLoc, s.frame, false)
        }), let screen = controller.targetScreen else {
            return false
        }

        let vm = controller.viewModel
        let distFromTop = screen.frame.maxY - mouseLoc.y
        let offsetFromMidX = mouseLoc.x - screen.frame.midX
        // Same zones and switches as the two-finger scroll; a three-finger swipe is always horizontal.
        let gesture = Self.gesture(
            isOpen: vm.isOpen, offsetFromMidX: offsetFromMidX, distFromTop: distFromTop, dx: -event.deltaX, dy: 0,
            notchWidth: vm.notchSize.width, notchHeight: vm.notchSize.height, openWidth: vm.openSize.width,
            openHeaderHeight: vm.notchSize.height + 30, settings: gestureSettings)
        guard gesture == .switchTab || gesture == .skipTrack else { return gesture == .none }

        if vm.isOpen {
            // 3-finger swipe: deltaX < 0 is swipe left (next tab), deltaX > 0 is swipe right (previous tab)
            if event.deltaX < 0 {
                vm.nextTab()
                if settings.hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }
                return true
            } else if event.deltaX > 0 {
                vm.previousTab()
                if settings.hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }
                return true
            }
        } else {
            if event.deltaX < 0 {
                media.nextTrack()
                if settings.hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }
                controller.showPeek(.trackSkip(direction: .next, title: nil))
                return true
            } else if event.deltaX > 0 {
                media.previousTrack()
                if settings.hapticsEnabled {
                    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                }
                controller.showPeek(.trackSkip(direction: .previous, title: nil))
                return true
            }
        }
        return false
    }

    func previewAnimation() {
        activeController?.previewAnimation()
    }

    func showPeek(_ peek: Peek) {
        // Played here, once, rather than per screen.
        if case .banner(let banner) = peek, settings.notificationSounds, let sound = banner.kind.sound {
            NSSound(named: sound)?.play()
        }
        switch settings.displayTarget {
        case .allScreens:
            for controller in controllers {
                controller.showPeek(peek)
            }
        case .builtIn, .active:
            activeController?.showPeek(peek)
        }
    }

    func reposition() {
        updateScreens()
    }

    // MARK: - Distributed Commands

    @objc private func handleCommand(_ note: Notification) {
        if let command = note.object as? String {
            if command.hasPrefix("theme-"), let theme = NotchTheme(rawValue: String(command.dropFirst(6))) {
                AppSettings.shared.theme = theme
                return
            }
            if command.hasPrefix("border-"), let border = BorderStyle(rawValue: String(command.dropFirst(7))) {
                AppSettings.shared.borderStyle = border
                return
            }
        }

        switch note.object as? String {
        case "open": open()
        case "close": closeAll()
        case "toggle": toggle()
        case "settings": AppDelegate.shared?.showSettings()
        case "pin": activeController?.viewModel.pinned = true
        case "unpin": activeController?.viewModel.pinned = false
        case "demo-on": AppDelegate.shared?.media.startDemo()
        case "demo-off": AppDelegate.shared?.media.stopDemo()
        case "peek-update":
            AppDelegate.shared?.updater.simulateUpdateNotification()
        case "peek-charging":
            showPeek(.charging(level: 85))
        case "peek-airpods":
            showPeek(.device(
                name: "AirPods Pro",
                symbol: "airpodspro",
                battery: 92,
                info: DeviceBatteryInfo(left: 92, right: 92, caseBattery: 85, single: 92)
            ))
        case "peek-headphones":
            showPeek(.device(
                name: "Sony WH-1000XM5",
                symbol: "headphones",
                battery: 80,
                info: DeviceBatteryInfo(left: nil, right: nil, caseBattery: nil, single: 80)
            ))
        case "peek-agent-done":
            showPeek(.banner(Banner(icon: "checkmark.circle.fill", tint: .green, badge: "Done", title: "Claude Code finished · OpenNotchi", subtitle: "All checks passed", duration: 6, kind: .success)))
        case "peek-agent-needs":
            showPeek(.banner(Banner(icon: "hand.raised.fill", tint: .orange, badge: "Needs you", title: "Claude Code needs you · OpenNotchi", subtitle: "Allow Bash: swift build?", duration: 10, kind: .attention)))
        case "peek-volume": showPeek(.volume(level: 0.68, muted: false))
        case "peek-mute": showPeek(.volume(level: 0, muted: true))
        case "peek-brightness": showPeek(.brightness(level: 0.75))
        case "peek-mic": showPeek(.micMute(muted: true))
        case "peek-meeting":
            showPeek(.banner(ReminderCenter.eventBanner(
                title: "Daily standup",
                start: .now.addingTimeInterval(5 * 60),
                link: (URL(string: "https://meet.google.com/")!, "Google Meet"),
                color: .blue
            )))
        case "peek-prayer":
            let settings = AppSettings.shared
            let prayer = PrayerTime(kind: .maghrib, date: .now)
            showPeek(.banner(ReminderCenter.prayerBanner(
                prayer,
                name: prayer.kind.name(indonesian: settings.prayerIndonesianNames),
                place: settings.weatherPlace,
                minutesLeft: 0,
                indonesian: settings.prayerIndonesianNames
            )))
        case "home":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .home
            ctrl.open()
        case "smart", "smarthome", "ac", "light", "lights":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .smarthome
            ctrl.open()
        case "player":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .home
            ctrl.open()
            DispatchQueue.main.async { AppSettings.shared.homeLyricsMode = false }
        case "lyrics":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .home
            ctrl.open()
            DispatchQueue.main.async { AppSettings.shared.homeLyricsMode = true }
        case "tray":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .tray
            ctrl.open()
        case "prompter":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .prompter
            ctrl.open()
        case "clipboard":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .clipboard
            ctrl.open()
        case "timer":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .timer
            ctrl.open()
        case "mirror":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .mirror
            ctrl.open()
        case "photobox":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .mirror
            ctrl.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .openStripPicker, object: nil)
            }
        case "markets":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .markets
            ctrl.open()
        case "ai":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .ai
            ctrl.open()
        case "dev", "tools":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .dev
            ctrl.open()
        default: break
        }
    }
}
