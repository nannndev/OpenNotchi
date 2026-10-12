import AppKit

/// YouTube and YouTube Music playing in a browser tab, read and controlled with
/// JavaScript through AppleScript. Needs "Allow JavaScript from Apple Events"
/// turned on in the browser.
final class BrowserYouTubeProvider: MediaProvider {
    enum Engine { case chromium, safari }

    static let all: [BrowserYouTubeProvider] = [
        BrowserYouTubeProvider(id: "com.google.Chrome", displayName: "Chrome", engine: .chromium),
        BrowserYouTubeProvider(id: "com.brave.Browser", displayName: "Brave", engine: .chromium),
        BrowserYouTubeProvider(id: "com.microsoft.edgemac", displayName: "Edge", engine: .chromium),
        BrowserYouTubeProvider(id: "company.thebrowser.Browser", displayName: "Arc", engine: .chromium),
        BrowserYouTubeProvider(id: "com.apple.Safari", displayName: "Safari", engine: .safari),
    ]

    let id: String
    let displayName: String
    let engine: Engine
    let notificationName: String? = nil
    var showsInLauncher: Bool { false }

    /// Set when the browser refused to run JavaScript (the Apple Events option is off).
    private(set) var needsJavaScriptPermission = false
    /// Substring of the URL of the tab we're showing, used to target commands.
    private var activeTabMatch: String?

    init(id: String, displayName: String, engine: Engine) {
        self.id = id
        self.displayName = displayName
        self.engine = engine
    }

    // MARK: - Reading

    private struct TabState: Decodable {
        let title: String
        let artist: String
        let art: String
        let id: String
        let music: Bool
        let t: Double
        let d: Double
        let paused: Bool
    }

    func fetch() -> NowPlayingInfo? {
        guard let result = runInYouTubeTabs(Self.readScript, onlyMatching: nil) else { return nil }

        var states: [TabState] = []
        var sawPermissionError = false
        for index in stride(from: 1, through: result.numberOfItems, by: 1) {
            let text = result.atIndex(index)?.stringValue ?? ""
            if text.hasPrefix("ERR:") {
                sawPermissionError = sawPermissionError || text.localizedCaseInsensitiveContains("javascript")
            } else if let data = text.data(using: .utf8), let state = try? JSONDecoder().decode(TabState.self, from: data) {
                states.append(state)
            }
        }
        needsJavaScriptPermission = sawPermissionError && states.isEmpty

        // Prefer a tab that's actually playing.
        guard let state = states.first(where: { !$0.paused }) ?? states.first, !state.title.isEmpty else {
            activeTabMatch = nil
            return nil
        }
        activeTabMatch = state.music ? "music.youtube.com" : "v=\(state.id)"

        return NowPlayingInfo(
            title: state.title,
            artist: state.artist,
            album: state.music ? "YouTube Music" : "YouTube",
            duration: state.d,
            position: state.t,
            isPlaying: !state.paused,
            artworkURL: URL(string: state.art),
            sourceID: id,
            videoID: state.music || state.id.isEmpty ? nil : state.id
        )
    }

    /// Artwork comes from the thumbnail URL.
    func fetchArtwork() -> NSImage? { nil }

    // MARK: - Commands

    func playPause() {
        run("(() => { const b = document.querySelector('.ytp-play-button, #play-pause-button'); if (b) { b.click() } else { const v = document.querySelector('video'); v.paused ? v.play() : v.pause() } })()")
    }

    func nextTrack() {
        run("document.querySelector('.ytp-next-button, ytmusic-player-bar .next-button')?.click()")
    }

    func previousTrack() {
        run("(() => { const p = document.querySelector('ytmusic-player-bar .previous-button'); if (p) { p.click(); return } const v = document.querySelector('video'); if (v.currentTime > 3) { v.currentTime = 0 } else { history.back() } })()")
    }

    func seek(to seconds: Double) {
        run("document.querySelector('video').currentTime = \(Int(seconds))")
    }

    private func run(_ javascript: String) {
        guard let match = activeTabMatch else { return }
        _ = runInYouTubeTabs(javascript, onlyMatching: match)
    }

    // MARK: - AppleScript

    /// Runs JavaScript in every YouTube tab (or only tabs whose URL contains `onlyMatching`)
    /// and returns a list with one result per tab ("ERR:…" when the browser refused).
    private func runInYouTubeTabs(_ javascript: String, onlyMatching match: String?) -> NSAppleEventDescriptor? {
        let js = javascript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let condition = match.map { "u contains \"\($0)\"" }
            ?? "u contains \"youtube.com/watch\" or u contains \"music.youtube.com\""
        let execute = engine == .safari ? "do JavaScript \"\(js)\" in t" : "execute t javascript \"\(js)\""

        return tell("""
            set out to {}
            repeat with w in windows
                repeat with t in tabs of w
                    set u to ""
                    try
                        set u to URL of t
                    end try
                    if \(condition) then
                        try
                            set end of out to (\(execute)) as text
                        on error errMsg
                            set end of out to "ERR:" & errMsg
                        end try
                    end if
                end repeat
            end repeat
            return out
            """)
    }

    private static let readScript = """
    (() => {
      const v = document.querySelector('video');
      if (!v) return '';
      const music = location.hostname === 'music.youtube.com';
      const q = (s) => (document.querySelector(s)?.textContent || '').trim();
      let title = '', artist = '', art = '', id = '';
      if (music) {
        title = q('ytmusic-player-bar .title');
        artist = q('ytmusic-player-bar .byline').split(' • ')[0];
        art = (document.querySelector('ytmusic-player-bar img.image')?.src || '').replace(/=w\\d+-h\\d+/, '=w544-h544');
      } else {
        title = q('h1.ytd-watch-metadata') || document.title.replace(/ - YouTube$/, '');
        artist = q('ytd-watch-metadata ytd-channel-name a') || q('ytd-channel-name a');
        id = new URLSearchParams(location.search).get('v') || '';
        art = id ? 'https://i.ytimg.com/vi/' + id + '/hqdefault.jpg' : '';
      }
      return JSON.stringify({ title, artist, art, id, music, t: v.currentTime || 0, d: isFinite(v.duration) ? v.duration : 0, paused: v.paused });
    })()
    """
}
