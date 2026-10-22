import AppKit
import Combine
import SwiftUI

/// Floating desktop widget with the current and next lyric line.
/// Drag anywhere to move, drag the corner grip to resize (text scales with it); hover for controls.
final class LyricsOverlayWindow: NSPanel {
    private var lockObserver: AnyCancellable?

    init(media: MediaManager, lyrics: LyricsManager, settings: AppSettings) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        minSize = NSSize(width: 280, height: 70)
        maxSize = NSSize(width: 1600, height: 400)

        let hosting = FirstMouseHostingView(rootView: LyricsOverlayView()
            .environmentObject(media)
            .environmentObject(lyrics)
            .environmentObject(settings))
        // Otherwise SwiftUI resizes the window to fit its content, which can collapse it to zero height.
        hosting.sizingOptions = []
        contentView = hosting

        setFrameUsingName("LyricsOverlay")
        setFrameAutosaveName("LyricsOverlay")
        if !isUsable { resetPosition() }

        // Locked: clicks pass through to whatever is underneath.
        lockObserver = settings.$lyricsOverlayLocked.sink { [weak self] in self?.ignoresMouseEvents = $0 }
    }

    override var canBecomeKey: Bool { false }

    /// Big enough to grab and mostly on a connected screen.
    private var isUsable: Bool {
        frame.width >= minSize.width && frame.height >= minSize.height
            && NSScreen.screens.contains { $0.visibleFrame.intersection(frame).height >= minSize.height }
    }

    /// Default size, centered near the bottom of the main screen.
    func resetPosition() {
        guard let screen = NSScreen.main else { return }
        let size = NSSize(width: 560, height: 120)
        setFrame(NSRect(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 80, width: size.width, height: size.height), display: true)
    }
}

private struct LyricsOverlayView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings
    @State private var hovering = false

    var body: some View {
        let accent = ResolvedAccent.resolve(settings.accent, palette: media.palette)
        GeometryReader { geo in
            // Text scales with the window height, so resizing the widget resizes the lyrics.
            let size = min(max(geo.size.height * (settings.lyricsOverlayNextLine ? 0.2 : 0.3), 12), 72)
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                let index = media.info.flatMap { info in info.isPlaying ? lyrics.currentIndex(at: info.position(at: context.date)) : nil }
                VStack(spacing: size * 0.3) {
                    if let index {
                        Text(lyrics.lines[index].text.isEmpty ? "♪" : lyrics.lines[index].text)
                            .font(.system(size: size, weight: .bold, design: .rounded))
                            .foregroundStyle(accent.isNeutral ? .white : accent.color)
                            .id(index)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        if let translated = lyrics.translations[lyrics.lines[index].text] {
                            TranslatedLine(text: translated, size: size * 0.68)
                        } else if settings.lyricsOverlayNextLine, index + 1 < lyrics.lines.count {
                            Text(lyrics.lines[index + 1].text)
                                .font(.system(size: size * 0.68, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    } else if hovering {
                        Label(media.info == nil ? "Nothing playing" : "Waiting for lyrics…", systemImage: "music.note")
                            .font(.system(size: size * 0.6, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.7), radius: 4)
                .padding(.horizontal, size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(WindowGrip(mode: .move))
                .background {
                    if index != nil || hovering {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.black.opacity(max(settings.lyricsOverlayOpacity, hovering ? 0.35 : 0)))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(hovering ? 0.25 : 0), lineWidth: 1))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: index)
            }
        }
        .overlay(alignment: .topTrailing) {
            if hovering { controls.padding(6).transition(.opacity) }
        }
        .overlay(alignment: .bottomLeading) {
            if hovering, settings.lyricsTranslate, let issue = lyrics.translationIssue {
                Label(issue, systemImage: "info.circle")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .padding(6)
                    .padding(.trailing, 34)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if hovering {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.black.opacity(0.6)))
                    .overlay(WindowGrip(mode: .resize))
                    .padding(6)
                    .help("Drag to resize")
                    .transition(.opacity)
            }
        }
        .onHover {
            hovering = $0
            if $0 { lyrics.retryTranslationIfNeeded() }
        }
        .animation(.easeOut(duration: 0.2), value: hovering)
    }

    private var controls: some View {
        HStack(spacing: 2) {
            control("circle.lefthalf.filled", help: "Background: \(Int(settings.lyricsOverlayOpacity * 100))%") {
                // Cycles 0 → 25 → 50 → 75 → 100%.
                settings.lyricsOverlayOpacity = settings.lyricsOverlayOpacity >= 0.99 ? 0 : min(1, (settings.lyricsOverlayOpacity / 0.25).rounded(.down) * 0.25 + 0.25)
            }
            control("square.and.arrow.up", help: "Share lyrics as an image") {
                LyricsShare.open()
            }
            control(settings.lyricsTranslate ? "translate" : "character.bubble", help: settings.lyricsTranslate ? "Stop translating" : "Translate lyrics") {
                settings.lyricsTranslate.toggle()
            }
            control(settings.lyricsOverlayNextLine ? "text.line.2.summary" : "text.line.first.and.arrowtriangle.forward", help: "Toggle next line") {
                settings.lyricsOverlayNextLine.toggle()
            }
            control("xmark", help: "Hide widget") {
                settings.lyricsOverlayEnabled = false
            }
        }
        .padding(3)
        .background(Capsule().fill(.black.opacity(0.6)))
    }

    private func control(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 22, height: 22)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// AppKit view that moves or resizes its window on drag; SwiftUI swallows the window's own drag handling.
private struct WindowGrip: NSViewRepresentable {
    enum Mode { case move, resize }
    let mode: Mode

    func makeNSView(context: Context) -> GripView { GripView(mode: mode) }
    func updateNSView(_ view: GripView, context: Context) {}

    final class GripView: NSView {
        let mode: Mode
        private var start: (mouse: NSPoint, frame: NSRect)?

        init(mode: Mode) {
            self.mode = mode
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: mode == .move ? .openHand : .crosshair)
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if mode == .move { return window.performDrag(with: event) }
            start = (NSEvent.mouseLocation, window.frame)
        }

        override func mouseDragged(with event: NSEvent) {
            guard mode == .resize, let window, let start else { return }
            let mouse = NSEvent.mouseLocation
            // Bottom-right grip: the top-left corner stays put.
            let width = min(max(start.frame.width + mouse.x - start.mouse.x, window.minSize.width), window.maxSize.width)
            let height = min(max(start.frame.height - (mouse.y - start.mouse.y), window.minSize.height), window.maxSize.height)
            window.setFrame(NSRect(x: start.frame.minX, y: start.frame.maxY - height, width: width, height: height), display: true)
        }

        override func mouseUp(with event: NSEvent) {
            start = nil
        }
    }
}
