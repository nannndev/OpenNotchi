import SwiftUI

/// Search Spotify (or the Apple Music library) and play a result. Fills the Home tab while open.
struct MusicSearchView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @ObservedObject private var spotify = SpotifyAuth.shared
    @Environment(\.notchAccent) private var accent
    let onClose: () -> Void

    @AppStorage("musicSearchSource") private var source: MusicSearch.Source = .spotify
    @State private var query = ""
    @State private var results: [MusicSearch.Track] = []
    @State private var searching = false
    @State private var message: String?
    @State private var playing: String?
    @FocusState private var focused: Bool

    private var appleMusicAvailable: Bool { MusicSearchView.appleMusicAvailable(settings) }
    private var spotifyAvailable: Bool { spotify.isLoggedIn }
    /// Spotify is used only when logged in; otherwise the library.
    private var effectiveSource: MusicSearch.Source { spotifyAvailable && (source == .spotify || !appleMusicAvailable) ? .spotify : .appleMusic }

    static func appleMusicAvailable(_ settings: AppSettings) -> Bool { settings.appleMusicEnabled && AppleMusicProvider().isInstalled }

    /// Search shows only when at least one source works: a Spotify login or the Music app.
    static func isAvailable(_ settings: AppSettings) -> Bool { SpotifyAuth.shared.isLoggedIn || appleMusicAvailable(settings) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(effectiveSource == .spotify ? "Search Spotify" : "Search your Music library", text: $query)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit { focused = true }
                    if searching {
                        ProgressView().controlSize(.mini)
                    } else if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                    }
                }
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? accent.highlight.opacity(0.5) : .white.opacity(0.08), lineWidth: 1))
                )

                if appleMusicAvailable && spotifyAvailable {
                    Picker("", selection: $source) {
                        Text("Spotify").tag(MusicSearch.Source.spotify)
                        Text("Music").tag(MusicSearch.Source.appleMusic)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 130)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Close search (Esc)")
                .accessibilityLabel("Close search")
            }

            Group {
                if let message, results.isEmpty {
                    placeholder(message, icon: "exclamationmark.magnifyingglass") { EmptyView() }
                } else if results.isEmpty {
                    placeholder(query.isEmpty ? emptyHint : (searching ? "Searching…" : "No results."), icon: "music.note.list") { EmptyView() }
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 2) {
                            ForEach(results) { track in
                                TrackRow(track: track, isStarting: playing == track.id, play: { play(track) }, queue: { queue(track) })
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let message, !results.isEmpty {
                Text(message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }
        }
        .onAppear { focused = true }
        .onExitCommand(perform: onClose)
        // Debounced: searches 300 ms after the last keystroke, and a newer query cancels the older one.
        .task(id: "\(effectiveSource.rawValue)|\(query)") {
            let q = query.trimmingCharacters(in: .whitespaces)
            guard !q.isEmpty else { results = []; message = nil; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            searching = true
            defer { searching = false }
            do {
                let found = effectiveSource == .spotify ? try await MusicSearch.spotify(q) : await MusicSearch.appleMusic(q)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    results = found
                    message = found.isEmpty && effectiveSource == .appleMusic && !AppleMusicProvider().isRunning ? "Open the Music app to search your library." : nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                message = error.localizedDescription
            }
        }
    }

    private var emptyHint: String {
        effectiveSource == .spotify
            ? "Type a song, artist or album."
            : "Type a song from your Music library. Connect Spotify in Settings › Media to search all of Spotify."
    }

    private func placeholder<A: View>(_ text: String, icon: String, @ViewBuilder action: () -> A) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 22, weight: .light)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            action()
        }
    }

    private func play(_ track: MusicSearch.Track) {
        playing = track.id
        message = nil
        Task {
            do {
                try await MusicSearch.play(track)
                try? await Task.sleep(for: .milliseconds(500))
                media.refresh()
                onClose()
            } catch {
                message = error.localizedDescription
            }
            playing = nil
        }
    }

    private func queue(_ track: MusicSearch.Track) {
        Task {
            do {
                try await MusicSearch.queue(track)
                withAnimation { message = nil }
            } catch {
                withAnimation { message = error.localizedDescription }
            }
        }
    }
}

private struct TrackRow: View {
    let track: MusicSearch.Track
    let isStarting: Bool
    let play: () -> Void
    let queue: () -> Void
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false
    @State private var queued = false

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                AsyncImage(url: track.artworkURL) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "music.note").foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if hovering || isStarting {
                    RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.45))
                    if isStarting {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "play.fill").font(.system(size: 12)).foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)

            if track.source == .spotify && hovering {
                Button {
                    queue()
                    withAnimation { queued = true }
                } label: {
                    Image(systemName: queued ? "checkmark" : "text.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(queued ? Color.green : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help("Add to queue")
                .accessibilityLabel("Add \(track.title) to queue")
                .transition(.opacity)
            }

            Text(Duration.seconds(track.duration).formatted(.time(pattern: .minuteSecond)))
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(hovering ? 0.08 : 0)))
        .contentShape(Rectangle())
        .onTapGesture(perform: play)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Play \(track.title) by \(track.artist)")
    }
}
