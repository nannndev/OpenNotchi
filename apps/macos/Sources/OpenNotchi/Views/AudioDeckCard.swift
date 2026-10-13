import SwiftUI

/// Symmetrical 112x112 live audio deck that features both an Analog Dual VU Meter and a 9-Band Spectrum Analyzer.
struct AudioDeckCard: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent
    @State private var isHovering = false

    var body: some View {
        ZStack {
            switch settings.audioDeckStyle {
            case .vuMeter:
                AnalogVUMeterView(isPlaying: media.info?.isPlaying ?? false)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .spectrum:
                SpectrumAnalyzerView(isPlaying: media.info?.isPlaying ?? false)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(width: 112, height: 112)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isHovering ? .white.opacity(0.24) : .white.opacity(0.12), lineWidth: 0.5)
                )
        }
        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onHover { isHovering = $0 }
        .onTapGesture {
            // Tap to toggle between Vintage VU Meter and Modern Spectrum Analyzer
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                settings.audioDeckStyle = (settings.audioDeckStyle == .vuMeter) ? .spectrum : .vuMeter
            }
        }
        .contextMenu {
            Section("Audio Deck Style") {
                ForEach(AudioDeckStyle.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            settings.audioDeckStyle = item
                        }
                    } label: {
                        HStack {
                            Label(item.displayName, systemImage: item.icon)
                            if settings.audioDeckStyle == item {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.calendarEnabled = true
                }
            } label: {
                Label("Switch to Calendar Widget", systemImage: "calendar")
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.audioDeckEnabled = false
                }
            } label: {
                Label("Hide Right Deck", systemImage: "eye.slash")
            }
        }
        .help("Audio Deck • Click to switch VU Meter / Spectrum • Right-click for options")
    }
}

// MARK: - 1. Analog Dual VU Meter
private struct AnalogVUMeterView: View {
    let isPlaying: Bool
    @Environment(\.notchAccent) private var accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            // Realistic ballistic simulation for Left and Right audio channels
            let leftVal = isPlaying
                ? max(0.05, min(1.0, 0.45 + 0.38 * sin(t * 5.2) + 0.22 * cos(t * 8.7 + 0.5) + 0.15 * sin(t * 13.1)))
                : 0.04
            let rightVal = isPlaying
                ? max(0.05, min(1.0, 0.42 + 0.35 * sin(t * 4.8 + 0.8) + 0.25 * cos(t * 7.9) + 0.18 * sin(t * 12.3 + 1.2)))
                : 0.04

            let leftAngle = -36 + leftVal * 72.0
            let rightAngle = -36 + rightVal * 72.0
            let isPeaking = isPlaying && (leftVal > 0.82 || rightVal > 0.82)

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("VU METER")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)

                    Spacer()

                    // Peak LED indicator
                    HStack(spacing: 3) {
                        Text("PEAK")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(isPeaking ? .red : .secondary.opacity(0.4))
                        Circle()
                            .fill(isPeaking ? Color.red : Color.red.opacity(0.2))
                            .frame(width: 4.5, height: 4.5)
                            .shadow(color: isPeaking ? Color.red.opacity(0.8) : .clear, radius: 3)
                    }
                }
                .padding(.top, 9)
                .padding(.horizontal, 10)

                Spacer(minLength: 0)

                // Dial Face & Needles
                ZStack(alignment: .bottom) {
                    // Vintage Arc Scale
                    VUMeterScaleView()
                        .frame(width: 96, height: 48)

                    // Left Needle (Amber / Red tip)
                    NeedleShape()
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1.5, height: 42)
                        .rotationEffect(.degrees(leftAngle), anchor: .bottom)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)

                    // Right Needle (Semi-transparent companion)
                    NeedleShape()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.85), .yellow.opacity(0.7), .white.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1.2, height: 40)
                        .rotationEffect(.degrees(rightAngle), anchor: .bottom)
                        .shadow(color: .black.opacity(0.4), radius: 1, x: 0.5, y: 1)

                    // Pivot Cap (Center screw)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.4), .black],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 7
                            )
                        )
                        .frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .offset(y: 4)
                }
                .frame(width: 96, height: 50)

                Spacer(minLength: 0)

                // Footer Scale Legend
                HStack {
                    Text("-20")
                        .font(.system(size: 7.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("STEREO CH 1·2")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.3)
                    Spacer()
                    Text("+3 dB")
                        .font(.system(size: 7.5, weight: .bold).monospacedDigit())
                        .foregroundStyle(.red.opacity(0.85))
                }
                .padding(.bottom, 8)
                .padding(.horizontal, 10)
            }
        }
    }
}

