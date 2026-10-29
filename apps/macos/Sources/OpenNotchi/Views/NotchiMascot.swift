import AppKit
import SwiftUI

/// Notchi's mood, driven by system activity, coding agents, music, focus timer, and direct user interactions.
enum NotchiMood: Equatable {
    /// Following the pointer with its eyes (2D X/Y gaze) and blinking.
    case idle
    /// Eyes closed, a "z" drifting up; after a while with nothing happening, or late at night.
    case sleepy
    /// Eyes darting, cyber scanning slit; an AI agent or CI build is working.
    case busy
    /// Wearing smart focus glasses, determined look; Pomodoro / Focus Timer is running.
    case focused
    /// Hyper starry eyes and buzzing energy; Keep Awake (Caffeine) is active or just drank coffee.
    case caffeinated
    /// Munching happily on a cyber-snack.
    case eating
    /// Spinning dizzy eyes (@ @) after being poked rapidly 6+ times!
    case dizzy
    /// Happy arcs, rosy cheeks and a hop; an agent or build just finished.
    case happy
    /// Wide eyes, open mouth and a shake; an agent needs you.
    case alert
    /// Headphones on, bopping to the beat with notes floating up; music or ambient soundscape is playing.
    case vibing
    /// Squinting and sweating; the battery is low and not charging.
    case tired
    /// Heart eyes and floating hearts; just got petted.
    case loved

    var badgeLabel: String {
        switch self {
        case .idle: return "Chilling"
        case .sleepy: return "Sleepy"
        case .busy: return "Coding / Working"
        case .focused: return "Deep Focus"
        case .caffeinated: return "Caffeinated ⚡"
        case .eating: return "Munching 🍙"
        case .dizzy: return "Dizzy @ @"
        case .happy: return " Celebrating!"
        case .alert: return "Needs You!"
        case .vibing: return "Vibing ♫"
        case .tired: return "Low Battery"
        case .loved: return "Happy ♥"
        }
    }
}

/// Customizable hat / accessory worn by Notchi.
enum NotchiAccessory: String, CaseIterable, Identifiable {
    case auto = "auto"
    case catEars = "catEars"
    case sprout = "sprout"
    case crown = "crown"
    case glasses = "glasses"
    case halo = "halo"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .catEars: return "Neko"
        case .sprout: return "Sprout"
        case .crown: return "Crown"
        case .glasses: return "Specs"
        case .halo: return "Halo"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .catEars: return "cat.fill"
        case .sprout: return "leaf.fill"
        case .crown: return "crown.fill"
        case .glasses: return "eyeglasses"
        case .halo: return "sparkles"
        }
    }
}

/// Persistent state & interactive personality engine for Notchi.
final class NotchiCompanionStore: ObservableObject {
    static let shared = NotchiCompanionStore()

    @Published var totalPets: Int {
        didSet { UserDefaults.standard.set(totalPets, forKey: "notchiTotalPets") }
    }
    @Published var xp: Int {
        didSet { UserDefaults.standard.set(xp, forKey: "notchiXP") }
    }
    @Published var snacksFed: Int {
        didSet { UserDefaults.standard.set(snacksFed, forKey: "notchiSnacksFed") }
    }
    @Published var accessory: NotchiAccessory {
        didSet { UserDefaults.standard.set(accessory.rawValue, forKey: "notchiAccessory") }
    }

    /// Transient interaction states
    @Published var pettedAt: Date?
    @Published var fedAt: Date?
    @Published var coffeeBoostUntil: Date?
    @Published var dizzyUntil: Date?
    @Published var speechBubble: String?
    @Published var recentPetCombo: Int = 0

    private var bubbleTimer: Timer?

    var level: Int {
        max(1, 1 + Int(sqrt(Double(max(0, xp)) / 25.0)))
    }

    var currentLevelProgress: Double {
        let curLv = level
        let baseXP = (curLv - 1) * (curLv - 1) * 25
        let nextXP = curLv * curLv * 25
        guard nextXP > baseXP else { return 0 }
        return min(1.0, max(0.0, Double(xp - baseXP) / Double(nextXP - baseXP)))
    }

    var bondTitle: String {
        switch level {
        case 1...2: return "Curious Bot"
        case 3...5: return "Desk Buddy"
        case 6...9: return "Focus Partner"
        case 10...15: return "Cyber Bestie"
        default: return "Legend Companion"
        }
    }

    private init() {
        let d = UserDefaults.standard
        self.totalPets = d.integer(forKey: "notchiTotalPets")
        self.xp = d.integer(forKey: "notchiXP")
        self.snacksFed = d.integer(forKey: "notchiSnacksFed")
        self.accessory = NotchiAccessory(rawValue: d.string(forKey: "notchiAccessory") ?? "") ?? .auto
    }

    func pet() {
        let now = Date()
        if let last = pettedAt, now.timeIntervalSince(last) > 4.5 {
            recentPetCombo = 0
        }
        recentPetCombo += 1
        totalPets += 1
        pettedAt = now
        let oldLevel = level
        xp += 5

        if AppSettings.shared.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        NSSound(named: "Pop")?.play()

        if recentPetCombo >= 6 {
            dizzyUntil = now.addingTimeInterval(3.2)
            say(["Waduh pusing! @ @", "Whoa slow down! 🌀", "Overclocked!! @ @"].randomElement()!, duration: 3.2)
        } else if level > oldLevel {
            NSSound(named: "Glass")?.play()
            say("Level Up! Lv.\(level) \(bondTitle) ✦", duration: 4.0)
        } else if recentPetCombo >= 3 {
            say(["Hehe geli! ♥", "Best friend! ✦", "Purr-computing~ ♥", "Sayang kamu! ♥"].randomElement()!, duration: 2.8)
        } else {
            say(["♥", "Hehe~", "Boop! ♥", "Hai!"].randomElement()!, duration: 2.2)
        }
    }

    func feedSnack() {
        let now = Date()
        fedAt = now
        dizzyUntil = nil
        snacksFed += 1
        let oldLevel = level
        xp += 15
        if AppSettings.shared.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        NSSound(named: "Hero")?.play()
        if level > oldLevel {
            say("Nyam! Naik ke Lv.\(level)! 🍙✦", duration: 3.8)
        } else {
            say(["Nyam nyam! Enak 🍙", "Battery hati 100%! 🍙", "Makasih snack-nya! 😋"].randomElement()!, duration: 3.2)
        }
    }

    func toggleCoffeeKeepAwake() {
        if KeepAwake.shared.isActive {
            KeepAwake.shared.stop()
            coffeeBoostUntil = nil
            say("Caffeine OFF · Mac bisa istirahat 🌙", duration: 3.0)
        } else {
            KeepAwake.shared.start(minutes: 60)
            coffeeBoostUntil = Date().addingTimeInterval(60 * 60)
            xp += 20
            NSSound(named: "Ping")?.play()
            say("Kopi masuk! Keep Awake 1 jam ⚡☕", duration: 3.5)
        }
    }

