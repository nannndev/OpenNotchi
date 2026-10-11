import EventKit
import Foundation

/// Today's remaining events. Only asks for access when the user taps "Connect".
final class CalendarManager: ObservableObject {
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var hasAccess = false

    private let store = EKEventStore()
    private var timer: Timer?

    init() {
        hasAccess = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .EKEventStoreChanged, object: store)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.reload() }
        reload()
    }

    var canRequestAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.hasAccess = granted
                self?.reload()
            }
        }
    }

    @objc func reload() {
        guard hasAccess else { return }
        let now = Date()
        let calendar = Calendar.current
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return }

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let upcoming = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
        DispatchQueue.main.async { self.events = upcoming }
    }
}
