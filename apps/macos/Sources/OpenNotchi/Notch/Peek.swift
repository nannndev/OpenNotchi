import SwiftUI

/// Battery levels for connected Bluetooth devices (especially AirPods).
struct DeviceBatteryInfo: Equatable {
    var left: Int?
    var right: Int?
    var caseBattery: Int?
    var single: Int?

    var primaryBattery: Int? {
        single ?? left ?? right
    }

    var isAirPods: Bool {
        left != nil || right != nil || caseBattery != nil
    }
}

/// A short-lived event shown beside or below the closed notch.
enum Peek: Equatable {
    case charging(level: Int)
    case device(name: String, symbol: String, battery: Int?, info: DeviceBatteryInfo? = nil)
    case volume(level: Float, muted: Bool)
    case brightness(level: Float)
    case micMute(muted: Bool)
    /// Some app just started using the camera and/or microphone.
    case privacy(camera: Bool, mic: Bool)
    /// A reminder that grows below the notch, with an optional action button.
    case banner(Banner)

    /// How long the peek stays visible.
    var duration: TimeInterval {
        switch self {
        case .charging: return 3.2
        case .device: return 3.8
        case .volume, .brightness, .micMute: return 1.8
        case .privacy: return 3
        case .banner(let banner): return banner.duration
        }
    }

    /// HUD peeks show a fluid level bar and need a wider pill.
    var isHUD: Bool {
        switch self {
        case .volume, .brightness, .micMute, .charging, .privacy: return true
        default: return false
        }
    }

    var isBanner: Bool {
        if case .banner = self { return true }
        return false
    }

    /// True when showing an AirPods or Bluetooth drop-down Dynamic Island card.
    var isDeviceCard: Bool {
        if case .device = self { return true }
        return false
    }
}

enum BannerActionType: String, Equatable {
    case openURL
    case triggerUpdate
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
    var actionType: BannerActionType = .openURL
    var duration: TimeInterval = 12
}

