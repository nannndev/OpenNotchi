import AppKit
import SwiftUI

/// Spotify and TikTok-style lyric cards and animated videos:
/// pick a few lines, choose an aesthetic frame, customize background video or photo,
/// and copy, save, or export an MP4 video or high-res image.
enum LyricsShare {
    private static var window: NSWindow?

    static func open(startAt line: String? = nil) {
        guard let app = AppDelegate.shared, let info = app.media.info else { return }
        let lyrics = app.lyrics
        // Synced lyrics keep their timestamps so video/card progress matches chosen lines.
        let timed: [(text: String, time: Double?)] = (lyrics.state == .synced
            ? lyrics.lines.map { ($0.text, Optional($0.time)) }
            : (lyrics.plainText ?? "").components(separatedBy: .newlines).map { ($0, nil) })
            .map { ($0.0.trimmingCharacters(in: .whitespaces), $0.1) }
            .filter { !$0.0.isEmpty }
        let lines = timed.map(\.text)
        guard !lines.isEmpty else { return }

        let position = info.position(at: .now)
        let current = line ?? lyrics.currentLine(at: position) ?? lines[0]
        let song = SharedSong(
            title: info.title,
            artist: info.artist,
            artwork: app.media.artwork,
            palette: app.media.palette,
            lines: lines,
            times: timed.map(\.time),
            duration: info.duration,
            translations: lyrics.translations
        )

        let start = lines.firstIndex(of: current) ?? 0
        let hosting = NSHostingController(rootView: LyricsShareView(song: song, selection: start...start))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Share Lyrics"
        window.styleMask = [.titled, .closable, .fullSizeContentView, .resizable]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 900, height: 750)
        window.setContentSize(NSSize(width: 920, height: 770))
        window.center()
        Self.window?.close()
        Self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Everything the card needs, frozen when the window opens.
struct SharedSong {
    let title: String
    let artist: String
    var artwork: NSImage?
    var palette: ArtworkPalette?
    let lines: [String]
    let times: [Double?]
    let duration: Double
    let translations: [String: String]
}
