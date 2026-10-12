import AppKit
import SwiftUI

final class NotchWindowController: NSObject {
    /// The panel is larger than the open notch so the drop shadow isn't clipped.
    private static let windowSize = CGSize(width: 780, height: 300)

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
        settings: AppSettings
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
            .environmentObject(settings)
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
            self?.viewModel.close()
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
        switch note.object as? String {
        case "open": viewModel.open()
        case "close": viewModel.close()
        case "toggle": viewModel.toggle()
        case "settings": AppDelegate.shared?.showSettings()
        // Previews for the live activities, handy when designing them.
        case "peek-charging": viewModel.showPeek(.charging(level: 76))
        case "peek-airpods": viewModel.showPeek(.device(name: "AirPods Pro", symbol: "airpodspro", battery: 82))
        case "peek-volume": viewModel.showPeek(.volume(level: 0.62, muted: false))
        case "peek-brightness": viewModel.showPeek(.brightness(level: 0.4))
        case "home": viewModel.tab = .home; viewModel.open()
        case "lyrics":
            viewModel.tab = .home
            viewModel.open()
            DispatchQueue.main.async { AppSettings.shared.homeLyricsMode = true }
        case "tray": viewModel.tab = .tray; viewModel.open()
        case "clipboard": viewModel.tab = .clipboard; viewModel.open()
        case "timer": viewModel.tab = .timer; viewModel.open()
        case "mirror": viewModel.tab = .mirror; viewModel.open()
        case "markets": viewModel.tab = .markets; viewModel.open()
        default: break
        }
    }

    func toggle() {
        viewModel.toggle()
    }

    func open() {
        viewModel.open()
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
