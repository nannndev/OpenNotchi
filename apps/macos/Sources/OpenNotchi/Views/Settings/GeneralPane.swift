import SwiftUI

struct GeneralPane: View {
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
                Toggle("Show battery in the open notch (the menu bar already shows it)", isOn: $settings.showHeaderBattery)
                Toggle("Trackpad gestures on the notch", isOn: $settings.closedNotchGesturesEnabled)
                Group {
                    Toggle("Swipe sideways on the closed notch to skip tracks", isOn: $settings.gestureSkipTrack)
                    Toggle("Scroll on the left of the closed notch for volume", isOn: $settings.gestureVolume)
                    Toggle("Scroll on the right of the closed notch for brightness", isOn: $settings.gestureBrightness)
                    Toggle("Swipe sideways on the open notch's tab bar to switch tabs", isOn: $settings.gestureSwitchTabs)
                }
                .padding(.leading, 18)
                .disabled(!settings.closedNotchGesturesEnabled)
                Text("Gestures only work on the notch itself, so the menu bar and scrolling inside a tab stay normal.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
