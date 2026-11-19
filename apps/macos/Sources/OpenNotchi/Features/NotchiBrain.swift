import AppKit
import Foundation
import SwiftUI

/// What Ask AI knows about OpenNotchi, and the settings it may change for the user.
/// The model asks for changes with a ```notchi {...}``` block at the end of its answer; the app applies
/// them and shows each one with an Undo, so nothing changes silently.
@MainActor
enum NotchiBrain {
    struct Setting {
        let key: String
        let info: String
        /// Allowed values shown to the model, e.g. "true|false" or "aurora (Aurora)|midnight (Midnight)".
        let values: String
        let get: (AppSettings) -> String
        /// Returns false for a value outside the allowed set.
        let set: (AppSettings, String) -> Bool
    }

    struct Change: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let undo: String?
        let key: String
    }

    static func bool(_ key: String, _ kp: ReferenceWritableKeyPath<AppSettings, Bool>, _ info: String) -> Setting {
        Setting(key: key, info: info, values: "true|false", get: { String($0[keyPath: kp]) }, set: { s, v in
            guard let b = Bool(v.lowercased()) else { return false }
            s[keyPath: kp] = b
            return true
        })
    }

    static func number(_ key: String, _ kp: ReferenceWritableKeyPath<AppSettings, Double>, _ range: ClosedRange<Double>, _ info: String) -> Setting {
        Setting(key: key, info: info, values: "\(range.lowerBound)...\(range.upperBound)", get: { String($0[keyPath: kp]) }, set: { s, v in
            guard let d = Double(v), range.contains(d) else { return false }
            s[keyPath: kp] = d
            return true
        })
    }

    static func choice<E: RawRepresentable & CaseIterable>(_ key: String, _ kp: ReferenceWritableKeyPath<AppSettings, E>, _ info: String,
                                                           name: @escaping (E) -> String) -> Setting where E.RawValue == String {
        Setting(key: key, info: info, values: E.allCases.map { "\($0.rawValue) (\(name($0)))" }.joined(separator: "|"),
                get: { $0[keyPath: kp].rawValue }, set: { s, v in
                    guard let e = E(rawValue: v) ?? E.allCases.first(where: { name($0).lowercased() == v.lowercased() }) else { return false }
                    s[keyPath: kp] = e
                    return true
                })
    }

    static func hexColor(_ key: String, _ kp: ReferenceWritableKeyPath<AppSettings, String>, _ info: String) -> Setting {
        Setting(key: key, info: info, values: "#RRGGBB hex color",
                get: { $0[keyPath: kp] }, set: { s, v in
                    let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalized = trimmed.hasPrefix("#") ? trimmed : "#\(trimmed)"
                    guard normalized.count == 7, Color(hexString: normalized) != nil else { return false }
                    s[keyPath: kp] = normalized.uppercased()
                    return true
                })
    }

    static let settings: [Setting] = [
        choice("theme", \.theme, "Notch look (use 'custom' with customThemeTop/customThemeBottom hex colors for bespoke AI themes)", name: \.displayName),
        hexColor("customThemeTop", \.customThemeTopHex, "Top gradient #RRGGBB hex color when theme is custom"),
        hexColor("customThemeBottom", \.customThemeBottomHex, "Bottom gradient #RRGGBB hex color when theme is custom"),
        choice("accent", \.accent, "Accent color", name: \.displayName),
        choice("borderStyle", \.borderStyle, "Outline around the open notch", name: \.displayName),
        number("borderWidth", \.borderWidth, 0.5...4, "Outline width in points"),
        number("cornerRadius", \.cornerRadius, 12...48, "Corner radius of the open notch"),
        choice("openAnimation", \.openAnimation, "How the notch opens", name: \.displayName),
        number("hoverDelay", \.hoverDelay, 0...1, "Seconds of hover before the notch opens"),
        choice("displayTarget", \.displayTarget, "Which screens show the notch", name: \.displayName),
        choice("artworkStyle", \.artworkStyle, "Album art style in the player", name: \.displayName),
        choice("audioDeckStyle", \.audioDeckStyle, "Audio visualizer style", name: \.displayName),
        choice("mirrorEffect", \.mirrorEffect, "Camera filter in Mirror", name: \.displayName),
        choice("mirrorBackground", \.mirrorBackground, "Mirror background", name: \.displayName),
        choice("prayerMethod", \.prayerMethod, "Prayer time calculation method", name: \.displayName),
        bool("haptics", \.hapticsEnabled, "Trackpad haptics when the notch opens"),
        bool("liveActivity", \.showLiveActivity, "Show now playing / activity in the closed notch"),
        bool("menuBarIcon", \.showMenuBarIcon, "Menu bar icon"),
        bool("spotify", \.spotifyEnabled, "Spotify playback source"),
        bool("appleMusic", \.appleMusicEnabled, "Apple Music playback source"),
        bool("youtube", \.youtubeEnabled, "YouTube in the browser as a playback source"),
        bool("videoPreview", \.videoPreviewEnabled, "Video thumbnail preview for YouTube"),
        bool("lyrics", \.lyricsEnabled, "Synced lyrics"),
        bool("lyricsOverlay", \.lyricsOverlayEnabled, "Floating desktop lyrics window"),
        bool("lyricsCodeMode", \.lyricsCodeMode, "Source code live-typing style for lyrics"),
        bool("lyricsCodeWorkspace", \.lyricsCodeWorkspace, "Dedicated full-screen IDE Workspace layout for code lyrics"),
        choice("lyricsAnimation", \.lyricsAnimation, "Lyrics animation style (overlay & full-screen)", name: \.displayName),
        bool("nowPlayingScreen", \.nowPlayingScreenEnabled, "Full-screen player with lyrics when the Mac sits idle while music plays"),
        number("nowPlayingScreenIdleMinutes", \.nowPlayingScreenIdleMinutes, 0.5...30, "Idle minutes before the full-screen player shows"),
        choice("nowPlayingScreenBackground", \.nowPlayingScreenBackground, "Full-screen player background", name: \.displayName),
        bool("nowPlayingScreenLyrics", \.nowPlayingScreenLyrics, "Lyrics on the full-screen player"),
        bool("nowPlayingScreenClock", \.nowPlayingScreenClock, "Clock on the full-screen player"),
        number("nowPlayingScreenTextScale", \.nowPlayingScreenTextScale, 0.8...1.3, "Lyrics size on the full-screen player"),
        bool("nowPlayingScreenOnlyCharging", \.nowPlayingScreenOnlyCharging, "Show the full-screen player automatically only while charging"),
        bool("lyricsTranslate", \.lyricsTranslate, "Translate lyrics"),
        bool("vinylMode", \.vinylModeEnabled, "Spinning vinyl player"),
        bool("ambientAura", \.ambientAuraEnabled, "Glow from album colors around the notch"),
        bool("chargingPeek", \.chargingPeekEnabled, "Peek when the charger connects"),
        bool("devicePeek", \.devicePeekEnabled, "Peek when AirPods / Bluetooth devices connect"),
        bool("hud", \.hudEnabled, "Volume and brightness HUD in the notch"),
        bool("privacyPeek", \.privacyPeekEnabled, "Peek when the camera or mic turns on"),
        bool("downloadPeek", \.downloadPeekEnabled, "Peek when a download finishes"),
        bool("notificationSounds", \.notificationSounds, "Sounds for peeks and reminders"),
        bool("mascot", \.showMascot, "Notchi mascot beside the notch"),
        bool("notchiBubble", \.notchiBubbleEnabled, "Notchi floating speech bubble"),
        choice("bubbleStyle", \.notchiBubbleStyle, "Floating speech bubble style", name: \.displayName),
        bool("statsInHeader", \.showStatsInHeader, "CPU / RAM stats in the header"),
        bool("markets", \.marketsEnabled, "Markets tab (stocks, crypto)"),
        bool("tickerInHeader", \.showTickerInHeader, "Market ticker in the header"),
        bool("weather", \.weatherEnabled, "Weather in the header"),
        bool("fahrenheit", \.useFahrenheit, "Fahrenheit instead of Celsius"),
        bool("calendar", \.calendarEnabled, "Calendar widget and meeting reminders"),
        bool("audioDeck", \.audioDeckEnabled, "Audio visualizer deck"),
        bool("prayer", \.prayerEnabled, "Prayer times in the header"),
        bool("prayerNotify", \.prayerNotify, "Prayer time reminders"),
        bool("clipboardTab", \.clipboardEnabled, "Clipboard history tab"),
        bool("timerTab", \.timerTabEnabled, "Timer / Pomodoro tab"),
        bool("mirrorTab", \.mirrorTabEnabled, "Mirror (camera) tab"),
        bool("mirrorGestures", \.mirrorGestures, "Hand gestures in Mirror"),
        bool("mirrorRingLight", \.mirrorRingLight, "Ring light in Mirror"),
        bool("devTab", \.devToolsEnabled, "Dev tools tab (ports, color picker)"),
        bool("smarthomeTab", \.smarthomeEnabled, "Smarthome tab"),
        bool("notesTab", \.notesTabEnabled, "Notes tab"),
        bool("calcTab", \.calcTabEnabled, "Calculator & currency converter tab"),
        bool("prompterTab", \.prompterTabEnabled, "Teleprompter tab"),
        bool("aiAgents", \.aiAgents, "Show coding agent status"),
        bool("aiNotify", \.aiNotify, "Peek when an agent finishes or needs you"),
        bool("launchAtLogin", \.launchAtLogin, "Start OpenNotchi at login"),
    ]

    static var systemPrompt: String {
        let s = AppSettings.shared
        let lines = settings.map { "- \($0.key) = \($0.get(s)) — \($0.info). Values: \($0.values)" }.joined(separator: "\n")
        return """
        You are Notchi, the assistant inside OpenNotchi, a macOS app that turns the MacBook notch into a hub. \
        You answer in a small panel at the top of the screen: be concise, plain text, no markdown headings. \
        Reply in the user's language.

        What OpenNotchi does: hover the notch to open it. Tabs: \(NotchTab.allCases.map(\.rawValue).joined(separator: ", ")). \
        Home shows the music player (Spotify, Apple Music, YouTube) with synced lyrics, calendar and weather. \
        Tray holds files dragged onto the notch (AirDrop, convert images). AI shows usage per account (local tools and Notchi Gateway), usage analytics, \
        coding agent status (Claude Code, Codex, Antigravity, Command Code) and this chat. Peeks are small banners for charging, \
        devices, downloads, camera/mic use, agents and meetings. Settings panes: \(SettingsPane.allCases.map(\.rawValue).joined(separator: ", ")).

        Current settings:
        \(lines)

        You can also play music: "play" takes a search like "Hindia Evaluasi" and starts the best match. \
        \(SpotifyAuth.shared.isLoggedIn ? "It searches Spotify." : "Spotify isn't connected, so it only searches the Apple Music library; if the user wants Spotify, tell them to connect it in Settings › Media (lyrics and play/pause/skip work without it).")

        You can also control OpenNotchi & this Mac with actions! When the user asks for any of these, say in one \
        short sentence what you'll do, then end your reply with exactly one block:
        ```notchi
        {
          "set": {"theme": "aurora", "lyrics": true},
          "tab": "Timer",
          "settings": "Appearance",
          "play": "song or artist",
          "media": "play_pause|next|previous",
          "volume": 50,
          "mute": false,
          "openApp": "Safari",
          "openUrl": "https://example.com",
          "copy": "text to put on clipboard",
          "note": "quick note content",
          "timer": 25,
          "killPort": 3000,
          "gatewayModel": "cc/claude-sonnet-5-5"
        }
        ```
        Every field is optional. Use only the keys and values listed above. Don't add the block when nothing should change.
        """
    }

    struct Actions: Decodable {
        var set: [String: JSONValue]?
        var tab: String?
        var settings: String?
        var play: String?
        var media: String?
        var volume: Int?
        var mute: Bool?
        var openApp: String?
        var openUrl: String?
        var copy: String?
        var note: String?
        var timer: Int?
        var killPort: Int?
        var gatewayModel: String?
    }

    /// A JSON scalar, so `true`, `2` and `"aurora"` all decode.
    enum JSONValue: Decodable {
        case string(String)
        var text: String { if case .string(let s) = self { return s }; return "" }

        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let b = try? c.decode(Bool.self) { self = .string(String(b)) }
            else if let d = try? c.decode(Double.self) { self = .string(String(d)) }
            else { self = .string(try c.decode(String.self)) }
        }
    }

    /// Splits a reply into the text to show and the action block (also hides a block that is still streaming in).
    nonisolated static func split(_ reply: String) -> (text: String, actions: Actions?) {
        guard let start = reply.range(of: "```notchi") else { return (reply, nil) }
        let text = String(reply[..<start.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rest = reply[start.upperBound...]
        guard let end = rest.range(of: "```") else { return (text, nil) }
        let json = rest[..<end.lowerBound]
        return (text, try? JSONDecoder().decode(Actions.self, from: Data(json.utf8)))
    }

    /// Applies the actions and returns what changed, each with the old value for Undo.
    static func apply(_ actions: Actions, vm: NotchViewModel?) -> [Change] {
        let s = AppSettings.shared
        var changes: [Change] = []
        for (key, value) in actions.set ?? [:] {
            guard let setting = settings.first(where: { $0.key == key }) else { continue }
            let old = setting.get(s)
            if setting.set(s, value.text) {
                changes.append(Change(label: "\(setting.info): \(setting.get(s))", undo: old, key: key))
            }
        }
        if let name = actions.tab, let tab = NotchTab.allCases.first(where: { $0.rawValue.lowercased() == name.lowercased() }) {
            vm?.tab = tab
            changes.append(Change(label: "Opened \(tab.rawValue)", undo: nil, key: "tab"))
        }
        if let query = actions.play?.trimmingCharacters(in: .whitespaces), !query.isEmpty {
            changes.append(Change(label: "Playing “\(query)”", undo: nil, key: "play"))
            Task {
                let spotify = SpotifyAuth.shared.isLoggedIn ? (try? await MusicSearch.spotify(query)) ?? [] : []
                let found = spotify.isEmpty ? await MusicSearch.appleMusic(query) : spotify
                if let first = found.first { try? await MusicSearch.play(first) }
            }
        }
        if let name = actions.settings, let pane = SettingsPane.allCases.first(where: { $0.rawValue.lowercased() == name.lowercased() }) {
            UserDefaults.standard.set(pane.rawValue, forKey: "settingsPane")
            AppDelegate.shared?.showSettings()
            changes.append(Change(label: "Opened Settings › \(pane.rawValue)", undo: nil, key: "settings"))
        }
        if let mediaCmd = actions.media?.lowercased() {
            switch mediaCmd {
            case "play_pause", "playpause", "toggle":
                AppDelegate.shared?.media.playPause()
                changes.append(Change(label: "Toggled playback", undo: nil, key: "media"))
            case "next", "skip":
                AppDelegate.shared?.media.nextTrack()
                changes.append(Change(label: "Skipped to next track", undo: nil, key: "media"))
            case "previous", "prev", "back":
                AppDelegate.shared?.media.previousTrack()
                changes.append(Change(label: "Previous track", undo: nil, key: "media"))
            default: break
            }
        }
        if let vol = actions.volume {
            let clamped = max(0, min(100, vol))
            runOsascript("set volume output volume \(clamped)")
            changes.append(Change(label: "Volume: \(clamped)%", undo: nil, key: "volume"))
        }
        if let muted = actions.mute {
            runOsascript("set volume output muted \(muted ? "true" : "false")")
            changes.append(Change(label: muted ? "Muted audio" : "Unmuted audio", undo: nil, key: "mute"))
        }
        if let appName = actions.openApp?.trimmingCharacters(in: .whitespacesAndNewlines), !appName.isEmpty {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", appName]
            try? proc.run()
            changes.append(Change(label: "Opened \(appName)", undo: nil, key: "openApp"))
        }
        if let urlStr = actions.openUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: urlStr),
           let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            NSWorkspace.shared.open(url)
            changes.append(Change(label: "Opened \(url.host ?? urlStr)", undo: nil, key: "openUrl"))
        }
        if let textToCopy = actions.copy, !textToCopy.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToCopy, forType: .string)
            changes.append(Change(label: "Copied to clipboard", undo: nil, key: "copy"))
        }
        if let noteText = actions.note?.trimmingCharacters(in: .whitespacesAndNewlines), !noteText.isEmpty {
            let id = NoteStore.shared.create()
            NoteStore.shared.update(id, text: noteText)
            changes.append(Change(label: "Saved note", undo: nil, key: "note"))
        }
        if let minutes = actions.timer, minutes > 0 {
            let t = AppDelegate.shared?.timer
            t?.setDuration(minutes: minutes)
            t?.start()
            changes.append(Change(label: "Started \(minutes)m timer", undo: nil, key: "timer"))
        }
        if let port = actions.killPort, (1...65535).contains(port) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/sh")
            proc.arguments = ["-c", "lsof -ti tcp:\(port) | xargs -r kill -9"]
            try? proc.run()
            changes.append(Change(label: "Killed process on :\(port)", undo: nil, key: "killPort"))
        }
        if let gwModel = actions.gatewayModel?.trimmingCharacters(in: .whitespacesAndNewlines), !gwModel.isEmpty {
            let old = s.aiGatewayModel
            s.aiGatewayModel = gwModel
            changes.append(Change(label: "Gateway model: \(gwModel)", undo: old, key: "gatewayModel"))
        }
        return changes
    }

    private static func runOsascript(_ script: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
    }

    static func undo(_ change: Change) {
        guard let old = change.undo, let setting = settings.first(where: { $0.key == change.key }) else { return }
        _ = setting.set(AppSettings.shared, old)
    }
}
