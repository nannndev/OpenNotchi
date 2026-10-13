import Foundation
import ServiceManagement
import SwiftUI

enum NotchAnimationStyle: String, CaseIterable, Identifiable {
    case fluid = "fluid"         // Fluid & Natural (Default)
    case bouncy = "bouncy"       // Bouncy Island (Playful spring)
    case waterfall = "waterfall" // Waterfall Slide (Drops down)
    case snappy = "snappy"       // Snappy Pro (Ultra fast)
    case pop = "pop"             // Elastic Pop (Magnetic punch)
    case gentle = "gentle"       // Gentle Float (Cinematic & soft)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fluid: return "Fluid Classic"
        case .bouncy: return "Bouncy Island"
        case .waterfall: return "Waterfall Drop"
        case .snappy: return "Snappy Pro"
        case .pop: return "Elastic Pop"
        case .gentle: return "Gentle Float"
        }
    }

    var subtitle: String {
        switch self {
        case .fluid: return "Halus, natural & seimbang (standar macOS)"
        case .bouncy: return "Elastis & membal seperti Dynamic Island"
        case .waterfall: return "Meluncur turun dari balik kamera notch"
        case .snappy: return "Sangat responsif tanpa jeda untuk produktivitas"
        case .pop: return "Penuh energi dengan hentakan skala magnetik"
        case .gentle: return "Gerakan mengambang lembut & sinematik"
        }
    }

    var icon: String {
        switch self {
        case .fluid: return "waveform.path"
        case .bouncy: return "arrow.up.and.down.and.sparkles"
        case .waterfall: return "arrow.down.to.line.compact"
        case .snappy: return "bolt.fill"
        case .pop: return "circle.circle.fill"
        case .gentle: return "wind"
        }
    }

    var springAnimation: Animation {
        switch self {
        case .fluid:
            return .spring(response: 0.36, dampingFraction: 0.82)
        case .bouncy:
            return .spring(response: 0.46, dampingFraction: 0.52)
        case .waterfall:
            return .spring(response: 0.40, dampingFraction: 0.78)
        case .snappy:
            return .spring(response: 0.16, dampingFraction: 0.98)
        case .pop:
            return .spring(response: 0.50, dampingFraction: 0.46)
        case .gentle:
            return .spring(response: 0.68, dampingFraction: 0.88)
        }
    }

    var contentTransition: AnyTransition {
        switch self {
        case .fluid:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
            )
        case .bouncy:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.76, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.88, anchor: .top))
            )
        case .waterfall:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(y: -65)),
                removal: .opacity.combined(with: .offset(y: -45))
            )
        case .snappy:
            return .opacity
        case .pop:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.58, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.80, anchor: .top))
            )
        case .gentle:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                removal: .opacity
            )
        }
    }
}

