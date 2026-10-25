import SwiftUI

enum NotchAnimationStyle: String, CaseIterable, Identifiable {
    case fluid = "fluid"         // Fluid & Natural (Default)
    case bouncy = "bouncy"       // Bouncy Island (Playful spring)
    case waterfall = "waterfall" // Waterfall Slide (Drops down)
    case snappy = "snappy"       // Snappy Pro (Ultra fast)
    case pop = "pop"             // Elastic Pop (Magnetic punch)
    case gentle = "gentle"       // Gentle Float (Cinematic & soft)
    case flip3D = "flip3D"       // 3D Trapdoor Flip (Realistic 3D hinge visor)
    case depth3D = "depth3D"     // 3D Holographic Depth (Spatial z-axis tilt & float)
    case cube3D = "cube3D"       // 3D Cube Roll (Steep 3D isometric roll)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fluid: return "Fluid Classic"
        case .bouncy: return "Bouncy Island"
        case .waterfall: return "Waterfall Drop"
        case .snappy: return "Snappy Pro"
        case .pop: return "Elastic Pop"
        case .gentle: return "Gentle Float"
        case .flip3D: return "3D Trapdoor Flip"
        case .depth3D: return "3D Holographic Depth"
        case .cube3D: return "3D Cube Roll"
        }
    }

    var subtitle: String {
        switch self {
        case .fluid: return "Halus, natural & seimbang (standar macOS)"
        case .bouncy: return "Elastis & membal seperti Dynamic Island"
        case .waterfall: return "Meluncur turun dari balik kamera notch"
        case .snappy: return "Sangat responsif tanpa jeda untuk produktivitas"
        case .pop: return "Penuh energi dengan hentakan skala magnetik"
        case .gentle: return "Gerakan mengambang lembut & sinematik"
        case .flip3D: return "Ayunan engsel 3D realistis berputar dari kamera atas"
        case .depth3D: return "Proyeksi spasial melayang keluar dari kedalaman z-space"
        case .cube3D: return "Rotasi sisi kubus 3D geometris dengan perspektif tajam"
        }
    }

    var icon: String {
        switch self {
        case .fluid: return "waveform.path"
        case .bouncy: return "arrow.up.and.down.and.sparkles"
        case .waterfall: return "arrow.down.to.line.compact"
        case .snappy: return "bolt.fill"
        case .pop: return "circle.circle.fill"
        case .gentle: return "wind"
        case .flip3D: return "cube.transparent.fill"
        case .depth3D: return "view.3d"
        case .cube3D: return "shippingbox.fill"
        }
    }

    var is3D: Bool {
        switch self {
        case .flip3D, .depth3D, .cube3D:
            return true
        default:
            return false
        }
    }

    var tiltAngle: Double {
        switch self {
        case .flip3D: return -36.0
        case .depth3D: return -22.0
        case .cube3D: return -55.0
        default: return 0.0
        }
    }

    var scale3D: CGFloat {
        switch self {
        case .flip3D: return 0.94
        case .depth3D: return 0.86
        case .cube3D: return 0.80
        default: return 1.0
        }
    }

    var springAnimation: Animation {
        switch self {
        case .fluid:
            return .spring(response: 0.36, dampingFraction: 0.82)
        case .bouncy:
            return .spring(response: 0.46, dampingFraction: 0.52)
        case .waterfall:
            return .spring(response: 0.40, dampingFraction: 0.78)
        case .snappy:
            return .spring(response: 0.16, dampingFraction: 0.98)
        case .pop:
            return .spring(response: 0.50, dampingFraction: 0.46)
        case .gentle:
            return .spring(response: 0.68, dampingFraction: 0.88)
        case .flip3D:
            return .spring(response: 0.54, dampingFraction: 0.68)
        case .depth3D:
            return .spring(response: 0.58, dampingFraction: 0.62)
        case .cube3D:
            return .spring(response: 0.52, dampingFraction: 0.70)
        }
    }

    var contentTransition: AnyTransition {
        switch self {
        case .fluid:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
            )
        case .bouncy:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.76, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.88, anchor: .top))
            )
        case .waterfall:
            return .asymmetric(
                insertion: .opacity.combined(with: .offset(y: -65)),
                removal: .opacity.combined(with: .offset(y: -45))
            )
        case .snappy:
            return .opacity
        case .pop:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.58, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.80, anchor: .top))
            )
        case .gentle:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                removal: .opacity
            )
        case .flip3D:
            return .asymmetric(
                insertion: .modifier(
                    active: Flip3DTransitionModifier(angle: -40, scale: 0.88, opacity: 0),
                    identity: Flip3DTransitionModifier(angle: 0, scale: 1.0, opacity: 1)
                ),
                removal: .modifier(
                    active: Flip3DTransitionModifier(angle: -28, scale: 0.92, opacity: 0),
                    identity: Flip3DTransitionModifier(angle: 0, scale: 1.0, opacity: 1)
                )
            )
        case .depth3D:
            return .asymmetric(
                insertion: .modifier(
                    active: Depth3DTransitionModifier(angle: -20, scale: 0.82, yOffset: -28, opacity: 0),
                    identity: Depth3DTransitionModifier(angle: 0, scale: 1.0, yOffset: 0, opacity: 1)
                ),
                removal: .modifier(
                    active: Depth3DTransitionModifier(angle: -15, scale: 0.88, yOffset: -18, opacity: 0),
                    identity: Depth3DTransitionModifier(angle: 0, scale: 1.0, yOffset: 0, opacity: 1)
                )
            )
        case .cube3D:
            return .asymmetric(
                insertion: .modifier(
                    active: Flip3DTransitionModifier(angle: -60, scale: 0.76, opacity: 0),
                    identity: Flip3DTransitionModifier(angle: 0, scale: 1.0, opacity: 1)
                ),
                removal: .modifier(
                    active: Flip3DTransitionModifier(angle: -40, scale: 0.84, opacity: 0),
                    identity: Flip3DTransitionModifier(angle: 0, scale: 1.0, opacity: 1)
                )
            )
        }
    }

    var openCardTransition: AnyTransition {
        switch self {
        case .flip3D:
            return .modifier(
                active: Notch3DCardModifier(progress: 0.0, targetAngle: -88, axis: (1, 0, 0), perspective: 0.55, minScale: 0.85, maxShade: 0.70),
                identity: Notch3DCardModifier(progress: 1.0, targetAngle: -88, axis: (1, 0, 0), perspective: 0.55, minScale: 0.85, maxShade: 0.70)
            )
        case .depth3D:
            return .modifier(
                active: Notch3DCardModifier(progress: 0.0, targetAngle: -55, axis: (1, 0, 0), perspective: 0.50, minScale: 0.38, maxShade: 0.85),
                identity: Notch3DCardModifier(progress: 1.0, targetAngle: -55, axis: (1, 0, 0), perspective: 0.50, minScale: 0.38, maxShade: 0.85)
            )
        case .cube3D:
            return .modifier(
                active: Notch3DCardModifier(progress: 0.0, targetAngle: -95, axis: (1, 0.40, 0.1), perspective: 0.55, minScale: 0.70, maxShade: 0.85),
                identity: Notch3DCardModifier(progress: 1.0, targetAngle: -95, axis: (1, 0.40, 0.1), perspective: 0.55, minScale: 0.70, maxShade: 0.85)
            )
        default:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
            )
        }
    }
}

