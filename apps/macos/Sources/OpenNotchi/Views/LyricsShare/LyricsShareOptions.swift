import SwiftUI

enum ShareMode: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case video = "Video"
    var id: String { rawValue }
}

enum CardAspectRatio: String, CaseIterable, Identifiable {
    case portrait = "4:5"
    case story = "9:16"
    case square = "1:1"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait: return "4:5 Post"
        case .story: return "9:16 Story"
        case .square: return "1:1 Square"
        }
    }

    var size: CGSize {
        switch self {
        case .portrait: return CGSize(width: 360, height: 450)
        case .story: return CGSize(width: 360, height: 640)
        case .square: return CGSize(width: 360, height: 360)
        }
    }
}

enum LyricFont: String, CaseIterable, Identifiable {
    case auto = "Auto", sans = "Sans", rounded = "Rounded", serif = "Serif", mono = "Mono", hand = "Handwritten"
    var id: String { rawValue }

    /// `auto` keeps the frame's own font.
    func font(_ original: Font, size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .auto: return original
        case .sans: return .system(size: size, weight: weight)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        case .hand: return .custom("Bradley Hand", size: size).weight(weight)
        }
    }
}

extension View {
    /// nil keeps the frame's own alignment.
    @ViewBuilder func lyricAlignment(_ align: TextAlignment?) -> some View {
        if let align {
            multilineTextAlignment(align)
                .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : align == .center ? .center : .trailing)
        } else {
            self
        }
    }
}

enum LyricCardStyle: String, CaseIterable, Identifiable {
    case aura, player, vhs, cassette, vinyl, glass, polaroid, paper, receipt, solid

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aura: return "Aura"
        case .player: return "Player"
        case .vhs: return "VHS 90s"
        case .cassette: return "Cassette"
        case .vinyl: return "Vinyl"
        case .glass: return "Glass"
        case .polaroid: return "Polaroid"
        case .paper: return "Paper"
        case .receipt: return "Receipt"
        case .solid: return "Solid"
        }
    }

    var icon: String {
        switch self {
        case .aura: return "sparkles"
        case .player: return "play.circle.fill"
        case .vhs: return "video.badge.waveform"
        case .cassette: return "opticaldisc"
        case .vinyl: return "record.circle"
        case .glass: return "cube.transparent"
        case .polaroid: return "photo.fill"
        case .paper: return "doc.text.fill"
        case .receipt: return "newspaper.fill"
        case .solid: return "square.fill"
        }
    }
}
