import SwiftUI

/// Presets on the left, ring in the middle, actions & ambient focus soundscapes on the right.
struct TimerView: View {
    @EnvironmentObject private var timer: TimerManager
    @ObservedObject private var ambient = AmbientSoundManager.shared
    @Environment(\.notchAccent) private var accent

    @State private var showSoundMixer = false

    private let presets = [1, 5, 10, 15, 25, 50]
    private let presetColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        HStack(spacing: NotchLayout.columnSpacing) {
            VStack(spacing: 8) {
                Button { timer.setPomodoro(!timer.pomodoro) } label: {
                    Label("Pomodoro", systemImage: timer.pomodoro ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 24)
                        .background(Capsule().fill(timer.pomodoro ? accent.highlight.opacity(0.9) : .white.opacity(0.08)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                if timer.pomodoro {
                    pomodoroInfo
                } else {
                    presetGrid
                }
            }
            .frame(width: NotchLayout.sideColumn)

            if showSoundMixer {
                soundMixerPanel
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                VStack(spacing: 6) {
                    ring
                    compactSoundscapeBar
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            VStack(spacing: 6) {
                PillButton(
                    title: timer.isRunning ? "Pause" : (timer.isActive ? "Resume" : "Start"),
                    icon: timer.isRunning ? "pause.fill" : "play.fill",
                    fill: accent.highlight
                ) {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                if timer.pomodoro {
                    PillButton(title: "Skip", icon: "forward.fill", fill: .white.opacity(0.1)) {
                        timer.skip()
                    }
                } else {
                    PillButton(title: "+1 min", icon: "plus", fill: .white.opacity(0.1)) {
                        timer.addMinute()
                    }
                }
                PillButton(title: "Reset", icon: "arrow.counterclockwise", fill: .white.opacity(0.1)) {
                    timer.reset()
                }
                .disabled(!timer.isActive && !timer.didFinish)
                .opacity(timer.isActive || timer.didFinish ? 1 : 0.35)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        showSoundMixer.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: ambient.isPlaying ? "waveform.circle.fill" : "headphones")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ambient.isPlaying ? accent.highlight : .secondary)
                        Text(showSoundMixer ? "Show Timer" : "Sound Mixer")
                            .font(.system(size: 10.5, weight: .semibold))
                        if !ambient.activeSounds.isEmpty {
                            Text("\(ambient.activeSounds.count)")
                                .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(accent.highlight.opacity(0.3)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background(Capsule().fill(showSoundMixer ? accent.color.opacity(0.28) : .white.opacity(0.07)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(width: NotchLayout.sideColumn)
        }
    }

    // MARK: - Quick Soundscape Bar (under Timer Ring)

    private var compactSoundscapeBar: some View {
        HStack(spacing: 5) {
            ForEach(AmbientSound.allCases) { sound in
                let active = ambient.isActive(sound)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        ambient.toggle(sound)
                    }
                } label: {
                    HStack(spacing: 3.5) {
                        Image(systemName: sound.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(sound.shortTitle)
                            .font(.system(size: 9.5, weight: active ? .semibold : .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(active ? accent.highlight.opacity(0.85) : .white.opacity(0.07))
                    )
                    .foregroundStyle(active ? .white : .secondary)
                }
                .buttonStyle(.plain)
                .help("\(sound.title) (click to toggle)")
            }
        }
    }

    // MARK: - Full Focus Soundscape Mixer

    private var soundMixerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Focus Soundscapes", systemImage: "waveform")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent.highlight)

                Spacer()

                Button {
                    ambient.autoPlayWithFocusTimer.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: ambient.autoPlayWithFocusTimer ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 9))
                        Text("Auto with Focus")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(ambient.autoPlayWithFocusTimer ? accent.color.opacity(0.25) : .white.opacity(0.07)))
                    .foregroundStyle(ambient.autoPlayWithFocusTimer ? accent.highlight : .secondary)
                }
                .buttonStyle(.plain)
                .help("Automatically play ambient mix during Focus sessions and pause on breaks")

                if !ambient.activeSounds.isEmpty {
                    Button {
                        ambient.stopAll()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 8.5, weight: .bold))
                            .padding(5)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .help("Stop all ambient sounds")
                }
            }

            VStack(spacing: 5) {
                ForEach(AmbientSound.allCases) { sound in
                    let active = ambient.isActive(sound)
                    HStack(spacing: 7) {
                        Button {
                            ambient.toggle(sound)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: sound.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(active ? accent.highlight : .secondary)
                                    .frame(width: 14)
                                Text(sound.shortTitle)
                                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                                    .foregroundStyle(active ? .white : .secondary)
                                    .frame(width: 42, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)

                        Slider(
                            value: Binding(
                                get: { Double(ambient.volume(for: sound)) },
                                set: { ambient.setVolume(Float($0), for: sound) }
                            ),
                            in: 0...1
                        )
                        .controlSize(.mini)
                        .tint(active ? accent.highlight : .gray.opacity(0.4))
                        .opacity(active ? 1.0 : 0.45)

                        Text("\(Int((ambient.volume(for: sound) * 100).rounded()))%")
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(active ? .white : .secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
        }
        .padding(.horizontal, 4)
    }

    private var presetGrid: some View {
        LazyVGrid(columns: presetColumns, spacing: 8) {
            ForEach(presets, id: \.self) { minutes in
                let selected = !timer.isActive && Int(timer.duration / 60) == minutes
                Button { timer.setDuration(minutes: minutes) } label: {
                    Text("\(minutes)m")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(Capsule().fill(selected ? accent.highlight.opacity(0.9) : .white.opacity(0.08)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(timer.isActive)
                .opacity(timer.isActive && !selected ? 0.35 : 1)
            }
        }
    }

    private var pomodoroInfo: some View {
        // Position inside the current 4-session round; a finished round shows all dots filled until the next focus ends.
        let done = timer.focusToday % TimerManager.sessionsPerLongBreak
        let filled = timer.phase == .longBreak ? TimerManager.sessionsPerLongBreak : done
        return VStack(spacing: 8) {
            ForEach([TimerManager.Phase.focus, .shortBreak, .longBreak], id: \.self) { phase in
                HStack {
                    Text(phase.label)
                    Spacer()
                    Text("\(phase.minutes)m").foregroundStyle(.secondary)
                }
                .font(.system(size: 11, weight: timer.phase == phase ? .bold : .medium))
                .opacity(timer.phase == phase ? 1 : 0.45)
            }
            HStack(spacing: 5) {
                ForEach(0..<TimerManager.sessionsPerLongBreak, id: \.self) { i in
                    Circle()
                        .fill(i < filled ? accent.highlight : .white.opacity(0.15))
                        .frame(width: 6, height: 6)
                }
                Spacer()
                Text("\(timer.focusToday) today")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }

    private var ring: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remainingFraction = timer.isActive ? 1 - timer.progress(at: context.date) : 1
            let ringColor = timer.pomodoro && timer.phase != .focus ? Color.green : accent.highlight
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: remainingFraction)
                    .stroke(
                        AngularGradient(colors: [ringColor.opacity(0.6), ringColor], center: .center),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.5), radius: 6)
                    .animation(.linear(duration: 0.25), value: remainingFraction)
                VStack(spacing: 1) {
                    Text(timer.didFinish ? "Done" : formatCountdown(timer.remaining(at: context.date)))
                        .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                    Text(timer.didFinish ? "time's up" : timer.pomodoro ? timer.phase.label + (timer.isActive && !timer.isRunning ? " · paused" : "") : (timer.isRunning ? "running" : (timer.isActive ? "paused" : "ready")))
                        .font(.system(size: 9.5, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 108, height: 108)
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
