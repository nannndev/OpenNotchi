import AppKit
import SwiftUI

final class NotchWindowController: NSObject {
    /// The panel is larger than the open notch so the drop shadow isn't clipped.
    private static let windowSize = CGSize(width: 780, height: NotchViewModel.maxOpenHeight + 60)

    let panel: NotchPanel
    let viewModel: NotchViewModel
    private(set) var targetScreen: NSScreen?
    weak var manager: NotchScreenManager?

    init(
        screen: NSScreen?,
        manager: NotchScreenManager,
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
        self.manager = manager
        self.targetScreen = screen
        self.viewModel = NotchViewModel(settings: settings)
        self.panel = NotchPanel(contentRect: NSRect(origin: .zero, size: Self.windowSize))

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
            .environmentObject(SmarthomeManager.shared)

        let hosting = FirstMouseHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: Self.windowSize)
        panel.contentView = hosting
        super.init()

        viewModel.onOpen = { [weak self] in
            guard let self else { return }
            self.manager?.controllerDidOpen(self)
        }

        reposition(on: screen)
        panel.orderFrontRegardless()
    }

    func reposition(on screen: NSScreen? = nil) {
        let screenToUse = screen ?? targetScreen ?? NSScreen.preferredNotchScreen
        guard let screen = screenToUse else { return }
        targetScreen = screen
        viewModel.update(for: screen)
        let size = Self.windowSize
        let origin = CGPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    func toggle() {
        viewModel.toggle()
    }

    func open() {
        viewModel.open()
    }

    func close() {
        viewModel.close()
    }

    func clickedOutside() {
        viewModel.clickedOutside()
    }

    func previewAnimation() {
        viewModel.replayAnimation(duration: 2.2)
    }

    func showPeek(_ peek: Peek) {
        viewModel.showPeek(peek)
    }

    func dismiss() {
        panel.orderOut(nil)
        panel.close()
    }
}