    func toggleFocusSession(timer: TimerManager) {
        if timer.isRunning {
            timer.pause()
            say("Focus di-pause dulu ya ⏸️", duration: 2.8)
        } else {
            if !timer.isActive {
                timer.setPomodoro(true)
            }
            timer.start()
            xp += 15
            say("Mode Fokus 25m dimulai! Semangat 🍅👓", duration: 3.5)
        }
    }

    func toggleLoFiRain() {
        let ambient = AmbientSoundManager.shared
        if ambient.isPlaying {
            ambient.stopAll()
            say("Suara ambient dimatikan 🔇", duration: 2.5)
        } else {
            ambient.applyPreset([.rain, .vinyl])
            xp += 10
            say("Rain + Vinyl Lo-Fi diputar 🌧️🎶", duration: 3.2)
        }
    }

    func say(_ text: String, duration: TimeInterval = 3.0) {
        speechBubble = text
        bubbleTimer?.invalidate()
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.speechBubble = nil
            }
        }
    }
}

/// Everything Notchi's mood is worked out from.
struct NotchiContext: Equatable {
    var agents: [AgentState] = []
    var ciBuilding = false
    var musicPlaying = false
    var focusActive = false
    var caffeinated = false
    var eating = false
    var dizzy = false
    var batteryLow = false
    var idleFor: TimeInterval = 0
    var hour = 12
    var petted = false
}

/// What Notchi is feeling right now. Urgent or direct interactions win first.
func notchiMood(_ c: NotchiContext) -> NotchiMood {
    if c.dizzy { return .dizzy }
    if c.eating { return .eating }
    if c.agents.contains(.needsYou) { return .alert }
    if c.petted { return .loved }
    if c.agents.contains(.working) || c.ciBuilding { return .busy }
    if c.batteryLow { return .tired }
    if c.focusActive { return .focused }
    if c.musicPlaying { return .vibing }
    if c.caffeinated { return .caffeinated }
    if c.agents.contains(.done) { return .happy }
    if c.idleFor > 10 * 60 || c.hour >= 23 || c.hour < 5 { return .sleepy }
    return .idle
}

/// A short line for Notchi's speech bubble; nil keeps it quiet.
func notchiLine(_ mood: NotchiMood, hour: Int, pets: Int) -> String? {
    switch mood {
    case .alert: return "cek agent!"
    case .busy: return "coding…"
    case .focused: return "fokus 🍅"
    case .caffeinated: return "awake ⚡"
    case .eating: return "nyam 🍙"
    case .dizzy: return "pusing @"
    case .happy: return "beres!"
    case .vibing: return "♪ ♫"
    case .tired: return "cas aku!"
    case .loved: return pets >= 5 ? "bestie! ♥" : pets >= 3 ? "hehe ♥" : "♥"
    case .sleepy: return "antuk zz"
    case .idle:
        switch hour {
        case 5..<11: return "pagi! ☀️"
        case 11..<14: return "makan siang?"
        case 15..<17: return "ngopi yuk ☕"
        case 18..<23: return "malam ✨"
        default: return nil
        }
    }
}

