import AppKit
import SwiftUI

/// Coordinates NotchWindowController instances across displays according to AppSettings.displayTarget.
final class NotchScreenManager: ObservableObject {
    /// Lets scripts (and shortcuts) drive the notch:
    /// post `io.github.opennotchi.command` with object "open", "close", "toggle" or a tab name.
    static let commandNotification = Notification.Name("io.github.opennotchi.command")

    private(set) var controllers: [NotchWindowController] = []
    private var clickOutsideMonitor: Any?
    private var cursorCheckTimer: Timer?
    private var lastCursorScreenID: CGDirectDisplayID?

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

    func previewAnimation() {
        activeController?.previewAnimation()
    }

    func showPeek(_ peek: Peek) {
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
        case "dev", "tools":
            guard let ctrl = activeController else { return }
            ctrl.viewModel.tab = .dev
            ctrl.open()
        default: break
        }
    }
}
