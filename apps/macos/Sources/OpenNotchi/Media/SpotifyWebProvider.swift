import AppKit

/// Spotify playing on any device (iPhone, speaker, TV…) through the Spotify Web API.
/// Reading works on every account; skipping and pausing need Spotify Premium.
final class SpotifyWebProvider: MediaProvider {
    static let providerID = "spotify-web"

    let id = SpotifyWebProvider.providerID
    let displayName = "Spotify (other devices)"
    let notificationName: String? = nil
    var showsInLauncher: Bool { false }

    var isRunning: Bool { SpotifyAuth.shared.isLoggedIn }

    /// Set when Spotify rejects a playback command (Premium is required for those).
    private(set) var needsPremium = false

    private let auth = SpotifyAuth.shared
    private let lock = NSLock()
    private var cached: NowPlayingInfo?
    private var lastRequest = Date.distantPast
    private var inFlight = false

    /// Returns the latest known state right away and refreshes it in the background,
    /// so a slow network never holds up the other players.
    func fetch() -> NowPlayingInfo? {
        refreshIfNeeded()
        return lock.withLock { cached }
    }

    func fetchArtwork() -> NSImage? { nil }

    private func refreshIfNeeded() {
        let shouldStart: Bool = lock.withLock {
            guard !inFlight, Date().timeIntervalSince(lastRequest) > 2.5 else { return false }
            inFlight = true
            lastRequest = Date()
            return true
        }
        guard shouldStart else { return }

        auth.withAccessToken { [weak self] token in
            guard let self, let token else {
                self?.finish(with: nil)
                return
            }
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player?additional_types=episode")!, timeoutInterval: 8)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let started = Date()
            URLSession.shared.dataTask(with: request) { data, response, _ in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 204 {
                    self.finish(with: nil) // Nothing playing on any device.
                } else if status == 200, let data {
                    // Assume the reported progress was measured halfway through the request.
                    let measuredAt = started.addingTimeInterval(Date().timeIntervalSince(started) / 2)
                    self.finish(with: Self.parse(data, measuredAt: measuredAt))
                } else {
                    self.lock.withLock { self.inFlight = false }
                }
            }.resume()
        }
    }

    private func finish(with info: NowPlayingInfo?) {
        lock.withLock {
            cached = info
            inFlight = false
        }
    }

    private static func parse(_ data: Data, measuredAt: Date) -> NowPlayingInfo? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = json["item"] as? [String: Any],
              let title = item["name"] as? String else { return nil }

        let artists = (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        let show = (item["show"] as? [String: Any])?["name"] as? String
        let album = item["album"] as? [String: Any]
        let images = (album?["images"] as? [[String: Any]]) ?? (item["images"] as? [[String: Any]]) ?? []
        let device = json["device"] as? [String: Any]
        let deviceName = device?["name"] as? String

        // Hide the device label when it's this Mac.
        let isThisMac = deviceName != nil && deviceName == Host.current().localizedName

        return NowPlayingInfo(
            title: title,
            artist: artists?.joined(separator: ", ") ?? show ?? "",
            album: album?["name"] as? String ?? show ?? "",
            duration: (item["duration_ms"] as? Double ?? 0) / 1000,
            position: (json["progress_ms"] as? Double ?? 0) / 1000,
            isPlaying: json["is_playing"] as? Bool ?? false,
            artworkURL: (images.first?["url"] as? String).flatMap(URL.init(string:)),
            sourceID: providerID,
            remoteDevice: isThisMac ? nil : deviceName,
            timestamp: measuredAt
        )
    }

    // MARK: - Commands (Premium only)

    func playPause() {
        let playing = lock.withLock { cached?.isPlaying ?? false }
        send("PUT", playing ? "/me/player/pause" : "/me/player/play")
    }

    func nextTrack() { send("POST", "/me/player/next") }
    func previousTrack() { send("POST", "/me/player/previous") }
    func seek(to seconds: Double) { send("PUT", "/me/player/seek?position_ms=\(Int(seconds * 1000))") }

    private func send(_ method: String, _ path: String) {
        auth.withAccessToken { [weak self] token in
            guard let token else { return }
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1\(path)")!)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: request) { _, response, _ in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                self?.needsPremium = status == 403
                // Pick up the change sooner than the next scheduled poll.
                self?.lock.withLock { self?.lastRequest = .distantPast }
            }.resume()
        }
    }
}
