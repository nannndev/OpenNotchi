import AppKit
import SwiftUI

/// Notchi, the mascot: the logo's five-bar waveform as a little creature beside the closed notch.
/// It reacts to what the Mac is doing (agents, music, battery, time of day, the pointer) and to being clicked.
enum NotchiMood: Equatable {
    /// Following the pointer with its eyes and blinking.
    case idle
    /// Eyes closed, a "z" drifting up; after a while with nothing happening, or late at night.
    case sleepy
    /// Eyes darting, a sweat drop; an AI agent is working.
    case busy
    /// Happy arcs, rosy cheeks and a hop; an agent just finished.
    case happy
    /// Wide eyes, open mouth and a shake; an agent needs you.
    case alert
    /// Headphones on, bopping to the beat with notes floating up; music is playing.
    case vibing
    /// Squinting and sweating; the battery is low and not charging.
    case tired
    /// Heart eyes and floating hearts; just got petted.
    case loved
}

/// Everything Notchi's mood is worked out from.
struct NotchiContext: Equatable {
    var agents: [AgentState] = []
    var musicPlaying = false
    var batteryLow = false
    var idleFor: TimeInterval = 0
    var hour = 12
    /// Petted in the last few seconds.
    var petted = false
}

/// What Notchi is feeling right now. Things that need you win over things that are just nice to know.
func notchiMood(_ c: NotchiContext) -> NotchiMood {
    if c.agents.contains(.needsYou) { return .alert }
    if c.petted { return .loved }
    if c.agents.contains(.working) { return .busy }
    if c.batteryLow { return .tired }
    // A finished agent stays "done" for minutes, so it must not hide the music.
    if c.musicPlaying { return .vibing }
    if c.agents.contains(.done) { return .happy }
    if c.idleFor > 10 * 60 || c.hour >= 23 || c.hour < 5 { return .sleepy }
    return .idle
}

/// A short line for Notchi's speech bubble; nil keeps it quiet.
func notchiLine(_ mood: NotchiMood, hour: Int, pets: Int) -> String? {
    switch mood {
    case .alert: return "you!"
    case .busy: return "working…"
    case .happy: return "done!"
    case .vibing: return "♪"
    case .tired: return "charge me"
    case .loved: return pets >= 5 ? "best friend!" : pets >= 3 ? "hehe" : "♥"
    case .sleepy: return "zz"
    case .idle:
        switch hour {
        case 5..<11: return "morning!"
        case 11..<14: return "lunch?"
        case 18..<23: return "evening"
        default: return nil
        }
    }
}

/// Notchi is the logo's five-bar waveform come alive: no face, all body language.
/// The bars keep the brand's shape (five, tallest in the middle) and move differently for each mood.
struct NotchiMascot: View {
    let mood: NotchiMood
    let size: CGFloat
    var color: Color = .white
    /// -1...1, where the pointer is to the left or right; the crest of the wave leans toward it when idle.
    var gaze: CGFloat = 0
    /// Last pet; drives the squish and the floating hearts.
    var pettedAt: Date?

