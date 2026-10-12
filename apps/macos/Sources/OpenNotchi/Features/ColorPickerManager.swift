import AppKit
import Foundation
import SwiftUI

enum ColorFormat: String, CaseIterable, Identifiable {
    case hex = "HEX"
    case rgb = "RGB"
    case hsl = "HSL"
    case swift = "Swift"

    var id: String { rawValue }
}

struct PickedColor: Identifiable, Codable, Equatable {
    let id: UUID
    let hex: String
    let rgb: String
    let hsl: String
    let swiftSnippet: String
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
    let timestamp: Date

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func == (lhs: PickedColor, rhs: PickedColor) -> Bool {
        lhs.hex == rhs.hex
    }
}

final class ColorPickerManager: ObservableObject {
    static let shared = ColorPickerManager()

    @Published private(set) var currentColor: PickedColor?
    @Published private(set) var recentColors: [PickedColor] = []
    @Published var copiedFeedback: String?

    private let defaultsKey = "recentPickedColors"
    private var feedbackTimer: Timer?

    init() {
        loadRecentColors()
    }

    func sampleColor(completion: ((PickedColor?) -> Void)? = nil) {
        NSColorSampler().show { [weak self] nsColor in
            guard let self, let nsColor else {
                completion?(nil)
                return
            }
            guard let srgb = nsColor.usingColorSpace(.sRGB) else {
                completion?(nil)
                return
            }

            let r = Int(round(srgb.redComponent * 255))
            let g = Int(round(srgb.greenComponent * 255))
            let b = Int(round(srgb.blueComponent * 255))
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            let rgb = "rgb(\(r), \(g), \(b))"

            let rf = Double(srgb.redComponent)
            let gf = Double(srgb.greenComponent)
            let bf = Double(srgb.blueComponent)

            let maxC = max(rf, gf, bf)
            let minC = min(rf, gf, bf)
            let delta = maxC - minC
            let l = (maxC + minC) / 2.0
            var h: Double = 0
            var s: Double = 0

            if delta > 0.0001 {
                s = l > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC)
                if maxC == rf {
                    h = ((gf - bf) / delta) + (gf < bf ? 6.0 : 0.0)
                } else if maxC == gf {
                    h = ((bf - rf) / delta) + 2.0
                } else {
                    h = ((rf - gf) / delta) + 4.0
                }
                h /= 6.0
            }

            let hsl = String(format: "hsl(%d, %d%%, %d%%)", Int(round(h * 360)), Int(round(s * 100)), Int(round(l * 100)))
            let swiftSnippet = String(format: "Color(red: %.2f, green: %.2f, blue: %.2f)", rf, gf, bf)

            let picked = PickedColor(
                id: UUID(),
                hex: hex,
                rgb: rgb,
                hsl: hsl,
                swiftSnippet: swiftSnippet,
                red: rf,
                green: gf,
                blue: bf,
                alpha: Double(srgb.alphaComponent),
                timestamp: Date()
            )

            DispatchQueue.main.async {
                self.currentColor = picked
                self.addRecent(picked)
                self.copyToClipboard(text: hex, label: "\(hex) copied!")
                completion?(picked)
            }
        }
    }

    func copyFormat(_ picked: PickedColor, format: ColorFormat) {
        let text: String
        switch format {
        case .hex: text = picked.hex
        case .rgb: text = picked.rgb
        case .hsl: text = picked.hsl
        case .swift: text = picked.swiftSnippet
        }
        copyToClipboard(text: text, label: "\(text) copied!")
    }

    func copyToClipboard(text: String, label: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copiedFeedback = label
        feedbackTimer?.invalidate()
        feedbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.copiedFeedback = nil
        }
    }

    private func addRecent(_ color: PickedColor) {
        var updated = recentColors.filter { $0.hex != color.hex }
        updated.insert(color, at: 0)
        if updated.count > 10 {
            updated = Array(updated.prefix(10))
        }
        recentColors = updated
        saveRecentColors()
    }

    private func saveRecentColors() {
        if let data = try? JSONEncoder().encode(recentColors) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func loadRecentColors() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let list = try? JSONDecoder().decode([PickedColor].self, from: data) else {
            return
        }
        recentColors = list
        currentColor = list.first
    }
}
