import SwiftUI

struct TurntableTonearmView: View {
    let isPlaying: Bool
    var size: CGFloat = 104

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Tonearm assembly pivoted at top right
            VStack(alignment: .trailing, spacing: 0) {
                // Pivot Base Cylinder
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(white: 0.8),
                                    Color(white: 0.4),
                                    Color(white: 0.15)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 8
                            )
                        )
                        .frame(width: 15, height: 15)
                        .shadow(color: .black.opacity(0.55), radius: 3, x: 1, y: 1)

                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
                        .frame(width: 15, height: 15)

                    // Pivot Center Screw
                    Circle()
                        .fill(Color(white: 0.22))
                        .frame(width: 4.5, height: 4.5)
                }
                .frame(width: 15, height: 15)

                // Arm Rod & Cartridge with Needle
                ZStack(alignment: .top) {
                    // Brushed Metallic Arm Rod
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.88),
                                    Color(white: 0.6),
                                    Color(white: 0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 2.2, height: size * 0.46)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: -1, y: 1)

                    // Headshell / Cartridge & Stylus
                    VStack(spacing: 0) {
                        Spacer()
                        ZStack(alignment: .bottom) {
                            // Angled Cartridge
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                                .frame(width: 5, height: 10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                                )

                            // Stylus Ruby Needle
                            Circle()
                                .fill(Color(red: 0.95, green: 0.28, blue: 0.25))
                                .frame(width: 2.5, height: 2.5)
                                .offset(y: 2)
                        }
                    }
                    .frame(height: size * 0.46)
                }
                .offset(x: -6, y: -2)
                .rotationEffect(.degrees(isPlaying ? 28 : 2), anchor: .top)
                .animation(.spring(response: 0.55, dampingFraction: 0.75), value: isPlaying)
            }
        }
        .frame(width: size, height: size, alignment: .topTrailing)
        .allowsHitTesting(false)
    }
}

struct VinylDiscView: View {
    let image: NSImage?
    let isPlaying: Bool
    var size: CGFloat = 104
    var centerLabelSize: CGFloat = 44
    var showCenterImage: Bool = true
    var interactive: Bool = true
    var onScratchSeek: ((Double) -> Void)? = nil
    var onTapToggle: (() -> Void)? = nil

    @State private var dragRotation: Double = 0
    @State private var lastDragAngle: Double = 0
    @State private var isDragging: Bool = false
    @State private var accumulatedScrubAngle: Double = 0
    @State private var lastHapticAngle: Double = 0

    var body: some View {
        TimelineView(.animation(paused: !isPlaying && !isDragging)) { context in
            let baseAngle = (context.date.timeIntervalSinceReferenceDate * 45).truncatingRemainder(dividingBy: 360)
            let totalAngle = baseAngle + dragRotation

            ZStack {
                // Outer Vinyl Disc Body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.14, green: 0.14, blue: 0.16),
                                Color(red: 0.06, green: 0.06, blue: 0.07)
                            ],
                            center: .center,
                            startRadius: size * 0.18,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)

                // Microgroove Concentric Rings
                Group {
                    Circle().stroke(Color.white.opacity(0.04), lineWidth: 1.0).frame(width: size * 0.94, height: size * 0.94)
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.8).frame(width: size * 0.86, height: size * 0.86)
                    Circle().stroke(Color.white.opacity(0.05), lineWidth: 0.9).frame(width: size * 0.78, height: size * 0.78)
                    Circle().stroke(Color.white.opacity(0.07), lineWidth: 0.8).frame(width: size * 0.70, height: size * 0.70)
                    Circle().stroke(Color.white.opacity(0.05), lineWidth: 0.9).frame(width: size * 0.62, height: size * 0.62)
                    Circle().stroke(Color.white.opacity(0.06), lineWidth: 0.8).frame(width: size * 0.54, height: size * 0.54)
                }

                // Specular Light Reflections across grooves (vinyl shine)
                AngularGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.12),
                        .clear,
                        .white.opacity(0.04),
                        .clear,
                        .white.opacity(0.12),
                        .clear
                    ]),
                    center: .center
                )
                .frame(width: size, height: size)
                .clipShape(Circle())

                // Center Label
                if showCenterImage && centerLabelSize > 0 {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.22))
                            .frame(width: centerLabelSize, height: centerLabelSize)

                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: centerLabelSize - 2, height: centerLabelSize - 2)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "music.note")
                                .font(.system(size: centerLabelSize * 0.35))
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                            .frame(width: centerLabelSize, height: centerLabelSize)

                        // Spindle Hole
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 0.8))
                    }
                }
            }
            .rotationEffect(.degrees(totalAngle))
            .gesture(interactive ? interactiveGesture : nil)
        }
        .frame(width: size, height: size)
    }

    private var interactiveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: size / 2, y: size / 2)
                let currentAngle = angle(from: center, to: value.location)

                if !isDragging {
                    isDragging = true
                    lastDragAngle = currentAngle
                    accumulatedScrubAngle = 0
                    lastHapticAngle = 0
                } else {
                    var delta = currentAngle - lastDragAngle
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }

                    dragRotation += delta
                    accumulatedScrubAngle += delta
                    lastDragAngle = currentAngle

                    // Haptic tick every ~30 degrees of manual spin
                    if abs(accumulatedScrubAngle - lastHapticAngle) >= 30 {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        lastHapticAngle = accumulatedScrubAngle
                    }
                }
            }
            .onEnded { _ in
                let totalMoved = abs(accumulatedScrubAngle)
                isDragging = false

                if totalMoved > 14 {
                    // DJ Scratch Scrub
                    let secondsDelta = (accumulatedScrubAngle / 360.0) * 4.0
                    onScratchSeek?(secondsDelta)
                } else {
                    // Tap to play/pause
                    onTapToggle?()
                }
            }
    }

    private func angle(from center: CGPoint, to point: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let rad = atan2(dy, dx)
        var deg = rad * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }
}