    /// The logo's resting shape, tallest in the middle.
    static let restHeights: [Double] = [0.42, 0.68, 1.0, 0.68, 0.42]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let sincePet = pettedAt.map { context.date.timeIntervalSince($0) } ?? .infinity
            ZStack {
                bars(t: t, sincePet: sincePet)
                switch mood {
                case .sleepy: zzz(t: t)
                case .alert: exclaim(t: t)
                case .vibing: notes(t: t)
                default: EmptyView()
                }
                if sincePet < 1.6 { hearts(progress: sincePet / 1.6) }
            }
            .frame(width: size, height: size)
        }
        .accessibilityLabel("Notchi")
    }

    private var tint: Color {
        switch mood {
        case .alert: return .orange
        case .loved: return .pink
        default: return color
        }
    }

    /// Glow strength: lively moods shine, quiet ones barely.
    private var glow: Double {
        switch mood {
        case .alert, .loved, .vibing: return 0.85
        case .happy, .busy: return 0.6
        case .idle: return 0.45
        case .tired, .sleepy: return 0.2
        }
    }

    private func bars(t: Double, sincePet: Double) -> some View {
        let width = size * 0.86
        let height = size * 0.86
        let barWidth = width / (5 + 4 * 0.55)
        // A pet squashes every bar, then they spring back.
        let squish = sincePet < 0.5 ? 1 - 0.4 * sin(sincePet / 0.5 * .pi) : 1
        let shake = mood == .alert ? sin(t * 32) * size * 0.025 : 0
        return HStack(spacing: barWidth * 0.55) {
            ForEach(0..<5, id: \.self) { i in
                let level = max(0.12, min(1, Self.level(i, mood: mood, t: t, gaze: gaze) * squish))
                Capsule()
                    .fill(LinearGradient(colors: barColors, startPoint: .top, endPoint: .bottom))
                    .frame(width: barWidth, height: max(barWidth, height * level))
            }
        }
        .frame(width: width, height: height)
        .opacity(mood == .tired || mood == .sleepy ? 0.7 : 1)
        .shadow(color: tint.opacity(glow), radius: 3.5)
        .shadow(color: tint.opacity(glow * 0.5), radius: 8)
        .offset(x: shake)
    }

    /// The accent fading to white at the tips (brand gradient when the accent is plain white),
    /// or a solid tint for the moods that need your eye.
    private var barColors: [Color] {
        switch mood {
        case .alert: return [Color(red: 1, green: 0.75, blue: 0.4), .orange]
        case .loved: return [Color(red: 1, green: 0.7, blue: 0.85), .pink]
        default: return [.white, color.opacity(0.95), color]
        }
    }

    /// Height of bar `i` (0...4) as a fraction of the full height.
    static func level(_ i: Int, mood: NotchiMood, t: Double, gaze: CGFloat) -> Double {
        let x = Double(i)
        let rest = restHeights[i]
        func crest(at center: Double, width: Double) -> Double { exp(-pow(x - center, 2) / width) }
        switch mood {
        case .idle:
            // The tallest bar slides toward the pointer, and the whole wave breathes.
            let center = 2 + Double(gaze) * 1.6
            return (0.32 + 0.66 * crest(at: center, width: 1.6)) * (1 + 0.07 * sin(t * 2.2 + x * 0.6))
        case .sleepy:
            // Low and flat, rising and falling slowly like breathing.
            return rest * 0.32 + 0.06 * (1 + sin(t * 1.3 + x * 0.35))
        case .busy:
            // A crest sweeping back and forth, like a scanner.
            let center = 2 + 2.2 * sin(t * 4)
            return 0.26 + 0.74 * crest(at: center, width: 0.8)
        case .happy:
            // A cascade of hops from left to right.
            return rest * (0.72 + 0.4 * abs(sin(t * 6 - x * 0.65)))
        case .alert:
            // All tall and jittery.
            return 0.82 + 0.18 * sin(t * 24 + x * 1.3)
        case .vibing:
            // An equalizer: each bar on its own beat.
            let beat = abs(sin(t * (4.6 + x * 1.15) + x * 1.7)) * 0.6 + abs(sin(t * 2.3 + x)) * 0.4
            return 0.22 + 0.78 * beat
        case .tired:
            // Drooping, with the last bar flickering like a dying battery.
            let flicker = i == 4 ? (sin(t * 9) > 0.55 ? 0.35 : 0.12) : rest * 0.5
            return flicker + 0.04 * sin(t * 1.6 + x)
        case .loved:
            // A heartbeat: lub-dub, then rest.
            let p = t.truncatingRemainder(dividingBy: 1.1)
            let beat = p < 0.12 ? sin(p / 0.12 * .pi) : (p > 0.22 && p < 0.34 ? 0.7 * sin((p - 0.22) / 0.12 * .pi) : 0)
            return rest * (0.68 + 0.36 * beat)
        }
    }

    private func zzz(t: Double) -> some View {
        let p = (t / 2.4).truncatingRemainder(dividingBy: 1)
        return Text("z")
            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
            .foregroundStyle(color.opacity(0.8 * (1 - p)))
            .offset(x: size * 0.4 + p * size * 0.08, y: -size * 0.1 - p * size * 0.18)
    }

    private func exclaim(t: Double) -> some View {
        Text("!")
            .font(.system(size: size * 0.32, weight: .black, design: .rounded))
            .foregroundStyle(.orange)
            .opacity(sin(t * 8) > 0 ? 1 : 0.4)
            .offset(x: size * 0.46, y: -size * 0.12)
    }

    private func notes(t: Double) -> some View {
        let p = (t / 1.8).truncatingRemainder(dividingBy: 1)
        return Text(Int(t / 1.8) % 2 == 0 ? "♪" : "♫")
            .font(.system(size: size * 0.24, weight: .bold))
            .foregroundStyle(color.opacity(0.85 * (1 - p)))
            .offset(x: size * 0.44 + sin(p * .pi * 2) * size * 0.04, y: -size * 0.08 - p * size * 0.22)
    }

    private func hearts(progress p: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: size * (0.16 + Double(i) * 0.03)))
                    .foregroundStyle(.pink)
                    .opacity(1 - p)
                    .offset(x: CGFloat(i - 1) * size * 0.22, y: -size * 0.15 - p * size * (0.25 + Double(i) * 0.08))
            }
        }
    }
}

