import SwiftUI

enum FeaturesSubTab: String, CaseIterable, Identifiable {
    case tabs = "Tabs & Modules"
    case liveActivities = "Live Activities"
    case homeLyrics = "Player & Lyrics"
    case widgets = "Locale & Widgets"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tabs: return "square.grid.2x2.fill"
        case .liveActivities: return "bell.badge.fill"
        case .homeLyrics: return "music.note.list"
        case .widgets: return "globe.asia.australia.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .tabs: return "Choose which tabs appear in the expanded notch header"
        case .liveActivities: return "Configure closed-notch indicators, HUDs, and drop-down banners"
        case .homeLyrics: return "Customize the Home player, synced karaoke lyrics, and idle screen"
        case .widgets: return "Set up location, weather, calendar reminders, prayer times, and markets"
        }
    }
}

struct FeaturesPane: View {
    @EnvironmentObject private var settings: AppSettings
    @AppStorage("featuresSubTab") private var subTab: FeaturesSubTab = .tabs
    @State private var accessibilityGranted = MediaKeyInterceptor.isTrusted

    private let moduleColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            subTabHeaderBar
            Divider()

            Group {
                switch subTab {
                case .tabs:
                    tabsModulesContent
                case .liveActivities:
                    liveActivitiesContent
                case .homeLyrics:
                    homeLyricsContent
                case .widgets:
                    widgetsLocaleContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = MediaKeyInterceptor.isTrusted
        }
    }

    // MARK: - Sticky Sub-Navigation Header

