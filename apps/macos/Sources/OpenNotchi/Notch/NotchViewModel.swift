import AppKit
import SwiftUI

enum NotchTab: String, CaseIterable {
    case home = "Home"
    case tray = "Tray"
    case clipboard = "Clipboard"
    case timer = "Timer"
    case mirror = "Mirror"
    case markets = "Markets"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .tray: return "tray.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .timer: return "timer"
        case .mirror: return "camera.fill"
        case .markets: return "chart.line.uptrend.xyaxis"
        }
    }
}

final class NotchViewModel: ObservableObject {
    @Published private(set) var isOpen = false
    @Published var tab: NotchTab = .home
    @Published var notchSize: CGSize = CGSize(width: 190, height: 32)
    @Published var hasPhysicalNotch = false

    @Published var isDropTargeted = false {
        didSet {
            guard isDropTargeted != oldValue else { return }
            if isDropTargeted {
                tab = .tray
                open()
            } else if !isHovering {
                scheduleClose(after: 0.6)
            }
        }
    }

    let openSize = CGSize(width: 680, height: 200)

    /// Current peek beside the closed notch, cleared after its duration.
    @Published private(set) var peek: Peek?
    private var peekWork: DispatchWorkItem?
    private var deferredBanner: (peek: Peek, at: Date)?

    private let settings: AppSettings
    private var isHovering = false
    private var pending: DispatchWorkItem?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func update(for screen: NSScreen) {
        if let size = screen.notchSize {
            notchSize = size
            hasPhysicalNotch = true
        } else {
            notchSize = CGSize(width: 190, height: screen.menuBarHeight)
            hasPhysicalNotch = false
        }
    }

    func hoverChanged(_ inside: Bool) {
        isHovering = inside
        pending?.cancel()
        // A banner stays put while the pointer is on it (so its button can be clicked) instead of opening the notch.
        if peek?.isBanner == true {
            inside ? peekWork?.cancel() : schedulePeekDismissal(after: 4)
            return
        }
        if inside {
            let work = DispatchWorkItem { [weak self] in self?.open() }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.hoverDelay, execute: work)
        } else if !isDropTargeted {
            scheduleClose(after: 0.12)
        }
    }

    func open() {
        pending?.cancel()
        guard !isOpen else { return }
        isOpen = true
        peek = nil
        if settings.hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func showPeek(_ peek: Peek) {
        guard !isOpen else {
            // Reminders shouldn't be lost while the notch is open: show them once it closes.
            if peek.isBanner { deferredBanner = (peek, .now) }
            return
        }
        self.peek = peek
        schedulePeekDismissal(after: peek.duration)
    }

    func dismissPeek() {
        peekWork?.cancel()
        peek = nil
    }

    private func schedulePeekDismissal(after delay: TimeInterval) {
        peekWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.peek = nil }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func toggle() {
        isOpen ? close() : open()
    }

    func close() {
        pending?.cancel()
        guard isOpen else { return }
        isOpen = false
        if let deferred = deferredBanner {
            deferredBanner = nil
            if Date.now.timeIntervalSince(deferred.at) < 5 * 60 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showPeek(deferred.peek) }
            }
        }
    }

    private func scheduleClose(after delay: TimeInterval) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isHovering, !self.isDropTargeted else { return }
            self.close()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
