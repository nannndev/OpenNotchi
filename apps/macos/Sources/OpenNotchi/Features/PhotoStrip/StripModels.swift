import AppKit
import SwiftUI

/// Look of a photobox strip.
enum StripStyle: String, CaseIterable, Identifiable {
    // Trending looks first.
    case classic, receipt, social, player, postcard, scrapbook, coquette, desktop
    case film, polaroid, y2k, midnight, sakura, retro, newspaper, neon, pastel, love, album

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .receipt: return "Receipt"
        case .social: return "Social Post"
        case .player: return "Player"
        case .postcard: return "Postcard"
        case .scrapbook: return "Scrapbook"
        case .coquette: return "Coquette"
        case .desktop: return "Retro PC"
        case .midnight: return "Midnight"
        case .film: return "Film"
        case .polaroid: return "Polaroid"
        case .y2k: return "Y2K"
        case .sakura: return "Sakura"
        case .retro: return "Retro"
        case .newspaper: return "Newspaper"
        case .neon: return "Neon"
        case .pastel: return "Pastel Grid"
        case .love: return "Love"
        case .album: return "Now Playing"
        }
    }

    /// Two colors for the picker swatch.
    var swatch: [Color] {
        switch self {
        case .classic: return [.white, Color(white: 0.85)]
        case .receipt: return [Color(red: 0.97, green: 0.96, blue: 0.94), Color(white: 0.3)]
        case .social: return [.white, Color(red: 0.93, green: 0.29, blue: 0.4)]
        case .player: return [Color(red: 0.2, green: 0.75, blue: 0.4), Color(white: 0.08)]
        case .postcard: return [Color(red: 0.85, green: 0.22, blue: 0.22), Color(red: 0.13, green: 0.32, blue: 0.62)]
        case .scrapbook: return [Color(red: 0.91, green: 0.86, blue: 0.77), Color(red: 0.55, green: 0.8, blue: 0.7)]
        case .coquette: return [Color(red: 0.97, green: 0.84, blue: 0.88), Color(red: 0.76, green: 0.1, blue: 0.36)]
        case .desktop: return [Color(red: 0, green: 0.5, blue: 0.5), Color(white: 0.75)]
        case .midnight: return [Color(white: 0.2), .black]
        case .film: return [Color(red: 0.91, green: 0.64, blue: 0.23), Color(white: 0.08)]
        case .polaroid: return [Color(red: 0.96, green: 0.94, blue: 0.9), Color(red: 0.17, green: 0.23, blue: 0.4)]
        case .y2k: return [Color(red: 1, green: 0.54, blue: 0.85), Color(red: 0.54, green: 0.48, blue: 1)]
        case .sakura: return [Color(red: 1, green: 0.89, blue: 0.93), Color(red: 0.83, green: 0.42, blue: 0.55)]
        case .retro: return [Color(red: 0.91, green: 0.64, blue: 0.23), Color(red: 0.85, green: 0.34, blue: 0.17)]
        case .newspaper: return [Color(red: 0.93, green: 0.92, blue: 0.89), Color(white: 0.15)]
        case .neon: return [.cyan, Color(red: 1, green: 0.2, blue: 0.75)]
        case .pastel: return [Color(red: 0.81, green: 0.96, blue: 0.91), Color(red: 0.98, green: 0.85, blue: 0.75)]
        case .love: return [Color(red: 0.9, green: 0.22, blue: 0.27), .pink]
        case .album: return [.purple, .orange]
        }
    }

    var isGrid: Bool { self == .pastel }
}

/// Output shape: the classic tall strip, or a fixed size for a social post, story or postcard.
enum StripFormat: String, CaseIterable, Identifiable {
    case strip, story, post, postcard, square

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strip: return "Photo strip"
        case .story: return "Story 9:16"
        case .post: return "Post 4:5"
        case .postcard: return "Postcard 3:2"
        case .square: return "Square 1:1"
        }
    }

    var icon: String {
        switch self {
        case .strip: return "rectangle.split.1x2"
        case .story: return "iphone"
        case .post: return "rectangle.portrait"
        case .postcard: return "envelope"
        case .square: return "square"
        }
    }

    /// Height ÷ width, or nil when the height grows with the number of photos.
    var heightRatio: CGFloat? {
        switch self {
        case .strip: return nil
        case .story: return 16 / 9
        case .post: return 5 / 4
        case .postcard: return 3 / 2
        case .square: return 1
        }
    }
}