enum PlayerArtworkStyle: String, CaseIterable, Identifiable {
    case vinylDisc = "vinylDisc"               // Full spinning vinyl record
    case vinylCoverCenter = "vinylCoverCenter" // Album cover framed in center of spinning vinyl
    case vinylSleeve = "vinylSleeve"           // Classic vinyl sliding out of its jacket
    case standard = "standard"                 // Modern square album art

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vinylDisc: return "Vinyl Only (Turntable)"
        case .vinylCoverCenter: return "Cover di Tengah Vinyl (Halo)"
        case .vinylSleeve: return "Vinyl Sleeve (Slide-out)"
        case .standard: return "Standard Cover (Kotak)"
        }
    }

    var icon: String {
        switch self {
        case .vinylDisc: return "opticaldisc"
        case .vinylCoverCenter: return "record.circle.fill"
        case .vinylSleeve: return "rectangle.stack.fill"
        case .standard: return "square.fill"
        }
    }
}

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
    @Published var spotifyRemoteEnabled: Bool { didSet { defaults.set(spotifyRemoteEnabled, forKey: "spotifyRemoteEnabled") } }
    @Published var spotifyClientID: String { didSet { defaults.set(spotifyClientID, forKey: "spotifyClientID") } }
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
    @Published var openAnimation: NotchAnimationStyle {
        didSet {
            defaults.set(openAnimation.rawValue, forKey: "openAnimation")
            AppDelegate.shared?.previewNotch()
        }
    }
    @Published var lyricsEnabled: Bool { didSet { defaults.set(lyricsEnabled, forKey: "lyricsEnabled") } }
    /// Home shows lyrics instead of the player (toggled from the artwork button).
    @Published var homeLyricsMode: Bool { didSet { defaults.set(homeLyricsMode, forKey: "homeLyricsMode") } }
    @Published var lyricsOnHome: Bool { didSet { defaults.set(lyricsOnHome, forKey: "lyricsOnHome") } }
    @Published var artworkStyle: PlayerArtworkStyle {
        didSet {
            defaults.set(artworkStyle.rawValue, forKey: "artworkStyle")
            vinylModeEnabled = (artworkStyle != .standard)
        }
    }
    @Published var vinylModeEnabled: Bool { didSet { defaults.set(vinylModeEnabled, forKey: "vinylModeEnabled") } }
    @Published var ambientAuraEnabled: Bool { didSet { defaults.set(ambientAuraEnabled, forKey: "ambientAuraEnabled") } }
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
    @Published var marketsEnabled: Bool { didSet { defaults.set(marketsEnabled, forKey: "marketsEnabled") } }
    @Published var showTickerInHeader: Bool { didSet { defaults.set(showTickerInHeader, forKey: "showTickerInHeader") } }
    @Published var networkLiveActivity: Bool { didSet { defaults.set(networkLiveActivity, forKey: "networkLiveActivity") } }
    @Published var showStatsInHeader: Bool { didSet { defaults.set(showStatsInHeader, forKey: "showStatsInHeader") } }
    @Published var marketTickers: [String] { didSet { defaults.set(marketTickers, forKey: "marketTickers") } }
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
    @Published var devToolsEnabled: Bool { didSet { defaults.set(devToolsEnabled, forKey: "devToolsEnabled") } }
    /// Height of the open notch on the Mirror tab, set by dragging its bottom edge.
    @Published var mirrorHeight: Double { didSet { defaults.set(mirrorHeight, forKey: "mirrorHeight") } }
    @Published var mirrorEffect: MirrorEffect { didSet { defaults.set(mirrorEffect.rawValue, forKey: "mirrorEffect") } }
    @Published var mirrorRingLight: Bool { didSet { defaults.set(mirrorRingLight, forKey: "mirrorRingLight") } }
    @Published var mirrorBackground: MirrorBackground { didSet { defaults.set(mirrorBackground.rawValue, forKey: "mirrorBackground") } }
    /// Text on photobox strips; empty uses each style's own title.
    @Published var stripCaption: String { didSet { defaults.set(stripCaption, forKey: "stripCaption") } }
    @Published var stripShots: Int { didSet { defaults.set(stripShots, forKey: "stripShots") } }
    @Published var stripFormat: StripFormat { didSet { defaults.set(stripFormat.rawValue, forKey: "stripFormat") } }
    @Published var mirrorStaysOpen: Bool { didSet { defaults.set(mirrorStaysOpen, forKey: "mirrorStaysOpen") } }
    @Published var stripStyle: StripStyle { didSet { defaults.set(stripStyle.rawValue, forKey: "stripStyle") } }
    @Published var mirrorGestures: Bool { didSet { defaults.set(mirrorGestures, forKey: "mirrorGestures") } }
    @Published var mirrorCameraID: String { didSet { defaults.set(mirrorCameraID, forKey: "mirrorCameraID") } }
    @Published var calendarEnabled: Bool { didSet { defaults.set(calendarEnabled, forKey: "calendarEnabled") } }
    /// Minutes before a calendar event to show the reminder; 0 turns it off.
    @Published var meetingReminderMinutes: Int { didSet { defaults.set(meetingReminderMinutes, forKey: "meetingReminderMinutes") } }
    @Published var meetingRemindersOnlyWithLink: Bool { didSet { defaults.set(meetingRemindersOnlyWithLink, forKey: "meetingRemindersOnlyWithLink") } }
    @Published var reminderSound: Bool { didSet { defaults.set(reminderSound, forKey: "reminderSound") } }
    @Published var prayerEnabled: Bool { didSet { defaults.set(prayerEnabled, forKey: "prayerEnabled") } }
    @Published var prayerMethod: PrayerMethod { didSet { defaults.set(prayerMethod.rawValue, forKey: "prayerMethod") } }
    @Published var hanafiAsr: Bool { didSet { defaults.set(hanafiAsr, forKey: "hanafiAsr") } }
    @Published var prayerIndonesianNames: Bool { didSet { defaults.set(prayerIndonesianNames, forKey: "prayerIndonesianNames") } }
    @Published var prayerNotify: Bool { didSet { defaults.set(prayerNotify, forKey: "prayerNotify") } }
    /// Extra heads-up this many minutes before each prayer; 0 turns it off.
    @Published var prayerReminderMinutes: Int { didSet { defaults.set(prayerReminderMinutes, forKey: "prayerReminderMinutes") } }

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
            "spotifyRemoteEnabled": true,
            "spotifyClientID": "",
            "videoPreviewEnabled": true,
            "hotKeyEnabled": true,
            "chargingPeekEnabled": true,
            "devicePeekEnabled": true,
            "hudEnabled": false,
            "weatherEnabled": true,
            "marketsEnabled": false,
            "showTickerInHeader": true,
            "networkLiveActivity": true,
            "showStatsInHeader": true,
            "marketTickers": ["^JKSE", "BBCA.JK", "^GSPC", "AAPL", "BTC-USD", "IDR=X"],
            "useFahrenheit": Locale.current.measurementSystem == .us,
            "weatherPlace": "",
            "hotKeyCode": 45,       // kVK_ANSI_N
            "hotKeyModifiers": 2304, // cmdKey | optionKey
            "hotKeyDisplay": "⌥⌘N",
            "borderStyle": BorderStyle.none.rawValue,
            "borderWidth": 1.5,
            "cornerRadius": 30.0,
            "openAnimation": NotchAnimationStyle.fluid.rawValue,
            "lyricsEnabled": true,
            "lyricsOnHome": true,
            "homeLyricsMode": false,
            "artworkStyle": PlayerArtworkStyle.vinylDisc.rawValue,
            "vinylModeEnabled": true,
            "ambientAuraEnabled": true,
            "theme": NotchTheme.defaultTheme.rawValue,
            "accent": AccentChoice.white.rawValue,
            "clipboardEnabled": true,
            "timerTabEnabled": false,
            "mirrorTabEnabled": false,
            "devToolsEnabled": true,
            "calendarEnabled": true,
            "mirrorHeight": 200.0,
            "mirrorEffect": MirrorEffect.natural.rawValue,
            "mirrorRingLight": false,
            "mirrorCameraID": "",
            "mirrorBackground": MirrorBackground.none.rawValue,
            "stripStyle": StripStyle.classic.rawValue,
            "stripCaption": "",
            "mirrorStaysOpen": true,
            "stripShots": 4,
            "stripFormat": StripFormat.strip.rawValue,
            "mirrorGestures": true,
            "meetingReminderMinutes": 5,
            "meetingRemindersOnlyWithLink": false,
            "reminderSound": false,
            "prayerEnabled": Locale.current.region?.identifier == "ID",
            "prayerMethod": PrayerMethod.regionalDefault.rawValue,
            "hanafiAsr": false,
            "prayerIndonesianNames": Locale.current.region?.identifier == "ID" || Locale.current.language.languageCode?.identifier == "id",
            "prayerNotify": true,
            "prayerReminderMinutes": 0,
        ])
        hoverDelay = defaults.double(forKey: "hoverDelay")
        hapticsEnabled = defaults.bool(forKey: "hapticsEnabled")
        showLiveActivity = defaults.bool(forKey: "showLiveActivity")
        showMenuBarIcon = defaults.bool(forKey: "showMenuBarIcon")
        spotifyEnabled = defaults.bool(forKey: "spotifyEnabled")
        appleMusicEnabled = defaults.bool(forKey: "appleMusicEnabled")
        youtubeEnabled = defaults.bool(forKey: "youtubeEnabled")
        spotifyRemoteEnabled = defaults.bool(forKey: "spotifyRemoteEnabled")
        spotifyClientID = defaults.string(forKey: "spotifyClientID") ?? ""
        videoPreviewEnabled = defaults.bool(forKey: "videoPreviewEnabled")
        hotKeyEnabled = defaults.bool(forKey: "hotKeyEnabled")
        chargingPeekEnabled = defaults.bool(forKey: "chargingPeekEnabled")
        devicePeekEnabled = defaults.bool(forKey: "devicePeekEnabled")
        hudEnabled = defaults.bool(forKey: "hudEnabled")
        weatherEnabled = defaults.bool(forKey: "weatherEnabled")
        marketsEnabled = defaults.bool(forKey: "marketsEnabled")
        showTickerInHeader = defaults.bool(forKey: "showTickerInHeader")
        networkLiveActivity = defaults.bool(forKey: "networkLiveActivity")
        showStatsInHeader = defaults.bool(forKey: "showStatsInHeader")
        marketTickers = defaults.stringArray(forKey: "marketTickers") ?? []
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
        openAnimation = NotchAnimationStyle(rawValue: defaults.string(forKey: "openAnimation") ?? "") ?? .fluid
        lyricsEnabled = defaults.bool(forKey: "lyricsEnabled")
        lyricsOnHome = defaults.bool(forKey: "lyricsOnHome")
        homeLyricsMode = defaults.bool(forKey: "homeLyricsMode")
        if let rawStyle = defaults.string(forKey: "artworkStyle"), let style = PlayerArtworkStyle(rawValue: rawStyle) {
            artworkStyle = style
        } else {
            artworkStyle = defaults.bool(forKey: "vinylModeEnabled") ? .vinylDisc : .standard
        }
        vinylModeEnabled = defaults.bool(forKey: "vinylModeEnabled")
        ambientAuraEnabled = defaults.bool(forKey: "ambientAuraEnabled")
        theme = NotchTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? NotchTheme.defaultTheme
        accent = AccentChoice(rawValue: defaults.string(forKey: "accent") ?? "") ?? .white
        clipboardEnabled = defaults.bool(forKey: "clipboardEnabled")
        timerTabEnabled = defaults.bool(forKey: "timerTabEnabled")
        mirrorTabEnabled = defaults.bool(forKey: "mirrorTabEnabled")
        devToolsEnabled = defaults.bool(forKey: "devToolsEnabled")
        calendarEnabled = defaults.bool(forKey: "calendarEnabled")
        mirrorHeight = defaults.double(forKey: "mirrorHeight")
        mirrorEffect = MirrorEffect(rawValue: defaults.string(forKey: "mirrorEffect") ?? "") ?? .natural
        mirrorRingLight = defaults.bool(forKey: "mirrorRingLight")
        mirrorCameraID = defaults.string(forKey: "mirrorCameraID") ?? ""
        mirrorBackground = MirrorBackground(rawValue: defaults.string(forKey: "mirrorBackground") ?? "") ?? .none
        stripStyle = StripStyle(rawValue: defaults.string(forKey: "stripStyle") ?? "") ?? .classic
        stripCaption = defaults.string(forKey: "stripCaption") ?? ""
        mirrorStaysOpen = defaults.bool(forKey: "mirrorStaysOpen")
        stripShots = StripShots.choices.contains(defaults.integer(forKey: "stripShots")) ? defaults.integer(forKey: "stripShots") : 4
        stripFormat = StripFormat(rawValue: defaults.string(forKey: "stripFormat") ?? "") ?? .strip
        mirrorGestures = defaults.bool(forKey: "mirrorGestures")
        meetingReminderMinutes = defaults.integer(forKey: "meetingReminderMinutes")
        meetingRemindersOnlyWithLink = defaults.bool(forKey: "meetingRemindersOnlyWithLink")
        reminderSound = defaults.bool(forKey: "reminderSound")
        prayerEnabled = defaults.bool(forKey: "prayerEnabled")
        prayerMethod = PrayerMethod(rawValue: defaults.string(forKey: "prayerMethod") ?? "") ?? .regionalDefault
        hanafiAsr = defaults.bool(forKey: "hanafiAsr")
        prayerIndonesianNames = defaults.bool(forKey: "prayerIndonesianNames")
        prayerNotify = defaults.bool(forKey: "prayerNotify")
        prayerReminderMinutes = defaults.integer(forKey: "prayerReminderMinutes")
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
            case .markets: return marketsEnabled
            case .dev: return devToolsEnabled
            }
        }
    }

    func isProviderEnabled(_ bundleID: String) -> Bool {
        switch bundleID {
        case SpotifyProvider.bundleID: return spotifyEnabled
        case AppleMusicProvider.bundleID: return appleMusicEnabled
        case SpotifyWebProvider.providerID: return spotifyRemoteEnabled
        default: return youtubeEnabled // browser YouTube providers
        }
    }
}
