import AppKit
import SwiftUI

/// Renders the card to an image or an MP4.
extension LyricsShareView {
    @MainActor func renderImage() -> NSImage? {
        let size = aspectRatio.size
        let renderer = ImageRenderer(content: card.frame(width: size.width, height: size.height))
        renderer.scale = 1080 / size.width
        return renderer.nsImage
    }

    @MainActor func copyImage() {
        guard let image = renderImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        NSSound(named: "Pop")?.play()
        flash("Copied image to clipboard")
    }

    @MainActor func saveImage() {
        guard let url = saveImageFile() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        flash("Saved to Pictures › OpenNotchi")
    }

    @MainActor func shareImage() {
        guard let url = saveImageFile(), let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(
            relativeTo: NSRect(x: view.bounds.width - 120, y: 20, width: 1, height: 1), of: view, preferredEdge: .minY)
    }

    @MainActor func saveImageFile() -> URL? {
        guard let image = renderImage(), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return MirrorPhotos.save(cg, name: "Lyrics – \(song.title)")
    }

    @MainActor func exportVideo() {
        isRendering = true
        renderProgress = 0

        let size = aspectRatio.size
        let totalDuration = duration
        let songSnap = song
        let linesSnap = chosen
        let transSnap = showTranslation ? song.translations : [:]
        let styleSnap = style
        let ratioSnap = aspectRatio
        let bgSnap = backdrop
        let bgBlurSnap = backdropBlur
        let bgZoomSnap = backdropZoom
        let fontSnap = lyricFont
        let fontScaleSnap = fontScale
        let alignSnap = textAlign
        let bgVideoSnap = customVideoURL
        let musicSnap = musicURL
        let startSongTime = songStartTime

        Task { @MainActor in
            do {
                var url = try await LyricVideoGenerator.renderVideo(
                    duration: totalDuration,
                    fps: 30,
                    size: size,
                    scale: 3.0,
                    backgroundVideoURL: bgVideoSnap,
                    frameBuilder: { elapsed, frameBgImage in
                        let currentSongTime = startSongTime + elapsed
                        var activeIdx = 0
                        var foundAny = false
                        for (idx, lineIndex) in self.selection.enumerated() {
                            if let t = songSnap.times[lineIndex] {
                                foundAny = true
                                if t <= currentSongTime {
                                    activeIdx = idx
                                }
                            }
                        }
                        if !foundAny && !self.selection.isEmpty && totalDuration > 0 {
                            let progress = min(max(elapsed / totalDuration, 0), 0.999)
                            activeIdx = Int(progress * Double(self.selection.count))
                        }

                        return AnyView(
                            LyricCard(
                                song: songSnap,
                                lines: linesSnap,
                                aspectRatio: ratioSnap,
                                time: currentSongTime,
                                duration: totalDuration,
                                elapsed: elapsed,
                                activeLineIndex: activeIdx,
                                translations: transSnap,
                                style: styleSnap,
                                backdrop: frameBgImage ?? bgSnap,
                                backdropBlur: bgBlurSnap,
                                backdropZoom: bgZoomSnap,
                                lyricFont: fontSnap,
                                fontScale: fontScaleSnap,
                                textAlign: alignSnap
                            )
                        )
                    },
                    onProgress: { p in
                        self.renderProgress = p
                    }
                )

                if let musicSnap {
                    url = try await LyricVideoGenerator.addAudio(to: url, from: musicSnap, startingAt: startSongTime)
                } else if let bgVideoSnap {
                    // No song file: keep the background clip's own sound (try? since it may be silent).
                    url = (try? await LyricVideoGenerator.addAudio(to: url, from: bgVideoSnap, startingAt: 0)) ?? url
                }

                self.isRendering = false
                NSSound(named: "Glass")?.play()
                self.flash("Video saved to Pictures › OpenNotchi!")
                NSWorkspace.shared.activateFileViewerSelecting([url])

                // Add to tray if available
                if let app = AppDelegate.shared {
                    app.tray.add([url])
                }
            } catch {
                self.isRendering = false
                self.flash("Export failed: \(error.localizedDescription)")
            }
        }
    }
}
