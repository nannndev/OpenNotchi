import AVFoundation
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case features = "Features"
    case media = "Media"
    case mirror = "Mirror"
    case smarthome = "Smarthome"
    case ai = "AI"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .features: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .mirror: return "camera.fill"
        case .smarthome: return "air.conditioner.horizontal.fill"
        case .ai: return "sparkles"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .pink
        case .features: return .blue
        case .media: return .red
        case .mirror: return .teal
        case .smarthome: return .green
        case .ai: return .purple
        case .about: return .indigo
        }
    }
}

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
        SettingItem(title: "Launch at login", subtitle: "Open OpenNotchi automatically upon user login", pane: .general, keywords: ["startup", "boot", "login", "auto"], icon: "power"),
        SettingItem(title: "Show menu bar icon", subtitle: "Toggle visibility of OpenNotchi in macOS menu bar", pane: .general, keywords: ["tray", "status", "menubar", "bar"], icon: "menubar.dock.rectangle"),
        SettingItem(title: "Displays & Monitors", subtitle: "Target display for OpenNotchi on multi-monitor setups", pane: .general, keywords: ["screen", "monitor", "display", "target"], icon: "display.2"),
        SettingItem(title: "Haptic feedback", subtitle: "Gentle trackpad vibration when opening the notch", pane: .general, keywords: ["haptic", "vibrate", "feedback"], icon: "hand.tap.fill"),
        SettingItem(title: "Show live activity beside notch", subtitle: "Dynamic island live indicators (media, timer, traffic)", pane: .general, keywords: ["live", "island", "activity"], icon: "waveform"),
        SettingItem(title: "Hover delay", subtitle: "Sensitivity & delay before notch expands on hover", pane: .general, keywords: ["sensitivity", "speed", "hover", "delay"], icon: "cursorarrow.motionlines"),
        SettingItem(title: "Global shortcut", subtitle: "Global keyboard hotkey to toggle notch open/closed", pane: .general, keywords: ["hotkey", "keyboard", "shortcut", "toggle"], icon: "command"),

        // Appearance
        SettingItem(title: "Theme", subtitle: "Visual styling: Liquid Glass, Frosted, Opaque, Clear, Vinyl, Album Art", pane: .appearance, keywords: ["theme", "style", "glass", "frosted", "opaque", "liquid"], icon: "paintbrush.fill"),
        SettingItem(title: "Accent color", subtitle: "Custom color accent or match playing song artwork", pane: .appearance, keywords: ["accent", "color", "tint", "artwork", "palette"], icon: "eyedropper.halffull"),
        SettingItem(title: "Border style & width", subtitle: "Customize border outline and thickness around the notch", pane: .appearance, keywords: ["border", "stroke", "width", "outline"], icon: "square.dashed"),
        SettingItem(title: "Corner radius", subtitle: "Adjust curvature and roundness of notch corners", pane: .appearance, keywords: ["corner", "radius", "round", "curve"], icon: "skew"),
        SettingItem(title: "Open animation", subtitle: "2D drop, 3D tilt stage, swing, and spring physics", pane: .appearance, keywords: ["animation", "3d", "spring", "tilt", "open"], icon: "sparkles"),

        // Features
        SettingItem(title: "Tabs visibility", subtitle: "Toggle tabs: AI, Prompter, Clipboard, Timer, Mirror, Dev, Notes", pane: .features, keywords: ["tabs", "navigation", "prompter", "clipboard", "notes"], icon: "square.grid.2x2"),
        SettingItem(title: "Eye-Contact Teleprompter", subtitle: "Floating teleprompter under camera with mirror preview", pane: .features, keywords: ["prompter", "teleprompter", "speech", "script"], icon: "text.viewfinder"),
        SettingItem(title: "Clipboard history", subtitle: "Search and paste recent clipboard items directly from notch", pane: .features, keywords: ["clipboard", "history", "paste", "copy"], icon: "doc.on.clipboard"),
        SettingItem(title: "Timer & Stopwatch", subtitle: "Quick focus timer, pomodoro breaks, and countdowns", pane: .features, keywords: ["timer", "stopwatch", "pomodoro", "countdown"], icon: "timer"),
        SettingItem(title: "Developer tools", subtitle: "Port inspector, color eyedropper, and audio mic test", pane: .features, keywords: ["dev", "ports", "developer", "eyedropper"], icon: "terminal"),
        SettingItem(title: "Notes & Keep awake", subtitle: "Scratchpad notes, caffeine keep awake, and Shortcuts runner", pane: .features, keywords: ["notes", "keep awake", "caffeine", "shortcuts"], icon: "note.text"),
        SettingItem(title: "Desktop synchronized lyrics", subtitle: "Floating desktop lyrics widget and real-time translation", pane: .features, keywords: ["lyrics", "karaoke", "translation", "overlay"], icon: "music.note.list"),
        SettingItem(title: "Prayer times & Adhan", subtitle: "Prayer schedule, Adhan countdowns, and Qibla direction", pane: .features, keywords: ["prayer", "adhan", "sholat", "qibla"], icon: "moon.stars.fill"),
        SettingItem(title: "Weather & Forecast", subtitle: "Real-time weather temperature, forecast, and location", pane: .features, keywords: ["weather", "forecast", "temperature", "rain"], icon: "cloud.sun.fill"),
        SettingItem(title: "Markets & Stock ticker", subtitle: "Crypto and stock watchlist in notch header ticker", pane: .features, keywords: ["stocks", "crypto", "markets", "ticker"], icon: "chart.line.uptrend.xyaxis"),
        SettingItem(title: "Device & Battery Peeks", subtitle: "AirPods battery banner, charging status, download finished", pane: .features, keywords: ["peek", "banner", "airpods", "charging", "battery", "downloads"], icon: "airpodspro"),
        SettingItem(title: "Volume & brightness HUD", subtitle: "Notch replacement for macOS volume and display brightness HUD", pane: .features, keywords: ["hud", "volume", "brightness", "sound"], icon: "speaker.wave.3.fill"),

        // Media
        SettingItem(title: "Spotify & Apple Music", subtitle: "Media players, playback controls, album art, and Spotify Connect", pane: .media, keywords: ["spotify", "apple music", "playback", "song", "player"], icon: "music.note"),
        SettingItem(title: "Browser YouTube", subtitle: "Support playing YouTube in Chrome, Safari, Brave, Arc, Edge", pane: .media, keywords: ["youtube", "browser", "video"], icon: "play.rectangle.fill"),
        SettingItem(title: "Audio deck & Visualizer", subtitle: "Equalizer spectrum deck next to the music player", pane: .features, keywords: ["audio", "deck", "spectrum", "equalizer"], icon: "waveform.path"),

        // Mirror
        SettingItem(title: "Mirror & Camera preview", subtitle: "Choose webcam, mirror flip, photobox studio, and hand gestures", pane: .mirror, keywords: ["mirror", "camera", "webcam", "gestures", "photobox"], icon: "camera.fill"),

        // Smarthome
        SettingItem(title: "HomeKit & Smarthome", subtitle: "Control smart lights, switches, AC, and HomeKit accessories", pane: .smarthome, keywords: ["smarthome", "homekit", "lights", "accessories"], icon: "air.conditioner.horizontal.fill"),

        // AI
        SettingItem(title: "Enable AI features", subtitle: "Master toggle for AI Quota, Agents, and Ask AI in OpenNotchi", pane: .ai, keywords: ["ai", "enable", "agents", "quota"], icon: "sparkles"),
        SettingItem(title: "Quota & Accounts (9router style)", subtitle: "Multi-account token monitoring, rate limit gauges, and reset countdowns", pane: .ai, keywords: ["quota", "tokens", "usage", "accounts", "rate limit", "9router"], icon: "chart.bar.xaxis"),
        SettingItem(title: "Google Antigravity", subtitle: "Track Antigravity agent sessions, prompts, and tokens in ~/.gemini/antigravity-ide", pane: .ai, keywords: ["antigravity", "gemini", "google", "agent"], icon: "sparkles"),
        SettingItem(title: "Claude Code & Codex", subtitle: "Track Anthropic Claude Code and OpenAI Codex sessions", pane: .ai, keywords: ["claude", "codex", "anthropic", "openai", "agent"], icon: "terminal"),
        SettingItem(title: "Claude Code hooks", subtitle: "Local HTTP webhook on port 47823 for instant real-time status", pane: .ai, keywords: ["hook", "webhook", "curl", "port", "realtime", "instant"], icon: "network"),
        SettingItem(title: "Agent completion notifications", subtitle: "Banner notification when an agent finishes or needs your input", pane: .ai, keywords: ["notify", "notification", "needs you", "done", "peek"], icon: "bell.badge.fill"),
        SettingItem(title: "Closed notch meter", subtitle: "Show usage in the closed notch: rate limit gauge on the closed notch pill", pane: .ai, keywords: ["meter", "closed", "pill", "gauge", "usage"], icon: "gauge.with.needle"),
        SettingItem(title: "Ask AI Provider", subtitle: "Connect Apple Intelligence, local Ollama LLM, Anthropic, or OpenAI", pane: .ai, keywords: ["ask", "provider", "ollama", "apple intelligence", "model", "llm"], icon: "bubble.left.and.bubble.right.fill"),

        // Every other control, by the label it has in its pane, so search finds all of them.
        // shortcut: this list is kept by hand; add a line here whenever a new setting gets a Toggle or Picker.
        SettingItem(title: "Network speed beside notch when active", subtitle: "Download and upload speed beside the closed notch", pane: .features, keywords: ["network", "traffic", "speed", "upload", "download", "jaringan", "trafik", "internet"], icon: "arrow.up.arrow.down"),
        SettingItem(title: "Show network traffic in header ticker", subtitle: "Network speed in the header while the notch is open", pane: .features, keywords: ["network", "traffic", "header", "ticker", "jaringan", "trafik"], icon: "arrow.up.arrow.down.circle"),
        SettingItem(title: "Notification sounds", subtitle: "A sound when an agent finishes or needs you, a download is done, or a meeting starts", pane: .features, keywords: ["sound", "notification", "notif", "bunyi", "suara", "alert", "banner"], icon: "speaker.wave.2.fill"),
        SettingItem(title: "Notchi, the mascot", subtitle: "A little character beside the notch when it's idle", pane: .features, keywords: ["mascot", "notchi", "character", "idle", "maskot", "karakter"], icon: "face.smiling"),
        SettingItem(title: "Live activities", subtitle: "Charger connected, AirPods and Bluetooth devices", pane: .features, keywords: ["charger", "charging", "airpods", "bluetooth", "device", "battery"], icon: "bolt.fill"),
        SettingItem(title: "Camera or microphone starts being used", subtitle: "A pill when any app turns on the camera or mic", pane: .features, keywords: ["camera", "microphone", "mic", "privacy", "indicator"], icon: "video.fill"),
        SettingItem(title: "Download finished", subtitle: "Banner when a file lands in ~/Downloads", pane: .features, keywords: ["download", "downloads", "file", "finished"], icon: "arrow.down.circle.fill"),
        SettingItem(title: "Home tab", subtitle: "Show the Home tab in the notch", pane: .features, keywords: ["home", "tab"], icon: "house.fill"),
        SettingItem(title: "Mirror (camera) tab", subtitle: "Show the Mirror tab in the notch", pane: .features, keywords: ["mirror", "camera", "tab"], icon: "camera.fill"),
        SettingItem(title: "AI tab", subtitle: "Show the AI tab: Quota, Agents & Ask AI", pane: .features, keywords: ["ai", "tab", "quota", "agents"], icon: "sparkles"),
        SettingItem(title: "Lyrics button on the artwork", subtitle: "Open synced lyrics from the album art", pane: .features, keywords: ["lyrics", "artwork", "button", "lirik"], icon: "quote.bubble"),
        SettingItem(title: "Show the current lyric line under the title", subtitle: "Lyric line on the player", pane: .features, keywords: ["lyrics", "line", "title", "player", "lirik"], icon: "text.quote"),
        SettingItem(title: "Translate lyrics", subtitle: "Translate into your language, on your Mac", pane: .features, keywords: ["translate", "translation", "language", "lyrics", "terjemah", "lirik"], icon: "character.bubble"),
        SettingItem(title: "Floating lyrics widget on the desktop", subtitle: "Show the next line, lock widget, reset widget size and position", pane: .features, keywords: ["lyrics", "widget", "desktop", "floating", "next line", "lock", "reset", "lirik"], icon: "pip"),
        SettingItem(title: "Today's calendar widget next to the player", subtitle: "Your next events beside the music player", pane: .features, keywords: ["calendar", "events", "widget", "agenda"], icon: "calendar"),
        SettingItem(title: "Meeting reminders", subtitle: "Remind me before events, only video calls, play a sound, connect calendar", pane: .features, keywords: ["reminder", "meeting", "events", "calendar", "zoom", "meet", "sound"], icon: "bell.fill"),
        SettingItem(title: "Prayer time options", subtitle: "Calculation method, Asr, names, notify at each prayer time, heads-up before", pane: .features, keywords: ["prayer", "calculation", "method", "asr", "notify", "heads-up", "sholat", "adzan"], icon: "moon.stars"),
        SettingItem(title: "Weather options", subtitle: "Show weather in the notch, units and location", pane: .features, keywords: ["weather", "units", "celsius", "fahrenheit", "location", "cuaca"], icon: "thermometer.medium"),
        SettingItem(title: "Markets options", subtitle: "Markets tab, rotate tickers in the notch header, quick add", pane: .features, keywords: ["markets", "ticker", "rotate", "header", "quick add", "saham"], icon: "chart.xyaxis.line"),
        SettingItem(title: "Artwork style", subtitle: "Cover, vinyl disc or sleeve for the playing song", pane: .media, keywords: ["artwork", "style", "vinyl", "cover", "album"], icon: "opticaldisc"),
        SettingItem(title: "Ambient artwork aura glow", subtitle: "Soft glow from the album art behind the player", pane: .media, keywords: ["aura", "glow", "ambient", "artwork"], icon: "sun.max.fill"),
        SettingItem(title: "Show lyrics on home player", subtitle: "Lyrics under the song on the Home tab", pane: .media, keywords: ["lyrics", "home", "player", "lirik"], icon: "music.note.list"),
        SettingItem(title: "Spotify on other devices", subtitle: "Show and control Spotify playing on your phone or a speaker", pane: .media, keywords: ["spotify", "connect", "devices", "phone", "speaker", "account"], icon: "hifispeaker.2.fill"),
        SettingItem(title: "YouTube and YouTube Music", subtitle: "Live video preview in the notch", pane: .media, keywords: ["youtube", "music", "video", "preview", "browser"], icon: "play.tv.fill"),
        SettingItem(title: "Photobox strip", subtitle: "Frame style, format (story, post, square) and number of photos", pane: .mirror, keywords: ["photobox", "strip", "frame", "format", "photos", "story", "post", "caption"], icon: "photo.on.rectangle"),
        SettingItem(title: "Mirror look & background", subtitle: "Filter look and blurred or album-art background", pane: .mirror, keywords: ["look", "filter", "background", "blur", "effect"], icon: "camera.filters"),
        SettingItem(title: "Ring light", subtitle: "Light up your face in the mirror", pane: .mirror, keywords: ["ring light", "light", "lamp"], icon: "light.max"),
        SettingItem(title: "Hand gestures", subtitle: "✌️ photo, 👍 confetti, ✋ ring light", pane: .mirror, keywords: ["gesture", "hand", "confetti", "peace"], icon: "hand.raised.fill"),
        SettingItem(title: "Keep the notch open while using the Mirror", subtitle: "The mirror stays open when the pointer leaves", pane: .mirror, keywords: ["keep open", "pin", "stay"], icon: "pin.fill"),
        SettingItem(title: "Home Assistant & Apple Shortcuts", subtitle: "Integration mode, Home Assistant configuration and test connection", pane: .smarthome, keywords: ["home assistant", "shortcuts", "integration", "token", "connection"], icon: "house.and.flag.fill"),
        SettingItem(title: "Check for updates automatically", subtitle: "Download new versions in the background", pane: .about, keywords: ["update", "automatic", "sparkle", "version"], icon: "arrow.triangle.2.circlepath"),

        // About
        SettingItem(title: "OpenNotchi version", subtitle: "Current version, release notes, and check for updates", pane: .about, keywords: ["version", "update", "sparkle", "github", "about"], icon: "info.circle.fill")
    ]
}

