import Foundation
import IOKit.pwr_mgt

/// Keeps the Mac and its display awake, like `caffeinate -d`.
final class KeepAwake: ObservableObject {
    static let shared = KeepAwake()

    /// When keep-awake ends; `.distantFuture` means until turned off. Nil when off.
    @Published private(set) var until: Date?
    private var assertion: IOPMAssertionID = 0
    private var timer: Timer?

    var isActive: Bool { until != nil }

    /// Starts keep-awake for `minutes`, or indefinitely when nil.
    func start(minutes: Int?) {
        stop()
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "OpenNotchi Keep Awake" as CFString,
            &assertion
        )
        guard result == kIOReturnSuccess else { return }
        until = minutes.map { .now + Double($0 * 60) } ?? .distantFuture
        if let minutes {
            timer = Timer.scheduledTimer(withTimeInterval: Double(minutes * 60), repeats: false) { [weak self] _ in self?.stop() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if until != nil { IOPMAssertionRelease(assertion) }
        until = nil
    }
}