    private var subTabHeaderBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(FeaturesSubTab.allCases) { item in
                    let selected = subTab == item
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            subTab = item
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.rawValue)
                                .font(.system(size: 12, weight: selected ? .semibold : .medium))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                                )
                        )
                        .foregroundStyle(selected ? Color.accentColor : .primary)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(subTab.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if subTab == .tabs {
                    HStack(spacing: 6) {
                        Button("Enable All") {
                            setAllTabs(true)
                        }
                        .controlSize(.mini)
                        Button("Minimal") {
                            setAllTabs(false)
                        }
                        .controlSize(.mini)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - 1. Tabs & Modules (2-Column Bento Grid, Zero Scroll)

    private var tabsModulesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: moduleColumns, spacing: 10) {
                    FeatureModuleCard(
                        title: "AI Hub",
                        subtitle: "Quota gauges, Agent monitor & Ask AI",
                        icon: "sparkles",
                        tint: .purple,
                        isOn: $settings.aiEnabled
                    )
                    FeatureModuleCard(
                        title: "Teleprompter",
                        subtitle: "Eye-contact script scroller under camera",
                        icon: "text.viewfinder",
                        tint: .cyan,
                        isOn: $settings.prompterTabEnabled
                    )
                    FeatureModuleCard(
                        title: "Clipboard History",
                        subtitle: "Searchable text & image history",
                        icon: "doc.on.clipboard.fill",
                        tint: .blue,
                        isOn: $settings.clipboardEnabled
                    )
                    FeatureModuleCard(
                        title: "Timer & Soundscapes",
                        subtitle: "Pomodoro focus timer & ambient mixer",
                        icon: "timer",
                        tint: .orange,
                        isOn: $settings.timerTabEnabled
                    )
                    FeatureModuleCard(
                        title: "Camera Mirror & Studio",
                        subtitle: "1080p mirror, gestures & Photobox strip",
                        icon: "camera.fill",
                        tint: .teal,
                        isOn: $settings.mirrorTabEnabled
                    )
                    FeatureModuleCard(
                        title: "Developer Tools",
                        subtitle: "Ports, CI builds, eyedropper & mic hub",
                        icon: "terminal.fill",
                        tint: .indigo,
                        isOn: $settings.devToolsEnabled
                    )
                    FeatureModuleCard(
                        title: "Smarthome Hub",
                        subtitle: "AC climate dial, lamps & quick scenes",
                        icon: "air.conditioner.horizontal.fill",
                        tint: .green,
                        isOn: $settings.smarthomeEnabled
                    )
                    FeatureModuleCard(
                        title: "Markets Watchlist",
                        subtitle: "IDX, US stocks, crypto & forex quotes",
                        icon: "chart.line.uptrend.xyaxis",
                        tint: .mint,
                        isOn: $settings.marketsEnabled
                    )
                    FeatureModuleCard(
                        title: "Notes & Keep Awake",
                        subtitle: "Quick scratchpad, caffeine & Shortcuts",
                        icon: "note.text",
                        tint: .yellow,
                        isOn: $settings.notesTabEnabled
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Home and File Tray (AirDrop & Instant OCR) are always enabled as core tabs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
            .padding(18)
        }
    }

    // MARK: - 2. Live Activities & HUD

    private var liveActivitiesContent: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Text("Quick Preview:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Charger") {
                        AppDelegate.shared?.screenManager.showPeek(.charging(level: 88))
                    }
                    Button("AirPods") {
                        AppDelegate.shared?.screenManager.showPeek(
                            .device(
                                name: "AirPods Pro",
                                symbol: "airpodspro",
                                battery: 94,
                                info: DeviceBatteryInfo(left: 94, right: 92, caseBattery: 85)
                            )
                        )
                    }
                    Button("Volume HUD") {
                        AppDelegate.shared?.screenManager.showPeek(.volume(level: 0.72, muted: false))
                    }
                    Button("CI Passed") {
                        CIBuildMonitor.shared.triggerSimulatedBanner(passed: true)
                    }
                }
                .controlSize(.small)
            }

            Section("Hardware & System Peeks") {
                Toggle("Charger connected HUD", isOn: $settings.chargingPeekEnabled)
                Toggle("AirPods & Bluetooth battery drop-down card", isOn: $settings.devicePeekEnabled)
                Toggle("Camera or microphone privacy indicator", isOn: $settings.privacyPeekEnabled)
                Toggle("Replace macOS Volume & Brightness HUD in the notch", isOn: $settings.hudEnabled)
                if settings.hudEnabled && !accessibilityGranted {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Label(
                                "Needs Accessibility permission to intercept volume & brightness keys.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(.orange)
                            Text("Already switched on? Select OpenNotchi, remove it with −, then add it again with +.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            )
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Background & Developer Activity") {
                Toggle("GitHub CI & local build status beside closed notch", isOn: $settings.ciLiveActivity)
                Toggle("Drop-down banner when a GitHub Actions workflow finishes", isOn: $settings.ciNotifyBanner)
                Toggle("Download finished banner (~/Downloads)", isOn: $settings.downloadPeekEnabled)
                Toggle("Live network download/upload speed beside closed notch", isOn: $settings.networkLiveActivity)
                Toggle("Show network traffic in open notch header", isOn: $settings.showStatsInHeader)
                Toggle("Notchi mascot beside closed notch when idle", isOn: $settings.showMascot)
                Toggle("Play sound effects for important banners", isOn: $settings.notificationSounds)
            }
        }
    }

    // MARK: - 3. Player & Lyrics

    private var homeLyricsContent: some View {
        Form {
            Section("Home Tab & Synchronized Lyrics") {
                Toggle("Today's calendar widget next to the player", isOn: $settings.calendarEnabled)
                if !settings.calendarEnabled {
                    Toggle("Audio spectrum deck next to the player", isOn: $settings.audioDeckEnabled)
                }
                Toggle("Lyrics button on the album artwork", isOn: $settings.lyricsEnabled)
                Toggle("Show current lyric line under song title", isOn: $settings.lyricsOnHome)
                    .disabled(!settings.lyricsEnabled)
                Toggle("Real-time lyrics translation", isOn: $settings.lyricsTranslate)
                    .disabled(!settings.lyricsEnabled)
                if settings.lyricsTranslate {
                    Picker("Translate into", selection: $settings.lyricsTranslateTarget) {
                        ForEach(
                            ["id", "en", "ja", "ko", "zh-Hans", "es", "fr", "de", "ar", "pt", "it", "th", "vi"],
                            id: \.self
                        ) { code in
                            Text(Locale.current.localizedString(forIdentifier: code) ?? code).tag(code)
                        }
                    }
                    TranslationIssueRow()
                }
            }

            Section("Floating Desktop Lyrics Overlay") {
                Toggle("Show floating lyrics widget on the desktop", isOn: $settings.lyricsOverlayEnabled)
                    .disabled(!settings.lyricsEnabled)
                if settings.lyricsOverlayEnabled {
                    Slider(value: $settings.lyricsOverlayOpacity, in: 0...1) { Text("Widget background opacity") }
                    Toggle("Show upcoming next lyric line", isOn: $settings.lyricsOverlayNextLine)
                    Toggle("Lock widget (clicks pass through)", isOn: $settings.lyricsOverlayLocked)
                    Button("Reset widget size and position") { AppDelegate.shared?.resetLyricsOverlay() }
                        .controlSize(.small)
                }
            }

            Section {
                HStack {
                    Toggle("Show automatically when Mac sits idle", isOn: $settings.nowPlayingScreenEnabled)
                    Spacer()
                    Button("Preview Full-Screen") { AppDelegate.shared?.nowPlayingScreen?.show() }
                        .controlSize(.small)
                }
                if settings.nowPlayingScreenEnabled {
                    Picker("Show after", selection: $settings.nowPlayingScreenIdleMinutes) {
                        ForEach([0.5, 1, 2, 5, 10, 15], id: \.self) { m in
                            Text(m < 1 ? "30 seconds" : "\(Int(m)) minute\(m == 1 ? "" : "s")").tag(m)
                        }
                    }
                    Toggle("Only while charging", isOn: $settings.nowPlayingScreenOnlyCharging)
                }
                Picker("Background style", selection: $settings.nowPlayingScreenBackground) {
                    ForEach(NowPlayingBackground.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Show synced lyrics", isOn: $settings.nowPlayingScreenLyrics)
                    .disabled(!settings.lyricsEnabled)
                if settings.nowPlayingScreenLyrics {
                    Picker("Lyrics size", selection: $settings.nowPlayingScreenTextScale) {
                        Text("Small").tag(0.8)
                        Text("Medium").tag(1.0)
                        Text("Large").tag(1.3)
                    }
                    .pickerStyle(.segmented)
                }
                Toggle("Show clock and date", isOn: $settings.nowPlayingScreenClock)
                if NSScreen.screens.count > 1 {
                    Picker("Target display", selection: $settings.nowPlayingScreenDisplay) {
                        Text("Main display").tag("main")
                        ForEach(NSScreen.screens, id: \.localizedName) { Text($0.localizedName).tag($0.localizedName) }
                    }
                }
            } header: {
                Text("Full-Screen Idle Player")
            } footer: {
                Text("Shortcuts: Space play/pause, ← → skip, T translate, L lyrics, B background, Esc close.")
            }
        }
    }

    // MARK: - 4. Locale & Widgets

    private var widgetsLocaleContent: some View {
        Form {
            Section {
                LocationSettings()
                WeatherSettings()
            } header: {
                Text("Location & Weather")
            } footer: {
                Text("Weather comes from Open-Meteo (free, no API key). Location is also used for offline prayer times.")
            }

            Section("Calendar & Meeting Reminders") {
                MeetingReminderSettings()
            }

            Section("Prayer Times") {
                PrayerSettings()
            }

            Section("Markets & Tickers") {
                MarketSettings()
            }
        }
    }

    private func setAllTabs(_ enabled: Bool) {
        settings.aiEnabled = enabled
        settings.prompterTabEnabled = enabled
        settings.clipboardEnabled = enabled
        settings.timerTabEnabled = enabled
        settings.mirrorTabEnabled = enabled
        settings.devToolsEnabled = enabled
        settings.smarthomeEnabled = enabled
        settings.marketsEnabled = enabled
        settings.notesTabEnabled = enabled
    }
}

private struct FeatureModuleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.secondary.opacity(0.25)))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(isOn ? tint.opacity(0.08) : Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isOn ? tint.opacity(0.3) : Color.primary.opacity(0.07), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 11))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                isOn.toggle()
            }
        }
    }
}

/// Explains why lyrics aren't being translated, with a shortcut to the language downloads.
struct TranslationIssueRow: View {
    @EnvironmentObject private var lyrics: LyricsManager

    var body: some View {
        if let issue = lyrics.translationIssue {
            HStack {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Button("Open Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension")!)
                }
                .controlSize(.small)
            }
        }
    }
}