struct SettingsView: View {
    @AppStorage("settingsPane") private var pane: SettingsPane = .general
    @State private var searchText = ""

    private var filteredItems: [SettingItem] {
        guard !searchText.isEmpty else { return [] }
        return SettingItem.all.filter { $0.matches(searchText) }
    }

    private var matchingPanes: [SettingsPane] {
        guard !searchText.isEmpty else { return SettingsPane.allCases }
        let matched = Set(filteredItems.map(\.pane))
        return SettingsPane.allCases.filter { matched.contains($0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11, weight: .semibold))
                    TextField("Search settings…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)

                List(selection: $pane) {
                    ForEach(matchingPanes) { item in
                        let matchCount = filteredItems.filter { $0.pane == item }.count
                        HStack {
                            Label {
                                Text(item.rawValue)
                            } icon: {
                                Image(systemName: item.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(item.tint.gradient))
                            }
                            Spacer()
                            if !searchText.isEmpty && matchCount > 0 {
                                Text("\(matchCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.1)))
                            }
                        }
                        .padding(.vertical, 2)
                        .tag(item)
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(width: 200)

            Divider()

            VStack(spacing: 0) {
                if !searchText.isEmpty && !filteredItems.isEmpty {
                    // Quick Search Highlights Banner
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Matches:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(filteredItems) { item in
                                Button {
                                    pane = item.pane
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: item.icon ?? item.pane.icon)
                                            .font(.system(size: 9))
                                        Text(item.title)
                                            .font(.system(size: 11, weight: pane == item.pane ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(Capsule().fill(pane == item.pane ? item.pane.tint.opacity(0.25) : Color.primary.opacity(0.06)))
                                    .foregroundStyle(pane == item.pane ? item.pane.tint : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .background(Color.primary.opacity(0.03))
                    Divider()
                } else if !searchText.isEmpty && filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No settings found for \"\(searchText)\"")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Button("Clear Search") { searchText = "" }
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if searchText.isEmpty || !filteredItems.isEmpty {
                    Group {
                        switch pane {
                        case .general: GeneralPane()
                        case .appearance: AppearancePane()
                        case .features: FeaturesPane()
                        case .media: MediaPane()
                        case .mirror: MirrorPane()
                        case .smarthome: SmarthomePane()
                        case .ai: AISettingsPane()
                        case .about: AboutPane()
                        }
                    }
                    .formStyle(.grouped)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 720, height: 580)
    }
}

private struct GeneralPane: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            }
            Section("Displays & Monitors") {
                Picker("Show OpenNotchi on", selection: $settings.displayTarget) {
                    ForEach(DisplayTarget.allCases) { target in
                        Label(target.displayName, systemImage: target.icon).tag(target)
                    }
                }
                Text(settings.displayTarget.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if NSScreen.screens.count > 1 {
                    HStack(spacing: 6) {
                        Image(systemName: "display.2")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("\(NSScreen.screens.count) monitors connected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            Section("Behavior") {
                Toggle("Haptic feedback when opening", isOn: $settings.hapticsEnabled)
                Toggle("Show live activity beside the notch", isOn: $settings.showLiveActivity)
                LabeledContent("Hover delay") {
                    HStack {
                        Slider(value: $settings.hoverDelay, in: 0...1, step: 0.05)
                        Text(String(format: "%.2fs", settings.hoverDelay))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            Section("Shortcut") {
                Toggle("Global shortcut to toggle the notch", isOn: $settings.hotKeyEnabled)
                if settings.hotKeyEnabled {
                    LabeledContent("Shortcut") { HotKeyRecorder() }
                }
            }
        }
    }
}

private struct AppearancePane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        Form {
            Section("Theme") {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(NotchTheme.allCases) { theme in
                        ThemeCard(theme: theme, isSelected: settings.theme == theme) {
                            settings.theme = theme
                        }
                    }
                }
                .padding(.vertical, 4)
                if !NotchTheme.liquidGlassAvailable,
                   settings.theme == .liquidGlass || settings.theme == .liquidGlassClear {
                    Text("Liquid Glass needs macOS 26 or later. Using Frosted instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if settings.theme == .adaptive || settings.theme == .albumArt {
                    Text("Changes with the artwork of the song that's playing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Accent color") {
                HStack(spacing: 10) {
                    ForEach(AccentChoice.allCases) { choice in
                        AccentSwatch(choice: choice, isSelected: settings.accent == choice) {
                            settings.accent = choice
                        }
                    }
                }
                .padding(.vertical, 2)
                Text(settings.accent.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shape & border") {
                Picker("Border", selection: $settings.borderStyle) {
                    ForEach(BorderStyle.allCases) { Text($0.displayName).tag($0) }
                }
                if settings.borderStyle != .none {
                    LabeledContent("Border width") {
                        HStack {
                            Slider(value: $settings.borderWidth, in: 0.5...4, step: 0.5)
                            Text(String(format: "%.1f", settings.borderWidth))
                                .monospacedDigit()
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                LabeledContent("Corner radius") {
                    HStack {
                        Slider(value: $settings.cornerRadius, in: 12...48, step: 2)
                        Text("\(Int(settings.cornerRadius))")
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }

            Section("Open Animation") {
                VStack(spacing: 5) {
                    ForEach(NotchAnimationStyle.allCases) { style in
                        AnimationRowView(
                            style: style,
                            isSelected: settings.openAnimation == style,
                            onSelect: {
                                settings.openAnimation = style
                            },
                            onPreview: {
                                settings.openAnimation = style
                                AppDelegate.shared?.previewNotch()
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct AnimationRowView: View {
    let style: NotchAnimationStyle
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: style.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(style.displayName)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(.primary)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text(style.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPreview) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    Text("Test")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.white.opacity(0.08))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Preview this open animation on the notch")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
}

private struct ThemeCard: View {
    @EnvironmentObject private var media: MediaManager
    let theme: NotchTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Busy backdrop so glass and frosted themes read as translucent.
                    LinearGradient(colors: [.orange, .pink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    NotchBackground(
                        theme: theme,
                        isOpen: true,
                        shape: RoundedRectangle(cornerRadius: 10),
                        artwork: media.artwork,
                        palette: media.palette
                    )
                    .padding(6)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.85)).frame(width: 16, height: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            Capsule().fill(.white.opacity(0.85)).frame(width: 34, height: 4)
                            Capsule().fill(.white.opacity(0.45)).frame(width: 24, height: 4)
                        }
                    }
                }
                .frame(height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.accentColor : .primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
                )

                Text(theme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AccentSwatch: View {
    let choice: AccentChoice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if choice == .artwork {
                    Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
                        .overlay(Image(systemName: "music.note").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                } else {
                    Circle().fill(choice.color)
                }
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(.primary.opacity(0.2), lineWidth: 1))
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .padding(-4)
                    .opacity(isSelected ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .help(choice.displayName)
    }
}

private struct FeaturesPane: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var accessibilityGranted = MediaKeyInterceptor.isTrusted

    var body: some View {
        Form {
            Section("Tabs") {
                Toggle("AI (Quota, Agents & Ask AI)", isOn: $settings.aiEnabled)
                Toggle("Eye-Contact Teleprompter", isOn: $settings.prompterTabEnabled)
                Toggle("Clipboard history", isOn: $settings.clipboardEnabled)
                Toggle("Timer", isOn: $settings.timerTabEnabled)
                Toggle("Mirror (camera)", isOn: $settings.mirrorTabEnabled)
                Toggle("Developer tools (ports, eyedropper, mic)", isOn: $settings.devToolsEnabled)
                Toggle("Notes, keep awake & Shortcuts", isOn: $settings.notesTabEnabled)
            }
            Section("Home") {
                Toggle("Lyrics (button on the artwork)", isOn: $settings.lyricsEnabled)
                Toggle("Today's calendar widget next to the player", isOn: $settings.calendarEnabled)
                if !settings.calendarEnabled {
                    Toggle("Audio spectrum deck next to the player", isOn: $settings.audioDeckEnabled)
                }
                Toggle("Show the current lyric line under the title", isOn: $settings.lyricsOnHome)
                    .disabled(!settings.lyricsEnabled)
                Toggle("Translate lyrics", isOn: $settings.lyricsTranslate)
                    .disabled(!settings.lyricsEnabled)
                if settings.lyricsTranslate {
                    Picker("Translate into", selection: $settings.lyricsTranslateTarget) {
                        ForEach(["id", "en", "ja", "ko", "zh-Hans", "es", "fr", "de", "ar", "pt", "it", "th", "vi"], id: \.self) { code in
                            Text(Locale.current.localizedString(forIdentifier: code) ?? code).tag(code)
                        }
                    }
                    TranslationIssueRow()
                }
                Toggle("Floating lyrics widget on the desktop", isOn: $settings.lyricsOverlayEnabled)
                    .disabled(!settings.lyricsEnabled)
                if settings.lyricsOverlayEnabled {
                    Slider(value: $settings.lyricsOverlayOpacity, in: 0...1) { Text("Widget background") }
                    Toggle("Show the next line", isOn: $settings.lyricsOverlayNextLine)
                    Toggle("Lock widget (clicks pass through)", isOn: $settings.lyricsOverlayLocked)
                    Button("Reset widget size and position") { AppDelegate.shared?.resetLyricsOverlay() }
                }
            }
            Section("Live activities") {
                Toggle("Charger connected", isOn: $settings.chargingPeekEnabled)
                Toggle("AirPods and Bluetooth devices", isOn: $settings.devicePeekEnabled)
                Toggle("Camera or microphone starts being used", isOn: $settings.privacyPeekEnabled)
                Toggle("Download finished in ~/Downloads", isOn: $settings.downloadPeekEnabled)
                Toggle("Network speed beside notch when active", isOn: $settings.networkLiveActivity)
                Toggle("Notchi, the mascot, when the notch is idle", isOn: $settings.showMascot)
                Toggle("Play sounds for important notifications", isOn: $settings.notificationSounds)
                Toggle("Show network traffic in header ticker", isOn: $settings.showStatsInHeader)
                Toggle("Volume & brightness HUD in the notch", isOn: $settings.hudEnabled)
                if settings.hudEnabled && !accessibilityGranted {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Needs Accessibility permission to catch the volume and brightness keys.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            // Unsigned builds look like a new app to macOS after every update.
                            Text("Already switched on? Select OpenNotchi, remove it with −, then add it again with +.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                        }
                        .controlSize(.small)
                    }
                }
            }
            Section("Reminders") {
                MeetingReminderSettings()
            }
            Section {
                LocationSettings()
            } header: {
                Text("Location")
            } footer: {
                Text("Used for weather and prayer times.")
            }
            Section("Prayer times") {
                PrayerSettings()
            }
            Section("Weather") {
                WeatherSettings()
            }
            Section("Markets") {
                MarketSettings()
            }
            Section {
                Text("Lyrics come from LRCLIB and weather from Open-Meteo, both free and open. Only the song details and your chosen location are sent.")
                Text("Clipboard history skips anything password managers mark as concealed.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = MediaKeyInterceptor.isTrusted
        }
    }
}

private struct MirrorPane: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section("Photobox") {
                PhotoboxSettings()
            }
            Section("Mirror") {
                Picker("Camera Device", selection: $settings.mirrorCameraID) {
                    Text("Automatic (Default)").tag("")
                    ForEach(CameraPreview.cameras, id: \.uniqueID) { camera in
                        Text(camera.localizedName).tag(camera.uniqueID)
                    }
                }
                if AVCaptureDevice.authorizationStatus(for: .video) == .denied || AVCaptureDevice.authorizationStatus(for: .video) == .restricted {
                    HStack {
                        Label("Camera access is disabled in macOS Privacy Settings.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                        }
                        .controlSize(.small)
                    }
                }
                Picker("Look", selection: $settings.mirrorEffect) {
                    ForEach(MirrorEffect.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Background", selection: $settings.mirrorBackground) {
                    ForEach(MirrorBackground.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Keep the notch open while using the Mirror", isOn: $settings.mirrorStaysOpen)
                Toggle("Ring light", isOn: $settings.mirrorRingLight)
                Toggle("Hand gestures: ✌️ photo, 👍 confetti, ✋ ring light", isOn: $settings.mirrorGestures)
                Text("Gestures and backgrounds are recognized on your Mac with Apple's Vision framework. Nothing leaves your Mac, and the camera only runs while the Mirror tab is open.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MediaPane: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager

    var body: some View {
        Form {
            Section("Playback & Style") {
                Picker("Artwork Style", selection: $settings.artworkStyle) {
                    ForEach(PlayerArtworkStyle.allCases) { style in
                        Label(style.displayName, systemImage: style.icon).tag(style)
                    }
                }
                Toggle("Ambient artwork aura glow", isOn: $settings.ambientAuraEnabled)
                Toggle("Show lyrics on home player", isOn: $settings.lyricsOnHome)
            }
            Section("Apps") {
                Toggle("Apple Music", isOn: $settings.appleMusicEnabled)
                Toggle("Spotify", isOn: $settings.spotifyEnabled)
            }
            Section("Spotify on other devices") {
                SpotifyConnectSettings()
            }
            Section("YouTube in your browser") {
                Toggle("YouTube and YouTube Music", isOn: $settings.youtubeEnabled)
                Toggle("Live video preview in the notch", isOn: $settings.videoPreviewEnabled)
                    .disabled(!settings.youtubeEnabled)
                if !media.browsersNeedingJavaScript.isEmpty {
                    Label("\(media.browsersNeedingJavaScript.joined(separator: ", ")) needs “Allow JavaScript from Apple Events” turned on.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Works with Chrome, Brave, Edge, Arc and Safari. Turn on JavaScript from Apple Events once:")
                    Text("• Chrome, Brave, Edge, Arc: View → Developer → Allow JavaScript from Apple Events")
                    Text("• Safari: Settings → Advanced → Show features for web developers, then Develop → Allow JavaScript from Apple Events")
                    Text("The preview is a muted copy of the video that only loads while the notch is open.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section {
                Text("macOS asks for permission to control each app the first time it's used. You can change this in System Settings → Privacy & Security → Automation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AboutPane: View {
    @EnvironmentObject private var updater: Updater

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            (Text("Open") + Text("Notchi").foregroundColor(.secondary))
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("Free and open source under the MIT license.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                if let update = updater.availableUpdate {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.cyan)
                        Text("Update v\(update.version) tersedia!")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.cyan)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.cyan.opacity(0.15)))
                }

                Button(updater.isChecking ? "Checking…" : "Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(updater.isChecking)

                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                    .toggleStyle(.checkbox)
                    .font(.callout)

                Button("Test Notch Update Banner") {
                    updater.simulateUpdateNotification()
                }
                .buttonStyle(.link)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SmarthomePane: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var smarthome = SmarthomeManager.shared
    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section("Smarthome Tab") {
                Toggle("Show Smarthome in Notch Tabs", isOn: $settings.smarthomeEnabled)
            }

            Section("Provider & Integration") {
                Picker("Integration Mode", selection: $settings.smarthomeProvider) {
                    ForEach(SmarthomeProviderType.allCases) { provider in
                        Label(provider.displayName, systemImage: provider == .demo ? "laptopcomputer" : (provider == .homeAssistant ? "house.fill" : "command")).tag(provider)
                    }
                }
                Text(settings.smarthomeProvider.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.smarthomeProvider == .homeAssistant {
                Section("Home Assistant Configuration") {
                    TextField("Server URL", text: $settings.homeAssistantURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Long-Lived Access Token", text: $settings.homeAssistantToken)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Test Connection") {
                            testConnection()
                        }
                        .disabled(isTesting || settings.homeAssistantURL.isEmpty)

                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        }

                        if let result = testResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.contains("Connected") ? .green : .red)
                        }
                    }

                    Text("Generate a token in Home Assistant: click your profile in the bottom-left → Long-Lived Access Tokens → Create Token.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if settings.smarthomeProvider == .shortcuts {
                Section("Apple Shortcuts Setup") {
                    Text("Name shortcuts matching scenes or devices: e.g. “Focus Work”, “Movie Night”, “Turn On AC”, “Turn Off Lights”.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Active Devices (\(smarthome.acDevices.count + smarthome.lightDevices.count + smarthome.switchDevices.count))") {
                ForEach(smarthome.acDevices) { ac in
                    HStack {
                        Label(ac.name, systemImage: "air.conditioner.horizontal.fill")
                        Spacer()
                        Text("\(Int(ac.targetTemperature))°C • \(ac.mode.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(smarthome.lightDevices) { light in
                    HStack {
                        Label(light.name, systemImage: "lightbulb.fill")
                        Spacer()
                        Text("\(Int(light.brightness * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(smarthome.switchDevices) { sw in
                    HStack {
                        Label(sw.name, systemImage: sw.icon)
                        Spacer()
                        Text(sw.isOn ? "On" : "Off")
                            .font(.caption)
                            .foregroundStyle(sw.isOn ? .green : .secondary)
                    }
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        smarthome.fetchHomeAssistantStates()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isTesting = false
            testResult = smarthome.connectionStatus
        }
    }
}

/// Explains why lyrics aren't being translated, with a shortcut to the language downloads.
private struct TranslationIssueRow: View {
    @EnvironmentObject private var lyrics: LyricsManager

    var body: some View {
        if let issue = lyrics.translationIssue {
            HStack {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!)
                }
                .controlSize(.small)
            }
        }
    }
}
