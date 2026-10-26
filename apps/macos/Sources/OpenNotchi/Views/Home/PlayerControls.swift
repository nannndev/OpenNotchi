import SwiftUI

struct ControlButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .frame(width: size + 16, height: size + 16)
                .background(Circle().fill(.white.opacity(hovering ? 0.12 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct WaveformView: View {
    let isPlaying: Bool
    let barCount: Int
    let maxHeight: CGFloat
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = t * (3 + Double(i) * 0.7) + Double(i) * 1.3
                    let amp = isPlaying ? (0.35 + 0.65 * abs(sin(phase))) : 0
                    Capsule()
                        .fill(isPlaying ? color.opacity(0.9) : .white.opacity(0.35))
                        .frame(width: isPlaying ? 3 : 10, height: max(4, maxHeight * amp))
                }
            }
            .frame(height: maxHeight)
        }
    }
}

struct PlayPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(accent.isNeutral ? AnyShapeStyle(.white) : AnyShapeStyle(accent.color))
                    .frame(width: 32, height: 32)
                    .shadow(color: (accent.isNeutral ? Color.white : accent.color).opacity(hovering ? 0.45 : 0.2), radius: 6)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent.isNeutral ? .black : .white)
                    .offset(x: isPlaying ? 0 : 1)
            }
            .scaleEffect(hovering ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hovering)
    }
}

struct TransportAuxButton: View {
    let systemName: String
    let isActive: Bool
    let size: CGFloat
    let action: () -> Void
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isActive ? (accent.isNeutral ? .white.opacity(0.2) : accent.color.opacity(0.25)) : (hovering ? .white.opacity(0.1) : .clear))
                    .frame(width: size + 12, height: size + 12)

                Image(systemName: systemName)
                    .font(.system(size: size, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? (accent.isNeutral ? .white : accent.color) : (hovering ? .white : .secondary))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .scaleEffect(hovering ? 1.1 : 1.0)
        .animation(.spring(response: 0.2), value: hovering)
    }
}

struct PlayerVolumeBar: View {
    @State private var volume: Float = SystemAudio.volume ?? 0.5
    @State private var isMuted: Bool = SystemAudio.isMuted
    @State private var dragFraction: Double?
    @State private var isHovering = false
    @Environment(\.notchAccent) private var accent

    private var speakerIcon: String {
        if isMuted || volume <= 0.001 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.fill"
        } else if volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Button {
                isMuted.toggle()
                SystemAudio.isMuted = isMuted
            } label: {
                Image(systemName: speakerIcon)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(isMuted ? 0.45 : 0.9)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help(isMuted ? "Unmute" : "Mute")

            GeometryReader { geo in
                let currentFraction = dragFraction ?? Double(volume)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                    Capsule()
                        .fill(isMuted ? .white.opacity(0.3) : accent.color)
                        .frame(width: geo.size.width * min(max(currentFraction, 0), 1))
                }
                .frame(height: (isHovering || dragFraction != nil) ? 5 : 3.5)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let frac = min(max(Double(value.location.x / geo.size.width), 0), 1)
                            dragFraction = frac
                            volume = Float(frac)
                            SystemAudio.volume = volume
                            if isMuted && frac > 0 {
                                isMuted = false
                                SystemAudio.isMuted = false
                            }
                        }
                        .onEnded { _ in
                            if let frac = dragFraction {
                                volume = Float(frac)
                                SystemAudio.volume = volume
                            }
                            dragFraction = nil
                        }
                )
            }
            .frame(width: 64, height: 12)
            .onHover { isHovering = $0 }

            Text("\(Int((isMuted ? 0 : (dragFraction ?? Double(volume))) * 100))%")
                .font(.system(size: 8, weight: .medium).monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .trailing)
        }
        .onAppear {
            volume = SystemAudio.volume ?? 0.5
            isMuted = SystemAudio.isMuted
        }
    }
}
