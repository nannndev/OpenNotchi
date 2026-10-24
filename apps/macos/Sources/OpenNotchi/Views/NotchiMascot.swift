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
                robotBody(t: t, sincePet: sincePet)
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
        .accessibilityLabel("Notchi Cyber-Bot")
    }

    private var tint: Color {
        switch mood {
        case .alert: return .orange
        case .loved: return .pink
        case .happy: return Color(red: 0.06, green: 0.75, blue: 0.5)
        case .tired: return Color(red: 0.58, green: 0.64, blue: 0.72)
        default: return (color == .white ? Color(red: 0.22, green: 0.74, blue: 0.97) : color)
        }
    }

    private var eyeColor: Color { tint }

    /// Glow strength: lively moods shine, quiet ones barely.
    private var glow: Double {
        switch mood {
        case .alert, .loved, .vibing: return 0.85
        case .happy, .busy: return 0.6
        case .idle: return 0.45
        case .tired, .sleepy: return 0.2
        }
    }

    private func robotBody(t: Double, sincePet: Double) -> some View {
        let squishY = sincePet < 0.45 ? 1 - 0.35 * sin(sincePet / 0.45 * .pi) : 1
        let squishX = sincePet < 0.45 ? 1 + 0.25 * sin(sincePet / 0.45 * .pi) : 1
        let hopY = mood == .happy ? -abs(sin(t * 7)) * (size * 0.1) : 0
        let shakeX = mood == .alert ? sin(t * 36) * (size * 0.05) : 0
        let floatY = (mood == .idle || mood == .sleepy) ? sin(t * 2) * (size * 0.025) : 0

        let blinkCycle = t.truncatingRemainder(dividingBy: 3.5)
        let isBlinking = (mood == .idle || mood == .busy) && blinkCycle < 0.16
        let blinkScale = isBlinking ? 0.1 : 1.0

        let gazeShift: CGFloat = mood == .idle ? max(-2.2, min(2.2, gaze * 2.2)) : 0
        let alertBlink = sin(t * 10) > 0

        return Canvas { context, canvasSize in
            let scale = canvasSize.width / 32.0
            context.scaleBy(x: scale, y: scale)

            drawRobot(
                context: &context,
                t: t,
                gazeShift: gazeShift,
                blinkScale: blinkScale,
                isBlinking: isBlinking,
                alertBlink: alertBlink
            )
        }
        .frame(width: size, height: size)
        .scaleEffect(x: squishX, y: squishY, anchor: .bottom)
        .offset(x: shakeX, y: hopY + floatY)
        .shadow(color: tint.opacity(glow * 0.7), radius: 3)
        .shadow(color: tint.opacity(glow * 0.35), radius: 6)
    }

    private func drawRobot(
        context: inout GraphicsContext,
        t: Double,
        gazeShift: CGFloat,
        blinkScale: CGFloat,
        isBlinking: Bool,
        alertBlink: Bool
    ) {
        // 1. Top Antenna
        var pole = Path()
        pole.move(to: CGPoint(x: 16, y: 4.5))
        pole.addLine(to: CGPoint(x: 16, y: 7.5))
        context.stroke(pole, with: .color(Color(red: 0.28, green: 0.33, blue: 0.41)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        let beaconRect = CGRect(x: 16 - 1.8, y: 3.8 - 1.8, width: 3.6, height: 3.6)
        let beaconAlpha = (mood == .alert && alertBlink) ? 1.0 : 0.85
        context.fill(Path(ellipseIn: beaconRect), with: .color(eyeColor.opacity(beaconAlpha)))

        // 2. Headphone Arc when vibing to music
        if mood == .vibing {
            var arc = Path()
            arc.addArc(center: CGPoint(x: 16, y: 16), radius: 13.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(arc, with: .color(tint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }

        // 3. Ear Pads
        let earPadColor = (mood == .vibing) ? tint : Color(red: 0.2, green: 0.25, blue: 0.33)
        let earStroke = (mood == .vibing) ? Color.white : Color.white.opacity(0.15)
        let leftEarRect = CGRect(x: 1.8, y: 12, width: 3.2, height: 9)
        let rightEarRect = CGRect(x: 27.0, y: 12, width: 3.2, height: 9)

        context.fill(Path(roundedRect: leftEarRect, cornerRadius: 1.6), with: .color(earPadColor))
        context.stroke(Path(roundedRect: leftEarRect, cornerRadius: 1.6), with: .color(earStroke), lineWidth: 0.8)

        context.fill(Path(roundedRect: rightEarRect, cornerRadius: 1.6), with: .color(earPadColor))
        context.stroke(Path(roundedRect: rightEarRect, cornerRadius: 1.6), with: .color(earStroke), lineWidth: 0.8)

        // 4. Robot Head / Helmet Base
        let helmetRect = CGRect(x: 4, y: 7.5, width: 24, height: 18)
        let helmetPath = Path(roundedRect: helmetRect, cornerRadius: 6.5)
        context.fill(helmetPath, with: .linearGradient(
            Gradient(colors: [Color(red: 0.14, green: 0.16, blue: 0.2), Color(red: 0.07, green: 0.07, blue: 0.09)]),
            startPoint: CGPoint(x: 16, y: 7.5),
            endPoint: CGPoint(x: 16, y: 25.5)
        ))
        context.stroke(helmetPath, with: .color(Color.white.opacity(0.16)), lineWidth: 1)

        // 5. OLED Visor Screen
        let visorRect = CGRect(x: 6, y: 9.5, width: 20, height: 14)
        let visorPath = Path(roundedRect: visorRect, cornerRadius: 4.5)
        context.fill(visorPath, with: .color(Color(red: 0.024, green: 0.027, blue: 0.039)))
        context.stroke(visorPath, with: .color(Color.white.opacity(0.08)), lineWidth: 0.7)

        // 6. Visor Gloss Reflection
        var glossPath = Path()
        glossPath.move(to: CGPoint(x: 6.8, y: 11.5))
        glossPath.addQuadCurve(to: CGPoint(x: 25.2, y: 12.2), control: CGPoint(x: 16, y: 9.8))
        glossPath.addLine(to: CGPoint(x: 25.2, y: 10.5))
        glossPath.addQuadCurve(to: CGPoint(x: 6.8, y: 10.5), control: CGPoint(x: 16, y: 9.0))
        glossPath.closeSubpath()
        context.fill(glossPath, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.0)]),
            startPoint: CGPoint(x: 6.8, y: 9.5),
            endPoint: CGPoint(x: 25.2, y: 14.0)
        ))

        // 7. Cheeks / Blushing on Loved & Happy
        if mood == .loved || mood == .happy {
            let blushColor = Color(red: 0.96, green: 0.25, blue: 0.37).opacity(0.65)
            context.fill(Path(ellipseIn: CGRect(x: 8.5 - 1.4, y: 19.5 - 1.4, width: 2.8, height: 2.8)), with: .color(blushColor))
            context.fill(Path(ellipseIn: CGRect(x: 23.5 - 1.4, y: 19.5 - 1.4, width: 2.8, height: 2.8)), with: .color(blushColor))
        }

        // 8. Eyes / Visor Face by Mood
        switch mood {
        case .loved:
            // Heart Eyes ♥ ♥
            let heart1 = heartPath(cx: 11.5 + gazeShift, cy: 16)
            let heart2 = heartPath(cx: 20.5 + gazeShift, cy: 16)
            context.fill(heart1, with: .color(eyeColor))
            context.fill(heart2, with: .color(eyeColor))

        case .happy:
            // Joyful Smiling Arcs ^ ^
            var leftArc = Path()
            leftArc.move(to: CGPoint(x: 9 + gazeShift, y: 18))
            leftArc.addQuadCurve(to: CGPoint(x: 14 + gazeShift, y: 18), control: CGPoint(x: 11.5 + gazeShift, y: 14.2))
            context.stroke(leftArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            var rightArc = Path()
            rightArc.move(to: CGPoint(x: 18 + gazeShift, y: 18))
            rightArc.addQuadCurve(to: CGPoint(x: 23 + gazeShift, y: 18), control: CGPoint(x: 20.5 + gazeShift, y: 14.2))
            context.stroke(rightArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .vibing:
            // Chill Groove Arcs ~ ~
            var leftArc = Path()
            leftArc.move(to: CGPoint(x: 9 + gazeShift, y: 16))
            leftArc.addQuadCurve(to: CGPoint(x: 14 + gazeShift, y: 16), control: CGPoint(x: 11.5 + gazeShift, y: 18.2))
            context.stroke(leftArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            var rightArc = Path()
            rightArc.move(to: CGPoint(x: 18 + gazeShift, y: 16))
            rightArc.addQuadCurve(to: CGPoint(x: 23 + gazeShift, y: 16), control: CGPoint(x: 20.5 + gazeShift, y: 18.2))
            context.stroke(rightArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .sleepy:
            // Relaxed Closed Lines - -
            var leftLine = Path()
            leftLine.move(to: CGPoint(x: 9.5, y: 16.5))
            leftLine.addLine(to: CGPoint(x: 13.5, y: 16.5))
            context.stroke(leftLine, with: .color(eyeColor.opacity(0.75)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            var rightLine = Path()
            rightLine.move(to: CGPoint(x: 18.5, y: 16.5))
            rightLine.addLine(to: CGPoint(x: 22.5, y: 16.5))
            context.stroke(rightLine, with: .color(eyeColor.opacity(0.75)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        case .tired:
            // Drooping Sad Lines v v
            var leftLine = Path()
            leftLine.move(to: CGPoint(x: 9.5, y: 15.8))
            leftLine.addLine(to: CGPoint(x: 13.5, y: 17.2))
            context.stroke(leftLine, with: .color(eyeColor.opacity(0.6)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            var rightLine = Path()
            rightLine.move(to: CGPoint(x: 18.5, y: 17.2))
            rightLine.addLine(to: CGPoint(x: 22.5, y: 15.8))
            context.stroke(rightLine, with: .color(eyeColor.opacity(0.6)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        case .busy:
            // Cyber Scanning Slits + Sweeping Scan Dot
            let slitH = 2.2 * blinkScale
            let leftSlit = CGRect(x: 9 + gazeShift, y: 16 - slitH / 2, width: 5, height: slitH)
            let rightSlit = CGRect(x: 18 + gazeShift, y: 16 - slitH / 2, width: 5, height: slitH)
            context.fill(Path(roundedRect: leftSlit, cornerRadius: 1.1), with: .color(eyeColor))
            context.fill(Path(roundedRect: rightSlit, cornerRadius: 1.1), with: .color(eyeColor))

            let dotX = 11.5 + 4.5 * sin(t * 8)
            let dotRect = CGRect(x: dotX - 1.0, y: 16.1 - 1.0, width: 2.0, height: 2.0)
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))

        case .alert:
            // Startled Wide Alert Eyes O O
            let leftCircle = CGRect(x: 11.5 - 3.2, y: 16 - 3.2, width: 6.4, height: 6.4)
            let rightCircle = CGRect(x: 20.5 - 3.2, y: 16 - 3.2, width: 6.4, height: 6.4)
            if alertBlink {
                context.fill(Path(ellipseIn: leftCircle), with: .color(eyeColor))
                context.fill(Path(ellipseIn: rightCircle), with: .color(eyeColor))
            } else {
                context.stroke(Path(ellipseIn: leftCircle), with: .color(eyeColor), lineWidth: 1.6)
                context.stroke(Path(ellipseIn: rightCircle), with: .color(eyeColor), lineWidth: 1.6)
            }
            context.fill(Path(ellipseIn: CGRect(x: 11.5 - 1.2, y: 16 - 1.2, width: 2.4, height: 2.4)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: 20.5 - 1.2, y: 16 - 1.2, width: 2.4, height: 2.4)), with: .color(.white))

        case .idle:
            // Standard Rounded LED Eyes (with Blink + Gaze)
            let eyeH = 5.6 * blinkScale
            let eyeR = min(1.8, eyeH / 2)
            let leftEye = CGRect(x: 11.5 + gazeShift - 1.8, y: 16 - eyeH / 2, width: 3.6, height: eyeH)
            let rightEye = CGRect(x: 20.5 + gazeShift - 1.8, y: 16 - eyeH / 2, width: 3.6, height: eyeH)
            context.fill(Path(roundedRect: leftEye, cornerRadius: eyeR), with: .color(eyeColor))
            context.fill(Path(roundedRect: rightEye, cornerRadius: eyeR), with: .color(eyeColor))

            if !isBlinking {
                let hl1 = CGRect(x: 12.2 + gazeShift - 0.8, y: 14.8 - 0.8, width: 1.6, height: 1.6)
                let hl2 = CGRect(x: 21.2 + gazeShift - 0.8, y: 14.8 - 0.8, width: 1.6, height: 1.6)
                context.fill(Path(ellipseIn: hl1), with: .color(.white))
                context.fill(Path(ellipseIn: hl2), with: .color(.white))
            }
        }
    }

    private func heartPath(cx: CGFloat, cy: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy + 2.8))
        p.addCurve(
            to: CGPoint(x: cx - 3.2, y: cy - 0.5),
            control1: CGPoint(x: cx - 1.2, y: cy + 1.8),
            control2: CGPoint(x: cx - 3.2, y: cy + 0.8)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy - 2.8),
            control1: CGPoint(x: cx - 3.2, y: cy - 2.2),
            control2: CGPoint(x: cx - 0.8, y: cy - 3.2)
        )
        p.addCurve(
            to: CGPoint(x: cx + 3.2, y: cy - 0.5),
            control1: CGPoint(x: cx + 0.8, y: cy - 3.2),
            control2: CGPoint(x: cx + 3.2, y: cy - 2.2)
        )
        p.addCurve(
            to: CGPoint(x: cx, y: cy + 2.8),
            control1: CGPoint(x: cx + 3.2, y: cy + 0.8),
            control2: CGPoint(x: cx + 1.2, y: cy + 1.8)
        )
        p.closeSubpath()
        return p
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
