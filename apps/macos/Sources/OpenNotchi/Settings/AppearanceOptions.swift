import Foundation

enum PlayerArtworkStyle: String, CaseIterable, Identifiable {
    case vinylDisc = "vinylDisc"               // Full spinning vinyl record
    case vinylCoverCenter = "vinylCoverCenter" // Album cover framed in center of spinning vinyl
    case vinylSleeve = "vinylSleeve"           // Classic vinyl sliding out of its jacket
    case standard = "standard"                 // Modern square album art

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vinylDisc: return "Vinyl Only (Turntable)"
        case .vinylCoverCenter: return "Cover di Tengah Vinyl (Halo)"
        case .vinylSleeve: return "Vinyl Sleeve (Slide-out)"
        case .standard: return "Standard Cover (Kotak)"
        }
    }

    var icon: String {
        switch self {
        case .vinylDisc: return "opticaldisc"
        case .vinylCoverCenter: return "record.circle.fill"
        case .vinylSleeve: return "rectangle.stack.fill"
        case .standard: return "square.fill"
        }
    }
}

enum AudioDeckStyle: String, CaseIterable, Identifiable {
    case vuMeter = "vuMeter"
    case spectrum = "spectrum"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vuMeter: return "Analog VU Meter"
        case .spectrum: return "9-Band Spectrum"
        }
    }

    var icon: String {
        switch self {
        case .vuMeter: return "gauge.with.needle.fill"
        case .spectrum: return "waveform"
        }
    }
}

enum DisplayTarget: String, CaseIterable, Identifiable {
    case builtIn = "builtIn"       // Built-in / Notch display only
    case active = "active"         // Active display (follows mouse cursor)
    case allScreens = "allScreens" // All connected displays

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .builtIn: return "Built-in Screen Only"
        case .active: return "Follow Active Screen"
        case .allScreens: return "All Connected Screens"
        }
    }

    var subtitle: String {
        switch self {
        case .builtIn: return "Stay pinned to the MacBook notch (or primary display)"
        case .active: return "Appear on whichever display your cursor is currently on"
        case .allScreens: return "Show on every monitor simultaneously (Notch + Island)"
        }
    }

    var icon: String {
        switch self {
        case .builtIn: return "laptopcomputer"
        case .active: return "cursorarrow.motionlines"
        case .allScreens: return "display.2"
        }
    }
}
