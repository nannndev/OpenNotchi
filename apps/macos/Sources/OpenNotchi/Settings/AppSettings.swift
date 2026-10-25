import ServiceManagement
import SwiftUI

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var hoverDelay: Double { didSet { defaults.set(hoverDelay, forKey: "hoverDelay") } }
    @Published var displayTarget: DisplayTarget {
        didSet {
            defaults.set(displayTarget.rawValue, forKey: "displayTarget")
            AppDelegate.shared?.screenManager.updateScreens()
        }
    }
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
    /// Notchi, the mascot, beside the closed notch when nothing else is showing.
    @Published var showMascot: Bool { didSet { defaults.set(showMascot, forKey: "showMascot") } }
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
    @Published var smarthomeEnabled: Bool { didSet { defaults.set(smarthomeEnabled, forKey: "smarthomeEnabled") } }
    @Published var notesTabEnabled: Bool { didSet { defaults.set(notesTabEnabled, forKey: "notesTabEnabled") } }
    @Published var notesText: String { didSet { defaults.set(notesText, forKey: "notesText") } }
    @Published var lyricsOverlayEnabled: Bool {
        didSet {
            defaults.set(lyricsOverlayEnabled, forKey: "lyricsOverlayEnabled")
            AppDelegate.shared?.updateLyricsOverlay()
        }
    }
    /// Desktop lyrics widget: background opacity (0 = text only) and click-through lock.
    @Published var lyricsOverlayOpacity: Double { didSet { defaults.set(lyricsOverlayOpacity, forKey: "lyricsOverlayOpacity") } }
    @Published var lyricsOverlayLocked: Bool { didSet { defaults.set(lyricsOverlayLocked, forKey: "lyricsOverlayLocked") } }
    /// Full-screen now playing after the Mac sits idle while music plays.
    @Published var nowPlayingScreenEnabled: Bool { didSet { defaults.set(nowPlayingScreenEnabled, forKey: "nowPlayingScreenEnabled") } }
    @Published var nowPlayingScreenIdleMinutes: Double { didSet { defaults.set(nowPlayingScreenIdleMinutes, forKey: "nowPlayingScreenIdleMinutes") } }
    @Published var nowPlayingScreenLyrics: Bool { didSet { defaults.set(nowPlayingScreenLyrics, forKey: "nowPlayingScreenLyrics") } }
    @Published var nowPlayingScreenClock: Bool { didSet { defaults.set(nowPlayingScreenClock, forKey: "nowPlayingScreenClock") } }
    @Published var nowPlayingScreenBackground: NowPlayingBackground { didSet { defaults.set(nowPlayingScreenBackground.rawValue, forKey: "nowPlayingScreenBackground") } }
    /// Lyrics text scale, 0.8 (small) to 1.3 (large).
    @Published var nowPlayingScreenTextScale: Double { didSet { defaults.set(nowPlayingScreenTextScale, forKey: "nowPlayingScreenTextScale") } }
    /// Show automatically only on power, so a battery Mac isn't kept awake.
    @Published var nowPlayingScreenOnlyCharging: Bool { didSet { defaults.set(nowPlayingScreenOnlyCharging, forKey: "nowPlayingScreenOnlyCharging") } }
    /// Screen to use: "main" or an NSScreen localizedName.
    @Published var nowPlayingScreenDisplay: String { didSet { defaults.set(nowPlayingScreenDisplay, forKey: "nowPlayingScreenDisplay") } }
    @Published var lyricsOverlayNextLine: Bool { didSet { defaults.set(lyricsOverlayNextLine, forKey: "lyricsOverlayNextLine") } }
    @Published var lyricsTranslate: Bool {
        didSet {
            defaults.set(lyricsTranslate, forKey: "lyricsTranslate")
            AppDelegate.shared?.lyrics.translateIfNeeded()
        }
    }
    /// Language code lyrics are translated into, e.g. "id".
    @Published var lyricsTranslateTarget: String {
        didSet {
            defaults.set(lyricsTranslateTarget, forKey: "lyricsTranslateTarget")
            AppDelegate.shared?.lyrics.translateIfNeeded()
        }
    }
    @Published var privacyPeekEnabled: Bool {
        didSet {
            defaults.set(privacyPeekEnabled, forKey: "privacyPeekEnabled")
            AppDelegate.shared?.updateSystemMonitors()
        }
    }
    @Published var downloadPeekEnabled: Bool {
        didSet {
            defaults.set(downloadPeekEnabled, forKey: "downloadPeekEnabled")
            AppDelegate.shared?.updateSystemMonitors()
        }
    }
    @Published var smarthomeProvider: SmarthomeProviderType { didSet { defaults.set(smarthomeProvider.rawValue, forKey: "smarthomeProvider") } }
    @Published var homeAssistantURL: String { didSet { defaults.set(homeAssistantURL, forKey: "homeAssistantURL") } }
    @Published var homeAssistantToken: String { didSet { defaults.set(homeAssistantToken, forKey: "homeAssistantToken") } }
    @Published var prompterTabEnabled: Bool { didSet { defaults.set(prompterTabEnabled, forKey: "prompterTabEnabled") } }
    @Published var prompterHeight: Double { didSet { defaults.set(prompterHeight, forKey: "prompterHeight") } }
    @Published var prompterStaysOpen: Bool { didSet { defaults.set(prompterStaysOpen, forKey: "prompterStaysOpen") } }
    @Published var prompterScrollSpeed: Double { didSet { defaults.set(prompterScrollSpeed, forKey: "prompterScrollSpeed") } }
    @Published var prompterFontSize: Double { didSet { defaults.set(prompterFontSize, forKey: "prompterFontSize") } }
    @Published var prompterOpacity: Double { didSet { defaults.set(prompterOpacity, forKey: "prompterOpacity") } }
    @Published var prompterShowCameraPreview: Bool { didSet { defaults.set(prompterShowCameraPreview, forKey: "prompterShowCameraPreview") } }
    @Published var prompterMirrorText: Bool { didSet { defaults.set(prompterMirrorText, forKey: "prompterMirrorText") } }
    @Published var prompterScript: String { didSet { defaults.set(prompterScript, forKey: "prompterScript") } }
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
    @Published var audioDeckEnabled: Bool { didSet { defaults.set(audioDeckEnabled, forKey: "audioDeckEnabled") } }
    @Published var audioDeckStyle: AudioDeckStyle { didSet { defaults.set(audioDeckStyle.rawValue, forKey: "audioDeckStyle") } }
    /// Minutes before a calendar event to show the reminder; 0 turns it off.
    @Published var meetingReminderMinutes: Int { didSet { defaults.set(meetingReminderMinutes, forKey: "meetingReminderMinutes") } }
    @Published var meetingRemindersOnlyWithLink: Bool { didSet { defaults.set(meetingRemindersOnlyWithLink, forKey: "meetingRemindersOnlyWithLink") } }
    @Published var reminderSound: Bool { didSet { defaults.set(reminderSound, forKey: "reminderSound") } }
    /// Sounds for important banners: an agent finishing or needing you, a download, a meeting or prayer.
    @Published var notificationSounds: Bool { didSet { defaults.set(notificationSounds, forKey: "notificationSounds") } }
    @Published var prayerEnabled: Bool { didSet { defaults.set(prayerEnabled, forKey: "prayerEnabled") } }
    @Published var prayerMethod: PrayerMethod { didSet { defaults.set(prayerMethod.rawValue, forKey: "prayerMethod") } }
    @Published var hanafiAsr: Bool { didSet { defaults.set(hanafiAsr, forKey: "hanafiAsr") } }
    @Published var prayerIndonesianNames: Bool { didSet { defaults.set(prayerIndonesianNames, forKey: "prayerIndonesianNames") } }
    @Published var prayerNotify: Bool { didSet { defaults.set(prayerNotify, forKey: "prayerNotify") } }
    /// Extra heads-up this many minutes before each prayer; 0 turns it off.
    @Published var prayerReminderMinutes: Int { didSet { defaults.set(prayerReminderMinutes, forKey: "prayerReminderMinutes") } }

    // AI (all off until "Enable AI features"; API keys live in the Keychain, never here)
    @Published var aiEnabled: Bool {
        didSet {
            defaults.set(aiEnabled, forKey: "aiEnabled")
            // First enable: add the default accounts whose folders exist.
            if aiEnabled && aiAccounts.isEmpty { aiAccounts = AIAccount.defaults }
            AppDelegate.shared?.updateAI()
        }
    }
    @Published var aiAgents: Bool { didSet { defaults.set(aiAgents, forKey: "aiAgents"); AppDelegate.shared?.updateAI() } }
    /// Peek when an agent finishes or needs you.
    @Published var aiNotify: Bool { didSet { defaults.set(aiNotify, forKey: "aiNotify") } }
    @Published var aiAccounts: [AIAccount] {
        didSet {
            defaults.set(try? JSONEncoder().encode(aiAccounts), forKey: "aiAccounts")
            AppDelegate.shared?.updateAI()
        }
    }
    @Published var aiClosedMeter: Bool { didSet { defaults.set(aiClosedMeter, forKey: "aiClosedMeter") } }
    @Published var aiProvider: AIProvider { didSet { defaults.set(aiProvider.rawValue, forKey: "aiProvider") } }
    @Published var aiOllamaURL: String { didSet { defaults.set(aiOllamaURL, forKey: "aiOllamaURL") } }
    @Published var aiOllamaModel: String { didSet { defaults.set(aiOllamaModel, forKey: "aiOllamaModel") } }
    @Published var aiAnthropicModel: String { didSet { defaults.set(aiAnthropicModel, forKey: "aiAnthropicModel") } }
    @Published var aiOpenaiURL: String { didSet { defaults.set(aiOpenaiURL, forKey: "aiOpenaiURL") } }
    @Published var aiOpenaiModel: String { didSet { defaults.set(aiOpenaiModel, forKey: "aiOpenaiModel") } }
    /// Empty means "pick a Haiku/Sonnet model automatically".
    @Published var aiNineRouterModel: String { didSet { defaults.set(aiNineRouterModel, forKey: "aiNineRouterModel") } }

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
            "displayTarget": DisplayTarget.builtIn.rawValue,
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
            "showMascot": true,
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
            "notesTabEnabled": true,
            "notesText": "",
            "lyricsOverlayEnabled": false,
            "nowPlayingScreenEnabled": true,
            "nowPlayingScreenIdleMinutes": 2.0,
            "nowPlayingScreenLyrics": true,
            "nowPlayingScreenClock": true,
            "nowPlayingScreenBackground": "blur",
            "nowPlayingScreenTextScale": 1.0,
            "nowPlayingScreenOnlyCharging": false,
            "nowPlayingScreenDisplay": "main",
            "lyricsOverlayOpacity": 0.45,
            "lyricsOverlayLocked": false,
            "lyricsOverlayNextLine": true,
            "lyricsTranslate": false,
            "lyricsTranslateTarget": "id",
            "privacyPeekEnabled": true,
            "downloadPeekEnabled": true,
            "smarthomeEnabled": true,
            "smarthomeProvider": SmarthomeProviderType.demo.rawValue,
            "homeAssistantURL": "http://homeassistant.local:8123",
            "homeAssistantToken": "",
            "calendarEnabled": true,
            "audioDeckEnabled": true,
            "audioDeckStyle": AudioDeckStyle.vuMeter.rawValue,
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
            "notificationSounds": true,
            "prayerEnabled": Locale.current.region?.identifier == "ID",
            "prayerMethod": PrayerMethod.regionalDefault.rawValue,
            "hanafiAsr": false,
            "prayerIndonesianNames": Locale.current.region?.identifier == "ID" || Locale.current.language.languageCode?.identifier == "id",
            "prayerNotify": true,
            "prayerReminderMinutes": 0,
            "prompterTabEnabled": true,
            "aiEnabled": true,
            "aiAgents": true,
            "aiNotify": true,
            "aiClosedMeter": false,
            "aiOllamaURL": "http://127.0.0.1:11434",
            "aiOllamaModel": "llama3.2",
            "aiAnthropicModel": "claude-haiku-5-5",
            "aiOpenaiURL": "https://api.openai.com/v1",
            "aiOpenaiModel": "gpt-4o-mini",
            "prompterHeight": 320.0,
            "prompterStaysOpen": true,
            "prompterScrollSpeed": 28.0,
            "prompterFontSize": 18.0,
            "prompterOpacity": 0.88,
            "prompterShowCameraPreview": false,
            "prompterMirrorText": false,
            "prompterScript": """
            Hello everyone! Welcome to today's meeting.

            [Look right at this camera line — your gaze is 100% natural]

            OpenNotchi transforms your MacBook notch into a living, intelligent dynamic hub.

            From spinning turntable vinyl decks with haptic grooves, to synced karaoke lyrics, developer tools, and this real-time eye-contact teleprompter — it turns unused screen space into your favorite daily companion.

            I'd love to walk you through our latest milestones today!
            """,
        ])
        hoverDelay = defaults.double(forKey: "hoverDelay")
        displayTarget = DisplayTarget(rawValue: defaults.string(forKey: "displayTarget") ?? "") ?? .builtIn
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
        showMascot = defaults.bool(forKey: "showMascot")
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
        notesTabEnabled = defaults.bool(forKey: "notesTabEnabled")
        notesText = defaults.string(forKey: "notesText") ?? ""
        lyricsOverlayEnabled = defaults.bool(forKey: "lyricsOverlayEnabled")
        nowPlayingScreenEnabled = defaults.bool(forKey: "nowPlayingScreenEnabled")
        nowPlayingScreenIdleMinutes = defaults.double(forKey: "nowPlayingScreenIdleMinutes")
        nowPlayingScreenLyrics = defaults.bool(forKey: "nowPlayingScreenLyrics")
        nowPlayingScreenClock = defaults.bool(forKey: "nowPlayingScreenClock")
        nowPlayingScreenBackground = NowPlayingBackground(rawValue: defaults.string(forKey: "nowPlayingScreenBackground") ?? "") ?? .blur
        nowPlayingScreenTextScale = defaults.double(forKey: "nowPlayingScreenTextScale")
        nowPlayingScreenOnlyCharging = defaults.bool(forKey: "nowPlayingScreenOnlyCharging")
        nowPlayingScreenDisplay = defaults.string(forKey: "nowPlayingScreenDisplay") ?? "main"
        lyricsOverlayOpacity = defaults.double(forKey: "lyricsOverlayOpacity")
        lyricsOverlayLocked = defaults.bool(forKey: "lyricsOverlayLocked")
        lyricsOverlayNextLine = defaults.bool(forKey: "lyricsOverlayNextLine")
        lyricsTranslate = defaults.bool(forKey: "lyricsTranslate")
        lyricsTranslateTarget = defaults.string(forKey: "lyricsTranslateTarget") ?? "id"
        privacyPeekEnabled = defaults.bool(forKey: "privacyPeekEnabled")
        downloadPeekEnabled = defaults.bool(forKey: "downloadPeekEnabled")
        smarthomeEnabled = defaults.object(forKey: "smarthomeEnabled") != nil ? defaults.bool(forKey: "smarthomeEnabled") : true
        smarthomeProvider = SmarthomeProviderType(rawValue: defaults.string(forKey: "smarthomeProvider") ?? "") ?? .demo
        homeAssistantURL = defaults.string(forKey: "homeAssistantURL") ?? "http://homeassistant.local:8123"
        homeAssistantToken = defaults.string(forKey: "homeAssistantToken") ?? ""
        calendarEnabled = defaults.bool(forKey: "calendarEnabled")
        audioDeckEnabled = defaults.bool(forKey: "audioDeckEnabled")
        audioDeckStyle = AudioDeckStyle(rawValue: defaults.string(forKey: "audioDeckStyle") ?? "") ?? .vuMeter
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
        notificationSounds = defaults.bool(forKey: "notificationSounds")
        prayerEnabled = defaults.bool(forKey: "prayerEnabled")
        prayerMethod = PrayerMethod(rawValue: defaults.string(forKey: "prayerMethod") ?? "") ?? .regionalDefault
        hanafiAsr = defaults.bool(forKey: "hanafiAsr")
        prayerIndonesianNames = defaults.bool(forKey: "prayerIndonesianNames")
        prayerNotify = defaults.bool(forKey: "prayerNotify")
        prayerReminderMinutes = defaults.integer(forKey: "prayerReminderMinutes")
        prompterTabEnabled = defaults.object(forKey: "prompterTabEnabled") != nil ? defaults.bool(forKey: "prompterTabEnabled") : true
        prompterHeight = defaults.double(forKey: "prompterHeight") > 0 ? defaults.double(forKey: "prompterHeight") : 320.0
        prompterStaysOpen = defaults.object(forKey: "prompterStaysOpen") != nil ? defaults.bool(forKey: "prompterStaysOpen") : true
        prompterScrollSpeed = defaults.double(forKey: "prompterScrollSpeed") > 0 ? defaults.double(forKey: "prompterScrollSpeed") : 28.0
        prompterFontSize = defaults.double(forKey: "prompterFontSize") > 0 ? defaults.double(forKey: "prompterFontSize") : 18.0
        prompterOpacity = defaults.double(forKey: "prompterOpacity") > 0 ? defaults.double(forKey: "prompterOpacity") : 0.88
        prompterShowCameraPreview = defaults.bool(forKey: "prompterShowCameraPreview")
        prompterMirrorText = defaults.bool(forKey: "prompterMirrorText")
        prompterScript = defaults.string(forKey: "prompterScript") ?? "Hello everyone! Welcome to today's meeting."
        aiEnabled = defaults.object(forKey: "aiEnabled") as? Bool ?? true
        aiAgents = defaults.object(forKey: "aiAgents") as? Bool ?? true
        aiNotify = defaults.object(forKey: "aiNotify") as? Bool ?? true
        let loadedAccounts = defaults.data(forKey: "aiAccounts").flatMap { try? JSONDecoder().decode([AIAccount].self, from: $0) } ?? []
        aiAccounts = loadedAccounts.isEmpty ? AIAccount.defaults : loadedAccounts
        aiClosedMeter = defaults.bool(forKey: "aiClosedMeter")
        // 9router is the default when installed (it uses the user's own accounts), then Apple Intelligence, then Ollama.
        aiProvider = AIProvider(rawValue: defaults.string(forKey: "aiProvider") ?? "").flatMap { AIProvider.available.contains($0) ? $0 : nil }
            ?? (NineRouterService.shared.isAvailable ? .ninerouter : AIAssistant.appleAvailable ? .apple : .ollama)
        aiOllamaURL = defaults.string(forKey: "aiOllamaURL") ?? ""
        aiOllamaModel = defaults.string(forKey: "aiOllamaModel") ?? ""
        aiAnthropicModel = defaults.string(forKey: "aiAnthropicModel") ?? "claude-haiku-5-5"
        aiOpenaiURL = defaults.string(forKey: "aiOpenaiURL") ?? ""
        aiOpenaiModel = defaults.string(forKey: "aiOpenaiModel") ?? ""
        aiNineRouterModel = defaults.string(forKey: "aiNineRouterModel") ?? ""
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
            case .prompter: return prompterTabEnabled
            case .clipboard: return clipboardEnabled
            case .timer: return timerTabEnabled
            case .mirror: return mirrorTabEnabled
            case .markets: return marketsEnabled
            case .dev: return devToolsEnabled
            case .notes: return notesTabEnabled
            case .smarthome: return smarthomeEnabled
            case .ai: return aiEnabled
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
