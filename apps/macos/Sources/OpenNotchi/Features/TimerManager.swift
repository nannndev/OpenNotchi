import AppKit
import UserNotifications

/// A single countdown timer (Pomodoro-style).
final class TimerManager: ObservableObject {
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

    func start() {
        didFinish = false
        endDate = Date().addingTimeInterval(pausedRemaining ?? duration)
        pausedRemaining = nil
        schedule()
        requestNotificationPermission()
    }

    func pause() {
        guard let endDate else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        finishTimer?.invalidate()
    }

    func reset() {
        finishTimer?.invalidate()
        endDate = nil
        pausedRemaining = nil
        didFinish = false
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
        didFinish = true
        NSSound(named: "Glass")?.play()
        postNotification()
        onFinish?()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "Your \(Int(duration / 60))-minute timer has finished."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
