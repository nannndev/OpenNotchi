import Foundation

/// A short-lived event shown beside the closed notch, e.g. "charger connected".
enum Peek: Equatable {
    case charging(level: Int)
    case device(name: String, symbol: String, battery: Int?)
    case volume(level: Float, muted: Bool)
    case brightness(level: Float)

    /// How long the peek stays visible.
    var duration: TimeInterval {
        switch self {
        case .charging, .device: return 3
        case .volume, .brightness: return 1.6
        }
    }

    /// HUD peeks show a level bar and need a little more room.
    var isHUD: Bool {
        switch self {
        case .volume, .brightness: return true
        default: return false
        }
    }
}
