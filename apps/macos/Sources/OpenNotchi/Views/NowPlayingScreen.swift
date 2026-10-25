import AppKit
import IOKit.ps
import IOKit.pwr_mgt
import SwiftUI

enum NowPlayingBackground: String, CaseIterable, Identifiable {
    case blur, aurora, gradient, vinyl, black
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .blur: return "photo.fill"
        case .aurora: return "sparkles"
        case .gradient: return "circle.lefthalf.filled"
        case .vinyl: return "opticaldisc"
        case .black: return "moon.fill"
        }
    }
    /// The next style, for the cycle button on the player.
    var next: NowPlayingBackground {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
    var displayName: String {
        switch self {
        case .blur: return "Blurred cover"
        case .aurora: return "Aurora (moving album colors)"
        case .gradient: return "Album color gradient"
        case .vinyl: return "Spinning record"
        case .black: return "Black"
        }
    }
}

/// Full-screen "now playing": blurred artwork backdrop, big cover, synced lyrics with optional translation.
/// Opens by itself after the Mac sits idle while music plays (like a screensaver), or from the player.
/// Any key or a click closes it. Note: macOS doesn't let apps draw on the real lock screen.
final class NowPlayingScreenController {
    private var window: NSWindow?
    private var idleTimer: Timer?
    private var keyMonitor: Any?
    /// Keeps the display (and screen saver) off while the player shows; released on hide.
    private var displayAssertion: IOPMAssertionID = 0
    private let media: MediaManager
    private let lyrics: LyricsManager
    private let settings: AppSettings

    init(media: MediaManager, lyrics: LyricsManager, settings: AppSettings) {
        self.media = media
        self.lyrics = lyrics
        self.settings = settings
        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.checkIdle() }
    }

    var isShowing: Bool { window != nil }

    /// Seconds since the last keyboard, mouse or trackpad input.
    private static var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    private var pausedSince: Date?

    private func checkIdle() {
        if isShowing {
            // Paused for 5 minutes: get out of the way so the screen saver and display sleep work again.
            if media.info?.isPlaying == true { pausedSince = nil } else { pausedSince = pausedSince ?? .now }
            if let pausedSince, Date.now.timeIntervalSince(pausedSince) > 300 { hide() }
            return
        }
        guard settings.nowPlayingScreenEnabled, !isShowing, media.info?.isPlaying == true,
              !settings.nowPlayingScreenOnlyCharging || Self.onPower,
              settings.nowPlayingScreenIdleMinutes > 0,
              Self.idleSeconds >= settings.nowPlayingScreenIdleMinutes * 60 else { return }
        show()
    }

    private static var onPower: Bool {
        IOPSGetProvidingPowerSourceType(IOPSCopyPowerSourcesInfo().takeRetainedValue()).takeUnretainedValue() as String == kIOPMACPowerKey
    }

    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.localizedName == settings.nowPlayingScreenDisplay } ?? NSScreen.main
    }

    func show() {
        guard window == nil, let screen = targetScreen else { return }
        let w = NowPlayingWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.isOpaque = true
        w.backgroundColor = .black
        w.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: NowPlayingScreenView(onClose: { [weak self] in self?.hide() }, size: screen.frame.size)
            .environmentObject(media)
            .environmentObject(lyrics)
            .environmentObject(settings))
        // Otherwise SwiftUI grows the window to fit the whole lyrics list, pushing the player off the bottom.
        hosting.sizingOptions = []
        w.contentView = hosting
        w.alphaValue = 0
        w.setFrame(screen.frame, display: true)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSCursor.setHiddenUntilMouseMoves(true)
        NSAnimationContext.runAnimationGroup { $0.duration = 0.6; w.animator().alphaValue = 1 }
        window = w
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "OpenNotchi full-screen player" as CFString, &displayAssertion)

        // Space / arrows control playback, T translation, L lyrics, B background, any other key (Esc) closes.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 49: self.media.playPause()            // Space
            case 124: self.media.nextTrack()           // →
            case 123: self.media.previousTrack()       // ←
            case 17: self.settings.lyricsTranslate.toggle() // T
            case 37: self.settings.nowPlayingScreenLyrics.toggle() // L
            case 11: self.settings.nowPlayingScreenBackground = self.settings.nowPlayingScreenBackground.next // B
            default: self.hide()
            }
            return nil
        }
    }

    func hide() {
        guard let w = window else { return }
        window = nil
        pausedSince = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if displayAssertion != 0 { IOPMAssertionRelease(displayAssertion) }
        displayAssertion = 0
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; w.animator().alphaValue = 0 }, completionHandler: { w.orderOut(nil) })
    }
}

