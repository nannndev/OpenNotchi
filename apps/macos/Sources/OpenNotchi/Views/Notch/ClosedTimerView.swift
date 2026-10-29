import SwiftUI

/// The running timer beside the closed notch: a ring that empties as time runs out (colored by Pomodoro
/// phase) on the left, and the countdown on the right with the focus sessions done as dots.
/// The last minute turns orange and pulses; a paused timer dims and blinks its time.
struct ClosedTimerView: View {
    @EnvironmentObject private var timer: TimerManager
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.notchAccent) private var accent
    let height: CGFloat

    /// Focus uses the accent; breaks are green so they read as "rest" at a glance.
    private var phaseColor: Color {
        guard timer.pomodoro else { return accent.highlight }
        return timer.phase == .focus ? accent.highlight : .green
    }

    private var symbol: String {
        if !timer.isRunning { return "pause.fill" }
        if timer.pomodoro { return timer.phase == .focus ? "brain.head.profile" : "cup.and.saucer.fill" }
        return "timer"
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: !timer.isRunning)) { context in
            let remaining = timer.remaining(at: context.date)
            let urgent = timer.isRunning && remaining <= 60
            let tint = urgent ? Color.orange : phaseColor
            // 0…1 once per second, for the last-minute pulse.
            let beat = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1)

            HStack {
                if settings.showMascot {
                    NotchiLive(size: height - 4)
                } else {
                    ring(progress: 1 - timer.progress(at: context.date), tint: tint)
                        .frame(width: height - 12, height: height - 12)
                        .scaleEffect(urgent ? 1 + 0.08 * (1 - beat) : 1)
                        .frame(width: height - 10)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    countdown(remaining, tint: tint, beat: beat)
                    if timer.pomodoro { sessionDots(tint: tint) }
                }
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    /// Time left as a ring around the phase symbol.
    private func ring(progress: Double, tint: Color) -> some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.6), radius: 2)
            Image(systemName: symbol)
                .font(.system(size: height * 0.26, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    /// mm:ss with the colon blinking while running; the whole time blinks slowly while paused.
    private func countdown(_ remaining: TimeInterval, tint: Color, beat: Double) -> some View {
        let text = formatCountdown(remaining)
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let font = Font.system(size: 12.5, weight: .bold, design: .rounded).monospacedDigit()
        return HStack(spacing: 0) {
            if parts.count == 2 && timer.isRunning {
                Text(parts[0])
                Text(":").opacity(beat < 0.5 ? 1 : 0.35)
                Text(parts[1])
            } else {
                Text(text)
            }
        }
        .font(font)
        .foregroundStyle(tint)
        .opacity(timer.isRunning ? 1 : 0.55)
        .contentTransition(.numericText(countsDown: true))
    }

    /// One dot per focus session in the current set of four; filled when done.
    private func sessionDots(tint: Color) -> some View {
        let done = timer.focusToday % TimerManager.sessionsPerLongBreak
        return HStack(spacing: 2.5) {
            ForEach(0..<TimerManager.sessionsPerLongBreak, id: \.self) { i in
                Circle()
                    .fill(i < done ? tint : tint.opacity(0.25))
                    .frame(width: 3.5, height: 3.5)
            }
        }
    }

    private var accessibilityText: String {
        let phase = timer.pomodoro ? timer.phase.label + ", " : ""
        let state = timer.isRunning ? "" : ", paused"
        return "Timer, \(phase)\(formatCountdown(timer.remaining())) left\(state)"
    }
}
