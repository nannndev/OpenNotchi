import Foundation

struct SettingItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let pane: SettingsPane
    let keywords: [String]
    let icon: String?

    /// Every word of the query must appear in the title, subtitle, pane or keywords, in any order.
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = ([title, subtitle, pane.rawValue] + keywords).joined(separator: " ")
        return words.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    static let all: [SettingItem] = [
        // General
        SettingItem(
            title: "Launch at login", subtitle: "Open OpenNotchi automatically upon user login", pane: .general,
            keywords: ["startup", "boot", "login", "auto"], icon: "power"),
        SettingItem(
            title: "Show menu bar icon", subtitle: "Toggle visibility of OpenNotchi in macOS menu bar", pane: .general,
            keywords: ["tray", "status", "menubar", "bar"], icon: "menubar.dock.rectangle"),
        SettingItem(
            title: "Displays & Monitors", subtitle: "Target display for OpenNotchi on multi-monitor setups",
            pane: .general, keywords: ["screen", "monitor", "display", "target"], icon: "display.2"),
        SettingItem(
            title: "Haptic feedback", subtitle: "Gentle trackpad vibration when opening the notch", pane: .general,
            keywords: ["haptic", "vibrate", "feedback"], icon: "hand.tap.fill"),
        SettingItem(
            title: "Show live activity beside notch",
            subtitle: "Dynamic island live indicators (media, timer, traffic)", pane: .general,
            keywords: ["live", "island", "activity"], icon: "waveform"),
        SettingItem(
            title: "Hover delay", subtitle: "Sensitivity & delay before notch expands on hover", pane: .general,
            keywords: ["sensitivity", "speed", "hover", "delay"], icon: "cursorarrow.motionlines"),
        SettingItem(
            title: "Global shortcut", subtitle: "Global keyboard hotkey to toggle notch open/closed", pane: .general,
            keywords: ["hotkey", "keyboard", "shortcut", "toggle"], icon: "command"),

        // Appearance
        SettingItem(
            title: "Theme", subtitle: "Visual styling: Liquid Glass, Frosted, Opaque, Clear, Vinyl, Album Art",
            pane: .appearance, keywords: ["theme", "style", "glass", "frosted", "opaque", "liquid"],
            icon: "paintbrush.fill"),
        SettingItem(
            title: "Accent color", subtitle: "Custom color accent or match playing song artwork", pane: .appearance,
            keywords: ["accent", "color", "tint", "artwork", "palette"], icon: "eyedropper.halffull"),
        SettingItem(
            title: "Border style & width", subtitle: "Customize border outline and thickness around the notch",
            pane: .appearance, keywords: ["border", "stroke", "width", "outline"], icon: "square.dashed"),
        SettingItem(
            title: "Corner radius", subtitle: "Adjust curvature and roundness of notch corners", pane: .appearance,
            keywords: ["corner", "radius", "round", "curve"], icon: "skew"),
        SettingItem(
            title: "Open animation", subtitle: "2D drop, 3D tilt stage, swing, and spring physics", pane: .appearance,
            keywords: ["animation", "3d", "spring", "tilt", "open"], icon: "sparkles"),

        // Features
        SettingItem(
            title: "Tabs visibility", subtitle: "Toggle tabs: AI, Prompter, Clipboard, Timer, Mirror, Dev, Notes",
            pane: .features, keywords: ["tabs", "navigation", "prompter", "clipboard", "notes"], icon: "square.grid.2x2"
        ),
        SettingItem(
            title: "Eye-Contact Teleprompter", subtitle: "Floating teleprompter under camera with mirror preview",
            pane: .features, keywords: ["prompter", "teleprompter", "speech", "script"], icon: "text.viewfinder"),
        SettingItem(
            title: "Clipboard history", subtitle: "Search and paste recent clipboard items directly from notch",
            pane: .features, keywords: ["clipboard", "history", "paste", "copy"], icon: "doc.on.clipboard"),
        SettingItem(
            title: "Timer & Stopwatch", subtitle: "Quick focus timer, pomodoro breaks, and countdowns", pane: .features,
            keywords: ["timer", "stopwatch", "pomodoro", "countdown"], icon: "timer"),
        SettingItem(
            title: "Developer tools", subtitle: "Port inspector, color eyedropper, and audio mic test", pane: .features,
            keywords: ["dev", "ports", "developer", "eyedropper"], icon: "terminal"),
        SettingItem(
            title: "Notes & Keep awake", subtitle: "Scratchpad notes, caffeine keep awake, and Shortcuts runner",
            pane: .features, keywords: ["notes", "keep awake", "caffeine", "shortcuts"], icon: "note.text"),
        SettingItem(
            title: "Desktop synchronized lyrics", subtitle: "Floating desktop lyrics widget and real-time translation",
            pane: .features, keywords: ["lyrics", "karaoke", "translation", "overlay"], icon: "music.note.list"),
        SettingItem(
            title: "Prayer times & Adhan", subtitle: "Prayer schedule, Adhan countdowns, and Qibla direction",
            pane: .features, keywords: ["prayer", "adhan", "sholat", "qibla"], icon: "moon.stars.fill"),
        SettingItem(
            title: "Weather & Forecast", subtitle: "Real-time weather temperature, forecast, and location",
            pane: .features, keywords: ["weather", "forecast", "temperature", "rain"], icon: "cloud.sun.fill"),
        SettingItem(
            title: "Markets & Stock ticker", subtitle: "Crypto and stock watchlist in notch header ticker",
            pane: .features, keywords: ["stocks", "crypto", "markets", "ticker"], icon: "chart.line.uptrend.xyaxis"),
        SettingItem(
            title: "Device & Battery Peeks", subtitle: "AirPods battery banner, charging status, download finished",
            pane: .features, keywords: ["peek", "banner", "airpods", "charging", "battery", "downloads"],
            icon: "airpodspro"),
        SettingItem(
            title: "Volume & brightness HUD", subtitle: "Notch replacement for macOS volume and display brightness HUD",
            pane: .features, keywords: ["hud", "volume", "brightness", "sound"], icon: "speaker.wave.3.fill"),

        // Media
        SettingItem(
            title: "Spotify & Apple Music",
            subtitle: "Media players, playback controls, album art, and Spotify Connect", pane: .media,
            keywords: ["spotify", "apple music", "playback", "song", "player"], icon: "music.note"),
        SettingItem(
            title: "Browser YouTube", subtitle: "Support playing YouTube in Chrome, Safari, Brave, Arc, Edge",
            pane: .media, keywords: ["youtube", "browser", "video"], icon: "play.rectangle.fill"),
        SettingItem(
            title: "Audio deck & Visualizer", subtitle: "Equalizer spectrum deck next to the music player",
            pane: .features, keywords: ["audio", "deck", "spectrum", "equalizer"], icon: "waveform.path"),

        // Mirror
        SettingItem(
            title: "Mirror & Camera preview",
            subtitle: "Choose webcam, mirror flip, photobox studio, and hand gestures", pane: .mirror,
            keywords: ["mirror", "camera", "webcam", "gestures", "photobox"], icon: "camera.fill"),

        // Smarthome
        SettingItem(
            title: "HomeKit & Smarthome", subtitle: "Control smart lights, switches, AC, and HomeKit accessories",
            pane: .smarthome, keywords: ["smarthome", "homekit", "lights", "accessories"],
            icon: "air.conditioner.horizontal.fill"),

        // AI
        SettingItem(
            title: "Enable AI features", subtitle: "Master toggle for AI Quota, Agents, and Ask AI in OpenNotchi",
            pane: .ai, keywords: ["ai", "enable", "agents", "quota"], icon: "sparkles"),
        SettingItem(
            title: "Quota & Accounts (9router style)",
            subtitle: "Multi-account token monitoring, rate limit gauges, and reset countdowns", pane: .ai,
            keywords: ["quota", "tokens", "usage", "accounts", "rate limit", "9router"], icon: "chart.bar.xaxis"),
        SettingItem(
            title: "Google Antigravity",
            subtitle: "Track Antigravity agent sessions, prompts, and tokens in ~/.gemini/antigravity-ide", pane: .ai,
            keywords: ["antigravity", "gemini", "google", "agent"], icon: "sparkles"),
        SettingItem(
            title: "Claude Code & Codex", subtitle: "Track Anthropic Claude Code and OpenAI Codex sessions", pane: .ai,
            keywords: ["claude", "codex", "anthropic", "openai", "agent"], icon: "terminal"),
        SettingItem(
            title: "Claude Code hooks", subtitle: "Local HTTP webhook on port 47823 for instant real-time status",
            pane: .ai, keywords: ["hook", "webhook", "curl", "port", "realtime", "instant"], icon: "network"),
        SettingItem(
            title: "Agent completion notifications",
            subtitle: "Banner notification when an agent finishes or needs your input", pane: .ai,
            keywords: ["notify", "notification", "needs you", "done", "peek"], icon: "bell.badge.fill"),
        SettingItem(
            title: "Closed notch meter",
            subtitle: "Show usage in the closed notch: rate limit gauge on the closed notch pill", pane: .ai,
            keywords: ["meter", "closed", "pill", "gauge", "usage"], icon: "gauge.with.needle"),
        SettingItem(
            title: "Ask AI Provider", subtitle: "Connect Apple Intelligence, local Ollama LLM, Anthropic, or OpenAI",
            pane: .ai, keywords: ["ask", "provider", "ollama", "apple intelligence", "model", "llm"],
            icon: "bubble.left.and.bubble.right.fill"),

        // Every other control, by the label it has in its pane, so search finds all of them.
        // shortcut: this list is kept by hand; add a line here whenever a new setting gets a Toggle or Picker.
        SettingItem(
            title: "Network speed beside notch when active",
            subtitle: "Download and upload speed beside the closed notch", pane: .features,
            keywords: ["network", "traffic", "speed", "upload", "download", "jaringan", "trafik", "internet"],
            icon: "arrow.up.arrow.down"),
        SettingItem(
            title: "Show network traffic in header ticker",
            subtitle: "Network speed in the header while the notch is open", pane: .features,
            keywords: ["network", "traffic", "header", "ticker", "jaringan", "trafik"],
            icon: "arrow.up.arrow.down.circle"),
        SettingItem(
            title: "Notification sounds",
            subtitle: "A sound when an agent finishes or needs you, a download is done, or a meeting starts",
            pane: .features, keywords: ["sound", "notification", "notif", "bunyi", "suara", "alert", "banner"],
            icon: "speaker.wave.2.fill"),
        SettingItem(
            title: "Notchi, the mascot", subtitle: "A little character beside the notch when it's idle",
            pane: .features, keywords: ["mascot", "notchi", "character", "idle", "maskot", "karakter"],
            icon: "face.smiling"),
        SettingItem(
            title: "Live activities", subtitle: "Charger connected, AirPods and Bluetooth devices", pane: .features,
            keywords: ["charger", "charging", "airpods", "bluetooth", "device", "battery"], icon: "bolt.fill"),
        SettingItem(
            title: "Camera or microphone starts being used", subtitle: "A pill when any app turns on the camera or mic",
            pane: .features, keywords: ["camera", "microphone", "mic", "privacy", "indicator"], icon: "video.fill"),
        SettingItem(
            title: "Download finished", subtitle: "Banner when a file lands in ~/Downloads", pane: .features,
            keywords: ["download", "downloads", "file", "finished"], icon: "arrow.down.circle.fill"),
        SettingItem(
            title: "Home tab", subtitle: "Show the Home tab in the notch", pane: .features, keywords: ["home", "tab"],
            icon: "house.fill"),
        SettingItem(
            title: "Mirror (camera) tab", subtitle: "Show the Mirror tab in the notch", pane: .features,
            keywords: ["mirror", "camera", "tab"], icon: "camera.fill"),
        SettingItem(
            title: "AI tab", subtitle: "Show the AI tab: Quota, Agents & Ask AI", pane: .features,
            keywords: ["ai", "tab", "quota", "agents"], icon: "sparkles"),
        SettingItem(
            title: "Lyrics button on the artwork", subtitle: "Open synced lyrics from the album art", pane: .features,
            keywords: ["lyrics", "artwork", "button", "lirik"], icon: "quote.bubble"),
        SettingItem(
            title: "Show the current lyric line under the title", subtitle: "Lyric line on the player", pane: .features,
            keywords: ["lyrics", "line", "title", "player", "lirik"], icon: "text.quote"),
        SettingItem(
            title: "Translate lyrics", subtitle: "Translate into your language, on your Mac", pane: .features,
            keywords: ["translate", "translation", "language", "lyrics", "terjemah", "lirik"], icon: "character.bubble"),
        SettingItem(
            title: "Floating lyrics widget on the desktop",
            subtitle: "Show the next line, lock widget, reset widget size and position", pane: .features,
            keywords: ["lyrics", "widget", "desktop", "floating", "next line", "lock", "reset", "lirik"], icon: "pip"),
        SettingItem(
            title: "Full-screen player when idle",
            subtitle: "Big cover, blurred background and lyrics when the Mac sits idle while music plays",
            pane: .features,
            keywords: [
                "fullscreen", "full screen", "screensaver", "idle", "lock screen", "lyrics", "now playing",
                "layar penuh", "lirik",
            ], icon: "play.rectangle.fill"),
        SettingItem(
            title: "Today's calendar widget next to the player", subtitle: "Your next events beside the music player",
            pane: .features, keywords: ["calendar", "events", "widget", "agenda"], icon: "calendar"),
        SettingItem(
            title: "Meeting reminders",
            subtitle: "Remind me before events, only video calls, play a sound, connect calendar", pane: .features,
            keywords: ["reminder", "meeting", "events", "calendar", "zoom", "meet", "sound"], icon: "bell.fill"),
        SettingItem(
            title: "Prayer time options",
            subtitle: "Calculation method, Asr, names, notify at each prayer time, heads-up before", pane: .features,
            keywords: ["prayer", "calculation", "method", "asr", "notify", "heads-up", "sholat", "adzan"],
            icon: "moon.stars"),
        SettingItem(
            title: "Weather options", subtitle: "Show weather in the notch, units and location", pane: .features,
            keywords: ["weather", "units", "celsius", "fahrenheit", "location", "cuaca"], icon: "thermometer.medium"),
        SettingItem(
            title: "Markets options", subtitle: "Markets tab, rotate tickers in the notch header, quick add",
            pane: .features, keywords: ["markets", "ticker", "rotate", "header", "quick add", "saham"],
            icon: "chart.xyaxis.line"),
        SettingItem(
            title: "Artwork style", subtitle: "Cover, vinyl disc or sleeve for the playing song", pane: .media,
            keywords: ["artwork", "style", "vinyl", "cover", "album"], icon: "opticaldisc"),
        SettingItem(
            title: "Ambient artwork aura glow", subtitle: "Soft glow from the album art behind the player",
            pane: .media, keywords: ["aura", "glow", "ambient", "artwork"], icon: "sun.max.fill"),
        SettingItem(
            title: "Show lyrics on home player", subtitle: "Lyrics under the song on the Home tab", pane: .media,
            keywords: ["lyrics", "home", "player", "lirik"], icon: "music.note.list"),
        SettingItem(
            title: "Spotify on other devices", subtitle: "Show and control Spotify playing on your phone or a speaker",
            pane: .media, keywords: ["spotify", "connect", "devices", "phone", "speaker", "account"],
            icon: "hifispeaker.2.fill"),
        SettingItem(
            title: "YouTube and YouTube Music", subtitle: "Live video preview in the notch", pane: .media,
            keywords: ["youtube", "music", "video", "preview", "browser"], icon: "play.tv.fill"),
        SettingItem(
            title: "Photobox strip", subtitle: "Frame style, format (story, post, square) and number of photos",
            pane: .mirror, keywords: ["photobox", "strip", "frame", "format", "photos", "story", "post", "caption"],
            icon: "photo.on.rectangle"),
        SettingItem(
            title: "Mirror look & background", subtitle: "Filter look and blurred or album-art background",
            pane: .mirror, keywords: ["look", "filter", "background", "blur", "effect"], icon: "camera.filters"),
        SettingItem(
            title: "Ring light", subtitle: "Light up your face in the mirror", pane: .mirror,
            keywords: ["ring light", "light", "lamp"], icon: "light.max"),
        SettingItem(
            title: "Hand gestures", subtitle: "✌️ photo, 👍 confetti, ✋ ring light", pane: .mirror,
            keywords: ["gesture", "hand", "confetti", "peace"], icon: "hand.raised.fill"),
        SettingItem(
            title: "Keep the notch open while using the Mirror",
            subtitle: "The mirror stays open when the pointer leaves", pane: .mirror,
            keywords: ["keep open", "pin", "stay"], icon: "pin.fill"),
        SettingItem(
            title: "Home Assistant & Apple Shortcuts",
            subtitle: "Integration mode, Home Assistant configuration and test connection", pane: .smarthome,
            keywords: ["home assistant", "shortcuts", "integration", "token", "connection"], icon: "house.and.flag.fill"
        ),
        SettingItem(
            title: "Check for updates automatically", subtitle: "Download new versions in the background", pane: .about,
            keywords: ["update", "automatic", "sparkle", "version"], icon: "arrow.triangle.2.circlepath"),

        // About
        SettingItem(
            title: "OpenNotchi version", subtitle: "Current version, release notes, and check for updates",
            pane: .about, keywords: ["version", "update", "sparkle", "github", "about"], icon: "info.circle.fill"),
    ]
}
