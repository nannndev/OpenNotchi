import SwiftUI

enum HVACMode: String, CaseIterable, Identifiable, Codable {
    case cool = "cool"
    case eco = "eco"
    case dry = "dry"
    case fan = "fan_only"
    case heat = "heat"
    case off = "off"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cool: return "Cool"
        case .eco: return "Eco"
        case .dry: return "Dry"
        case .fan: return "Fan"
        case .heat: return "Heat"
        case .off: return "Off"
        }
    }

    var icon: String {
        switch self {
        case .cool: return "snowflake"
        case .eco: return "leaf.fill"
        case .dry: return "drop.fill"
        case .fan: return "fanblades.fill"
        case .heat: return "flame.fill"
        case .off: return "power"
        }
    }

    var accentColor: Color {
        switch self {
        case .cool: return .cyan
        case .eco: return .green
        case .dry: return .blue
        case .fan: return .teal
        case .heat: return .orange
        case .off: return .secondary
        }
    }
}

enum FanSpeed: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case low = "low"
    case medium = "medium"
    case high = "high"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

struct SmartACDevice: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isOn: Bool
    var targetTemperature: Double
    var currentTemperature: Double?
    var mode: HVACMode
    var fanSpeed: FanSpeed
    var minTemp: Double = 16.0
    var maxTemp: Double = 30.0
}

struct SmartLightDevice: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var isOn: Bool
    var brightness: Double // 0.0 to 1.0
    var colorTemperature: String? // "warm", "neutral", "cool"
}

struct SmartSwitchDevice: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var isOn: Bool
    var powerWatts: Double?
}

struct SmartScene: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var description: String
}

enum SmarthomeProviderType: String, CaseIterable, Identifiable {
    case demo = "demo"
    case homeAssistant = "homeAssistant"
    case shortcuts = "shortcuts"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .demo: return "Demo (Simulated)"
        case .homeAssistant: return "Home Assistant"
        case .shortcuts: return "Apple Shortcuts"
        }
    }

    var subtitle: String {
        switch self {
        case .demo: return "Simulated devices to test controls without server setup"
        case .homeAssistant: return "Connect via REST API (http://homeassistant.local:8123)"
        case .shortcuts: return "Trigger native macOS shortcuts for HomeKit devices"
        }
    }
}
