import Foundation

struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var album: String
    /// Seconds. 0 when unknown (e.g. radio streams).
    var duration: Double
    /// Seconds, as reported at `timestamp`.
    var position: Double
    var isPlaying: Bool
    var artworkURL: URL?
    var sourceID: String
    /// YouTube video ID when the source is a YouTube video (used for the live preview).
    var videoID: String? = nil
    var timestamp = Date()

    var trackKey: String { "\(sourceID)|\(title)|\(artist)|\(album)" }

    /// Position interpolated between polls so the progress bar moves smoothly.
    func position(at date: Date) -> Double {
        let elapsed = isPlaying ? date.timeIntervalSince(timestamp) : 0
        let value = position + elapsed
        return duration > 0 ? min(value, duration) : value
    }
}