/// Photos per photobox session.
enum StripShots {
    static let choices = [1, 2, 3, 4, 6]
}

/// A sticker or stamp placed on the photo strip canvas.
struct PlacedSticker: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    /// Emoji string, SF symbol name, or badge text.
    var content: String
    /// If true, rendered as an authentic rubber stamp badge with double border.
    var isBadge: Bool = false
    /// Color for badge ("red", "pink", "green", "black", "gold", "blue", "purple").
    var badgeColor: String = "red"
    /// Normalized horizontal position (0.0 ... 1.0).
    var x: CGFloat = 0.5
    /// Normalized vertical position (0.0 ... 1.0).
    var y: CGFloat = 0.5
    /// Relative scale multiplier (default 1.0).
    var scale: CGFloat = 1.0
    /// Rotation angle in degrees (-180 ... 180).
    var rotation: Double = 0.0
}

enum StickerPresets {
    static let cute: [String] = ["🎀", "💖", "✨", "🌸", "🐱", "🍒", "🍓", "🧸", "✌️", "🍰", "🪞", "🌷", "💄", "🐰"]
    static let y2k: [String] = ["⭐", "✦", "💿", "⚡", "🕶️", "👾", "🛸", "🔥", "🎧", "🦋", "🎱", "💎", "🛹", "💫"]
    static let mood: [String] = ["💌", "💋", "🍀", "🫧", "🌙", "☁️", "🍿", "☕", "🎞️", "📸", "💐", "🎉", "🕊️", "🐾"]

    struct StampItem: Identifiable {
        var id: String { text }
        let text: String
        let color: String
    }

    static let stamps: [StampItem] = [
        StampItem(text: "APPROVED", color: "red"),
        StampItem(text: "BESTIES ♡", color: "pink"),
        StampItem(text: "MEMORIES", color: "green"),
        StampItem(text: "TOP SECRET", color: "black"),
        StampItem(text: "100% CUTE", color: "pink"),
        StampItem(text: "PHOTO ID", color: "black"),
        StampItem(text: "LUCKY ✦", color: "blue"),
        StampItem(text: "HARU FILM", color: "black"),
        StampItem(text: "VINTAGE", color: "gold"),
        StampItem(text: "『極上』", color: "red"),
        StampItem(text: "『最高』", color: "red"),
        StampItem(text: "XOXO", color: "pink"),
    ]
}

/// What's printed on the strip besides the photos.
struct StripInfo {
    /// The user's own text; replaces the style's title when set.
    var caption: String?
    var date = Date.now
    var songTitle: String?
    var artist: String?
    var artwork: NSImage?
    /// Where the song is, for the Player style's progress bar.
    var songPosition: Double?
    var songDuration: Double?
    var isPlaying = true

    /// The song that's playing now. `sample` fills in a placeholder song for previews when nothing plays.
    @MainActor
    init(caption: String? = nil, media: MediaManager, sample: Bool = false) {
        self.caption = caption
        if let song = media.info {
            songTitle = song.title
            artist = song.artist
            artwork = media.artwork
            songPosition = song.position(at: .now)
            songDuration = song.duration > 0 ? song.duration : nil
            isPlaying = song.isPlaying
        } else if sample {
            songTitle = "Midnight Drive"
            artist = "The Placeholders"
        }
    }

    init(
        caption: String? = nil, date: Date = .now, songTitle: String? = nil, artist: String? = nil,
        artwork: NSImage? = nil
    ) {
        self.caption = caption
        self.date = date
        self.songTitle = songTitle
        self.artist = artist
        self.artwork = artwork
    }
}
