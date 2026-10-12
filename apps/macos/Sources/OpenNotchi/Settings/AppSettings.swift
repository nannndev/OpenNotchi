import Foundation
import ServiceManagement

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: "hoverDelay") } }
    @Published var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") } }
    @Published var showLiveActivity: Bool { didSet { defaults.set(showLiveActivity, forKey: "showLiveActivity") } }
    @Published var showMenuBarIcon: Bool {
        didSet {
            defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon")
            AppDelegate.shared?.setMenuBarIconVisible(showMenuBarIcon)
        }
    }
    @Published var spotifyEnabled: Bool { didSet { defaults.set(spotifyEnabled, forKey: "spotifyEnabled") } }
    @Published var appleMusicEnabled: Bool { didSet { defaults.set(appleMusicEnabled, forKey: "appleMusicEnabled") } }
    @Published var youtubeEnabled: Bool { didSet { defaults.set(youtubeEnabled, forKey: "youtubeEnabled") } }
    @Published var videoPreviewEnabled: Bool { didSet { defaults.set(videoPreviewEnabled, forKey: "videoPreviewEnabled") } }
    @Published var theme: NotchTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: "theme")
            AppDelegate.shared?.previewNotch()
        }
    }
    @Published var accent: AccentChoice {
        didSet {
            defaults.set(accent.rawValue, forKey: "accent")
            AppDelegate.shared?.previewNotch()
        }
    }
    @Published var borderStyle: BorderStyle { didSet { defaults.set(borderStyle.rawValue, forKey: "borderStyle"); AppDelegate.shared?.previewNotch() } }
    @Published var borderWidth: Double { didSet { defaults.set(borderWidth, forKey: "borderWidth"); AppDelegate.shared?.previewNotch() } }
    @Published var cornerRadius: Double { didSet { defaults.set(cornerRadius, forKey: "cornerRadius"); AppDelegate.shared?.previewNotch() } }
    @Published var lyricsEnabled: Bool { didSet { defaults.set(lyricsEnabled, forKey: "lyricsEnabled") } }
    /// Home shows lyrics instead of the player (toggled from the artwork button).
    @Published var homeLyricsMode: Bool { didSet { defaults.set(homeLyricsMode, forKey: "homeLyricsMode") } }
    @Published var lyricsOnHome: Bool { didSet { defaults.set(lyricsOnHome, forKey: "lyricsOnHome") } }
    @Published var chargingPeekEnabled: Bool { didSet { defaults.set(chargingPeekEnabled, forKey: "chargingPeekEnabled") } }
    @Published var devicePeekEnabled: Bool {
        didSet {
            defaults.set(devicePeekEnabled, forKey: "devicePeekEnabled")
            AppDelegate.shared?.updateSystemMonitors()
        }
    }
    @Published var hudEnabled: Bool {
        didSet {
            defaults.set(hudEnabled, forKey: "hudEnabled")
            AppDelegate.shared?.updateSystemMonitors()
        }
    }
    @Published var weatherEnabled: Bool { didSet { defaults.set(weatherEnabled, forKey: "weatherEnabled") } }
    @Published var useFahrenheit: Bool { didSet { defaults.set(useFahrenheit, forKey: "useFahrenheit") } }
    @Published private(set) var weatherPlace: String
    private(set) var weatherLatitude: Double
    private(set) var weatherLongitude: Double
    /// Carbon key code, Carbon modifier mask and display string of the toggle shortcut.
    @Published private(set) var hotKeyCode: Int
    @Published private(set) var hotKeyModifiers: Int
    @Published private(set) var hotKeyDisplay: String
    @Published var hotKeyEnabled: Bool {
        didSet {
            defaults.set(hotKeyEnabled, forKey: "hotKeyEnabled")
            AppDelegate.shared?.updateHotKey()
        }
    }
    @Published var clipboardEnabled: Bool { didSet { defaults.set(clipboardEnabled, forKey: "clipboardEnabled") } }
    @Published var timerTabEnabled: Bool { didSet { defaults.set(timerTabEnabled, forKey: "timerTabEnabled") } }
    @Published var mirrorTabEnabled: Bool { didSet { defaults.set(mirrorTabEnabled, forKey: "mirrorTabEnabled") } }
    @Published var calendarEnabled: Bool { didSet { defaults.set(calendarEnabled, forKey: "calendarEnabled") } }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("OpenNotchi: launch at login failed: \(error)")
            }
        }
    }

    private init() {
        defaults.register(defaults: [
            "hoverDelay": 0.15,
            "hapticsEnabled": true,
            "showLiveActivity": true,
            "showMenuBarIcon": true,
            "spotifyEnabled": true,
            "appleMusicEnabled": true,
            "youtubeEnabled": true,
            "videoPreviewEnabled": true,
            "hotKeyEnabled": true,
            "chargingPeekEnabled": true,
            "devicePeekEnabled": true,
            "hudEnabled": false,
            "weatherEnabled": true,
            "useFahrenheit": Locale.current.measurementSystem == .us,
            "weatherPlace": "",
            "hotKeyCode": 45,       // kVK_ANSI_N
            "hotKeyModifiers": 2304, // cmdKey | optionKey
            "hotKeyDisplay": "⌥⌘N",
            "borderStyle": BorderStyle.none.rawValue,
            "borderWidth": 1.5,
            "cornerRadius": 30.0,
            "lyricsEnabled": true,
            "lyricsOnHome": true,
            "homeLyricsMode": false,
            "theme": NotchTheme.defaultTheme.rawValue,
            "accent": AccentChoice.white.rawValue,
            "clipboardEnabled": true,
            "timerTabEnabled": true,
            "mirrorTabEnabled": true,
            "calendarEnabled": true,
        ])
        hoverDelay = defaults.double(forKey: "hoverDelay")
        hapticsEnabled = defaults.bool(forKey: "hapticsEnabled")
        showLiveActivity = defaults.bool(forKey: "showLiveActivity")
        showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        spotifyEnabled = defaults.bool(forKey: "spotifyEnabled")
        appleMusicEnabled = defaults.bool(forKey: "appleMusicEnabled")
        youtubeEnabled = defaults.bool(forKey: "youtubeEnabled")
        videoPreviewEnabled = defaults.bool(forKey: "videoPreviewEnabled")
        hotKeyEnabled = defaults.bool(forKey: "hotKeyEnabled")
        chargingPeekEnabled = defaults.bool(forKey: "chargingPeekEnabled")
        devicePeekEnabled = defaults.bool(forKey: "devicePeekEnabled")
        hudEnabled = defaults.bool(forKey: "hudEnabled")
        weatherEnabled = defaults.bool(forKey: "weatherEnabled")
        useFahrenheit = defaults.bool(forKey: "useFahrenheit")
        weatherPlace = defaults.string(forKey: "weatherPlace") ?? ""
        weatherLatitude = defaults.double(forKey: "weatherLatitude")
        weatherLongitude = defaults.double(forKey: "weatherLongitude")
        hotKeyCode = defaults.integer(forKey: "hotKeyCode")
        hotKeyModifiers = defaults.integer(forKey: "hotKeyModifiers")
        hotKeyDisplay = defaults.string(forKey: "hotKeyDisplay") ?? "⌥⌘N"
        borderStyle = BorderStyle(rawValue: defaults.string(forKey: "borderStyle") ?? "") ?? .none
        borderWidth = defaults.double(forKey: "borderWidth")
        cornerRadius = defaults.double(forKey: "cornerRadius")
        lyricsEnabled = defaults.bool(forKey: "lyricsEnabled")
        lyricsOnHome = defaults.bool(forKey: "lyricsOnHome")
        homeLyricsMode = defaults.bool(forKey: "homeLyricsMode")
        theme = NotchTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? NotchTheme.defaultTheme
        accent = AccentChoice(rawValue: defaults.string(forKey: "accent") ?? "") ?? .white
        clipboardEnabled = defaults.bool(forKey: "clipboardEnabled")
        timerTabEnabled = defaults.bool(forKey: "timerTabEnabled")
        mirrorTabEnabled = defaults.bool(forKey: "mirrorTabEnabled")
        calendarEnabled = defaults.bool(forKey: "calendarEnabled")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setWeatherPlace(name: String, latitude: Double, longitude: Double) {
        weatherLatitude = latitude
        weatherLongitude = longitude
        defaults.set(latitude, forKey: "weatherLatitude")
        defaults.set(longitude, forKey: "weatherLongitude")
        defaults.set(name, forKey: "weatherPlace")
        weatherPlace = name // published last so observers see the new coordinates
    }

    func setHotKey(code: Int, modifiers: Int, display: String) {
        hotKeyCode = code
        hotKeyModifiers = modifiers
        hotKeyDisplay = display
        defaults.set(code, forKey: "hotKeyCode")
        defaults.set(modifiers, forKey: "hotKeyModifiers")
        defaults.set(display, forKey: "hotKeyDisplay")
        AppDelegate.shared?.updateHotKey()
    }

    var visibleTabs: [NotchTab] {
        NotchTab.allCases.filter { tab in
            switch tab {
            case .home, .tray: return true
            case .clipboard: return clipboardEnabled
            case .timer: return timerTabEnabled
            case .mirror: return mirrorTabEnabled
            }
        }
    }

    func isProviderEnabled(_ bundleID: String) -> Bool {
        switch bundleID {
        case SpotifyProvider.bundleID: return spotifyEnabled
        case AppleMusicProvider.bundleID: return appleMusicEnabled
        default: return youtubeEnabled // browser YouTube providers
        }
    }
}
