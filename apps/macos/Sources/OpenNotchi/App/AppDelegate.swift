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
    private let privacy = PrivacyMonitor()
    private let downloads = DownloadsMonitor()
    private var lyricsOverlay: LyricsOverlayWindow?
    private(set) var nowPlayingScreen: NowPlayingScreenController?
    private var hudRetryTimer: Timer?
    private var hotKey: HotKey?
    private var cancellables: Set<AnyCancellable> = []

    private(set) var screenManager: NotchScreenManager!
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        screenManager = NotchScreenManager(
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
        setupStatusItem()
        updateHotKey()
        setupPeeks()
        updateSystemMonitors()
        updateLyricsOverlay()
        nowPlayingScreen = NowPlayingScreenController(media: media, lyrics: lyrics, settings: settings)
        updateAI()

        if CommandLine.arguments.contains("--settings") || CommandLine.arguments.contains("-s") {
            showSettings()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        screenManager.toggle()
        return true
    }

    @objc private func screensChanged() {
        screenManager.reposition()
    }

    // MARK: - Shortcut

    /// Registers the user's toggle shortcut (⌥⌘N by default).
    func updateHotKey() {
        hotKey = settings.hotKeyEnabled
            ? HotKey(keyCode: settings.hotKeyCode, modifiers: settings.hotKeyModifiers) { [weak self] in self?.screenManager.toggle() }
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
                self.screenManager.showPeek(.charging(level: self.battery.level))
            }
            .store(in: &cancellables)

        bluetooth.onConnect = { [weak self] name, symbol, battery, info in
            self?.screenManager.showPeek(.device(name: name, symbol: symbol, battery: battery, info: info))
        }

        reminders.onBanner = { [weak self] banner in
            self?.screenManager.showPeek(.banner(banner))
        }

        updater.onUpdateBanner = { [weak self] banner in
            self?.screenManager.showPeek(.banner(banner))
        }

        privacy.onStart = { [weak self] camera, mic in
            self?.screenManager.showPeek(.privacy(camera: camera, mic: mic))
        }

        CIBuildMonitor.shared.onBanner = { [weak self] banner in
            self?.screenManager.showPeek(.banner(banner))
        }
        CIBuildMonitor.shared.startMonitoring()

        downloads.onFinish = { [weak self] url in
            self?.screenManager.showPeek(.banner(Banner(
                icon: "arrow.down.circle.fill",
                tint: .blue,
                badge: "Done",
                title: url.lastPathComponent,
                subtitle: "Downloaded",
                actionTitle: "Open",
                actionURL: url,
                kind: .success
            )))
        }

        mediaKeys.handler = { [weak self] key in
            self?.handleMediaKey(key) ?? false
        }
    }

    /// Starts or stops the Bluetooth and media key monitors to match Settings.
    func updateSystemMonitors() {
        settings.devicePeekEnabled ? bluetooth.start() : bluetooth.stop()
        settings.privacyPeekEnabled ? privacy.start() : privacy.stop()
        settings.downloadPeekEnabled ? downloads.start() : downloads.stop()

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

    /// Starts or stops agent polling, the hook listener and usage scans to match Settings › AI.
    func updateAI() {
        let accounts = settings.aiAccounts
        AgentMonitor.shared.onPeek = { [weak self] banner in self?.screenManager.showPeek(.banner(banner)) }
        AgentMonitor.shared.configure(enabled: settings.aiEnabled && settings.aiAgents, accounts: accounts)
        AIUsageManager.shared.configure(enabled: settings.aiEnabled, accounts: accounts)
    }

    /// Shows or hides the floating desktop lyrics widget to match Settings.
    func updateLyricsOverlay() {
        if settings.lyricsOverlayEnabled {
            if lyricsOverlay == nil { lyricsOverlay = LyricsOverlayWindow(media: media, lyrics: lyrics, settings: settings) }
            lyricsOverlay?.orderFrontRegardless()
        } else {
            lyricsOverlay?.orderOut(nil)
        }
    }

    /// Brings a lost or tiny widget back to its default size and spot.
    func resetLyricsOverlay() {
        settings.lyricsOverlayLocked = false
        settings.lyricsOverlayEnabled = true
        lyricsOverlay?.resetPosition()
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
            screenManager.showPeek(.volume(level: volume, muted: SystemAudio.isMuted))
        case .mute:
            SystemAudio.isMuted.toggle()
            screenManager.showPeek(.volume(level: SystemAudio.volume ?? 0, muted: SystemAudio.isMuted))
        case .brightnessUp, .brightnessDown:
            guard var level = DisplayBrightness.level else { return false }
            level = (level + (key == .brightnessUp ? step : -step)).clamped(to: 0...1)
            DisplayBrightness.level = level
            screenManager.showPeek(.brightness(level: level))
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
                    .environmentObject(lyrics)
                    .environmentObject(AgentMonitor.shared)
                    .environmentObject(AIUsageManager.shared)
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

    /// Opens the notch so theme and animation changes in Settings are visible right away.
    func previewNotch() {
        screenManager.previewAnimation()
    }

    @objc private func toggleNotch() {
        screenManager.toggle()
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
