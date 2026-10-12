import AppKit
import ApplicationServices

/// Volume and brightness keys on the keyboard.
enum MediaKey {
    case volumeUp, volumeDown, mute, brightnessUp, brightnessDown
}

/// Intercepts media keys with a CGEvent tap so OpenNotchi can replace the system HUD.
/// Needs Accessibility permission.
final class MediaKeyInterceptor {
    /// Return true to swallow the key (OpenNotchi handled it), false to let macOS handle it.
    var handler: ((MediaKey) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt if permission hasn't been granted.
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        guard tap == nil, Self.isTrusted else { return tap != nil }
        let mask = CGEventMask(1 << 14) // NX_SYSDEFINED
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(context).takeUnretainedValue()
                return interceptor.handle(type: type, event: event)
            },
            userInfo: context
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables slow taps; turn ours back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else { return Unmanaged.passUnretained(event) }

        let keyCode = (nsEvent.data1 & 0xFFFF_0000) >> 16
        let keyState = (nsEvent.data1 & 0xFF00) >> 8
        let isKeyDown = keyState == 0xA

        let key: MediaKey
        switch keyCode {
        case 0: key = .volumeUp
        case 1: key = .volumeDown
        case 7: key = .mute
        case 2: key = .brightnessUp
        case 3: key = .brightnessDown
        default: return Unmanaged.passUnretained(event)
        }

        // Decide on key down; the matching key up follows the same decision.
        if isKeyDown {
            if handler?(key) == true {
                swallowed.insert(keyCode)
                return nil
            }
            swallowed.remove(keyCode)
            return Unmanaged.passUnretained(event)
        }
        return swallowed.contains(keyCode) ? nil : Unmanaged.passUnretained(event)
    }

    /// Key codes whose last key down was swallowed.
    private var swallowed: Set<Int> = []
}
