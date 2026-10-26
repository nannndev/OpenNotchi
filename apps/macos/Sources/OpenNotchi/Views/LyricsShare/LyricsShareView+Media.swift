import AVFoundation
import AppKit
import SwiftUI

/// Custom cover, background photo, background video and song file.
extension LyricsShareView {
    func setVideoURL(_ url: URL?) {
        customVideoURL = url
        if let url = url {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            videoAssetGenerator = gen
            videoDuration = 0
            Task { @MainActor in
                videoDuration = (try? await asset.load(.duration).seconds) ?? 0
                updateVideoPreviewFrame(at: previewElapsed)
            }
        } else {
            videoAssetGenerator = nil
            videoPreviewFrame = nil
        }
    }

    func updateVideoPreviewFrame(at seconds: Double) {
        guard let gen = videoAssetGenerator, videoDuration > 0 else { return }
        // Loop like the exporter does when the clip is shorter than the lyric video.
        let cmTime = CMTime(seconds: seconds.truncatingRemainder(dividingBy: videoDuration), preferredTimescale: 600)
        if let cg = try? gen.copyCGImage(at: cmTime, actualTime: nil) {
            self.videoPreviewFrame = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    func choosePhoto(for target: PhotoTarget) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url) else { return flash("Couldn't open that image") }
        setPhoto(image, for: target)
    }

    func setPhoto(_ image: NSImage?, for target: PhotoTarget) {
        switch target {
        case .backdrop:
            backdrop = image
        case .cover:
            song.artwork = image ?? originalArtwork.0
            song.palette = image.flatMap(ArtworkPalette.extract) ?? originalArtwork.1
        }
    }

    func chooseMusicFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .movie]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        musicURL = url
        flash("Music attached!")
    }

    func chooseVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setVideoURL(url)
        flash("Custom video selected!")
    }
}
