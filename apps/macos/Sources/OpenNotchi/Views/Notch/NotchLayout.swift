import SwiftUI

/// Shared measurements so every tab lines up the same way:
/// equal side columns with the main content centered between them.
enum NotchLayout {
    static let sideColumn: CGFloat = 124
    static let columnSpacing: CGFloat = 18
}

func formatTime(_ seconds: Double) -> String {
    let s = max(0, Int(seconds))
    return String(format: "%d:%02d", s / 60, s % 60)
}

func formatCountdown(_ seconds: TimeInterval) -> String {
    let s = Int(seconds.rounded(.up))
    return s >= 3600
        ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
        : String(format: "%d:%02d", s / 60, s % 60)
}
