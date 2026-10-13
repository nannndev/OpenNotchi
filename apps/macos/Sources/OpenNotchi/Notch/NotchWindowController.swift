import AppKit
import SwiftUI

final class NotchWindowController: NSObject {
    /// The panel is larger than the open notch so the drop shadow isn't clipped.
    private static let windowSize = CGSize(width: 780, height: NotchViewModel.maxOpenHeight + 60)

    private let panel: NotchPanel
    private let viewModel: NotchViewModel

    private var clickOutsideMonitor: Any?

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
        viewModel = NotchViewModel(settings: settings)
        panel = NotchPanel(contentRect: NSRect(origin: .zero, size: Self.windowSize))

        let root = NotchRootView()
            .environmentObject(viewModel)
            .environmentObject(media)
            .environmentObject(tray)
            .environmentObject(battery)
            .environmentObject(clipboard)
            .environmentObject(timer)
            .environmentObject(calendar)
            .environmentObject(lyrics)
            .environmentObject(weather)
            .environmentObject(markets)
            .environmentObject(prayers)
            .environmentObject(settings)
            .environmentObject(updater)
            .environmentObject(AirDropService.shared)
            .environmentObject(AudioDeviceManager.shared)
            .environmentObject(ColorPickerManager.shared)
            .environmentObject(PortInspector.shared)
            .environmentObject(VisionService.shared)
            .environmentObject(SystemStatsManager.shared)
        let hosting = FirstMouseHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: Self.windowSize)
        panel.contentView = hosting
        super.init()

        reposition()
        panel.orderFrontRegardless()

        timer.onFinish = { [weak self] in
            self?.viewModel.tab = .timer
            self?.viewModel.open()
        }

        // Clicks in other apps close the notch (works without Accessibility permission).
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.viewModel.clickedOutside()
        }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleCommand(_:)),
            name: Self.commandNotification,
            object: nil
        )
    }

    /// Lets scripts (and later, shortcuts) drive the notch:
    /// post `io.github.opennotchi.command` with object "open", "close", "toggle" or a tab name.
    static let commandNotification = Notification.Name("io.github.opennotchi.command")

    @objc private func handleCommand(_ note: Notification) {
        // "theme-aurora", "border-rainbow": switch looks without opening Settings (demos, screenshots).
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
        case "open": viewModel.open()
        case "close": viewModel.close()
        case "toggle": viewModel.toggle()
        case "settings": AppDelegate.shared?.showSettings()
        case "pin": viewModel.pinned = true
        case "unpin": viewModel.pinned = false
        case "demo-on": AppDelegate.shared?.media.startDemo()
        case "demo-off": AppDelegate.shared?.media.stopDemo()
        // Previews for the live activities, handy when designing them.
        case "peek-update":
            AppDelegate.shared?.updater.simulateUpdateNotification()
        case "peek-charging": viewModel.showPeek(.charging(level: 85))
        case "peek-airpods":
            viewModel.showPeek(.device(
                name: "AirPods Pro",
                symbol: "airpodspro",
                battery: 92,
                info: DeviceBatteryInfo(left: 92, right: 92, caseBattery: 85, single: 92)
            ))
        case "peek-headphones":
            viewModel.showPeek(.device(
                name: "Sony WH-1000XM5",
                symbol: "headphones",
                battery: 80,
                info: DeviceBatteryInfo(left: nil, right: nil, caseBattery: nil, single: 80)
            ))
        case "peek-volume": viewModel.showPeek(.volume(level: 0.68, muted: false))
        case "peek-mute": viewModel.showPeek(.volume(level: 0, muted: true))
        case "peek-brightness": viewModel.showPeek(.brightness(level: 0.75))
        case "peek-mic": viewModel.showPeek(.micMute(muted: true))
        case "peek-meeting":
            viewModel.showPeek(.banner(ReminderCenter.eventBanner(
                title: "Daily standup",
                start: .now.addingTimeInterval(5 * 60),
                link: (URL(string: "https://meet.google.com/")!, "Google Meet"),
                color: .blue
            )))
        case "peek-prayer":
            let settings = AppSettings.shared
            let prayer = PrayerTime(kind: .maghrib, date: .now)
            viewModel.showPeek(.banner(ReminderCenter.prayerBanner(
                prayer,
                name: prayer.kind.name(indonesian: settings.prayerIndonesianNames),
                place: settings.weatherPlace,
                minutesLeft: 0,
                indonesian: settings.prayerIndonesianNames
            )))
        case "home": viewModel.tab = .home; viewModel.open()
        case "player":
            viewModel.tab = .home
            viewModel.open()
            DispatchQueue.main.async { AppSettings.shared.homeLyricsMode = false }
        case "lyrics":
            viewModel.tab = .home
            viewModel.open()
            DispatchQueue.main.async { AppSettings.shared.homeLyricsMode = true }
        case "tray": viewModel.tab = .tray; viewModel.open()
        case "prompter": viewModel.tab = .prompter; viewModel.open()
        case "clipboard": viewModel.tab = .clipboard; viewModel.open()
        case "timer": viewModel.tab = .timer; viewModel.open()
        case "mirror": viewModel.tab = .mirror; viewModel.open()
        case "photobox":
            viewModel.tab = .mirror
            viewModel.open()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .openStripPicker, object: nil)
            }
        case "markets": viewModel.tab = .markets; viewModel.open()
        case "dev", "tools": viewModel.tab = .dev; viewModel.open()
        default: break
        }
    }

    func toggle() {
        viewModel.toggle()
    }

    func open() {
        viewModel.open()
    }

    func previewAnimation() {
        viewModel.replayAnimation(duration: 2.2)
    }

    func showPeek(_ peek: Peek) {
        viewModel.showPeek(peek)
    }

    func reposition() {
        guard let screen = NSScreen.preferredNotchScreen else { return }
        viewModel.update(for: screen)
        let size = Self.windowSize
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
