import SwiftUI

/// A short-lived event shown beside the closed notch, e.g. "charger connected".
enum Peek: Equatable {
    case charging(level: Int)
    case device(name: String, symbol: String, battery: Int?)
    case volume(level: Float, muted: Bool)
    case brightness(level: Float)
    /// A reminder that grows below the notch, with an optional action button.
    case banner(Banner)

    /// How long the peek stays visible.
    var duration: TimeInterval {
        switch self {
        case .charging, .device: return 3
        case .volume, .brightness: return 1.6
        case .banner: return 12
        }
    }

    /// HUD peeks show a level bar and need a little more room.
    var isHUD: Bool {
        switch self {
        case .volume, .brightness: return true
        default: return false
        }
    }

    var isBanner: Bool {
        if case .banner = self { return true }
        return false
    }
}

struct Banner: Equatable {
    var icon: String
    var tint: Color
    /// Short text beside the notch, e.g. "in 5 min" or "17:52".
    var badge: String
    var title: String
    var subtitle: String?
    var actionTitle: String?
    var actionURL: URL?
}