/// Reads the app state Notchi reacts to, so every place it appears agrees on its mood.
private struct NotchiState: DynamicProperty {
    @EnvironmentObject var agents: AgentMonitor
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var media: MediaManager
    @EnvironmentObject var battery: BatteryMonitor
    @Environment(\.notchAccent) var notchAccent

    /// The notch accent (the artwork's color while music plays); a soft brand silver when the accent is plain white.
    var accent: Color { notchAccent.isNeutral ? Color(red: 0.82, green: 0.82, blue: 0.84) : notchAccent.color }

    var agentStates: [AgentState] { settings.aiEnabled && settings.aiAgents ? agents.sessions.map(\.state) : [] }

    /// Like `agentStates`, but a "done" older than `doneFor` seconds counts as idle.
    func recentAgentStates(now: Date, doneFor: TimeInterval) -> [AgentState] {
        guard settings.aiEnabled && settings.aiAgents else { return [] }
        return agents.sessions.map { $0.state == .done && now.timeIntervalSince($0.updatedAt) > doneFor ? .idle : $0.state }
    }

    func context(now: Date, idleFor: TimeInterval = 0, petted: Bool = false) -> NotchiContext {
        NotchiContext(
            agents: agentStates,
            musicPlaying: media.info?.isPlaying ?? false,
            batteryLow: battery.hasBattery && battery.level <= 15 && !battery.isCharging,
            idleFor: idleFor,
            hour: Calendar.current.component(.hour, from: now),
            petted: petted
        )
    }
}

/// Notchi on its own, for slots that already show something else on the other side (the usage meter, music).
struct NotchiLive: View {
    private var state = NotchiState()
    let size: CGFloat

    init(size: CGFloat) { self.size = size }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            var c = state.context(now: context.date)
            let _ = c.agents = state.recentAgentStates(now: context.date, doneFor: NotchiIdleRow.doneFor)
            NotchiMascot(mood: notchiMood(c), size: size, color: state.accent)
        }
    }
}

/// The closed-notch slot Notchi lives in: the mascot on the left, a small status on the right.
/// Click Notchi to pet it; its eyes follow the pointer.
struct NotchiIdleRow: View {
    private var state = NotchiState()
    @EnvironmentObject private var vm: NotchViewModel
    let height: CGFloat
    @State private var hovered = false
    @State private var quietSince = Date.now
    @State private var pettedAt: Date?
    @State private var pets = 0
    @State private var gaze: CGFloat = 0

    /// How long "done" is celebrated before the right side goes back to the clock.
    static let doneFor: TimeInterval = 8

    init(height: CGFloat) { self.height = height }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now = context.date
            let petted = pettedAt.map { now.timeIntervalSince($0) < 4 } ?? false
            // Hovering counts as attention: Notchi perks up like it's being petted.
            var c = state.context(now: now, idleFor: now.timeIntervalSince(quietSince), petted: petted || hovered)
            // An agent that finished a while ago is old news: Notchi stops cheering after a few seconds.
            let _ = c.agents = state.recentAgentStates(now: now, doneFor: Self.doneFor)
            let mood = notchiMood(c)
            // Both sides get the same box, centered in equal slots, so they mirror each other around the notch.
            let box = height - 10
            HStack(spacing: 0) {
                NotchiMascot(mood: mood, size: box, color: state.accent, gaze: gaze, pettedAt: pettedAt)
                    .frame(width: height + 6, height: height)
                    .scaleEffect(hovered ? 1.15 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: hovered)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        hovered = inside
                        vm.isOverMascot = inside
                        if inside { quietSince = .now }
                    }
                    .onDisappear { vm.isOverMascot = false }
                    .onTapGesture { pet() }
                    .help("Click to pet Notchi · hover the notch to open it")
                Spacer(minLength: 0)
                NotchiStatus(mood: mood, now: now, accent: state.accent, size: box, pets: pets)
                    .frame(width: height + 6, height: height)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .onChange(of: now) { _, _ in followPointer() }
            .onChange(of: state.agentStates) { _, _ in quietSince = .now }
        }
    }

    private func pet() {
        // Pets in quick succession add up; a pause starts the count over.
        if let last = pettedAt, Date.now.timeIntervalSince(last) > 6 { pets = 0 }
        pets += 1
        pettedAt = .now
        quietSince = .now
        NSSound(named: "Pop")?.play()
    }

    /// The notch sits at the top center of its screen, so left/right of that center is all the eyes need.
    private func followPointer() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let target = max(-1, min(1, (mouse.x - screen.frame.midX) / 400))
        if abs(target - gaze) > 0.05 { withAnimation(.easeOut(duration: 0.25)) { gaze = target } }
    }
}

