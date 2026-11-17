import AppKit
import SwiftUI

/// Logo for any gateway provider: the bundled PNG when there is one, else a tinted SF Symbol.
struct ProviderBrandIcon: View {
    let providerId: String
    let name: String
    var size: CGFloat = 22

    private static func rawAsset(for providerId: String) -> NSImage? {
        let key: String? = switch providerId.lowercased() {
        case "claude", "anthropic": "claude"
        case "codex": "codex"
        case "antigravity": "antigravity"
        case "commandcode": "commandcode"
        default: nil
        }
        guard let key else { return nil }
        return Bundle.main.url(forResource: key, withExtension: "png", subdirectory: "ProviderIcons")
            .flatMap(NSImage.init(contentsOf:))
    }

    private static func resized(_ source: NSImage, to size: CGFloat) -> NSImage {
        let target = NSSize(width: size, height: size)
        let img = NSImage(size: target)
        img.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: target),
                    from: NSRect(origin: .zero, size: source.size),
                    operation: .copy,
                    fraction: 1.0)
        img.unlockFocus()
        return img
    }

    /// Fixed-size image safe to use inside macOS `Menu` labels & items (which ignore SwiftUI `.frame`).
    @ViewBuilder
    static func menuIcon(providerId: String, size: CGFloat = 16) -> some View {
        if let raw = rawAsset(for: providerId) {
            Image(nsImage: resized(raw, to: size))
        } else {
            Image(systemName: style(for: providerId).symbol)
        }
    }

    static func style(for providerId: String) -> (symbol: String, color: Color) {
        switch providerId.lowercased() {
        case "openai", "codex", "oai", "cx": return ("sparkles", Color(red: 0.06, green: 0.64, blue: 0.49))
        case "anthropic", "claude", "ant", "cc": return ("brain.head.profile", Color(red: 0.85, green: 0.47, blue: 0.34))
        case "gemini", "gemini-cli", "google", "gem", "gc": return ("diamond.fill", Color(red: 0.26, green: 0.52, blue: 0.96))
        case "copilot", "github", "gh": return ("chevron.left.forwardslash.chevron.right", Color(red: 0.44, green: 0.32, blue: 0.85))
        case "deepseek", "ds": return ("waveform.path.ecg", Color(red: 0.25, green: 0.42, blue: 0.92))
        case "openrouter", "or": return ("arrow.triangle.branch", Color(red: 0.38, green: 0.40, blue: 0.95))
        case "groq": return ("bolt.fill", Color(red: 0.94, green: 0.34, blue: 0.22))
        case "mistral": return ("wind", Color(red: 0.96, green: 0.52, blue: 0.14))
        case "together": return ("square.stack.3d.up.fill", Color(red: 0.18, green: 0.49, blue: 0.96))
        case "xai", "grok": return ("xmark", Color(white: 0.25))
        case "cohere": return ("circle.grid.2x2.fill", Color(red: 0.22, green: 0.58, blue: 0.46))
        case "fireworks": return ("flame.fill", Color(red: 0.90, green: 0.30, blue: 0.28))
        case "perplexity": return ("magnifyingglass.circle.fill", Color(red: 0.13, green: 0.62, blue: 0.68))
        case "cerebras": return ("cpu.fill", Color(red: 0.88, green: 0.38, blue: 0.18))
        case "hyperbolic": return ("infinity", Color(red: 0.48, green: 0.32, blue: 0.88))
        case "sambanova": return ("atom", Color(red: 0.92, green: 0.42, blue: 0.22))
        case "novita": return ("wand.and.stars", Color(red: 0.52, green: 0.36, blue: 0.92))
        case "siliconflow": return ("memorychip.fill", Color(red: 0.34, green: 0.44, blue: 0.90))
        case "ollama": return ("desktopcomputer", Color(white: 0.42))
        case "azure-openai": return ("cloud.fill", Color(red: 0.00, green: 0.47, blue: 0.83))
        case "aws-bedrock": return ("cube.fill", Color(red: 0.92, green: 0.55, blue: 0.12))
        case "moonshot", "kimi": return ("moon.stars.fill", Color(red: 0.22, green: 0.32, blue: 0.72))
        case "dashscope", "qwen": return ("sparkles.rectangle.stack.fill", Color(red: 0.42, green: 0.28, blue: 0.88))
        case "zai", "glm": return ("z.circle.fill", Color(red: 0.16, green: 0.52, blue: 0.88))
        case "minimax": return ("waveform", Color(red: 0.86, green: 0.28, blue: 0.48))
        case "nvidia": return ("rectangle.3.group.fill", Color(red: 0.46, green: 0.73, blue: 0.00))
        case "deepinfra": return ("server.rack", Color(red: 0.24, green: 0.48, blue: 0.82))
        case "muse": return ("paintpalette.fill", Color(red: 0.12, green: 0.48, blue: 0.92))
        case "nous": return ("compass.drawing", Color(red: 0.58, green: 0.38, blue: 0.86))
        case "kilocode": return ("terminal.fill", Color(red: 0.82, green: 0.36, blue: 0.24))
        case "custom": return ("slider.horizontal.3", Color(white: 0.45))
        case "cline": return ("terminal", Color(red: 0.20, green: 0.55, blue: 0.95))
        case "minimax-code", "minimax-code-global": return ("waveform", Color(red: 0.86, green: 0.28, blue: 0.48))
        case "grok-cli": return ("xmark", Color(white: 0.25))
        case "kiro": return ("bolt.horizontal.fill", Color(red: 0.55, green: 0.32, blue: 0.95))
        case "xiaomi-mimo": return ("circle.hexagongrid.fill", Color(red: 0.98, green: 0.42, blue: 0.10))
        default: return ("cpu.fill", .accentColor)
        }
    }

    var body: some View {
        if let raw = Self.rawAsset(for: providerId) {
            Image(nsImage: Self.resized(raw, to: size))
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.26))
        } else {
            let s = Self.style(for: providerId)
            Image(systemName: s.symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.26)
                        .fill(s.color.gradient)
                )
        }
    }
}
