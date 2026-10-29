import AppKit
import UserNotifications

/// A single countdown timer, optionally cycling Pomodoro focus/break phases.
final class TimerManager: ObservableObject {
    enum Phase {
        case focus, shortBreak, longBreak

        var minutes: Int {
            switch self {
            case .focus: return 25
            case .shortBreak: return 5
            case .longBreak: return 15
            }
        }

        var label: String {
            switch self {
            case .focus: return "Focus"
            case .shortBreak: return "Break"
            case .longBreak: return "Long Break"
            }
        }
    }

    /// Every 4th finished focus earns a long break.
    static let sessionsPerLongBreak = 4

    static func phase(after phase: Phase, focusDone: Int) -> Phase {
        guard phase == .focus else { return .focus }
        return focusDone % sessionsPerLongBreak == 0 ? .longBreak : .shortBreak
    }

    @Published private(set) var pomodoro = false
    @Published private(set) var phase: Phase = .focus
    /// Focus sessions finished today.
    @Published private(set) var focusToday = 0
    private var focusDay = Calendar.current.startOfDay(for: Date())

    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?
    @Published private(set) var duration: TimeInterval = 25 * 60
    @Published private(set) var didFinish = false

    /// Called on the main thread when the countdown hits zero.
    var onFinish: (() -> Void)?

    private var finishTimer: Timer?

    var isRunning: Bool { endDate != nil }
    var isActive: Bool { endDate != nil || pausedRemaining != nil }

    func remaining(at date: Date = Date()) -> TimeInterval {
        if let endDate { return max(0, endDate.timeIntervalSince(date)) }
        return pausedRemaining ?? duration
    }

    func progress(at date: Date = Date()) -> Double {
        guard duration > 0 else { return 0 }
        return 1 - remaining(at: date) / duration
    }

    func setDuration(minutes: Int) {
        guard !isActive else { return }
        duration = TimeInterval(max(1, minutes) * 60)
        didFinish = false
    }

    func addMinute() {
        if let endDate {
            self.endDate = endDate.addingTimeInterval(60)
            duration += 60
            schedule()
        } else if let pausedRemaining {
            self.pausedRemaining = pausedRemaining + 60
            duration += 60
        } else {
            duration += 60
        }
    }

    func setPomodoro(_ on: Bool) {
        reset()
        pomodoro = on
        phase = .focus
        duration = TimeInterval((on ? Phase.focus.minutes : 25) * 60)
    }

    /// Ends the current phase early and starts the next one.
    func skip() {
        guard pomodoro else { return }
        advance(countFocus: false)
    }

    private func advance(countFocus: Bool) {
        if countFocus, phase == .focus {
            let today = Calendar.current.startOfDay(for: Date())
            if today != focusDay { focusDay = today; focusToday = 0 }
            focusToday += 1
        }
        // A skipped focus never earns the long break.
        phase = countFocus ? Self.phase(after: phase, focusDone: focusToday) : (phase == .focus ? .shortBreak : .focus)
        duration = TimeInterval(phase.minutes * 60)
        pausedRemaining = nil
        start()
    }

    func start() {
        didFinish = false
        endDate = Date().addingTimeInterval(pausedRemaining ?? duration)
        pausedRemaining = nil
        schedule()
        requestNotificationPermission()
        AmbientSoundManager.shared.handleTimerStart(isFocusPhase: !pomodoro || phase == .focus)
    }

    func pause() {
        guard let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        finishTimer?.invalidate()
        AmbientSoundManager.shared.handleTimerPauseOrEnd()
    }

    func reset() {
        finishTimer?.invalidate()
        endDate = nil
        pausedRemaining = nil
        didFinish = false
        AmbientSoundManager.shared.handleTimerPauseOrEnd()
    }

    private func schedule() {
        finishTimer?.invalidate()
        guard let endDate else { return }
        let timer = Timer(fire: endDate, interval: 0, repeats: false) { [weak self] _ in self?.finish() }
        RunLoop.main.add(timer, forMode: .common)
        finishTimer = timer
    }

    private func finish() {
        endDate = nil
        pausedRemaining = nil
        NSSound(named: "Glass")?.play()
        postNotification()
        if pomodoro {
            // Next phase starts by itself; no "Done" state between phases.
            advance(countFocus: true)
        } else {
            didFinish = true
            AmbientSoundManager.shared.handleTimerPauseOrEnd()
        }
        onFinish?()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        if pomodoro {
            content.title = phase == .focus ? "Focus done" : "Break's over"
            content.body = phase == .focus ? "Nice work. Time for a break." : "Back to focus."
        } else {
            content.title = "Time's up"
            content.body = "Your \(Int(duration / 60))-minute timer has finished."
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
