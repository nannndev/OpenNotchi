import AppKit
import Combine

/// Polls the enabled providers and publishes whatever is playing.
final class MediaManager: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: NSImage? {
        didSet { updatePalette() }
    }
    @Published private(set) var palette: ArtworkPalette?

    // Order matters: when several report the same state, the earlier one wins.
    let providers: [MediaProvider] = [AppleMusicProvider(), SpotifyProvider()] + BrowserYouTubeProvider.all + [SpotifyWebProvider()]

    private let settings: AppSettings
    private var timer: Timer?
    private var isRefreshing = false
    private var activeProviderID: String?
    private var artworkKey: String?

    init(settings: AppSettings) {
        self.settings = settings

        for provider in providers {
            guard let name = provider.notificationName else { continue }
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(playerStateChanged),
                name: Notification.Name(name),
                object: nil
            )
        }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(playerStateChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(playerStateChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    /// Music apps offered as launchers when nothing is playing.
    var installedProviders: [MediaProvider] {
        providers.filter { $0.showsInLauncher && $0.isInstalled }
    }

    /// Browsers with a YouTube tab that refused to run JavaScript.
    var browsersNeedingJavaScript: [String] {
        BrowserYouTubeProvider.all.filter { $0.isRunning && $0.needsJavaScriptPermission }.map(\.displayName)
    }

    @objc private func playerStateChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refresh() }
    }

    /// Demo content for screenshots and recordings (no real cover art or tracks).
    @Published private(set) var isDemo = false

    func startDemo() {
        isDemo = true
        artworkKey = "demo"
        info = NowPlayingInfo(
            title: "Midnight Drive", artist: "The Placeholders", album: "Demo",
            duration: 204, position: 72, isPlaying: true, sourceID: "demo"
        )
        artwork = Self.demoArtwork()
    }

    func stopDemo() {
        isDemo = false
        artworkKey = nil
        info = nil
        refresh()
    }

    /// A soft monochrome "album cover" drawn in code.
    private static func demoArtwork() -> NSImage {
        NSImage(size: NSSize(width: 600, height: 600), flipped: false) { rect in
            // Calm, natural tones (morning sky over sand and sage hills), so screenshots stay neutral.
            NSGradient(colors: [
                NSColor(red: 0.62, green: 0.76, blue: 0.84, alpha: 1),
                NSColor(red: 0.86, green: 0.88, blue: 0.84, alpha: 1),
                NSColor(red: 0.93, green: 0.87, blue: 0.76, alpha: 1),
            ])?.draw(in: rect, angle: -90)
            NSGradient(colors: [NSColor(white: 1, alpha: 0.9), NSColor(white: 1, alpha: 0)])?
                .draw(fromCenter: NSPoint(x: 410, y: 400), radius: 0, toCenter: NSPoint(x: 410, y: 400), radius: 120, options: [])
            let hills: [(NSColor, CGFloat)] = [
                (NSColor(red: 0.62, green: 0.70, blue: 0.58, alpha: 1), 230),
                (NSColor(red: 0.45, green: 0.55, blue: 0.43, alpha: 1), 150),
            ]
            for (color, height) in hills {
                color.setFill()
                let hill = NSBezierPath()
                hill.move(to: NSPoint(x: 0, y: 0))
                hill.line(to: NSPoint(x: 0, y: height))
                hill.curve(to: NSPoint(x: 600, y: height - 30), controlPoint1: NSPoint(x: 200, y: height + 80), controlPoint2: NSPoint(x: 380, y: height - 90))
                hill.line(to: NSPoint(x: 600, y: 0))
                hill.close()
                hill.fill()
            }
            return true
        }
    }

    func refresh() {
        guard !isDemo else { return }
        guard !isRefreshing else { return }
        let candidates = providers.filter { settings.isProviderEnabled($0.id) && $0.isRunning }
        guard !candidates.isEmpty else {
            apply([])
            return
        }
        isRefreshing = true
        AppleScriptRunner.queue.async { [weak self] in
            let results = candidates.compactMap { $0.fetch() }
            DispatchQueue.main.async {
                self?.isRefreshing = false
                self?.apply(results)
            }
        }
    }

    private func apply(_ results: [NowPlayingInfo]) {
        // If local Spotify is running and active, prefer it over SpotifyWebProvider to avoid out-of-sync states
        let hasLocalSpotify = results.contains { $0.sourceID == SpotifyProvider.bundleID && $0.isPlaying }
        let filtered = hasLocalSpotify ? results.filter { $0.sourceID != SpotifyWebProvider.providerID } : results

        let chosen = filtered.first(where: \.isPlaying)
            ?? filtered.first(where: { $0.sourceID == activeProviderID })
            ?? filtered.first
        activeProviderID = chosen?.sourceID
        info = chosen

        if chosen?.trackKey != artworkKey {
            artworkKey = chosen?.trackKey
            loadArtwork(for: chosen)
        }
    }

    private func loadArtwork(for info: NowPlayingInfo?) {
        artwork = nil
        guard let info, let provider = provider(for: info.sourceID) else { return }
        let key = info.trackKey

        let deliver: (NSImage?) -> Void = { [weak self] image in
            DispatchQueue.main.async {
                guard let self, self.artworkKey == key else { return }
                self.artwork = image
            }
        }

        if let url = info.artworkURL {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                deliver(data.flatMap(NSImage.init(data:)))
            }.resume()
        } else {
            AppleScriptRunner.queue.async { deliver(provider.fetchArtwork()) }
        }
    }

    private func updatePalette() {
        guard let image = artwork else {
            palette = nil
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let palette = ArtworkPalette.extract(from: image)
            DispatchQueue.main.async {
                guard self?.artwork === image else { return }
                self?.palette = palette
            }
        }
    }

    private func provider(for id: String) -> MediaProvider? {
        providers.first { $0.id == id }
    }

    // MARK: - Commands

    func playPause() {
        guard !isDemo else { return }
        if var current = info {
            // Optimistic update so the button flips immediately.
            current.position = current.position(at: Date())
            current.timestamp = Date()
            current.isPlaying.toggle()
            info = current
        }
        perform { $0.playPause() }
    }

    func nextTrack() { perform { $0.nextTrack() } }
    func previousTrack() { perform { $0.previousTrack() } }

    func seek(to seconds: Double) {
        if var current = info {
            current.position = seconds
            current.timestamp = Date()
            info = current
        }
        perform { $0.seek(to: seconds) }
    }

    func toggleShuffle() {
        if var current = info {
            current.isShuffled = !(current.isShuffled ?? false)
            info = current
        }
        perform { $0.toggleShuffle() }
    }

    func toggleRepeat() {
        if var current = info {
            current.isRepeating = !(current.isRepeating ?? false)
            info = current
        }
        perform { $0.toggleRepeat() }
    }

    func toggleLove() {
        if var current = info {
            current.isLoved = !(current.isLoved ?? false)
            info = current
        }
        perform { $0.toggleLove() }
    }

    private func perform(_ action: @escaping (MediaProvider) -> Void) {
        guard let id = info?.sourceID ?? activeProviderID, let provider = provider(for: id) else { return }
        AppleScriptRunner.queue.async { [weak self] in
            action(provider)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresh() }
        }
    }
}
