import AppKit

final class SpotifyProvider: MediaProvider {
    static let bundleID = "com.spotify.client"

    let id = SpotifyProvider.bundleID
    let displayName = "Spotify"
    let notificationName: String? = "com.spotify.client.PlaybackStateChanged"

    func fetch() -> NowPlayingInfo? {
        // Returned as a list so numbers aren't formatted with the user's locale.
        guard let result = tell("""
            set s to player state as string
            if s is "stopped" then return {s}
            set t to current track
            set art to ""
            try
                set art to artwork url of t
            end try
            return {s, name of t, artist of t, album of t, (duration of t) / 1000, player position, art}
            """), result.numberOfItems >= 6 else { return nil }

        return NowPlayingInfo(
            title: result.string(at: 2),
            artist: result.string(at: 3),
            album: result.string(at: 4),
            duration: result.double(at: 5),
            position: result.double(at: 6),
            isPlaying: result.string(at: 1) == "playing",
            artworkURL: URL(string: result.string(at: 7)),
            sourceID: id
        )
    }

    /// Spotify exposes artwork as a URL, which MediaManager downloads.
    func fetchArtwork() -> NSImage? { nil }

    func playPause() { tell("playpause") }
    func nextTrack() { tell("next track") }
    func previousTrack() { tell("previous track") }
    func seek(to seconds: Double) { tell("set player position to \(Int(seconds))") }
    func toggleShuffle() { tell("set shuffling to not shuffling") }
    func toggleRepeat() { tell("set repeating to not repeating") }
}
