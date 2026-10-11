import AppKit

/// A music app OpenNotchi can read from and control.
/// `fetch`, `fetchArtwork` and the commands are called on `AppleScriptRunner.queue`.
protocol MediaProvider: AnyObject {
    var id: String { get }
    var displayName: String { get }
    /// Distributed notification the app posts when playback changes.
    var notificationName: String? { get }

    func fetch() -> NowPlayingInfo?
    func fetchArtwork() -> NSImage?
    func playPause()
    func nextTrack()
    func previousTrack()
    func seek(to seconds: Double)
}

extension MediaProvider {
    var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) }
    var isInstalled: Bool { appURL != nil }
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty }

    var icon: NSImage? {
        guard let url = appURL else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    func launch() {
        guard let url = appURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Never call this unless the app is running: `tell application` would launch it.
    @discardableResult
    func tell(_ body: String) -> NSAppleEventDescriptor? {
        guard isRunning else { return nil }
        return AppleScriptRunner.run("tell application id \"\(id)\"\n\(body)\nend tell")
    }
}
