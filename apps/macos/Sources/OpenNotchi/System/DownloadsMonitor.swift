import Foundation

/// Watches ~/Downloads and reports each file once its browser finishes downloading it.
final class DownloadsMonitor {
    var onFinish: ((URL) -> Void)?
    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    private var known: Set<String> = []
    private var timer: Timer?

    /// Extensions browsers use while a download is still in progress.
    static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial"]

    func start() {
        guard timer == nil else { return }
        known = Set(entries())
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.scan() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func entries() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

    private func scan() {
        let current = entries()
        for name in Self.finished(in: current, known: known) {
            onFinish?(folder.appendingPathComponent(name))
        }
        known = Set(current).subtracting(Self.pending(in: current))
    }

    /// New, complete files. A file next to its own `.part` (Firefox) is still downloading.
    static func finished(in entries: [String], known: Set<String>) -> [String] {
        let pending = pending(in: entries)
        return entries.filter { !known.contains($0) && !pending.contains($0) && !$0.hasPrefix(".") }
    }

    private static func pending(in entries: [String]) -> Set<String> {
        let all = Set(entries)
        return Set(entries.filter { name in
            partialExtensions.contains((name as NSString).pathExtension.lowercased())
                || partialExtensions.contains { all.contains("\(name).\($0)") }
        })
    }
}
