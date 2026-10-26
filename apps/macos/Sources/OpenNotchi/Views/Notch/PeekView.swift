import SwiftUI

/// Left icon + right detail for a peek. Content transitions between peeks.
struct PeekView: View {
    let peek: Peek
    let height: CGFloat
    @Environment(\.notchAccent) private var accent

    var body: some View {
        Group {
            switch peek {
            case .charging(let level):
                Image(systemName: "bolt.fill")
                    .font(.system(size: height * 0.46, weight: .bold))
                    .foregroundStyle(Color(red: 0.2, green: 0.95, blue: 0.4))
                    .shadow(color: Color.green.opacity(0.6), radius: 6)
                    .frame(width: height - 8, alignment: .leading)
                Spacer()
                HStack(spacing: 6) {
                    FluidHUDLevelBar(level: Float(level) / 100.0, color: Color(red: 0.2, green: 0.95, blue: 0.4))
                    Text("\(level)%")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(red: 0.2, green: 0.95, blue: 0.4))
                        .frame(width: 32, alignment: .trailing)
                }

            case .device(let name, let symbol, let battery, _):
                Image(systemName: symbol)
                    .font(.system(size: height * 0.45, weight: .medium))
                    .frame(width: height - 10)
                    .help(name)
                Spacer()
                if let battery {
                    Text("\(battery)%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(battery <= 20 ? .red : .white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: height * 0.42))
                        .foregroundStyle(.green)
                }

            case .volume(let level, let muted):
                HStack(spacing: 5) {
                    if muted || level == 0 {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: height * 0.44, weight: .bold))
                            .foregroundStyle(.red)
                            .shadow(color: .red.opacity(0.5), radius: 4)
                    } else {
                        Image(systemName: level < 0.34 ? "speaker.wave.1.fill" : level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")
                            .font(.system(size: height * 0.44, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 4)
                    }
                }
                .frame(width: height - 4, alignment: .leading)

                Spacer()

                HStack(spacing: 6) {
                    FluidHUDLevelBar(
                        level: muted ? 0 : level,
                        color: muted ? .red : accent.color
                    )

                    if muted {
                        Text("MUTE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.red)
                            .frame(width: 32, alignment: .trailing)
                    } else {
                        Text("\(Int((level * 100).rounded()))%")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 32, alignment: .trailing)
                    }
                }

            case .brightness(let level):
                Image(systemName: level < 0.35 ? "sun.min.fill" : level < 0.7 ? "sun.haze.fill" : "sun.max.fill")
                    .font(.system(size: height * 0.46, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.25))
                    .shadow(color: Color.yellow.opacity(0.5), radius: 5)
                    .frame(width: height - 4, alignment: .leading)

                Spacer()

                HStack(spacing: 6) {
                    FluidHUDLevelBar(
                        level: level,
                        color: Color(red: 1.0, green: 0.85, blue: 0.25)
                    )

                    Text("\(Int((level * 100).rounded()))%")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(width: 32, alignment: .trailing)
                }

            case .micMute(let muted):
                Image(systemName: muted ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: height * 0.44, weight: .bold))
                    .foregroundStyle(muted ? .red : Color(red: 1.0, green: 0.6, blue: 0.2))
                    .shadow(color: muted ? .red.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
                    .frame(width: height - 4, alignment: .leading)

                Spacer()

                Text(muted ? "MUTED" : "ACTIVE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(muted ? .red : Color(red: 1.0, green: 0.6, blue: 0.2))

            case .privacy(let camera, let mic):
                HStack(spacing: 4) {
                    if camera { Image(systemName: "video.fill").foregroundStyle(.green) }
                    if mic { Image(systemName: "mic.fill").foregroundStyle(.orange) }
                }
                .font(.system(size: height * 0.4, weight: .bold))
                .frame(width: height + 4, alignment: .leading)

                Spacer()

                Text("IN USE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(camera ? .green : .orange)

            case .banner:
                EmptyView()
            }
        }
        .transition(.opacity)
    }
}

struct FluidHUDLevelBar: View {
    let level: Float
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.85), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(min(max(level, 0), 1))))
                    .shadow(color: color.opacity(0.45), radius: 3, y: 0)
            }
        }
        .frame(width: 68, height: 7.5)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: level)
    }
}
