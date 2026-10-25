import SwiftUI

struct MediaPane: View {
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
                    Label(
                        "\(media.browsersNeedingJavaScript.joined(separator: ", ")) needs “Allow JavaScript from Apple Events” turned on.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Works with Chrome, Brave, Edge, Arc and Safari. Turn on JavaScript from Apple Events once:")
                    Text("• Chrome, Brave, Edge, Arc: View → Developer → Allow JavaScript from Apple Events")
                    Text(
                        "• Safari: Settings → Advanced → Show features for web developers, then Develop → Allow JavaScript from Apple Events"
                    )
                    Text("The preview is a muted copy of the video that only loads while the notch is open.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Section {
                Text(
                    "macOS asks for permission to control each app the first time it's used. You can change this in System Settings → Privacy & Security → Automation."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}
