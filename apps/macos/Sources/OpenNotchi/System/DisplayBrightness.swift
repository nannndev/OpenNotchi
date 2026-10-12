import CoreGraphics
import Foundation

/// Built-in display brightness through the DisplayServices framework (no public API exists).
enum DisplayBrightness {
    private typealias GetFunction = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFunction = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getBrightness: GetFunction? = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFunction.self) }
    private static let setBrightness: SetFunction? = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFunction.self) }

    private static var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }

    /// 0...1, or nil when there's no built-in display we can control.
    static var level: Float? {
        get {
            guard let display = builtInDisplay, let getBrightness else { return nil }
            var value: Float = 0
            return getBrightness(display, &value) == 0 ? value : nil
        }
        set {
            guard let display = builtInDisplay, let setBrightness, let newValue else { return }
            _ = setBrightness(display, min(max(newValue, 0), 1))
        }
    }
}
