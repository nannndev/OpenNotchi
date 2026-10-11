import SwiftUI

/// Presets on the left, ring in the middle, actions on the right.
struct TimerView: View {
    @EnvironmentObject private var timer: TimerManager
    @Environment(\.notchAccent) private var accent

    private let presets = [1, 5, 10, 15, 25, 50]
    private let presetColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        HStack(spacing: NotchLayout.columnSpacing) {
            LazyVGrid(columns: presetColumns, spacing: 8) {
                ForEach(presets, id: \.self) { minutes in
                    let selected = !timer.isActive && Int(timer.duration / 60) == minutes
                    Button { timer.setDuration(minutes: minutes) } label: {
                        Text("\(minutes)m")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(Capsule().fill(selected ? accent.highlight.opacity(0.9) : .white.opacity(0.08)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(timer.isActive)
                    .opacity(timer.isActive && !selected ? 0.35 : 1)
                }
            }
            .frame(width: NotchLayout.sideColumn)

            ring
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                PillButton(
                    title: timer.isRunning ? "Pause" : (timer.isActive ? "Resume" : "Start"),
                    icon: timer.isRunning ? "pause.fill" : "play.fill",
                    fill: accent.highlight
                ) {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                PillButton(title: "+1 min", icon: "plus", fill: .white.opacity(0.1)) {
                    timer.addMinute()
                }
                PillButton(title: "Reset", icon: "arrow.counterclockwise", fill: .white.opacity(0.1)) {
                    timer.reset()
                }
                .disabled(!timer.isActive && !timer.didFinish)
                .opacity(timer.isActive || timer.didFinish ? 1 : 0.35)
            }
            .frame(width: NotchLayout.sideColumn)
        }
    }

    private var ring: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remainingFraction = timer.isActive ? 1 - timer.progress(at: context.date) : 1
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: remainingFraction)
                    .stroke(
                        AngularGradient(colors: [accent.highlight.opacity(0.6), accent.highlight], center: .center),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.highlight.opacity(0.5), radius: 6)
                    .animation(.linear(duration: 0.25), value: remainingFraction)
                VStack(spacing: 2) {
                    Text(timer.didFinish ? "Done" : formatCountdown(timer.remaining(at: context.date)))
                        .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                    Text(timer.didFinish ? "time's up" : (timer.isRunning ? "running" : (timer.isActive ? "paused" : "ready")))
                        .font(.system(size: 10, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 128, height: 128)
        }
    }
}

private struct PillButton: View {
    let title: String
    let icon: String
    let fill: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Capsule().fill(fill))
                .overlay(Capsule().fill(.white.opacity(hovering ? 0.08 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
