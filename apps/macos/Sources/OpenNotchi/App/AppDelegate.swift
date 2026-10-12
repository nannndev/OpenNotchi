import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate? { NSApp.delegate as? AppDelegate }

    let settings = AppSettings.shared
    private(set) lazy var media = MediaManager(settings: settings)
    let battery = BatteryMonitor()
    let tray = TrayStore()
    private(set) lazy var clipboard = ClipboardMonitor(settings: settings)
    let timer = TimerManager()
    let calendar = CalendarManager()
    private(set) lazy var lyrics = LyricsManager(media: media, settings: settings)
    private(set) lazy var weather = WeatherManager(settings: settings)
    private(set) lazy var markets = MarketManager(settings: settings)
    private(set) lazy var prayers = PrayerTimesManager(settings: settings)
    private lazy var reminders = ReminderCenter(settings: settings, calendar: calendar, prayers: prayers)
    let audioDevice = AudioDeviceManager.shared
    let colorPicker = ColorPickerManager.shared
    let portInspector = PortInspector.shared
    let vision = VisionService.shared
    let stats = SystemStatsManager.shared
    let updater = Updater()

    private let bluetooth = BluetoothMonitor()
    private let mediaKeys = MediaKeyInterceptor()
    private var hudRetryTimer: Timer?
    private var hotKey: HotKey?
    private var cancellables: Set<AnyCancellable> = []

    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchController = NotchWindowController(
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
            settings: settings
        )
        setupStatusItem()
        updateHotKey()
        setupPeeks()
        updateSystemMonitors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        notchController?.reposition()
    }

    // MARK: - Shortcut

    /// Registers the user's toggle shortcut (⌥⌘N by default).
    func updateHotKey() {
        hotKey = settings.hotKeyEnabled
            ? HotKey(keyCode: settings.hotKeyCode, modifiers: settings.hotKeyModifiers) { [weak self] in self?.notchController?.toggle() }
            : nil
        toggleMenuItem?.title = settings.hotKeyEnabled ? "Toggle Notch  \(settings.hotKeyDisplay)" : "Toggle Notch"
    }

    /// Releases the shortcut while a new one is being recorded.
    func suspendHotKey() {
        hotKey = nil
    }

    // MARK: - Live activities

    private func setupPeeks() {
        // Charger plugged in.
        battery.$isPluggedIn
            .removeDuplicates()
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self, self.settings.chargingPeekEnabled else { return }
                self.notchController?.showPeek(.charging(level: self.battery.level))
            }
            .store(in: &cancellables)

        bluetooth.onConnect = { [weak self] name, symbol, battery, info in
            self?.notchController?.showPeek(.device(name: name, symbol: symbol, battery: battery, info: info))
        }

        reminders.onBanner = { [weak self] banner in
            self?.notchController?.showPeek(.banner(banner))
        }

        mediaKeys.handler = { [weak self] key in
            self?.handleMediaKey(key) ?? false
        }
    }

    /// Starts or stops the Bluetooth and media key monitors to match Settings.
    func updateSystemMonitors() {
        settings.devicePeekEnabled ? bluetooth.start() : bluetooth.stop()

        hudRetryTimer?.invalidate()
        hudRetryTimer = nil
        guard settings.hudEnabled else {
            mediaKeys.stop()
            return
        }
        if !mediaKeys.start() {
            MediaKeyInterceptor.requestPermission()
            // Start as soon as the user grants Accessibility access.
            hudRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                if self?.mediaKeys.start() == true { timer.invalidate() }
            }
        }
    }

    /// Adjusts volume or brightness and shows the HUD. Returns false to let macOS handle the key.
    private func handleMediaKey(_ key: MediaKey) -> Bool {
        let step: Float = 1 / 16
        switch key {
        case .volumeUp, .volumeDown:
            guard var volume = SystemAudio.volume else { return false }
            volume = (volume + (key == .volumeUp ? step : -step)).clamped(to: 0...1)
            SystemAudio.volume = volume
            if SystemAudio.isMuted && key == .volumeUp { SystemAudio.isMuted = false }
            notchController?.showPeek(.volume(level: volume, muted: SystemAudio.isMuted))
        case .mute:
            SystemAudio.isMuted.toggle()
            notchController?.showPeek(.volume(level: SystemAudio.volume ?? 0, muted: SystemAudio.isMuted))
        case .brightnessUp, .brightnessDown:
            guard var level = DisplayBrightness.level else { return false }
            level = (level + (key == .brightnessUp ? step : -step)).clamped(to: 0...1)
            DisplayBrightness.level = level
            notchController?.showPeek(.brightness(level: level))
        }
        return true
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = BrandMark.menuBarImage()

        let menu = NSMenu()
        let toggle = menu.addItem(withTitle: "Toggle Notch", action: #selector(toggleNotch), keyEquivalent: "")
        toggle.target = self
        toggleMenuItem = toggle
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        if updater.isAvailable {
            menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "").target = self
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OpenNotchi", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu

        item.isVisible = settings.showMenuBarIcon
        statusItem = item
    }

    func setMenuBarIconVisible(_ visible: Bool) {
        statusItem?.isVisible = visible
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView()
                    .environmentObject(settings)
                    .environmentObject(media)
                    .environmentObject(weather)
                    .environmentObject(markets)
                    .environmentObject(prayers)
                    .environmentObject(calendar)
                    .environmentObject(updater)
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "OpenNotchi Settings"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Opens the notch so theme changes in Settings are visible right away.
    func previewNotch() {
        notchController?.open()
    }

    @objc private func toggleNotch() {
        notchController?.toggle()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
