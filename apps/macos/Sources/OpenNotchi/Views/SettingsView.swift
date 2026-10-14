import AVFoundation
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case features = "Features"
    case media = "Media"
    case mirror = "Mirror"
    case smarthome = "Smarthome"
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
        case .about: return .indigo
        }
    }
}

struct SettingsView: View {
    @AppStorage("settingsPane") private var pane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPane.allCases, selection: $pane) { item in
                Label {
                    Text(item.rawValue)
                } icon: {
                    Image(systemName: item.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(item.tint.gradient))
                }
                .padding(.vertical, 2)
                .tag(item)
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            Divider()

            Group {
                switch pane {
                case .general: GeneralPane()
                case .appearance: AppearancePane()
                case .features: FeaturesPane()
                case .media: MediaPane()
                case .mirror: MirrorPane()
                case .smarthome: SmarthomePane()
                case .about: AboutPane()
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 560)
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
                Toggle("Eye-Contact Teleprompter", isOn: $settings.prompterTabEnabled)
                Toggle("Clipboard history", isOn: $settings.clipboardEnabled)
                Toggle("Timer", isOn: $settings.timerTabEnabled)
                Toggle("Mirror (camera)", isOn: $settings.mirrorTabEnabled)
                Toggle("Developer tools (ports, eyedropper, mic)", isOn: $settings.devToolsEnabled)
            }
            Section("Home") {
                Toggle("Lyrics (button on the artwork)", isOn: $settings.lyricsEnabled)
                Toggle("Today's calendar widget next to the player", isOn: $settings.calendarEnabled)
                if !settings.calendarEnabled {
                    Toggle("Audio spectrum deck next to the player", isOn: $settings.audioDeckEnabled)
                }
                Toggle("Show the current lyric line under the title", isOn: $settings.lyricsOnHome)
                    .disabled(!settings.lyricsEnabled)
            }
            Section("Live activities") {
                Toggle("Charger connected", isOn: $settings.chargingPeekEnabled)
                Toggle("AirPods and Bluetooth devices", isOn: $settings.devicePeekEnabled)
                Toggle("Network speed beside notch when active", isOn: $settings.networkLiveActivity)
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
