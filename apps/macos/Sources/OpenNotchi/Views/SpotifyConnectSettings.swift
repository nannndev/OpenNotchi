import SwiftUI

/// Connect a Spotify account to see and control playback on other devices.
struct SpotifyConnectSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var auth = SpotifyAuth.shared
    @State private var showClientID = false

    var body: some View {
        Toggle("Show Spotify playing on other devices", isOn: $settings.spotifyRemoteEnabled)

        if settings.spotifyRemoteEnabled {
            LabeledContent("Account") {
                if auth.isLoggedIn {
                    HStack {
                        Label(auth.accountName ?? "Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Button("Disconnect") { auth.disconnect() }
                    }
                } else {
                    Button {
                        auth.connect()
                    } label: {
                        if auth.isAuthorizing {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Connect Spotify")
                        }
                    }
                    .disabled(auth.isAuthorizing)
                }
            }

            if let error = auth.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            DisclosureGroup("Use your own Spotify Client ID", isExpanded: $showClientID) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Client ID", text: $settings.spotifyClientID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("Spotify only lets 25 people use a new developer app, so you may need your own (free, about two minutes): create an app at developer.spotify.com, add the redirect URI below, tick Web API, then paste its Client ID here.")
                    HStack {
                        Text(SpotifyAuth.redirectURI)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SpotifyAuth.redirectURI, forType: .string)
                        }
                        .controlSize(.small)
                        Spacer()
                        Link("Open Spotify Developer", destination: URL(string: "https://developer.spotify.com/dashboard")!)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }

            Text("See what's playing on your iPhone, speaker or TV, with lyrics. Skipping and pausing other devices need Spotify Premium.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