// MARK: - VU Meter Scale Arc Graphics
private struct VUMeterScaleView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height)
            let radius = size.width * 0.44

            // Safe Arc (-36° to 10°)
            let safePath = Path { p in
                p.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(180 + 54),
                    endAngle: .degrees(180 + 100),
                    clockwise: false
                )
            }
            context.stroke(safePath, with: .color(.white.opacity(0.25)), lineWidth: 1)

            // Redline Overload Arc (10° to 36°)
            let redPath = Path { p in
                p.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(180 + 100),
                    endAngle: .degrees(180 + 126),
                    clockwise: false
                )
            }
            context.stroke(redPath, with: .color(.red.opacity(0.85)), lineWidth: 1.5)

            // Tick Marks
            let ticks: [(deg: Double, isRed: Bool, isMajor: Bool)] = [
                (-34, false, true),  // -20 dB
                (-24, false, false), // -10 dB
                (-14, false, true),  // -7 dB
                (-5, false, false),  // -3 dB
                (4, false, false),   // -1 dB
                (12, true, true),    // 0 dB
                (22, true, false),   // +1 dB
                (32, true, true),    // +3 dB
            ]

            for tick in ticks {
                let rad = (tick.deg - 90) * .pi / 180
                let r1 = radius - (tick.isMajor ? 4.5 : 2.5)
                let r2 = radius + 0.5
                let p1 = CGPoint(x: center.x + CGFloat(cos(rad)) * r1, y: center.y + CGFloat(sin(rad)) * r1)
                let p2 = CGPoint(x: center.x + CGFloat(cos(rad)) * r2, y: center.y + CGFloat(sin(rad)) * r2)

                var tickPath = Path()
                tickPath.move(to: p1)
                tickPath.addLine(to: p2)
                context.stroke(
                    tickPath,
                    with: .color(tick.isRed ? .red.opacity(0.85) : .white.opacity(0.4)),
                    lineWidth: tick.isMajor ? 1.2 : 0.8
                )
            }
        }
    }
}

// Needle Shape
private struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - 0.6, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX - 0.2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + 0.2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX + 0.6, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - 2. 9-Band Graphic Spectrum Analyzer
private struct SpectrumAnalyzerView: View {
    let isPlaying: Bool
    @Environment(\.notchAccent) private var accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(accent.isNeutral ? .white : accent.color)
                    Text("SPECTRUM")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)

                    Spacer()

                    Circle()
                        .fill(isPlaying ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 4.5, height: 4.5)
                }
                .padding(.top, 9)
                .padding(.horizontal, 10)

                Spacer(minLength: 0)

                // 9 Animated Frequency Columns
                HStack(alignment: .bottom, spacing: 3.5) {
                    ForEach(0..<9, id: \.self) { i in
                        let speed = 3.2 + Double(i) * 0.75
                        let phase = t * speed + Double(i) * 1.3
                        let rawAmp = isPlaying ? CGFloat(0.22 + 0.78 * abs(sin(phase) * cos(phase * 0.65))) : 0.08
                        let barHeight = max(4.0, min(42.0, 42.0 * rawAmp))

                        VStack(spacing: 1.5) {
                            // Falling Peak Cap
                            Capsule()
                                .fill(accent.isNeutral ? Color.white : accent.color)
                                .frame(width: 5, height: 1.5)
                                .opacity(isPlaying ? 0.95 : 0.3)

                            // Main Frequency Bar
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accent.isNeutral ? .white : accent.color,
                                            accent.isNeutral ? .white.opacity(0.65) : accent.color.opacity(0.4)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 5, height: barHeight)
                        }
                    }
                }
                .frame(height: 44)

                Spacer(minLength: 0)

                // Frequency Bands Axis
                HStack {
                    Text("60Hz")
                        .font(.system(size: 7.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("1kHz")
                        .font(.system(size: 7.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("16kHz")
                        .font(.system(size: 7.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                .padding(.horizontal, 10)
            }
        }
    }
}