private final class NowPlayingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct NowPlayingScreenView: View {
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var settings: AppSettings
    let onClose: () -> Void
    @State private var controlsVisible = true
    @State private var hideControls: Task<Void, Never>?

    private var tint: Color { media.palette?.accent ?? .white }

    /// Fixed to the screen so the backdrop or the lyrics list can never grow the layout past the edges.
    let size: CGSize

    var body: some View {
        let compact = size.width < 1300
        let showLyrics = settings.nowPlayingScreenLyrics
        // Leaves room for title, progress and controls (~300 pt) under the cover.
        let coverSize = max(220, min(size.height - 360, showLyrics ? (compact ? 380 : 480) : 560))

        ZStack {
            if let info = media.info {
                HStack(alignment: .center, spacing: compact ? 56 : 96) {
                    player(info, coverSize: coverSize, compact: compact)

                    if showLyrics {
                        lyricsColumn(info)
                            .frame(maxWidth: .infinity)
                            .frame(height: size.height * 0.78)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                }
                .padding(.horizontal, compact ? 72 : 140)
                .frame(width: size.width, height: size.height)
                .foregroundStyle(.white)
            } else {
                Text("Nothing playing").font(.system(size: 28, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            }

            if settings.nowPlayingScreenClock {
                clock
                    .padding(.top, 36)
                    .padding(.trailing, 44)
                    .frame(width: size.width, height: size.height, alignment: .topTrailing)
            }
        }
        .frame(width: size.width, height: size.height)
        .background { backdrop.frame(width: size.width, height: size.height).clipped() }
        .clipped()
        .contentShape(Rectangle())
        .onContinuousHover { _ in poke() }
        .onAppear(perform: poke)
        .animation(.easeInOut(duration: 0.4), value: controlsVisible)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showLyrics)
        .animation(.easeInOut(duration: 0.4), value: settings.nowPlayingScreenClock)
        .animation(.easeInOut(duration: 0.8), value: settings.nowPlayingScreenBackground)
    }

    /// Cover, title, progress and controls, centered as one column.
    private func player(_ info: NowPlayingInfo, coverSize: CGFloat, compact: Bool) -> some View {
        VStack(alignment: .center, spacing: 20) {
            cover(size: coverSize)
            VStack(spacing: 6) {
                Text(info.title)
                    .font(.system(size: compact ? 30 : 36, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(info.artist)
                    .font(.system(size: compact ? 19 : 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            progress(info)
            controls(info)
        }
        .frame(width: coverSize)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        let style = settings.nowPlayingScreenBackground
        let primary = media.palette.map { Color(nsColor: $0.primary) } ?? Color(red: 0.35, green: 0.25, blue: 0.6)
        let secondary = media.palette.map { Color(nsColor: $0.secondary) } ?? Color(red: 0.1, green: 0.3, blue: 0.5)
        return ZStack {
            Color.black
            switch style {
            case .blur:
                if let art = media.artwork {
                    // Overlay on a clear view so the filled image never grows the layout.
                    Color.clear.overlay(
                        Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                            .blur(radius: 90).saturation(1.5).scaleEffect(1.3).opacity(0.85)
                    )
                    .clipped()
                    .id(media.info?.trackKey)
                }
                glow(primary, secondary, strength: 0.35)
            case .aurora:
                glow(primary, secondary, strength: 0.75)
                glow(secondary, primary, strength: 0.45, speed: 0.6)
            case .gradient:
                // Falls back to built-in colors until the artwork palette is known, so it never looks black.
                LinearGradient(colors: [primary.opacity(0.85), secondary.opacity(0.7), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .vinyl:
                vinylBackdrop(primary)
            case .black:
                EmptyView()
            }
            LinearGradient(colors: [.black.opacity(0.15), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        }
        .animation(.easeInOut(duration: 1.2), value: media.info?.trackKey)
    }

    /// Slow drifting blobs in the album colors; keeps the screen alive and avoids burn-in.
    private func glow(_ a: Color, _ b: Color, strength: Double, speed: Double = 1) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate * speed
            ZStack {
                RadialGradient(colors: [a.opacity(strength), .clear], center: UnitPoint(x: 0.3 + 0.25 * sin(t / 9), y: 0.3 + 0.25 * cos(t / 11)), startRadius: 0, endRadius: 800)
                RadialGradient(colors: [b.opacity(strength * 0.85), .clear], center: UnitPoint(x: 0.75 + 0.2 * cos(t / 13), y: 0.75 + 0.2 * sin(t / 8)), startRadius: 0, endRadius: 750)
            }
            .blendMode(.plusLighter)
        }
    }

    /// A large record spinning slowly behind everything, with the cover as its label.
    private func vinylBackdrop(_ tint: Color) -> some View {
        GeometryReader { g in
            let d = max(g.size.width, g.size.height) * 1.1
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                let angle = media.info?.isPlaying == true ? ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 24) * 15 : 0
                ZStack {
                    Circle().fill(Color(white: 0.06))
                    ForEach(0..<14) { i in
                        Circle().stroke(.white.opacity(0.035), lineWidth: 1).padding(CGFloat(i) * d / 34 + d * 0.04)
                    }
                    Circle()
                        .fill(AngularGradient(colors: [.clear, .white.opacity(0.08), .clear, .white.opacity(0.05), .clear], center: .center))
                    Group {
                        if let art = media.artwork { Image(nsImage: art).resizable().aspectRatio(contentMode: .fill) } else { tint }
                    }
                    .frame(width: d * 0.33, height: d * 0.33)
                    .clipShape(Circle())
                    .opacity(0.8)
                }
                .frame(width: d, height: d)
                .rotationEffect(.degrees(angle))
                .position(x: g.size.width * 0.72, y: g.size.height * 0.5)
                .opacity(0.55)
            }
        }
    }

    private func cover(size: CGFloat) -> some View {
        Group {
            if let art = media.artwork {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack { Color.white.opacity(0.08); Image(systemName: "music.note").font(.system(size: 60)).foregroundStyle(.white.opacity(0.4)) }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
        .scaleEffect(media.info?.isPlaying == true ? 1 : 0.92)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: media.info?.isPlaying)
        .id(media.info?.trackKey)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func progress(_ info: NowPlayingInfo) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let pos = info.position(at: ctx.date)
            VStack(spacing: 4) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.2))
                        Capsule().fill(.white.opacity(0.85))
                            .frame(width: info.duration > 0 ? g.size.width * min(1, pos / info.duration) : 0)
                    }
                }
                .frame(height: 4)
                HStack {
                    Text(Duration.seconds(pos).formatted(.time(pattern: .minuteSecond)))
                    Spacer()
                    Text(Duration.seconds(info.duration).formatted(.time(pattern: .minuteSecond)))
                }
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private func controls(_ info: NowPlayingInfo) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 36) {
                button("backward.fill", 26) { media.previousTrack() }
                    .help("Previous (←)")
                button(info.isPlaying ? "pause.fill" : "play.fill", 40) { media.playPause() }
                    .help("Play / pause (Space)")
                button("forward.fill", 26) { media.nextTrack() }
                    .help("Next (→)")
            }
            // Extras fade out when the mouse rests, the transport stays.
            HStack(spacing: 22) {
                button("shuffle", 15, on: info.isShuffled ?? false) { media.toggleShuffle() }
                    .help("Shuffle")
                button("quote.bubble", 15, on: settings.nowPlayingScreenLyrics) { settings.nowPlayingScreenLyrics.toggle() }
                    .help("Lyrics")
                button("character.bubble", 15, on: settings.lyricsTranslate) { settings.lyricsTranslate.toggle() }
                    .help("Translate lyrics (T)")
                button(settings.nowPlayingScreenBackground.icon, 15) {
                    withAnimation(.easeInOut(duration: 0.8)) { settings.nowPlayingScreenBackground = settings.nowPlayingScreenBackground.next }
                }
                .help("Background: \(settings.nowPlayingScreenBackground.displayName) (B)")
                button("repeat", 15, on: info.isRepeating ?? false) { media.toggleRepeat() }
                    .help("Repeat")
                button("xmark", 14) { onClose() }
                    .help("Close (Esc)")
            }
            .opacity(controlsVisible ? 0.9 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func button(_ icon: String, _ size: CGFloat, on: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(on ? tint : .white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size * 1.8, height: size * 1.8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Lyrics

    @ViewBuilder
    private func lyricsColumn(_ info: NowPlayingInfo) -> some View {
        if lyrics.state == .synced, !lyrics.lines.isEmpty {
            TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
                let current = lyrics.currentIndex(at: info.position(at: ctx.date)) ?? -1
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 26) {
                            Color.clear.frame(height: 200)
                            ForEach(lyrics.lines) { line in
                                lyricLine(line, distance: line.id - current)
                                    .id(line.id)
                            }
                            Color.clear.frame(height: 300)
                        }
                    }
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                                 .init(color: .black, location: 0.75), .init(color: .clear, location: 1)],
                                         startPoint: .top, endPoint: .bottom))
                    .onChange(of: current) { _, new in
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { proxy.scrollTo(max(0, new), anchor: UnitPoint(x: 0, y: 0.35)) }
                    }
                    .onAppear { proxy.scrollTo(max(0, current), anchor: UnitPoint(x: 0, y: 0.35)) }
                }
            }
        } else if let plain = lyrics.plainText, !plain.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                Text(plain).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white.opacity(0.8)).lineSpacing(10)
            }
        } else {
            Text(lyrics.state == .loading ? "Loading lyrics…" : lyrics.state == .instrumental ? "♪ Instrumental" : "No lyrics for this song")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lyricLine(_ line: LyricLine, distance: Int) -> some View {
        let isCurrent = distance == 0
        let translation = settings.lyricsTranslate ? lyrics.translations[line.text] : nil
        let k = settings.nowPlayingScreenTextScale
        return VStack(alignment: .leading, spacing: 6) {
            Text(line.text.isEmpty ? "♪" : line.text)
                .font(.system(size: (isCurrent ? 40 : 32) * k, weight: .bold))
            if let translation, !line.text.isEmpty {
                Text(translation)
                    .font(.system(size: (isCurrent ? 22 : 19) * k, weight: .semibold))
                    .foregroundStyle(isCurrent ? tint : .white.opacity(0.7))
            }
        }
        .opacity(isCurrent ? 1 : (distance < 0 ? 0.3 : max(0.25, 0.55 - Double(distance) * 0.06)))
        .blur(radius: isCurrent ? 0 : min(3, Double(abs(distance)) * 0.6))
        .scaleEffect(isCurrent ? 1 : 0.97, anchor: .leading)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isCurrent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .trailing, spacing: 2) {
                Text(ctx.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 54, weight: .semibold).monospacedDigit())
                Text(ctx.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 10)
        }
    }

    /// Controls show on mouse movement and fade after 3 s.
    private func poke() {
        controlsVisible = true
        hideControls?.cancel()
        hideControls = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { controlsVisible = false }
        }
    }
}
