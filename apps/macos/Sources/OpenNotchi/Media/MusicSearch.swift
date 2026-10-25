import AppKit
import Foundation

/// Finds songs and starts them: Spotify through the Web API (needs the Spotify login from Settings › Media),
/// Apple Music through the user's library.
enum MusicSearch {
    enum Source: String { case spotify, appleMusic }

    struct Track: Identifiable, Equatable {
        var id: String { uri }
        /// "spotify:track:…" or the Apple Music persistent ID.
        let uri: String
        let title: String
        let artist: String
        let album: String
        let artworkURL: URL?
        let duration: Double
        let source: Source
    }

    enum Failure: LocalizedError {
        case notLoggedIn, message(String)
        var errorDescription: String? {
            switch self {
            case .notLoggedIn: return "Connect Spotify in Settings › Media to search."
            case .message(let m): return m
            }
        }
    }

    // MARK: Spotify

    static func spotify(_ query: String) async throws -> [Track] {
        let token = try await spotifyToken()
        var c = URLComponents(string: "https://api.spotify.com/v1/search")!
        c.queryItems = [.init(name: "q", value: query), .init(name: "type", value: "track"), .init(name: "limit", value: "10")]
        var req = URLRequest(url: c.url!, timeoutInterval: 8)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            // Show Spotify's own reason; "failed" alone doesn't say whether it's the login, the app or the query.
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let reason = (json?["error"] as? [String: Any])?["message"] as? String
            NSLog("OpenNotchi Spotify search HTTP \(status): \(String(data: data, encoding: .utf8) ?? "")")
            throw Failure.message("Spotify search failed (HTTP \(status)\(reason.map { ": \($0)" } ?? "")).")
        }
        return parseSpotify(data)
    }

    static func parseSpotify(_ data: Data) -> [Track] {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let items = ((json?["tracks"] as? [String: Any])?["items"] as? [[String: Any]]) ?? []
        return items.compactMap { item in
            guard let uri = item["uri"] as? String, let name = item["name"] as? String else { return nil }
            let album = item["album"] as? [String: Any]
            let images = album?["images"] as? [[String: Any]] ?? []
            return Track(
                uri: uri,
                title: name,
                artist: (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "",
                album: album?["name"] as? String ?? "",
                // The smallest image is enough for a row thumbnail.
                artworkURL: (images.last?["url"] as? String).flatMap(URL.init(string:)),
                duration: (item["duration_ms"] as? Double ?? 0) / 1000,
                source: .spotify
            )
        }
    }

    private static func spotifyToken() async throws -> String {
        let token: String? = await withCheckedContinuation { c in SpotifyAuth.shared.withAccessToken { c.resume(returning: $0) } }
        guard let token else { throw Failure.notLoggedIn }
        return token
    }

    /// The Spotify app on this Mac plays it right away (no Premium needed); otherwise the Web API plays it
    /// on the active device (Premium); otherwise the track opens in Spotify.
    static func play(_ track: Track) async throws {
        switch track.source {
        case .appleMusic:
            let ok = await runScript("""
                tell application id "com.apple.Music"
                    play (first track of library playlist 1 whose persistent ID is "\(track.uri)")
                end tell
                """)
            if !ok { throw Failure.message("Couldn't play it in Music.") }

        case .spotify:
            if !NSRunningApplication.runningApplications(withBundleIdentifier: SpotifyProvider.bundleID).isEmpty {
                if await runScript("tell application id \"\(SpotifyProvider.bundleID)\" to play track \"\(track.uri)\"") { return }
            }
            if let token = try? await spotifyToken(), await spotifyAPI("PUT", "/me/player/play", token: token, body: ["uris": [track.uri]]) == 204 {
                return
            }
            await MainActor.run { _ = URL(string: track.uri).map { NSWorkspace.shared.open($0) } }
        }
    }

    /// Adds to the Spotify queue (Premium).
    static func queue(_ track: Track) async throws {
        let token = try await spotifyToken()
        let path = "/me/player/queue?uri=\(track.uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? track.uri)"
        switch await spotifyAPI("POST", path, token: token) {
        case 200, 204: return
        case 403: throw Failure.message("Adding to the queue needs Spotify Premium.")
        case 404: throw Failure.message("Start playing something in Spotify first.")
        default: throw Failure.message("Couldn't add it to the queue.")
        }
    }

    private static func spotifyAPI(_ method: String, _ path: String, token: String, body: [String: Any]? = nil) async -> Int {
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1\(path)")!, timeoutInterval: 8)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let resp = try? await URLSession.shared.data(for: req).1
        return (resp as? HTTPURLResponse)?.statusCode ?? 0
    }

    // MARK: Apple Music library

    static func appleMusic(_ query: String) async -> [Track] {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: AppleMusicProvider.bundleID).isEmpty else { return [] }
        let q = query.replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: "\"", with: "")
        let result: NSAppleEventDescriptor? = await withCheckedContinuation { c in
            AppleScriptRunner.queue.async {
                c.resume(returning: AppleScriptRunner.run("""
                    tell application id "com.apple.Music"
                        set out to {}
                        set found to (search library playlist 1 for "\(q)" only songs)
                        set n to count of found
                        if n > 12 then set n to 12
                        repeat with i from 1 to n
                            set t to item i of found
                            set end of out to {persistent ID of t, name of t, artist of t, album of t, duration of t}
                        end repeat
                        return out
                    end tell
                    """))
            }
        }
        guard let result, result.numberOfItems > 0 else { return [] }
        return (1...result.numberOfItems).compactMap { i in
            guard let row = result.atIndex(i), row.numberOfItems >= 5 else { return nil }
            return Track(uri: row.string(at: 1), title: row.string(at: 2), artist: row.string(at: 3), album: row.string(at: 4),
                         artworkURL: nil, duration: row.double(at: 5), source: .appleMusic)
        }
    }

    private static func runScript(_ source: String) async -> Bool {
        await withCheckedContinuation { c in
            AppleScriptRunner.queue.async { c.resume(returning: AppleScriptRunner.run(source) != nil) }
        }
    }
}
