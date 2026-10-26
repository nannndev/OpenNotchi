import SwiftUI

/// Active photobox editing session.
struct PhotoboxSession: Identifiable {
    let id = UUID()
    var photos: [CGImage]
    var style: StripStyle
    var format: StripFormat
    var info: StripInfo
    var stickers: [PlacedSticker] = []
}

enum StickerTab: String, CaseIterable, Identifiable {
    case cute = "Cute"
    case y2k = "Y2K"
    case stamps = "Stamps"
    case custom = "Text"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cute: return "sparkles"
        case .y2k: return "star.fill"
        case .stamps: return "seal.fill"
        case .custom: return "character.cursor.ibeam"
        }
    }
}

/// Ink color of a rubber-stamp sticker, from its `PlacedSticker.badgeColor` name.
func stampColor(_ name: String) -> Color {
    switch name.lowercased() {
    case "pink": return Color(red: 0.95, green: 0.25, blue: 0.60)
    case "green": return Color(red: 0.12, green: 0.65, blue: 0.40)
    case "black": return Color(white: 0.2)
    case "gold": return Color(red: 0.92, green: 0.65, blue: 0.15)
    case "blue": return Color(red: 0.20, green: 0.58, blue: 0.95)
    case "purple": return Color(red: 0.70, green: 0.35, blue: 0.90)
    default: return Color(red: 0.90, green: 0.20, blue: 0.20)  // red
    }
}
