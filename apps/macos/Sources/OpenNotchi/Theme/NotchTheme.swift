import AppKit
import SwiftUI

enum NotchTheme: String, CaseIterable, Identifiable {
    case classic
    case liquidGlass
    case liquidGlassClear
    case frosted
    case adaptive
    case albumArt
    case midnight
    case aurora

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "Classic Black"
        case .liquidGlass: return "Liquid Glass"
        case .liquidGlassClear: return "Liquid Glass (Clear)"
        case .frosted: return "Frosted"
        case .adaptive: return "Music Adaptive"
        case .albumArt: return "Album Art"
        case .midnight: return "Midnight"
        case .aurora: return "Aurora"
        }
    }

    /// Liquid Glass is available on macOS.
    static var liquidGlassAvailable: Bool { true }

    static var defaultTheme: NotchTheme { .liquidGlass }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case artwork, white, system, blue, purple, pink, orange, green

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .artwork: return "From music"
        case .system: return "Mac accent"
        default: return rawValue.capitalized
        }
    }

    /// Static swatch color. `.artwork` is resolved against the palette by `ResolvedAccent`.
    var color: Color {
        switch self {
        case .artwork, .white: return .white
        case .system: return Color(nsColor: .controlAccentColor)
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        }
    }

}

/// The accent actually used for drawing, after resolving "From music".
struct ResolvedAccent: Equatable {
    var color: Color
    /// True for plain white, where filled controls need a stronger color.
    var isNeutral: Bool

    /// Color for filled highlights (timer ring, start button).
    var highlight: Color { isNeutral ? .orange : color }

    static func resolve(_ choice: AccentChoice, palette: ArtworkPalette?) -> ResolvedAccent {
        switch choice {
        case .artwork:
            if let palette { return ResolvedAccent(color: palette.accent, isNeutral: false) }
            return ResolvedAccent(color: .white, isNeutral: true)
        case .white:
            return ResolvedAccent(color: .white, isNeutral: true)
        default:
            return ResolvedAccent(color: choice.color, isNeutral: false)
        }
    }
}

private struct NotchAccentKey: EnvironmentKey {
    static let defaultValue = ResolvedAccent(color: .white, isNeutral: true)
}

extension EnvironmentValues {
    var notchAccent: ResolvedAccent {
        get { self[NotchAccentKey.self] }
        set { self[NotchAccentKey.self] = newValue }
    }
}

enum BorderStyle: String, CaseIterable, Identifiable {
    case none, subtle, accent, gradient, rainbow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .subtle: return "Subtle"
        case .accent: return "Accent color"
        case .gradient: return "Music gradient"
        case .rainbow: return "Rainbow"
        }
    }
}

/// Outline drawn around the open notch (no line along the screen edge).
struct NotchBorder: View {
    let style: BorderStyle
    let width: CGFloat
    let shape: NotchShape
    let accent: ResolvedAccent
    let palette: ArtworkPalette?

    var body: some View {
        switch style {
        case .none:
            EmptyView()
        case .subtle:
            shape.stroke(.white.opacity(0.18), lineWidth: width)
        case .accent:
            shape.stroke(accent.color.opacity(0.85), lineWidth: width)
        case .gradient:
            let colors = palette.map { [Color(nsColor: $0.primary.adjusted(minBrightness: 0.8)), Color(nsColor: $0.secondary.adjusted(minBrightness: 0.7))] }
                ?? [accent.highlight, .purple]
            shape.stroke(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing), lineWidth: width)
        case .rainbow:
            shape.stroke(
                AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center),
                lineWidth: width
            )
        }
    }
}

/// Paints the notch body for the chosen theme, open or closed. `isOpen` only adds the glass rim.
struct NotchBackground<S: Shape>: View {
    let theme: NotchTheme
    let isOpen: Bool
    let shape: S
    let artwork: NSImage?
    var palette: ArtworkPalette?

    var body: some View {
        themed
        .clipShape(shape)
        .overlay(glassStroke)
    }

    @ViewBuilder
    private var glassStroke: some View {
        if isOpen && (theme == .liquidGlass || theme == .liquidGlassClear) {
            shape
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme == .liquidGlassClear ? 0.22 : 0.16),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        } else if isOpen && theme == .frosted {
            shape
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var themed: some View {
        switch theme {
        case .classic:
            Color.black
        case .liquidGlass:
            liquidGlass(clear: false)
        case .liquidGlassClear:
            liquidGlass(clear: true)
        case .frosted:
            frosted
        case .adaptive:
            ZStack {
                Color.black
                if let palette {
                    LinearGradient(
                        colors: [palette.backgroundTop, palette.backgroundBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: palette)
        case .albumArt:
            ZStack {
                Color.black
                if let artwork {
                    // Overlay on a clear view so the filled image never grows the layout.
                    Color.clear
                        .overlay(
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 40)
                                .saturation(1.4)
                                .opacity(0.75)
                        )
                        .clipped()
                        .transition(.opacity)
                }
                Color.black.opacity(0.35)
            }
            .animation(.easeInOut(duration: 0.6), value: artwork)
        case .midnight:
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.16), Color(red: 0.12, green: 0.08, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .aurora:
            ZStack {
                Color(red: 0.03, green: 0.05, blue: 0.08)
                RadialGradient(colors: [.teal.opacity(0.55), .clear], center: .bottomLeading, startRadius: 0, endRadius: 320)
                RadialGradient(colors: [.purple.opacity(0.5), .clear], center: .topTrailing, startRadius: 0, endRadius: 320)
                RadialGradient(colors: [.green.opacity(0.25), .clear], center: .bottom, startRadius: 0, endRadius: 260)
            }
        }
    }

    @ViewBuilder
    private func liquidGlass(clear: Bool) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26, *) {
            // Real Liquid Glass: refraction + specular edges, not a dark blur.
            Color.clear.glassEffect(clear ? .clear.tint(.black.opacity(0.18)) : .regular.tint(.black.opacity(0.12)), in: shape)
        } else {
            legacyGlass(clear: clear)
        }
        #else
        legacyGlass(clear: clear)
        #endif
    }

    /// Pre-Tahoe approximation: light tint so the desktop blur stays visible.
    private func legacyGlass(clear: Bool) -> some View {
        ZStack {
            VisualEffectBlur(material: clear ? .underWindowBackground : .hudWindow)
            LinearGradient(
                colors: [Color.white.opacity(clear ? 0.10 : 0.06), Color.black.opacity(clear ? 0.18 : 0.30)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var frosted: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow)
            Color(white: 0.08, opacity: 0.82)
        }
    }
}

/// NSVisualEffectView that stays "active" even though the notch panel is never key.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        view.appearance = NSAppearance(named: .vibrantDark)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.appearance = NSAppearance(named: .vibrantDark)
    }
}
