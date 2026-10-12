import Foundation

/// Runs AppleScript on one serial queue (NSAppleScript is not thread-safe)
/// and caches compiled scripts by source.
enum AppleScriptRunner {
    static let queue = DispatchQueue(label: "io.github.opennotchi.applescript", qos: .userInitiated)

    private static var cache: [String: NSAppleScript] = [:]

    /// Must be called on `queue`.
    @discardableResult
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        dispatchPrecondition(condition: .onQueue(queue))
        let script: NSAppleScript
        if let cached = cache[source] {
            script = cached
        } else if let created = NSAppleScript(source: source) {
            cache[source] = created
            script = created
        } else {
            return nil
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("OpenNotchi AppleScript error: \(error)")
            return nil
        }
        return result
    }
}

extension NSAppleEventDescriptor {
    /// 1-based list access that tolerates missing items.
    func string(at index: Int) -> String {
        guard index <= numberOfItems else { return "" }
        return atIndex(index)?.stringValue ?? ""
    }

    func double(at index: Int) -> Double {
        guard index <= numberOfItems, let item = atIndex(index) else { return 0 }
        return item.doubleValue
    }
}

