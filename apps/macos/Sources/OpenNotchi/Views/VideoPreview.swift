import SwiftUI
import WebKit

/// Muted YouTube player kept in sync with the video playing in the browser.
/// Only exists while the notch is open, so it doesn't stream in the background.
struct VideoPreview: NSViewRepresentable {
    let videoID: String
    let position: Double
    let isPlaying: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        load(videoID, in: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.videoID != videoID {
            load(videoID, in: webView, coordinator: context.coordinator)
        } else {
            webView.evaluateJavaScript("sync(\(position), \(isPlaying))")
        }
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator {
        var videoID: String?
    }

    private func load(_ id: String, in webView: WKWebView, coordinator: Coordinator) {
        coordinator.videoID = id
        // Only letters, digits, - and _ are valid in a video ID.
        let safeID = id.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width">
        <style>
          html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
          /* Fill the square and zoom in a little so the YouTube title bar and logo fall outside. */
          #p { position: absolute; top: 50%; left: 50%; height: 100%; aspect-ratio: 16 / 9; transform: translate(-50%, -50%) scale(1.45); pointer-events: none; }
        </style></head><body>
        <div id="p"></div>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
          let player, ready = false;
          function onYouTubeIframeAPIReady() {
            player = new YT.Player('p', {
              videoId: '\(safeID)',
              host: 'https://www.youtube-nocookie.com',
              playerVars: { autoplay: 1, mute: 1, controls: 0, start: \(Int(position)), playsinline: 1, rel: 0, disablekb: 1, fs: 0, iv_load_policy: 3, modestbranding: 1 },
              events: { onReady: (e) => { e.target.mute(); \(isPlaying ? "e.target.playVideo();" : "e.target.pauseVideo();") ready = true; } }
            });
          }
          function sync(t, playing) {
            if (!ready) return;
            if (Math.abs(player.getCurrentTime() - t) > 1.5) player.seekTo(t, true);
            const state = player.getPlayerState();
            if (playing && state !== 1) player.playVideo();
            if (!playing && state === 1) player.pauseVideo();
          }
        </script></body></html>
        """
        // A real origin so YouTube accepts the embed.
        webView.loadHTMLString(html, baseURL: URL(string: "https://opennotchi.vercel.app/"))
    }
}