/// The right side of Notchi's row: an animated icon for what's happening, or something useful
/// (next prayer, weather, the time) when nothing is.
private struct NotchiStatus: View {
    @EnvironmentObject private var prayers: PrayerTimesManager
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var settings: AppSettings
    let mood: NotchiMood
    let now: Date
    let accent: Color
    let size: CGFloat
    let pets: Int

    var body: some View {
        Group {
            switch mood {
            case .busy: busyRing
            case .happy: icon("checkmark.circle.fill", .green, effect: .bounce)
            case .alert: icon("hand.raised.fill", .orange, effect: .wiggle)
            case .loved: icon(pets >= 3 ? "heart.circle.fill" : "heart.fill", .pink, effect: .bounce)
            case .tired: icon("battery.25percent", .red, effect: .pulse)
            case .vibing: icon("music.note", accent, effect: .pulse)
            case .sleepy: icon("moon.zzz.fill", accent.opacity(0.7), effect: .pulse)
            case .idle: ambient
            }
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: mood)
    }

    private enum Effect { case bounce, wiggle, pulse }

    private func icon(_ name: String, _ color: Color, effect: Effect) -> some View {
        // Restarts the effect every couple of seconds so it keeps feeling alive.
        let tick = Int(now.timeIntervalSinceReferenceDate / 2)
        return Image(systemName: name)
            .font(.system(size: size * 0.7, weight: .semibold))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 3)
            .modifier(EffectModifier(effect: effect, tick: tick))
            .id(name)
    }

    private struct EffectModifier: ViewModifier {
        let effect: Effect
        let tick: Int
        func body(content: Content) -> some View {
            switch effect {
            case .bounce: content.symbolEffect(.bounce, value: tick)
            case .wiggle:
                if #available(macOS 15, *) {
                    content.symbolEffect(.wiggle, value: tick)
                } else {
                    content.symbolEffect(.bounce, value: tick)
                }
            case .pulse: content.symbolEffect(.pulse)
            }
        }
    }

    /// A spinning arc while an agent works.
    private var busyRing: some View {
        let angle = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2 * 360
        return ZStack {
            // Bright enough that the whole ring reads, so it matches Notchi's height instead of just the arc.
            Circle().stroke(accent.opacity(0.35), lineWidth: 2)
            Circle().trim(from: 0, to: 0.3)
                .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(angle))
                .animation(.linear(duration: 0.25), value: angle)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(width: size * 0.78, height: size * 0.78)
        .shadow(color: accent.opacity(0.5), radius: 3)
    }

    /// Nothing going on: rotate through the next prayer, the weather and the clock, so the right side
    /// balances the mascot on the left with something worth a glance.
    @ViewBuilder
    private var ambient: some View {
        let items = ambientItems
        if !items.isEmpty {
            let item = items[Int(now.timeIntervalSinceReferenceDate / 6) % items.count]
            // Stacked so it fits the same square as Notchi: the symbol on top, a tiny label under it.
            VStack(spacing: 0) {
                Image(systemName: item.symbol)
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .frame(height: size * 0.55)
                Text(item.text)
                    .font(.system(size: 8, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: size + 10, height: size)
            .id(item.text)
            .transition(.push(from: .bottom))
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: item.text)
        }
    }

    private var ambientItems: [(symbol: String, text: String)] {
        var items: [(String, String)] = []
        if settings.prayerEnabled, let next = prayers.next, next.date.timeIntervalSince(now) < 3 * 3600 {
            items.append((next.kind.symbol, next.date.formatted(date: .omitted, time: .shortened)))
        }
        if settings.weatherEnabled, let w = weather.snapshot {
            items.append((w.symbol, "\(Int(w.temperature.rounded()))°"))
        }
        items.append(("clock", now.formatted(date: .omitted, time: .shortened)))
        return items
    }
}
