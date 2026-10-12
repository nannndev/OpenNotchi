import AppKit
import Combine

/// Polls the enabled providers and publishes whatever is playing.
final class MediaManager: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: NSImage? {
        didSet { updatePalette() }
    }
    @Published private(set) var palette: ArtworkPalette?

    let providers: [MediaProvider] = [AppleMusicProvider(), SpotifyProvider()] + BrowserYouTubeProvider.all

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

    func refresh() {
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
        let chosen = results.first(where: \.isPlaying)
            ?? results.first(where: { $0.sourceID == activeProviderID })
            ?? results.first
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

    private func perform(_ action: @escaping (MediaProvider) -> Void) {
        guard let id = info?.sourceID ?? activeProviderID, let provider = provider(for: id) else { return }
        AppleScriptRunner.queue.async { [weak self] in
            action(provider)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self?.refresh() }
        }
    }
}