/// Notchi Cyber-Bot with 2D eye gaze, expressive mouth, custom hats/accessories, and particle effects.
struct NotchiMascot: View {
    let mood: NotchiMood
    let size: CGFloat
    var color: Color = .white
    /// -1...1 horizontal pointer gaze
    var gaze: CGFloat = 0
    /// -1...1 vertical pointer gaze
    var gazeY: CGFloat = 0
    var pettedAt: Date?
    var accessory: NotchiAccessory = NotchiCompanionStore.shared.accessory

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
                case .caffeinated: sparks(t: t)
                case .eating: snackParticle(t: t)
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
        case .happy, .eating: return Color(red: 0.06, green: 0.85, blue: 0.55)
        case .focused: return Color(red: 0.38, green: 0.72, blue: 1.0)
        case .caffeinated: return Color(red: 1.0, green: 0.78, blue: 0.22)
        case .dizzy: return .purple
        case .tired: return Color(red: 0.58, green: 0.64, blue: 0.72)
        default: return (color == .white ? Color(red: 0.22, green: 0.74, blue: 0.97) : color)
        }
    }

    private var eyeColor: Color { tint }

    private var glow: Double {
        switch mood {
        case .alert, .loved, .vibing, .caffeinated: return 0.85
        case .happy, .busy, .focused, .eating, .dizzy: return 0.65
        case .idle: return 0.45
        case .tired, .sleepy: return 0.2
        }
    }

    private var resolvedAccessory: NotchiAccessory {
        guard accessory == .auto else { return accessory }
        switch mood {
        case .focused: return .glasses
        case .happy: return .crown
        case .caffeinated: return .halo
        case .idle, .sleepy: return .sprout
        default: return .auto
        }
    }

    private func robotBody(t: Double, sincePet: Double) -> some View {
        let squishY = sincePet < 0.45 ? 1 - 0.35 * sin(sincePet / 0.45 * .pi) : 1
        let squishX = sincePet < 0.45 ? 1 + 0.25 * sin(sincePet / 0.45 * .pi) : 1
        let hopY = (mood == .happy || mood == .caffeinated) ? -abs(sin(t * 7.5)) * (size * 0.09) : 0
        let shakeX = (mood == .alert || mood == .dizzy) ? sin(t * 32) * (size * 0.05) : 0
        let floatY = (mood == .idle || mood == .sleepy || mood == .focused) ? sin(t * 2.2) * (size * 0.025) : 0
        let bopTilt = mood == .vibing ? sin(t * 5.5) * 5.0 : 0

        let blinkCycle = t.truncatingRemainder(dividingBy: 3.4)
        let isBlinking = (mood == .idle || mood == .busy || mood == .focused) && blinkCycle < 0.15
        let blinkScale = isBlinking ? 0.1 : 1.0

        let gazeShiftX: CGFloat = (mood == .idle || mood == .focused) ? max(-2.4, min(2.4, gaze * 2.4)) : 0
        let gazeShiftY: CGFloat = (mood == .idle || mood == .focused) ? max(-1.6, min(1.8, gazeY * 1.8)) : 0
        let alertBlink = sin(t * 10) > 0

        return Canvas { context, canvasSize in
            let scale = canvasSize.width / 32.0
            context.scaleBy(x: scale, y: scale)

            drawRobot(
                context: &context,
                t: t,
                gazeShiftX: gazeShiftX,
                gazeShiftY: gazeShiftY,
                blinkScale: blinkScale,
                isBlinking: isBlinking,
                alertBlink: alertBlink
            )
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(bopTilt))
        .scaleEffect(x: squishX, y: squishY, anchor: .bottom)
        .offset(x: shakeX, y: hopY + floatY)
        .shadow(color: tint.opacity(glow * 0.7), radius: 3)
        .shadow(color: tint.opacity(glow * 0.35), radius: 6)
    }

    private func drawRobot(
        context: inout GraphicsContext,
        t: Double,
        gazeShiftX: CGFloat,
        gazeShiftY: CGFloat,
        blinkScale: CGFloat,
        isBlinking: Bool,
        alertBlink: Bool
    ) {
        let acc = resolvedAccessory
        if acc == .catEars {
            drawCatEars(&context)
        } else {
            drawAntenna(&context, alertBlink: alertBlink, hasSprout: acc == .sprout)
        }
        if acc == .crown {
            drawCrown(&context)
        } else if acc == .halo {
            drawHalo(&context, t: t)
        }
        drawHeadphones(&context)
        drawEarPads(&context)
        drawHelmet(&context)
        drawCheeks(&context)
        drawEyes(
            &context,
            t: t,
            gazeShiftX: gazeShiftX,
            gazeShiftY: gazeShiftY,
            blinkScale: blinkScale,
            isBlinking: isBlinking,
            alertBlink: alertBlink
        )
        drawMouth(&context, t: t, gazeShiftX: gazeShiftX, gazeShiftY: gazeShiftY)
        if acc == .glasses || mood == .focused {
            drawGlasses(&context, gazeShiftX: gazeShiftX, gazeShiftY: gazeShiftY)
        }
    }

    private func drawAntenna(_ context: inout GraphicsContext, alertBlink: Bool, hasSprout: Bool) {
        var pole = Path()
        pole.move(to: CGPoint(x: 16, y: 4.5))
        pole.addLine(to: CGPoint(x: 16, y: 7.5))
        context.stroke(
            pole, with: .color(Color(red: 0.28, green: 0.33, blue: 0.41)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))

        if hasSprout {
            var leftLeaf = Path()
            leftLeaf.move(to: CGPoint(x: 16, y: 4.5))
            leftLeaf.addQuadCurve(to: CGPoint(x: 11.8, y: 2.2), control: CGPoint(x: 12.5, y: 4.8))
            leftLeaf.addQuadCurve(to: CGPoint(x: 16, y: 4.5), control: CGPoint(x: 14.8, y: 1.8))
            context.fill(leftLeaf, with: .color(Color(red: 0.25, green: 0.88, blue: 0.45)))

            var rightLeaf = Path()
            rightLeaf.move(to: CGPoint(x: 16, y: 4.5))
            rightLeaf.addQuadCurve(to: CGPoint(x: 20.2, y: 2.2), control: CGPoint(x: 19.5, y: 4.8))
            rightLeaf.addQuadCurve(to: CGPoint(x: 16, y: 4.5), control: CGPoint(x: 17.2, y: 1.8))
            context.fill(rightLeaf, with: .color(Color(red: 0.18, green: 0.78, blue: 0.38)))
        } else {
            let beaconRect = CGRect(x: 16 - 1.8, y: 3.8 - 1.8, width: 3.6, height: 3.6)
            let beaconAlpha = (mood == .alert && alertBlink) ? 1.0 : 0.85
            context.fill(Path(ellipseIn: beaconRect), with: .color(eyeColor.opacity(beaconAlpha)))
        }
    }

    private func drawCatEars(_ context: inout GraphicsContext) {
        var leftEar = Path()
        leftEar.move(to: CGPoint(x: 5.5, y: 8.5))
        leftEar.addLine(to: CGPoint(x: 4.2, y: 2.2))
        leftEar.addLine(to: CGPoint(x: 11.2, y: 7.5))
        leftEar.closeSubpath()
        context.fill(leftEar, with: .color(Color(red: 0.16, green: 0.18, blue: 0.24)))
        context.stroke(leftEar, with: .color(tint.opacity(0.8)), lineWidth: 1.0)

        var rightEar = Path()
        rightEar.move(to: CGPoint(x: 26.5, y: 8.5))
        rightEar.addLine(to: CGPoint(x: 27.8, y: 2.2))
        rightEar.addLine(to: CGPoint(x: 20.8, y: 7.5))
        rightEar.closeSubpath()
        context.fill(rightEar, with: .color(Color(red: 0.16, green: 0.18, blue: 0.24)))
        context.stroke(rightEar, with: .color(tint.opacity(0.8)), lineWidth: 1.0)
    }

    private func drawCrown(_ context: inout GraphicsContext) {
        var crown = Path()
        crown.move(to: CGPoint(x: 10.5, y: 7.5))
        crown.addLine(to: CGPoint(x: 11.2, y: 2.8))
        crown.addLine(to: CGPoint(x: 13.8, y: 5.2))
        crown.addLine(to: CGPoint(x: 16.0, y: 2.0))
        crown.addLine(to: CGPoint(x: 18.2, y: 5.2))
        crown.addLine(to: CGPoint(x: 20.8, y: 2.8))
        crown.addLine(to: CGPoint(x: 21.5, y: 7.5))
        crown.closeSubpath()
        context.fill(crown, with: .color(Color(red: 1.0, green: 0.82, blue: 0.2)))
        context.stroke(crown, with: .color(Color.orange), lineWidth: 0.7)
    }

    private func drawHalo(_ context: inout GraphicsContext, t: Double) {
        let floatOffset = CGFloat(sin(t * 4) * 0.6)
        let haloRect = CGRect(x: 9.5, y: 2.0 + floatOffset, width: 13, height: 3.2)
        context.stroke(
            Path(ellipseIn: haloRect),
            with: .color(Color(red: 1.0, green: 0.88, blue: 0.35)),
            style: StrokeStyle(lineWidth: 1.6)
        )
    }

    private func drawGlasses(_ context: inout GraphicsContext, gazeShiftX: CGFloat, gazeShiftY: CGFloat) {
        let gx = gazeShiftX * 0.4
        let gy = gazeShiftY * 0.4
        let leftLens = CGRect(x: 7.8 + gx, y: 13.0 + gy, width: 7.2, height: 5.4)
        let rightLens = CGRect(x: 17.0 + gx, y: 13.0 + gy, width: 7.2, height: 5.4)
        let glassColor = Color.white.opacity(0.75)
        context.stroke(Path(roundedRect: leftLens, cornerRadius: 1.4), with: .color(glassColor), lineWidth: 1.1)
        context.stroke(Path(roundedRect: rightLens, cornerRadius: 1.4), with: .color(glassColor), lineWidth: 1.1)

        var bridge = Path()
        bridge.move(to: CGPoint(x: leftLens.maxX, y: 15.2 + gy))
        bridge.addLine(to: CGPoint(x: rightLens.minX, y: 15.2 + gy))
        context.stroke(bridge, with: .color(glassColor), lineWidth: 1.1)
    }

    private func drawHeadphones(_ context: inout GraphicsContext) {
        if mood == .vibing {
            var arc = Path()
            arc.addArc(
                center: CGPoint(x: 16, y: 16), radius: 13.5, startAngle: .degrees(180), endAngle: .degrees(0),
                clockwise: false)
            context.stroke(arc, with: .color(tint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private func drawEarPads(_ context: inout GraphicsContext) {
        let earPadColor = (mood == .vibing) ? tint : Color(red: 0.2, green: 0.25, blue: 0.33)
        let earStroke = (mood == .vibing) ? Color.white : Color.white.opacity(0.15)
        let leftEarRect = CGRect(x: 1.8, y: 12, width: 3.2, height: 9)
        let rightEarRect = CGRect(x: 27.0, y: 12, width: 3.2, height: 9)

        context.fill(Path(roundedRect: leftEarRect, cornerRadius: 1.6), with: .color(earPadColor))
        context.stroke(Path(roundedRect: leftEarRect, cornerRadius: 1.6), with: .color(earStroke), lineWidth: 0.8)

        context.fill(Path(roundedRect: rightEarRect, cornerRadius: 1.6), with: .color(earPadColor))
        context.stroke(Path(roundedRect: rightEarRect, cornerRadius: 1.6), with: .color(earStroke), lineWidth: 0.8)
    }

    private func drawHelmet(_ context: inout GraphicsContext) {
        let helmetRect = CGRect(x: 4, y: 7.5, width: 24, height: 18)
        let helmetPath = Path(roundedRect: helmetRect, cornerRadius: 6.5)
        context.fill(
            helmetPath,
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.14, green: 0.16, blue: 0.2), Color(red: 0.07, green: 0.07, blue: 0.09)]),
                startPoint: CGPoint(x: 16, y: 7.5),
                endPoint: CGPoint(x: 16, y: 25.5)
            ))
        context.stroke(helmetPath, with: .color(Color.white.opacity(0.16)), lineWidth: 1)

        let visorRect = CGRect(x: 6, y: 9.5, width: 20, height: 14)
        let visorPath = Path(roundedRect: visorRect, cornerRadius: 4.5)
        context.fill(visorPath, with: .color(Color(red: 0.024, green: 0.027, blue: 0.039)))
        context.stroke(visorPath, with: .color(Color.white.opacity(0.08)), lineWidth: 0.7)

        var glossPath = Path()
        glossPath.move(to: CGPoint(x: 6.8, y: 11.5))
        glossPath.addQuadCurve(to: CGPoint(x: 25.2, y: 12.2), control: CGPoint(x: 16, y: 9.8))
        glossPath.addLine(to: CGPoint(x: 25.2, y: 10.5))
        glossPath.addQuadCurve(to: CGPoint(x: 6.8, y: 10.5), control: CGPoint(x: 16, y: 9.0))
        glossPath.closeSubpath()
        context.fill(
            glossPath,
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.0)]),
                startPoint: CGPoint(x: 6.8, y: 9.5),
                endPoint: CGPoint(x: 25.2, y: 14.0)
            ))
    }

    private func drawCheeks(_ context: inout GraphicsContext) {
        if mood == .loved || mood == .happy || mood == .eating || mood == .caffeinated {
            let blushColor = Color(red: 0.96, green: 0.28, blue: 0.42).opacity(0.65)
            context.fill(
                Path(ellipseIn: CGRect(x: 8.5 - 1.4, y: 19.8 - 1.4, width: 2.8, height: 2.8)), with: .color(blushColor))
            context.fill(
                Path(ellipseIn: CGRect(x: 23.5 - 1.4, y: 19.8 - 1.4, width: 2.8, height: 2.8)), with: .color(blushColor)
            )
        }
    }

    private func drawEyes(
        _ context: inout GraphicsContext,
        t: Double,
        gazeShiftX: CGFloat,
        gazeShiftY: CGFloat,
        blinkScale: CGFloat,
        isBlinking: Bool,
        alertBlink: Bool
    ) {
        let cy: CGFloat = 15.5 + gazeShiftY

        switch mood {
        case .loved:
            let heart1 = heartPath(cx: 11.5 + gazeShiftX, cy: cy)
            let heart2 = heartPath(cx: 20.5 + gazeShiftX, cy: cy)
            context.fill(heart1, with: .color(eyeColor))
            context.fill(heart2, with: .color(eyeColor))

        case .happy, .eating:
            var leftArc = Path()
            leftArc.move(to: CGPoint(x: 9 + gazeShiftX, y: cy + 1.8))
            leftArc.addQuadCurve(to: CGPoint(x: 14 + gazeShiftX, y: cy + 1.8), control: CGPoint(x: 11.5 + gazeShiftX, y: cy - 2.0))
            context.stroke(leftArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))

            var rightArc = Path()
            rightArc.move(to: CGPoint(x: 18 + gazeShiftX, y: cy + 1.8))
            rightArc.addQuadCurve(to: CGPoint(x: 23 + gazeShiftX, y: cy + 1.8), control: CGPoint(x: 20.5 + gazeShiftX, y: cy - 2.0))
            context.stroke(rightArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))

        case .caffeinated:
            // Sparkling Star Eyes ✦ ✦
            let s1 = starPath(cx: 11.5, cy: cy, r: 3.1)
            let s2 = starPath(cx: 20.5, cy: cy, r: 3.1)
            context.fill(s1, with: .color(eyeColor))
            context.fill(s2, with: .color(eyeColor))

        case .dizzy:
            // Spinning Swirl Rings @ @
            let r1 = CGRect(x: 11.5 - 2.8, y: cy - 2.8, width: 5.6, height: 5.6)
            let r2 = CGRect(x: 20.5 - 2.8, y: cy - 2.8, width: 5.6, height: 5.6)
            context.stroke(Path(ellipseIn: r1), with: .color(eyeColor), lineWidth: 1.5)
            context.stroke(Path(ellipseIn: r2), with: .color(eyeColor), lineWidth: 1.5)
            let pupX1 = 11.5 + CGFloat(cos(t * 14)) * 1.3
            let pupY1 = cy + CGFloat(sin(t * 14)) * 1.3
            let pupX2 = 20.5 + CGFloat(sin(t * 14)) * 1.3
            let pupY2 = cy + CGFloat(cos(t * 14)) * 1.3
            context.fill(Path(ellipseIn: CGRect(x: pupX1 - 1.1, y: pupY1 - 1.1, width: 2.2, height: 2.2)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: pupX2 - 1.1, y: pupY2 - 1.1, width: 2.2, height: 2.2)), with: .color(.white))

        case .vibing:
            var leftArc = Path()
            leftArc.move(to: CGPoint(x: 9 + gazeShiftX, y: cy))
            leftArc.addQuadCurve(to: CGPoint(x: 14 + gazeShiftX, y: cy), control: CGPoint(x: 11.5 + gazeShiftX, y: cy + 2.2))
            context.stroke(leftArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

            var rightArc = Path()
            rightArc.move(to: CGPoint(x: 18 + gazeShiftX, y: cy))
            rightArc.addQuadCurve(to: CGPoint(x: 23 + gazeShiftX, y: cy), control: CGPoint(x: 20.5 + gazeShiftX, y: cy + 2.2))
            context.stroke(rightArc, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))

        case .sleepy:
            var leftLine = Path()
            leftLine.move(to: CGPoint(x: 9.5, y: 16.5))
            leftLine.addLine(to: CGPoint(x: 13.5, y: 16.5))
            context.stroke(
                leftLine, with: .color(eyeColor.opacity(0.75)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            var rightLine = Path()
            rightLine.move(to: CGPoint(x: 18.5, y: 16.5))
            rightLine.addLine(to: CGPoint(x: 22.5, y: 16.5))
            context.stroke(
                rightLine, with: .color(eyeColor.opacity(0.75)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        case .tired:
            var leftLine = Path()
            leftLine.move(to: CGPoint(x: 9.5, y: 15.8))
            leftLine.addLine(to: CGPoint(x: 13.5, y: 17.2))
            context.stroke(
                leftLine, with: .color(eyeColor.opacity(0.6)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

            var rightLine = Path()
            rightLine.move(to: CGPoint(x: 18.5, y: 17.2))
            rightLine.addLine(to: CGPoint(x: 22.5, y: 15.8))
            context.stroke(
                rightLine, with: .color(eyeColor.opacity(0.6)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))

        case .busy:
            let slitH = 2.2 * blinkScale
            let leftSlit = CGRect(x: 9 + gazeShiftX, y: cy - slitH / 2, width: 5, height: slitH)
            let rightSlit = CGRect(x: 18 + gazeShiftX, y: cy - slitH / 2, width: 5, height: slitH)
            context.fill(Path(roundedRect: leftSlit, cornerRadius: 1.1), with: .color(eyeColor))
            context.fill(Path(roundedRect: rightSlit, cornerRadius: 1.1), with: .color(eyeColor))

            let dotX = 11.5 + 4.5 * sin(t * 8)
            let dotRect = CGRect(x: dotX - 1.0, y: cy - 1.0, width: 2.0, height: 2.0)
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))

        case .alert:
            let leftCircle = CGRect(x: 11.5 - 3.2, y: cy - 3.2, width: 6.4, height: 6.4)
            let rightCircle = CGRect(x: 20.5 - 3.2, y: cy - 3.2, width: 6.4, height: 6.4)
            if alertBlink {
                context.fill(Path(ellipseIn: leftCircle), with: .color(eyeColor))
                context.fill(Path(ellipseIn: rightCircle), with: .color(eyeColor))
            } else {
                context.stroke(Path(ellipseIn: leftCircle), with: .color(eyeColor), lineWidth: 1.6)
                context.stroke(Path(ellipseIn: rightCircle), with: .color(eyeColor), lineWidth: 1.6)
            }
            context.fill(
                Path(ellipseIn: CGRect(x: 11.5 - 1.2, y: cy - 1.2, width: 2.4, height: 2.4)), with: .color(.white))
            context.fill(
                Path(ellipseIn: CGRect(x: 20.5 - 1.2, y: cy - 1.2, width: 2.4, height: 2.4)), with: .color(.white))

        case .idle, .focused:
            let eyeH = (mood == .focused ? 4.8 : 5.6) * blinkScale
            let eyeR = min(1.8, eyeH / 2)
            let leftEye = CGRect(x: 11.5 + gazeShiftX - 1.8, y: cy - eyeH / 2, width: 3.6, height: eyeH)
            let rightEye = CGRect(x: 20.5 + gazeShiftX - 1.8, y: cy - eyeH / 2, width: 3.6, height: eyeH)
            context.fill(Path(roundedRect: leftEye, cornerRadius: eyeR), with: .color(eyeColor))
            context.fill(Path(roundedRect: rightEye, cornerRadius: eyeR), with: .color(eyeColor))

            if !isBlinking {
                let hl1 = CGRect(x: 12.2 + gazeShiftX - 0.8, y: cy - 1.1 - 0.8, width: 1.6, height: 1.6)
                let hl2 = CGRect(x: 21.2 + gazeShiftX - 0.8, y: cy - 1.1 - 0.8, width: 1.6, height: 1.6)
                context.fill(Path(ellipseIn: hl1), with: .color(.white))
                context.fill(Path(ellipseIn: hl2), with: .color(.white))
            }
        }
    }

    private func drawMouth(_ context: inout GraphicsContext, t: Double, gazeShiftX: CGFloat, gazeShiftY: CGFloat) {
        let mx = 16.0 + gazeShiftX * 0.6
        let my = 20.4 + gazeShiftY * 0.5

        switch mood {
        case .loved, .happy, .caffeinated:
            // Cute cat smile ω
            var w = Path()
            w.move(to: CGPoint(x: mx - 2.4, y: my - 0.4))
            w.addQuadCurve(to: CGPoint(x: mx, y: my - 0.2), control: CGPoint(x: mx - 1.2, y: my + 1.4))
            w.addQuadCurve(to: CGPoint(x: mx + 2.4, y: my - 0.4), control: CGPoint(x: mx + 1.2, y: my + 1.4))
            context.stroke(w, with: .color(eyeColor.opacity(0.9)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

        case .eating:
            // Munching mouth opening & closing
            let openH = 1.2 + abs(sin(t * 12)) * 2.2
            let rect = CGRect(x: mx - 2.0, y: my - openH / 2, width: 4.0, height: openH)
            context.fill(Path(roundedRect: rect, cornerRadius: openH / 2), with: .color(eyeColor))

        case .alert, .dizzy:
            // Surprised 'o' mouth
            let oRect = CGRect(x: mx - 1.4, y: my - 1.2, width: 2.8, height: 2.8)
            context.stroke(Path(ellipseIn: oRect), with: .color(eyeColor), lineWidth: 1.2)

        case .idle:
            // Subtle friendly mini curve
            var smile = Path()
            smile.move(to: CGPoint(x: mx - 1.5, y: my))
            smile.addQuadCurve(to: CGPoint(x: mx + 1.5, y: my), control: CGPoint(x: mx, y: my + 1.1))
            context.stroke(smile, with: .color(eyeColor.opacity(0.65)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        default:
            break
        }
    }

    private func starPath(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - r))
        p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx + r * 0.22, y: cy - r * 0.22))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx + r * 0.22, y: cy + r * 0.22))
        p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx - r * 0.22, y: cy + r * 0.22))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx - r * 0.22, y: cy - r * 0.22))
        p.closeSubpath()
        return p
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

    static func level(_ i: Int, mood: NotchiMood, t: Double, gaze: CGFloat) -> Double {
        let x = Double(i)
        let rest = restHeights[i]
        func crest(at center: Double, width: Double) -> Double { exp(-pow(x - center, 2) / width) }
        switch mood {
        case .idle, .focused:
            let center = 2 + Double(gaze) * 1.6
            return (0.32 + 0.66 * crest(at: center, width: 1.6)) * (1 + 0.07 * sin(t * 2.2 + x * 0.6))
        case .sleepy:
            return rest * 0.32 + 0.06 * (1 + sin(t * 1.3 + x * 0.35))
        case .busy:
            let center = 2 + 2.2 * sin(t * 4)
            return 0.26 + 0.74 * crest(at: center, width: 0.8)
        case .happy, .eating, .caffeinated:
            return rest * (0.72 + 0.4 * abs(sin(t * 6 - x * 0.65)))
        case .alert, .dizzy:
            return 0.82 + 0.18 * sin(t * 24 + x * 1.3)
        case .vibing:
            let beat = abs(sin(t * (4.6 + x * 1.15) + x * 1.7)) * 0.6 + abs(sin(t * 2.3 + x)) * 0.4
            return 0.22 + 0.78 * beat
        case .tired:
            let flicker = i == 4 ? (sin(t * 9) > 0.55 ? 0.35 : 0.12) : rest * 0.5
            return flicker + 0.04 * sin(t * 1.6 + x)
        case .loved:
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

    private func sparks(t: Double) -> some View {
        let p = (t / 1.4).truncatingRemainder(dividingBy: 1)
        return Text("⚡")
            .font(.system(size: size * 0.22))
            .opacity(1 - p)
            .offset(x: size * 0.44, y: -size * 0.1 - p * size * 0.2)
    }

    private func snackParticle(t: Double) -> some View {
        let p = (t / 1.5).truncatingRemainder(dividingBy: 1)
        return Text("🍙")
            .font(.system(size: size * 0.24))
            .opacity(1 - p)
            .offset(x: size * 0.42, y: -size * 0.06 - p * size * 0.2)
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
    @EnvironmentObject var timer: TimerManager
    @ObservedObject var companion = NotchiCompanionStore.shared
    @ObservedObject var keepAwake = KeepAwake.shared
    @ObservedObject var ambient = AmbientSoundManager.shared
    @ObservedObject var ciMonitor = CIBuildMonitor.shared
    @Environment(\.notchAccent) var notchAccent

    var accent: Color { notchAccent.isNeutral ? Color(red: 0.82, green: 0.82, blue: 0.84) : notchAccent.color }

    var agentStates: [AgentState] { settings.aiEnabled && settings.aiAgents ? agents.sessions.map(\.state) : [] }

    func recentAgentStates(now: Date, doneFor: TimeInterval) -> [AgentState] {
        guard settings.aiEnabled && settings.aiAgents else { return [] }
        return agents.sessions.map {
            $0.state == .done && now.timeIntervalSince($0.updatedAt) > doneFor ? .idle : $0.state
        }
    }

    func context(now: Date, idleFor: TimeInterval = 0, petted: Bool = false) -> NotchiContext {
        let isEating = companion.fedAt.map { now.timeIntervalSince($0) < 3.2 } ?? false
        let isDizzy = companion.dizzyUntil.map { now < $0 } ?? false
        return NotchiContext(
            agents: agentStates,
            ciBuilding: ciMonitor.hasActiveBuild,
            musicPlaying: (media.info?.isPlaying ?? false) || ambient.isPlaying,
            focusActive: timer.isRunning,
            caffeinated: keepAwake.isActive,
            eating: isEating,
            dizzy: isDizzy,
            batteryLow: battery.hasBattery && battery.level <= 15 && !battery.isCharging,
            idleFor: idleFor,
            hour: Calendar.current.component(.hour, from: now),
            petted: petted
        )
    }
}

/// Interactive Notchi for slots that already show something else on the other side (music on left, timer on right, AI meter).
/// Supports full hover (without opening the notch), left-click petting, 2D gaze, and right-click companion menu.
struct NotchiLive: View {
    private var state = NotchiState()
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var timer: TimerManager
    @ObservedObject private var companion = NotchiCompanionStore.shared
    @ObservedObject private var keepAwake = KeepAwake.shared
    @ObservedObject private var ambient = AmbientSoundManager.shared
    let size: CGFloat

    @State private var hovered = false
    @State private var gaze: CGFloat = 0
    @State private var gazeY: CGFloat = 0

    init(size: CGFloat) { self.size = size }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now = context.date
            let petted = companion.pettedAt.map { now.timeIntervalSince($0) < 3.8 } ?? false
            var c = state.context(now: now, petted: petted)
            let _ = c.agents = state.recentAgentStates(now: now, doneFor: NotchiIdleRow.doneFor)
            NotchiMascot(
                mood: notchiMood(c),
                size: size,
                color: state.accent,
                gaze: gaze,
                gazeY: gazeY,
                pettedAt: companion.pettedAt,
                accessory: companion.accessory
            )
            .frame(width: size + 12, height: size + 4)
            .scaleEffect(hovered ? 1.16 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: hovered)
            .contentShape(Rectangle())
            .onHover { inside in
                hovered = inside
                vm.isOverMascot = inside
            }
            .onDisappear { vm.isOverMascot = false }
            .onTapGesture { companion.pet() }
            .contextMenu {
                notchiLiveContextMenu
            }
            .help("Notchi Lv.\(companion.level) (\(companion.bondTitle)) · Click to pet, right-click for actions")
            .onChange(of: now) { _, _ in followPointer() }
        }
    }

    @ViewBuilder
    private var notchiLiveContextMenu: some View {
        Section("Notchi Lv.\(companion.level) · \(companion.bondTitle)") {
            Button {
                companion.pet()
            } label: {
                Label("Pet Notchi (+5 XP)", systemImage: "heart.fill")
            }
            Button {
                companion.feedSnack()
            } label: {
                Label("Feed Cyber-Snack (+15 XP)", systemImage: "carrot.fill")
            }
            Button {
                companion.toggleCoffeeKeepAwake()
            } label: {
                Label(
                    keepAwake.isActive ? "Turn Off Coffee (Keep Awake)" : "Give Coffee (Keep Awake 1h)",
                    systemImage: "cup.and.saucer.fill"
                )
            }
        }
        Section("Do Together") {
            Button {
                companion.toggleFocusSession(timer: timer)
            } label: {
                Label(timer.isRunning ? "Pause Focus Timer" : "Start 25m Focus Session", systemImage: "timer")
            }
            Button {
                companion.toggleLoFiRain()
            } label: {
                Label(ambient.isPlaying ? "Stop Focus Soundscapes" : "Play Rain + Vinyl Lo-Fi", systemImage: "cloud.rain.fill")
            }
            Button {
                vm.tab = .ai
                vm.open()
            } label: {
                Label("Ask Notchi AI…", systemImage: "sparkles")
            }
        }
        Menu("Costume & Hat") {
            ForEach(NotchiAccessory.allCases) { item in
                Button {
                    companion.accessory = item
                } label: {
                    HStack {
                        Label(item.label, systemImage: item.icon)
                        if companion.accessory == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    private func followPointer() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let targetX = max(-1, min(1, (mouse.x - screen.frame.midX) / 400))
        let distFromTop = max(0, screen.frame.maxY - mouse.y)
        let targetY = max(-0.5, min(1, (distFromTop - 40) / 350))
        if abs(targetX - gaze) > 0.05 || abs(targetY - gazeY) > 0.05 {
            withAnimation(.easeOut(duration: 0.25)) {
                gaze = targetX
                gazeY = targetY
            }
        }
    }
}

/// Compact interactive Notchi button for the Open Notch HeaderView, with a full Companion Popover.
struct NotchiHeaderAvatarButton: View {
    private var state = NotchiState()
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var timer: TimerManager
    @ObservedObject private var companion = NotchiCompanionStore.shared
    @State private var showPopover = false
    @State private var isHovering = false

    var body: some View {
        let now = Date.now
        let petted = companion.pettedAt.map { now.timeIntervalSince($0) < 3.5 } ?? false
        let c = state.context(now: now, petted: petted || isHovering)
        let mood = notchiMood(c)

        Button {
            showPopover.toggle()
        } label: {
            HStack(spacing: 4) {
                NotchiMascot(
                    mood: mood,
                    size: 20,
                    color: state.accent,
                    pettedAt: companion.pettedAt,
                    accessory: companion.accessory
                )
                if let bubble = companion.speechBubble {
                    Text(bubble)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(.white.opacity(isHovering || showPopover ? 0.14 : 0.06))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .onChange(of: showPopover) { _, open in
            vm.holdOpen = open
        }
        .help("Notchi Companion (Lv.\(companion.level) \(companion.bondTitle)) — Click to interact!")
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            NotchiCompanionCard(mood: mood, accent: state.accent)
                .environmentObject(vm)
                .environmentObject(timer)
        }
    }
}

/// Interactive Companion Popover Card for petting, feeding, changing hats, and triggering quick workflows.
struct NotchiCompanionCard: View {
    let mood: NotchiMood
    let accent: Color
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var timer: TimerManager
    @ObservedObject private var companion = NotchiCompanionStore.shared
    @ObservedObject private var keepAwake = KeepAwake.shared
    @ObservedObject private var ambient = AmbientSoundManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Profile & Interactive Avatar
            HStack(spacing: 12) {
                Button {
                    companion.pet()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accent.opacity(0.35), lineWidth: 1)
                            )
                        NotchiMascot(
                            mood: mood,
                            size: 48,
                            color: accent,
                            pettedAt: companion.pettedAt,
                            accessory: companion.accessory
                        )
                    }
                    .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                .help("Click to pet Notchi!")

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Notchi")
                            .font(.system(size: 13, weight: .bold))
                        Text("Lv.\(companion.level)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Color.accentColor.opacity(0.22)))
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                        Text(mood.badgeLabel)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(companion.bondTitle)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    ProgressView(value: companion.currentLevelProgress)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                        .frame(height: 5)

                    HStack(spacing: 10) {
                        Label("\(companion.totalPets) pets", systemImage: "heart.fill")
                        Label("\(companion.snacksFed) snacks", systemImage: "takeoutbag.and.cup.and.straw.fill")
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                }
            }

            // Speech Bubble Quote Bar
            HStack(spacing: 6) {
                Image(systemName: "quote.Opening")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(companion.speechBubble ?? notchiLine(mood, hour: Calendar.current.component(.hour, from: Date()), pets: companion.recentPetCombo) ?? "Klik aku untuk elus, kasih snack, atau mulai fokus bareng!")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))

            // 4 Quick Care & Utility Actions
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                companionActionButton(
                    title: "Feed Snack",
                    subtitle: "+15 XP",
                    icon: "carrot.fill",
                    tint: .green,
                    active: false
                ) {
                    companion.feedSnack()
                }

                companionActionButton(
                    title: keepAwake.isActive ? "Caffeine ON" : "Give Coffee",
                    subtitle: keepAwake.isActive ? "Mac stays awake" : "Keep Awake 1h",
                    icon: "cup.and.saucer.fill",
                    tint: .orange,
                    active: keepAwake.isActive
                ) {
                    companion.toggleCoffeeKeepAwake()
                }

                companionActionButton(
                    title: timer.isRunning ? "Pause Focus" : "Focus 25m",
                    subtitle: timer.isRunning ? "Pomodoro active" : "Pomodoro + XP",
                    icon: "timer",
                    tint: .cyan,
                    active: timer.isRunning
                ) {
                    companion.toggleFocusSession(timer: timer)
                }

                companionActionButton(
                    title: ambient.isPlaying ? "Lo-Fi Playing" : "Rain + Vinyl",
                    subtitle: ambient.isPlaying ? "Click to mute" : "Focus soundscape",
                    icon: "cloud.rain.fill",
                    tint: .indigo,
                    active: ambient.isPlaying
                ) {
                    companion.toggleLoFiRain()
                }
            }

            // Hat / Costume Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Costume & Accessory")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(NotchiAccessory.allCases) { item in
                        let selected = companion.accessory == item
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                companion.accessory = item
                                companion.say("Ganti kostum: \(item.label)! ✨", duration: 2.2)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                Text(item.label)
                                    .font(.system(size: 8.5, weight: selected ? .bold : .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(selected ? Color.accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 310)
    }

    private func companionActionButton(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(active ? .white : tint)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(active ? tint : tint.opacity(0.15))
                    )
                VStack(alignment: .leading, spacing: 0.5) {
                    Text(title)
                        .font(.system(size: 10.5, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? tint.opacity(0.14) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(active ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// The closed-notch slot Notchi lives in: the mascot on the left, live speech bubble / status on the right.
/// Left-click to pet, right-click for quick actions (Feed, Coffee/Keep Awake, Focus 25m, Costume).
struct NotchiIdleRow: View {
    private var state = NotchiState()
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var timer: TimerManager
    @ObservedObject private var companion = NotchiCompanionStore.shared
    @ObservedObject private var keepAwake = KeepAwake.shared
    @ObservedObject private var ambient = AmbientSoundManager.shared
    let height: CGFloat

    @State private var hovered = false
    @State private var quietSince = Date.now
    @State private var gaze: CGFloat = 0
    @State private var gazeY: CGFloat = 0

    static let doneFor: TimeInterval = 8

    init(height: CGFloat) { self.height = height }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now = context.date
            let petted = companion.pettedAt.map { now.timeIntervalSince($0) < 3.8 } ?? false
            var c = state.context(now: now, idleFor: now.timeIntervalSince(quietSince), petted: petted || hovered)
            let _ = c.agents = state.recentAgentStates(now: now, doneFor: Self.doneFor)
            let mood = notchiMood(c)
            let box = height - 10

            HStack(spacing: 0) {
                NotchiMascot(
                    mood: mood,
                    size: box,
                    color: state.accent,
                    gaze: gaze,
                    gazeY: gazeY,
                    pettedAt: companion.pettedAt,
                    accessory: companion.accessory
                )
                .frame(width: height + 6, height: height)
                .scaleEffect(hovered ? 1.16 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: hovered)
                .contentShape(Rectangle())
                .onHover { inside in
                    hovered = inside
                    vm.isOverMascot = inside
                    if inside { quietSince = .now }
                }
                .onDisappear { vm.isOverMascot = false }
                .onTapGesture { companion.pet() }
                .contextMenu {
                    notchiContextMenu
                }
                .help("Notchi Lv.\(companion.level) (\(companion.bondTitle)) · Click to pet, right-click for actions")

                Spacer(minLength: 0)

                NotchiStatus(
                    mood: mood,
                    now: now,
                    accent: state.accent,
                    size: box,
                    pets: companion.recentPetCombo,
                    speechBubble: companion.speechBubble ?? (hovered ? notchiLine(mood, hour: Calendar.current.component(.hour, from: now), pets: companion.recentPetCombo) : nil)
                )
                .frame(width: height + 6, height: height)
                .fixedSize(horizontal: true, vertical: false)
            }
            .onChange(of: now) { _, _ in followPointer() }
            .onChange(of: state.agentStates) { _, _ in quietSince = .now }
        }
    }

    @ViewBuilder
    private var notchiContextMenu: some View {
        Section("Notchi Lv.\(companion.level) · \(companion.bondTitle)") {
            Button {
                companion.pet()
            } label: {
                Label("Pet Notchi (+5 XP)", systemImage: "heart.fill")
            }
            Button {
                companion.feedSnack()
            } label: {
                Label("Feed Cyber-Snack (+15 XP)", systemImage: "carrot.fill")
            }
            Button {
                companion.toggleCoffeeKeepAwake()
            } label: {
                Label(
                    keepAwake.isActive ? "Turn Off Coffee (Keep Awake)" : "Give Coffee (Keep Awake 1h)",
                    systemImage: "cup.and.saucer.fill"
                )
            }
        }
        Section("Do Together") {
            Button {
                companion.toggleFocusSession(timer: timer)
            } label: {
                Label(timer.isRunning ? "Pause Focus Timer" : "Start 25m Focus Session", systemImage: "timer")
            }
            Button {
                companion.toggleLoFiRain()
            } label: {
                Label(ambient.isPlaying ? "Stop Focus Soundscapes" : "Play Rain + Vinyl Lo-Fi", systemImage: "cloud.rain.fill")
            }
            Button {
                vm.tab = .ai
                vm.open()
            } label: {
                Label("Ask Notchi AI…", systemImage: "sparkles")
            }
        }
        Menu("Costume & Hat") {
            ForEach(NotchiAccessory.allCases) { item in
                Button {
                    companion.accessory = item
                } label: {
                    HStack {
                        Label(item.label, systemImage: item.icon)
                        if companion.accessory == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }

    /// Tracks both horizontal and vertical cursor position so Notchi looks toward and down at your work.
    private func followPointer() {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let targetX = max(-1, min(1, (mouse.x - screen.frame.midX) / 400))
        let distFromTop = max(0, screen.frame.maxY - mouse.y)
        let targetY = max(-0.5, min(1, (distFromTop - 40) / 350))
        if abs(targetX - gaze) > 0.05 || abs(targetY - gazeY) > 0.05 {
            withAnimation(.easeOut(duration: 0.25)) {
                gaze = targetX
                gazeY = targetY
            }
        }
    }
}

/// The right side of Notchi's row: shows Notchi's live speech bubble when talking, or animated status / ambient info.
private struct NotchiStatus: View {
    @EnvironmentObject private var prayers: PrayerTimesManager
    @EnvironmentObject private var weather: WeatherManager
    @EnvironmentObject private var settings: AppSettings
    let mood: NotchiMood
    let now: Date
    let accent: Color
    let size: CGFloat
    let pets: Int
    let speechBubble: String?

    var body: some View {
        Group {
            if let speechBubble, !speechBubble.isEmpty {
                Text(speechBubble)
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.28))
                            .overlay(Capsule().stroke(accent.opacity(0.5), lineWidth: 0.6))
                    )
                    .lineLimit(1)
            } else {
                switch mood {
                case .busy: busyRing
                case .focused: icon("eyeglasses", .cyan, effect: .pulse)
                case .caffeinated: icon("cup.and.saucer.fill", .yellow, effect: .bounce)
                case .eating: icon("carrot.fill", .green, effect: .bounce)
                case .dizzy: icon("tornado", .purple, effect: .wiggle)
                case .happy: icon("checkmark.circle.fill", .green, effect: .bounce)
                case .alert: icon("hand.raised.fill", .orange, effect: .wiggle)
                case .loved: icon(pets >= 3 ? "heart.circle.fill" : "heart.fill", .pink, effect: .bounce)
                case .tired: icon("battery.25percent", .red, effect: .pulse)
                case .vibing: icon("music.note", accent, effect: .pulse)
                case .sleepy: icon("moon.zzz.fill", accent.opacity(0.7), effect: .pulse)
                case .idle: ambient
                }
            }
        }
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: mood)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: speechBubble)
    }

    private enum Effect { case bounce, wiggle, pulse }

    private func icon(_ name: String, _ color: Color, effect: Effect) -> some View {
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

    private var busyRing: some View {
        let angle = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2 * 360
        return ZStack {
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

    @ViewBuilder
    private var ambient: some View {
        let items = ambientItems
        if !items.isEmpty {
            let item = items[Int(now.timeIntervalSinceReferenceDate / 6) % items.count]
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
