import AppKit
import SwiftUI

enum NotchTab: String, CaseIterable {
    case home = "Home"
    case tray = "Tray"
    case clipboard = "Clipboard"
    case timer = "Timer"
    case mirror = "Mirror"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .tray: return "tray.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .timer: return "timer"
        case .mirror: return "camera.fill"
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
        guard !isOpen else { return }
        self.peek = peek
        peekWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.peek = nil }
        peekWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + peek.duration, execute: work)
    }

    func toggle() {
        isOpen ? close() : open()
    }

    func close() {
        pending?.cancel()
        isOpen = false
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
