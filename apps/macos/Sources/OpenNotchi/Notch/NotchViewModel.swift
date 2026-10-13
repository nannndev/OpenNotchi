import AppKit
import SwiftUI

enum NotchTab: String, CaseIterable {
    case home = "Home"
    case tray = "Tray"
    case prompter = "Prompter"
    case clipboard = "Clipboard"
    case timer = "Timer"
    case mirror = "Mirror"
    case markets = "Markets"
    case dev = "Dev"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .tray: return "tray.fill"
        case .prompter: return "text.viewfinder"
        case .clipboard: return "doc.on.clipboard.fill"
        case .timer: return "timer"
        case .mirror: return "camera.fill"
        case .markets: return "chart.line.uptrend.xyaxis"
        case .dev: return "terminal.fill"
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

    @Published var isStudioOpen = false

    static let openWidth: CGFloat = 680
    static let defaultOpenHeight: CGFloat = 200
    /// The Mirror tab can be dragged taller, up to this height.
    static let maxOpenHeight: CGFloat = 470

    var openSize: CGSize {
        let height: CGFloat
        if isStudioOpen {
            height = Self.maxOpenHeight
        } else if tab == .mirror && settings.mirrorTabEnabled {
            height = min(max(settings.mirrorHeight, Self.defaultOpenHeight), Self.maxOpenHeight)
        } else if tab == .prompter && settings.prompterTabEnabled {
            height = min(max(settings.prompterHeight, 240), Self.maxOpenHeight)
        } else if tab == .dev {
            height = 230
        } else {
            height = Self.defaultOpenHeight
        }
        return CGSize(width: Self.openWidth, height: height)
    }

    /// True while the bottom edge is being dragged, so the notch doesn't close if the pointer slips outside.
    @Published var isResizing = false

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
        } else if !isDropTargeted && !staysOpenOnHoverExit {
            scheduleClose(after: 0.12)
        }
    }

    /// The Mirror or Prompter tab stays open when the pointer leaves; a click elsewhere closes it.
    private var staysOpenOnHoverExit: Bool {
        isOpen && (pinned || (tab == .mirror && settings.mirrorStaysOpen) || (tab == .prompter && settings.prompterStaysOpen))
    }

    /// Keeps the notch open regardless of the pointer (the `pin` command, for demos and screenshots).
    var pinned = false

    /// Set while something must not be interrupted, like a photobox countdown.
    @Published var holdOpen = false

    /// A click in another app closes the notch, unless it's being held open.
    func clickedOutside() {
        guard !holdOpen, !pinned else { return }
        close()
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
            guard let self, !self.isHovering, !self.isDropTargeted, !self.isResizing else { return }
            self.close()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Replays the open animation for live previews (e.g. testing animation styles in Settings).
    func replayAnimation(duration: TimeInterval = 2.2) {
        pending?.cancel()
        if isOpen {
            isOpen = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
                guard let self else { return }
                self.isOpen = true
                self.scheduleClose(after: duration)
            }
        } else {
            isOpen = true
            scheduleClose(after: duration)
        }
    }
}
