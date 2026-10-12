import AppKit

final class AppleMusicProvider: MediaProvider {
    static let bundleID = "com.apple.Music"

    let id = AppleMusicProvider.bundleID
    let displayName = "Apple Music"
    let notificationName: String? = "com.apple.Music.playerInfo"

    func fetch() -> NowPlayingInfo? {
        guard let result = tell("""
            set s to player state as string
            if s is "stopped" then return {s}
            set t to current track
            set d to 0
            try
                set d to duration of t
            end try
            return {s, name of t, artist of t, album of t, d, player position}
            """), result.numberOfItems >= 6 else { return nil }

        return NowPlayingInfo(
            title: result.string(at: 2),
            artist: result.string(at: 3),
            album: result.string(at: 4),
            duration: result.double(at: 5),
            position: result.double(at: 6),
            isPlaying: result.string(at: 1) == "playing",
            artworkURL: nil,
            sourceID: id
        )
    }

    func fetchArtwork() -> NSImage? {
        guard let data = tell("""
            try
                return raw data of artwork 1 of current track
            end try
            """)?.data, !data.isEmpty else { return nil }
        return NSImage(data: data)
    }

    func playPause() { tell("playpause") }
    func nextTrack() { tell("next track") }
    func previousTrack() { tell("previous track") }
    func seek(to seconds: Double) { tell("set player position to \(Int(seconds))") }
    func toggleShuffle() { tell("set shuffle enabled to not (shuffle enabled)") }
    func toggleRepeat() { tell("if song repeat is off then set song repeat to all else if song repeat is all then set song repeat to one else set song repeat to off") }
}
