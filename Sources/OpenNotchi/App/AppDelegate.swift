import AppKit
import Carbon.HIToolbox
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
    private var hotKey: HotKey?

    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?
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
            settings: settings
        )
        setupStatusItem()
        updateHotKey()

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

    /// ⌥⌘N toggles the notch.
    func updateHotKey() {
        hotKey = settings.hotKeyEnabled
            ? HotKey(keyCode: kVK_ANSI_N, modifiers: cmdKey | optionKey) { [weak self] in self?.notchController?.toggle() }
            : nil
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "OpenNotchi")

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle Notch  ⌥⌘N", action: #selector(toggleNotch), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
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

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
