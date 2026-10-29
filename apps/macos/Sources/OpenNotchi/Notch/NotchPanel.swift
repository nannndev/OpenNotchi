import AppKit
import SwiftUI

/// Borderless, transparent panel that floats above the menu bar on every Space.
/// Fully transparent pixels let clicks pass through to whatever is underneath.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that reacts to the first click even when the panel isn't key,
/// and forwards closed-notch scroll & swipe gestures to NotchScreenManager.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    weak var viewModel: NotchViewModel?
    weak var media: MediaManager?
    weak var settings: AppSettings?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        if AppDelegate.shared?.screenManager?.handleNotchScroll(event) == true {
            return
        }
        super.scrollWheel(with: event)
    }

    override func swipe(with event: NSEvent) {
        if AppDelegate.shared?.screenManager?.handleNotchSwipe(event) == true {
            return
        }
        super.swipe(with: event)
    }
}

extension NSScreen {
    /// Size of the physical camera housing, or nil when the screen has none.
    var notchSize: CGSize? {
        guard safeAreaInsets.top > 0,
              let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else { return nil }
        return CGSize(width: frame.width - left.width - right.width, height: safeAreaInsets.top)
    }

    var menuBarHeight: CGFloat {
        let h = frame.maxY - visibleFrame.maxY
        return h > 0 ? h : 24
    }

    /// The built-in display if it has a notch, otherwise the main screen.
    static var preferredNotchScreen: NSScreen? {
        screens.first(where: { $0.notchSize != nil }) ?? main
    }

    /// The display currently containing the mouse cursor.
    static var screenWithCursor: NSScreen? {
        let mouseLoc = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLoc, $0.frame, false) } ?? main
    }

    /// Hardware display ID (CGDirectDisplayID) to uniquely identify this monitor.
    var displayID: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(id.uint32Value)
    }
}
