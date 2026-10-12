import AppKit

/// Sends files with AirDrop and tracks the transfer, so the notch can show its progress.
final class AirDropService: NSObject, ObservableObject, NSSharingServiceDelegate {
    static let shared = AirDropService()

    enum State: Equatable {
        case idle
        /// The AirDrop window is open and the user is picking a device.
        case choosing(count: Int)
        /// Sending; `progress` is nil until macOS reports how far along it is.
        case sending(count: Int, progress: Double?)
        case sent(count: Int)
        case failed
    }

    @Published private(set) var state: State = .idle

    /// A transfer is in flight or just finished (shown beside the closed notch).
    var isTransferring: Bool {
        switch state {
        case .sending, .sent, .failed: return true
        case .idle, .choosing: return false
        }
    }

    static var isAvailable: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }

    /// Kept alive for the whole transfer; a released service closes its window and never reports back.
    private var service: NSSharingService?
    private var subscribers: [Any] = []
    private var observations: [NSKeyValueObservation] = []
    private var fractions: [URL: Double] = [:]
    private var resetWork: DispatchWorkItem?

    static func send(_ urls: [URL]) {
        shared.send(urls)
    }

    func send(_ urls: [URL]) {
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls) else {
            NSSound.beep()
            return
        }
        cleanUp()
        resetWork?.cancel()
        service.delegate = self
        self.service = service
        state = .choosing(count: urls.count)
        watchProgress(of: urls)

        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    /// macOS publishes a Progress for each file AirDrop is sending (it's what draws the bar on
    /// the icon in Finder). Subscribing to it is the only public way to follow the transfer.
    private func watchProgress(of urls: [URL]) {
        for url in urls {
            let subscriber = Progress.addSubscriber(forFileURL: url) { [weak self] progress in
                let observation = progress.observe(\.fractionCompleted, options: [.initial, .new]) { progress, _ in
                    DispatchQueue.main.async { self?.update(url, fraction: progress.fractionCompleted) }
                }
                DispatchQueue.main.async { self?.observations.append(observation) }
                return { observation.invalidate() }
            }
            subscribers.append(subscriber)
        }
    }

    /// The first progress report means a device was picked and the transfer is under way.
    private func update(_ url: URL, fraction: Double) {
        let count: Int
        switch state {
        case .choosing(let n), .sending(let n, _): count = n
        default: return
        }
        fractions[url] = fraction
        if case .choosing = state, fraction <= 0 { return }
        state = .sending(count: count, progress: overall(count))
    }

    private func overall(_ count: Int) -> Double {
        min(1, fractions.values.reduce(0, +) / Double(max(count, 1)))
    }

    // MARK: - NSSharingServiceDelegate

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(.sent(count: items.count))
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        let cancelled = (error as NSError).code == NSUserCancelledError
        finish(cancelled ? .idle : .failed)
    }

    private func finish(_ final: State) {
        cleanUp()
        state = final
        guard final != .idle else { return }
        let work = DispatchWorkItem { [weak self] in self?.state = .idle }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    private func cleanUp() {
        subscribers.forEach(Progress.removeSubscriber)
        subscribers = []
        observations.forEach { $0.invalidate() }
        observations = []
        fractions = [:]
        service = nil
    }
}