/// Hinged 3D transform for the whole open notch card, pivoting on the top (camera) edge.
/// Conforms to AnimatableModifier so SwiftUI interpolates angle, scale, and shade on EVERY frame of the spring animation!
struct Notch3DCardModifier: AnimatableModifier {
    var progress: Double // 0.0 = closed/tilted, 1.0 = open/flat
    let targetAngle: Double
    let axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    let perspective: CGFloat
    let minScale: CGFloat
    let maxShade: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let currentAngle = targetAngle * (1.0 - progress)
        let currentScale = minScale + (1.0 - minScale) * progress
        let currentShade = max(0.0, maxShade * (1.0 - progress))
        let currentOpacity = min(1.0, max(0.0, progress * 3.0))

        return content
            .overlay(
                Color.black
                    .opacity(currentShade)
                    .allowsHitTesting(false)
            )
            .rotation3DEffect(
                .degrees(currentAngle),
                axis: axis,
                anchor: .top,
                anchorZ: 0,
                perspective: perspective
            )
            .scaleEffect(currentScale, anchor: .top)
            .opacity(currentOpacity)
    }
}

struct Flip3DTransitionModifier: ViewModifier {
    let angle: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .top,
                anchorZ: 0,
                perspective: 0.60
            )
            .scaleEffect(scale, anchor: .top)
            .opacity(opacity)
    }
}

struct Depth3DTransitionModifier: ViewModifier {
    let angle: Double
    let scale: CGFloat
    let yOffset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .top,
                anchorZ: 0,
                perspective: 0.55
            )
            .offset(y: yOffset)
            .scaleEffect(scale, anchor: .top)
            .opacity(opacity)
    }
}
