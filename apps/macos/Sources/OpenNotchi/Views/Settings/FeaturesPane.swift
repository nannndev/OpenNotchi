import SwiftUI

struct FeaturesPane: View {
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
                        ForEach(
                            ["id", "en", "ja", "ko", "zh-Hans", "es", "fr", "de", "ar", "pt", "it", "th", "vi"],
                            id: \.self
                        ) { code in
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
            Section {
                Toggle("Show automatically when the Mac sits idle", isOn: $settings.nowPlayingScreenEnabled)
                if settings.nowPlayingScreenEnabled {
                    Picker("Show after", selection: $settings.nowPlayingScreenIdleMinutes) {
                        ForEach([0.5, 1, 2, 5, 10, 15], id: \.self) { m in
                            Text(m < 1 ? "30 seconds" : "\(Int(m)) minute\(m == 1 ? "" : "s")").tag(m)
                        }
                    }
                    Toggle("Only while charging", isOn: $settings.nowPlayingScreenOnlyCharging)
                }
                Picker("Background", selection: $settings.nowPlayingScreenBackground) {
                    ForEach(NowPlayingBackground.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Lyrics", isOn: $settings.nowPlayingScreenLyrics)
                    .disabled(!settings.lyricsEnabled)
                if settings.nowPlayingScreenLyrics {
                    Picker("Lyrics size", selection: $settings.nowPlayingScreenTextScale) {
                        Text("Small").tag(0.8)
                        Text("Medium").tag(1.0)
                        Text("Large").tag(1.3)
                    }
                    .pickerStyle(.segmented)
                    Toggle("Translate lyrics", isOn: $settings.lyricsTranslate)
                }
                Toggle("Clock and date", isOn: $settings.nowPlayingScreenClock)
                if NSScreen.screens.count > 1 {
                    Picker("Display", selection: $settings.nowPlayingScreenDisplay) {
                        Text("Main display").tag("main")
                        ForEach(NSScreen.screens, id: \.localizedName) { Text($0.localizedName).tag($0.localizedName) }
                    }
                }
                HStack {
                    Spacer()
                    Button("Preview") { AppDelegate.shared?.nowPlayingScreen?.show() }
                }
            } header: {
                Text("Full-screen player")
            } footer: {
                Text(
                    "Space plays or pauses, ← → skip, T translates, L shows lyrics, B switches the background, Esc closes. It also opens from the ⤢ button on the player. macOS doesn't let apps change the lock screen, so this shows on top of your desktop; keep it shorter than your screen saver."
                )
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
                            Label(
                                "Needs Accessibility permission to catch the volume and brightness keys.",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(.orange)
                            // Unsigned builds look like a new app to macOS after every update.
                            Text("Already switched on? Select OpenNotchi, remove it with −, then add it again with +.")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        Spacer()
                        Button("Open Settings") {
                            NSWorkspace.shared.open(
                                URL(
                                    string:
                                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            )
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
                Text(
                    "Lyrics come from LRCLIB and weather from Open-Meteo, both free and open. Only the song details and your chosen location are sent."
                )
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
