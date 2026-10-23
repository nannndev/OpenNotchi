import AppKit
import AVFoundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

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

enum ShareMode: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case video = "Video"
    var id: String { rawValue }
}

enum CardAspectRatio: String, CaseIterable, Identifiable {
    case portrait = "4:5"
    case story = "9:16"
    case square = "1:1"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait: return "4:5 Post"
        case .story: return "9:16 Story"
        case .square: return "1:1 Square"
        }
    }

    var size: CGSize {
        switch self {
        case .portrait: return CGSize(width: 360, height: 450)
        case .story: return CGSize(width: 360, height: 640)
        case .square: return CGSize(width: 360, height: 360)
        }
    }
}

enum LyricFont: String, CaseIterable, Identifiable {
    case auto = "Auto", sans = "Sans", rounded = "Rounded", serif = "Serif", mono = "Mono", hand = "Handwritten"
    var id: String { rawValue }

    /// `auto` keeps the frame's own font.
    func font(_ original: Font, size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .auto: return original
        case .sans: return .system(size: size, weight: weight)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .mono: return .system(size: size, weight: weight, design: .monospaced)
        case .hand: return .custom("Bradley Hand", size: size).weight(weight)
        }
    }
}

extension View {
    /// nil keeps the frame's own alignment.
    @ViewBuilder func lyricAlignment(_ align: TextAlignment?) -> some View {
        if let align {
            multilineTextAlignment(align)
                .frame(maxWidth: .infinity, alignment: align == .leading ? .leading : align == .center ? .center : .trailing)
        } else {
            self
        }
    }
}

enum LyricCardStyle: String, CaseIterable, Identifiable {
    case aura, player, vhs, cassette, vinyl, glass, polaroid, paper, receipt, solid

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aura: return "Aura"
        case .player: return "Player"
        case .vhs: return "VHS 90s"
        case .cassette: return "Cassette"
        case .vinyl: return "Vinyl"
        case .glass: return "Glass"
        case .polaroid: return "Polaroid"
        case .paper: return "Paper"
        case .receipt: return "Receipt"
        case .solid: return "Solid"
        }
    }

    var icon: String {
        switch self {
        case .aura: return "sparkles"
        case .player: return "play.circle.fill"
        case .vhs: return "video.badge.waveform"
        case .cassette: return "opticaldisc"
        case .vinyl: return "record.circle"
        case .glass: return "cube.transparent"
        case .polaroid: return "photo.fill"
        case .paper: return "doc.text.fill"
        case .receipt: return "newspaper.fill"
        case .solid: return "square.fill"
        }
    }
}

private struct LyricsShareView: View {
    @State var song: SharedSong
    @State var selection: ClosedRange<Int>

    // Settings
    @State private var mode: ShareMode = .photo
    @State private var style: LyricCardStyle = .aura
    @State private var aspectRatio: CardAspectRatio = .portrait
    @State private var showTranslation = false
    @State private var toast: String?

    // Custom media backgrounds
    @State private var backdrop: NSImage?
    @State private var backdropBlur: Double = 12
    @State private var backdropZoom: Double = 1
    @State private var lyricFont: LyricFont = .auto
    @State private var fontScale: Double = 1
    @State private var textAlign: TextAlignment?
    @State private var customVideoURL: URL?
    @State private var musicURL: URL?
    @State private var videoAssetGenerator: AVAssetImageGenerator?
    @State private var videoPreviewFrame: NSImage?
    @State private var videoDuration: Double = 0

    // Video preview & export state
    @State private var isPlaying = true
    @State private var previewElapsed: Double = 0
    @State private var duration: Double = 15
    @State private var isRendering = false
    @State private var renderProgress: Double = 0

    // Sheets
    @State private var cameraTarget: PhotoTarget?
    @State private var showRecordVideoSheet = false

    private let originalArtwork: (NSImage?, ArtworkPalette?)
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(song: SharedSong, selection: ClosedRange<Int>) {
        _song = State(initialValue: song)
        _selection = State(initialValue: selection)
        originalArtwork = (song.artwork, song.palette)

        // Calculate initial auto duration based on selected lyrics
        let startIdx = selection.lowerBound
        let endIdx = selection.upperBound
        if let startTime = song.times[startIdx], let endTime = song.times[endIdx] {
            let autoDur = max(5.0, min(30.0, (endTime - startTime) + 3.5))
            _duration = State(initialValue: autoDur)
        }
    }

    enum PhotoTarget: Identifiable {
        case cover, backdrop
        var id: Self { self }
    }

    private static let maxLines = 8
    private var chosen: [String] { selection.map { song.lines[$0] } }
    private var hasTranslations: Bool { chosen.contains { song.translations[$0] != nil } }

    private var songStartTime: Double {
        song.times[selection.lowerBound] ?? 0
    }

    private var activeLineOffset: Int {
        let currentSongTime = songStartTime + previewElapsed
        var best = 0
        var foundAny = false
        for (idx, lineIndex) in selection.enumerated() {
            if let t = song.times[lineIndex] {
                foundAny = true
                if t <= currentSongTime {
                    best = idx
                }
            }
        }
        if !foundAny && !selection.isEmpty && duration > 0 {
            let progress = min(max(previewElapsed / duration, 0), 0.999)
            best = Int(progress * Double(selection.count))
        }
        return best
    }

    private var card: some View {
        LyricCard(
            song: song,
            lines: chosen,
            aspectRatio: aspectRatio,
            time: songStartTime + previewElapsed,
            duration: duration,
            elapsed: previewElapsed,
            activeLineIndex: mode == .video ? activeLineOffset : nil,
            translations: showTranslation ? song.translations : [:],
            style: style,
            backdrop: (mode == .video && customVideoURL != nil) ? (videoPreviewFrame ?? backdrop) : backdrop,
            backdropBlur: backdropBlur,
            backdropZoom: backdropZoom,
            lyricFont: lyricFont,
            fontScale: fontScale,
            textAlign: textAlign
        )
    }

    private var previewScale: CGFloat {
        switch aspectRatio {
        case .portrait: return 0.82
        case .story: return 0.64
        case .square: return 0.92
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            linePicker
                .frame(width: 260)
                .background(Color.black.opacity(0.18))

            VStack(spacing: 0) {
                // Top Studio Bar (Clear of titlebar drag area)
                topToolbar
                    .padding(.horizontal, 22)
                    .padding(.top, 38)
                    .padding(.bottom, 12)

                // Card Preview Area
                cardPreviewArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Settings & Actions Panel
                controlDeck
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 890, minHeight: 740)
        .onReceive(timer) { _ in
            guard mode == .video, isPlaying, !isRendering else { return }
            previewElapsed += 1.0 / 30.0
            if previewElapsed >= duration {
                previewElapsed = 0
            }
            if customVideoURL != nil {
                updateVideoPreviewFrame(at: previewElapsed)
            }
        }
        .sheet(item: $cameraTarget) { target in
            CameraCaptureSheet { image in setPhoto(image, for: target) }
        }
        .sheet(isPresented: $showRecordVideoSheet) {
            CameraVideoRecordSheet { url in
                setVideoURL(url)
                flash("Webcam video attached!")
            }
        }
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack {
            // Mode Switcher (Custom responsive pill, no titlebar conflict)
            HStack(spacing: 2) {
                modePill(.photo, icon: "photo", title: "Photo")
                modePill(.video, icon: "film.fill", title: "Video")
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))

            Spacer()

            // Aspect Ratio Switcher
            HStack(spacing: 2) {
                ratioPill(.portrait, label: "4:5 Post")
                ratioPill(.story, label: "9:16 Story")
                ratioPill(.square, label: "1:1 Square")
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private func modePill(_ target: ShareMode, icon: String, title: String) -> some View {
        let isSelected = mode == target
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                mode = target
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color.clear))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func ratioPill(_ target: CardAspectRatio, label: String) -> some View {
        let isSelected = aspectRatio == target
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                aspectRatio = target
            }
        } label: {
            Text(label)
                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? Color.white.opacity(0.2) : Color.clear))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Preview Area

    private var cardPreviewArea: some View {
        let cardSize = aspectRatio.size

        return VStack(spacing: 10) {
            Spacer(minLength: 0)

            card
                .frame(width: cardSize.width, height: cardSize.height)
                // Blurred artwork overflows the card; clipped() doesn't clip hit-testing, so it ate clicks on the toolbar.
                .allowsHitTesting(false)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
                .scaleEffect(previewScale)
                .frame(width: cardSize.width * previewScale, height: cardSize.height * previewScale)
                .overlay(alignment: .bottom) {
                    if let toast {
                        Text(toast)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(.black.opacity(0.85)))
                            .foregroundStyle(.white)
                            .padding(14)
                            .transition(.opacity)
                    }
                }
                .overlay {
                    if isRendering {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.black.opacity(0.8))
                            VStack(spacing: 12) {
                                ProgressView(value: renderProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .frame(width: 200)
                                Text("Rendering Video: \(Int(renderProgress * 100))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(24)
                        }
                    }
                }

            // Video scrubber & transport if in Video mode
            if mode == .video {
                HStack(spacing: 10) {
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.18)))
                    }
                    .buttonStyle(.plain)

                    Text(formatTime(previewElapsed))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)

                    Slider(value: $previewElapsed, in: 0...duration) { _ in
                        if customVideoURL != nil {
                            updateVideoPreviewFrame(at: previewElapsed)
                        }
                    }
                    .frame(width: 180)

                    Text(formatTime(duration))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.45)))
                .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Control Deck

    private var controlDeck: some View {
        VStack(spacing: 12) {
            // Style Selector Row
            styleSelector
            textControls

            Divider().opacity(0.15)

            // Dynamic Context Controls
            if mode == .video {
                VStack(spacing: 10) {
                    // Duration Selector
                    HStack(spacing: 6) {
                        Text("Duration:")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)

                        let autoD = autoDuration
                        Button {
                            duration = autoD
                            if previewElapsed > autoD { previewElapsed = 0 }
                        } label: {
                            Text("Auto (\(Int(autoD))s)")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(abs(duration - autoD) < 0.5 ? Color.accentColor : Color.white.opacity(0.08)))
                                .foregroundStyle(abs(duration - autoD) < 0.5 ? .white : .secondary)
                        }
                        .buttonStyle(.plain)

                        ForEach([10.0, 15.0, 30.0], id: \.self) { d in
                            Button {
                                duration = d
                                if previewElapsed > d { previewElapsed = 0 }
                            } label: {
                                Text("\(Int(d))s")
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(duration == d ? Color.accentColor : Color.white.opacity(0.08)))
                                    .foregroundStyle(duration == d ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 12) {
                        videoSourceMenu
                        photoMenu("Photo", icon: "photo", target: .backdrop, isCustom: backdrop != nil)
                        photoMenu("Cover", icon: "music.note.list", target: .cover, isCustom: song.artwork !== originalArtwork.0)
                        musicMenu
                        Spacer()
                        if customVideoURL != nil || backdrop != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "drop.halffull").foregroundStyle(.secondary).font(.system(size: 11))
                                Slider(value: $backdropBlur, in: 0...40)
                                    .frame(width: 80)
                                    .help("Background blur")
                                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary).font(.system(size: 11))
                                Slider(value: $backdropZoom, in: 1...3)
                                    .frame(width: 80)
                                    .help("Background zoom")
                            }
                        }
                    }
                    .frame(height: 28)
                }
            } else {
                HStack(spacing: 14) {
                    photoMenu("Cover Art", icon: "music.note.list", target: .cover, isCustom: song.artwork !== originalArtwork.0)
                    photoMenu("Background", icon: "photo", target: .backdrop, isCustom: backdrop != nil)

                    if backdrop != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.halffull").foregroundStyle(.secondary).font(.system(size: 11))
                            Slider(value: $backdropBlur, in: 0...40)
                                .frame(width: 90)
                                .help("Background blur")
                        }
                    }

                    Spacer()
                }
                .frame(height: 28)
            }

            // Action Buttons
            HStack(spacing: 12) {
                if mode == .photo {
                    Button { copyImage() } label: { Label("Copy Image", systemImage: "doc.on.doc") }
                    Button { saveImage() } label: { Label("Save Image", systemImage: "square.and.arrow.down") }
                    Button { shareImage() } label: { Label("Share…", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button {
                        exportVideo()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isRendering ? "hourglass" : "film.fill")
                            Text(isRendering ? "Rendering Video…" : "Export Video (MP4)")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .frame(minWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRendering)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private var videoSourceMenu: some View {
        HStack(spacing: 6) {
            Menu {
                Button {
                    chooseVideoFile()
                } label: {
                    Label("Upload Video File…", systemImage: "arrow.up.circle")
                }
                Button {
                    showRecordVideoSheet = true
                } label: {
                    Label("Record from Webcam…", systemImage: "record.circle")
                }
                if customVideoURL != nil {
                    Divider()
                    Button("Reset to Motion Canvas") {
                        setVideoURL(nil)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: customVideoURL != nil ? "checkmark.circle.fill" : "video.badge.plus")
                        .foregroundStyle(customVideoURL != nil ? Color.green : Color.primary)
                    Text(customVideoURL != nil ? "Video Attached" : "Video Background")
                        .font(.system(size: 11.5, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(customVideoURL != nil ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(customVideoURL != nil ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if customVideoURL != nil {
                Button {
                    setVideoURL(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove custom video")
            }
        }
    }

    private func setVideoURL(_ url: URL?) {
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

    private func updateVideoPreviewFrame(at seconds: Double) {
        guard let gen = videoAssetGenerator, videoDuration > 0 else { return }
        // Loop like the exporter does when the clip is shorter than the lyric video.
        let cmTime = CMTime(seconds: seconds.truncatingRemainder(dividingBy: videoDuration), preferredTimescale: 600)
        if let cg = try? gen.copyCGImage(at: cmTime, actualTime: nil) {
            self.videoPreviewFrame = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    private var autoDuration: Double {
        let startIdx = selection.lowerBound
        let endIdx = selection.upperBound
        if let startTime = song.times[startIdx], let endTime = song.times[endIdx] {
            return max(5.0, min(30.0, (endTime - startTime) + 3.5))
        }
        return 15.0
    }

    private var textControls: some View {
        HStack(spacing: 12) {
            Picker("Font", selection: $lyricFont) {
                ForEach(LyricFont.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 170)

            Picker("Align", selection: $textAlign) {
                Text("Auto").tag(TextAlignment?.none)
                Image(systemName: "text.alignleft").tag(TextAlignment?.some(.leading))
                Image(systemName: "text.aligncenter").tag(TextAlignment?.some(.center))
                Image(systemName: "text.alignright").tag(TextAlignment?.some(.trailing))
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Image(systemName: "textformat.size").foregroundStyle(.secondary).font(.system(size: 11))
            Slider(value: $fontScale, in: 0.6...1.6)
                .frame(width: 100)
                .help("Lyric size")
            Spacer()
        }
        .font(.system(size: 11.5))
        .controlSize(.small)
    }

    // MARK: - Style Selector

    private var styleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(LyricCardStyle.allCases) { item in
                    let isSelected = style == item
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            style = item
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(item.name)
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor : Color.white.opacity(0.06))
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 36)
    }

    // MARK: - Line Picker

    private var linePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Lyrics")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(selection.count) of \(Self.maxLines) lines")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(song.lines.indices, id: \.self) { index in
                            let isOn = selection.contains(index)
                            Button { toggleLine(index) } label: {
                                Text(song.lines[index])
                                    .font(.system(size: 12.5, weight: isOn ? .semibold : .medium))
                                    .foregroundStyle(isOn ? .white : .secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(selectionShape(index).fill(isOn ? Color.accentColor.opacity(0.35) : .clear))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .onAppear { proxy.scrollTo(selection.lowerBound, anchor: .center) }
            }

            if hasTranslations {
                Divider().opacity(0.2).padding(.horizontal, 12)
                Toggle("Include translation", isOn: $showTranslation)
                    .font(.system(size: 11.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }


    private func selectionShape(_ index: Int) -> UnevenRoundedRectangle {
        let top: CGFloat = index == selection.lowerBound ? 7 : 0
        let bottom: CGFloat = index == selection.upperBound ? 7 : 0
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    private func toggleLine(_ index: Int) {
        selection = Self.nextSelection(selection, tapping: index, maxLines: Self.maxLines)
        // Auto update duration if synced
        if let start = song.times[selection.lowerBound], let end = song.times[selection.upperBound] {
            let autoDur = max(5.0, min(30.0, (end - start) + 3.5))
            duration = autoDur
        }
    }

    static func nextSelection(_ range: ClosedRange<Int>, tapping index: Int, maxLines: Int) -> ClosedRange<Int> {
        if range.count > 1, index == range.lowerBound { return (index + 1)...range.upperBound }
        if range.count > 1, index == range.upperBound { return range.lowerBound...(index - 1) }
        if range.contains(index) { return range.lowerBound...index }
        let stretched = min(index, range.lowerBound)...max(index, range.upperBound)
        return stretched.count <= maxLines ? stretched : index...index
    }

    // MARK: - Custom Photos & Videos

    private func photoMenu(_ title: String, icon: String, target: PhotoTarget, isCustom: Bool) -> some View {
        Menu {
            Button { choosePhoto(for: target) } label: { Label("Choose Photo…", systemImage: "photo.on.rectangle") }
            Button { cameraTarget = target } label: { Label("Take Photo…", systemImage: "camera") }
            if isCustom {
                Divider()
                Button(target == .cover ? "Use Song Artwork" : "Remove Photo") { setPhoto(nil, for: target) }
            }
        } label: {
            Label(title, systemImage: isCustom ? "checkmark.circle.fill" : icon)
                .font(.system(size: 11))
        }
        .fixedSize()
    }

    private func choosePhoto(for target: PhotoTarget) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let image = NSImage(contentsOf: url) else { return flash("Couldn't open that image") }
        setPhoto(image, for: target)
    }

    private func setPhoto(_ image: NSImage?, for target: PhotoTarget) {
        switch target {
        case .backdrop:
            backdrop = image
        case .cover:
            song.artwork = image ?? originalArtwork.0
            song.palette = image.flatMap(ArtworkPalette.extract) ?? originalArtwork.1
        }
    }

    private var musicMenu: some View {
        Menu {
            Button { chooseMusicFile() } label: { Label("Choose Song File…", systemImage: "music.note") }
            if musicURL != nil {
                Divider()
                Button("Remove Music") { musicURL = nil }
            }
        } label: {
            Label("Music", systemImage: musicURL != nil ? "checkmark.circle.fill" : "music.note")
                .font(.system(size: 11))
        }
        .fixedSize()
        .help("Audio file of the song; the part matching the chosen lines is added to the video")
    }

    private func chooseMusicFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .movie]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        musicURL = url
        flash("Music attached!")
    }

    private func chooseVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie, .mpeg4Movie]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setVideoURL(url)
        flash("Custom video selected!")
    }

    // MARK: - Export Image

    @MainActor private func renderImage() -> NSImage? {
        let size = aspectRatio.size
        let renderer = ImageRenderer(content: card.frame(width: size.width, height: size.height))
        renderer.scale = 1080 / size.width
        return renderer.nsImage
    }

    @MainActor private func copyImage() {
        guard let image = renderImage() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        NSSound(named: "Pop")?.play()
        flash("Copied image to clipboard")
    }

    @MainActor private func saveImage() {
        guard let url = saveImageFile() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        flash("Saved to Pictures › OpenNotchi")
    }

    @MainActor private func shareImage() {
        guard let url = saveImageFile(), let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: NSRect(x: view.bounds.width - 120, y: 20, width: 1, height: 1), of: view, preferredEdge: .minY)
    }

    @MainActor private func saveImageFile() -> URL? {
        guard let image = renderImage(), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return MirrorPhotos.save(cg, name: "Lyrics – \(song.title)")
    }

    // MARK: - Export Video

    @MainActor private func exportVideo() {
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

    private func flash(_ text: String) {
        withAnimation { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation { toast = nil }
        }
    }
}

// MARK: - Lyric Card Component

struct LyricCard: View {
    let song: SharedSong
    let lines: [String]
    var aspectRatio: CardAspectRatio = .portrait
    var time: Double?
    var duration: Double?
    var elapsed: Double = 0
    var activeLineIndex: Int?
    let translations: [String: String]
    let style: LyricCardStyle
    var backdrop: NSImage?
    var backdropBlur: CGFloat = 0
    var backdropZoom: CGFloat = 1
    var lyricFont: LyricFont = .auto
    var fontScale: CGFloat = 1
    var textAlign: TextAlignment?

    private var top: Color { song.palette?.backgroundTop ?? Color(red: 0.16, green: 0.12, blue: 0.24) }
    private var bottom: Color { song.palette?.backgroundBottom ?? Color(red: 0.05, green: 0.05, blue: 0.09) }
    private var flat: Color { Color(nsColor: (song.palette?.primary ?? .systemIndigo).adjusted(minSaturation: 0.35, minBrightness: 0.45, maxBrightness: 0.85)) }

    private var ink: Color {
        if backdrop != nil, style != .polaroid, style != .receipt { return .white }
        switch style {
        case .aura, .player, .vhs, .cassette, .vinyl, .glass: return .white
        case .polaroid: return Color(red: 0.15, green: 0.13, blue: 0.12)
        case .solid: return .white
        case .paper: return Color(red: 0.13, green: 0.11, blue: 0.10)
        case .receipt: return Color.black.opacity(0.85)
        }
    }

    private var lyricSize: CGFloat {
        let count = lines.joined().count
        let base: CGFloat
        switch count {
        case ..<40: base = 28
        case ..<90: base = 23
        case ..<160: base = 19
        default: base = 16
        }
        return base * fontScale
    }

    var body: some View {
        Group {
            switch style {
            case .player: playerLayout
            case .polaroid: polaroidLayout
            case .vhs: vhsLayout
            case .cassette: cassetteLayout
            case .vinyl: vinylLayout
            case .glass: glassLayout
            case .receipt: receiptLayout
            default: defaultLayout
            }
        }
        .frame(width: aspectRatio.size.width, height: aspectRatio.size.height)
        .background { background.frame(width: aspectRatio.size.width, height: aspectRatio.size.height).clipped() }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder private var background: some View {
        if let backdrop {
            ZStack {
                Image(nsImage: backdrop)
                    .resizable()
                    .scaledToFill()
                    .frame(width: aspectRatio.size.width + backdropBlur * 4, height: aspectRatio.size.height + backdropBlur * 4)
                    .scaleEffect(backdropZoom)
                    .blur(radius: backdropBlur, opaque: true)
                LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                if style == .vhs {
                    VHSScanlines(offset: activeLineIndex != nil ? CGFloat(Int(elapsed * 45) % 4) : 0)
                    Grain(opacity: 0.12, dark: false)
                }
            }
        } else {
            styleBackground
        }
    }

    @ViewBuilder private var styleBackground: some View {
        switch style {
        case .aura, .player, .glass:
            ZStack {
                LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                if let artwork = song.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: aspectRatio.size.width * 1.5, height: aspectRatio.size.height * 1.5)
                        .blur(radius: 60)
                        .opacity(0.75)
                        .rotationEffect(.degrees(activeLineIndex != nil ? elapsed * 12 : 0))
                        .scaleEffect(activeLineIndex != nil ? (1.0 + sin(elapsed * 2.5) * 0.05) : 1.0)
                }
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.07)
            }
        case .vhs:
            ZStack {
                Color.black
                VHSScanlines(offset: activeLineIndex != nil ? CGFloat(Int(elapsed * 45) % 4) : 0)
                Grain(opacity: 0.12, dark: false)
            }
        case .cassette:
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.12)
                Grain(opacity: 0.08)
            }
        case .vinyl:
            ZStack {
                LinearGradient(colors: [Color(red: 0.12, green: 0.11, blue: 0.13), Color(red: 0.04, green: 0.04, blue: 0.05)], startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.07)
            }
        case .receipt:
            Color(red: 0.15, green: 0.15, blue: 0.18)
        case .solid:
            ZStack {
                flat
                if activeLineIndex != nil {
                    LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.clear, Color.black.opacity(0.18)],
                        startPoint: UnitPoint(x: 0.5 + cos(elapsed * 1.5) * 0.5, y: 0.5 + sin(elapsed * 1.5) * 0.5),
                        endPoint: UnitPoint(x: 0.5 - cos(elapsed * 1.5) * 0.5, y: 0.5 - sin(elapsed * 1.5) * 0.5)
                    )
                }
                Grain(opacity: 0.06)
            }
        case .polaroid:
            ZStack {
                LinearGradient(colors: [Color(red: 0.93, green: 0.89, blue: 0.83), Color(red: 0.86, green: 0.81, blue: 0.74)], startPoint: .top, endPoint: .bottom)
                Grain(opacity: 0.1, dark: true)
            }
        case .paper:
            ZStack {
                Color(red: 0.96, green: 0.93, blue: 0.87)
                Grain(opacity: 0.09, dark: true)
            }
        }
    }

    // MARK: - Layouts

    private var defaultLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                header
                Spacer()
                if activeLineIndex != nil {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text(formatTime(elapsed))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 16)
            lyricsBlock
            Spacer(minLength: 16)
            footer
        }
        .padding(26)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let artwork = song.artwork {
                    Image(nsImage: artwork).resizable().scaledToFill()
                } else {
                    Rectangle().fill(ink.opacity(0.15)).overlay(Image(systemName: "music.note").foregroundStyle(ink.opacity(0.6)))
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: style == .paper ? 3 : 8))
            .shadow(color: .black.opacity(style == .paper ? 0.25 : 0.3), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 14, weight: .bold, design: style == .paper ? .serif : .rounded))
                Text(song.artist)
                    .font(.system(size: 12, weight: .medium, design: style == .paper ? .serif : .rounded))
                    .opacity(0.7)
            }
            .lineLimit(1)
            .foregroundStyle(ink)
        }
    }

    private var lyricsBlock: some View {
        VStack(alignment: .leading, spacing: lyricSize * 0.38) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isCurrent = activeLineIndex == nil || activeLineIndex == index
                VStack(alignment: .leading, spacing: 3) {
                    Text(line)
                        .font(lyricFont.font(.system(size: lyricSize, weight: isCurrent ? .bold : .medium, design: style == .paper ? .serif : .rounded), size: lyricSize, weight: isCurrent ? .bold : .medium))
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                        .shadow(color: isCurrent && activeLineIndex != nil ? ink.opacity(0.6) : .clear, radius: 8)
                        .scaleEffect(isCurrent && activeLineIndex != nil ? 1.02 : 1.0, anchor: .leading)
                        .padding(.horizontal, style == .paper && isCurrent && activeLineIndex != nil ? 4 : 0)
                        .background(
                            style == .paper && isCurrent && activeLineIndex != nil
                                ? RoundedRectangle(cornerRadius: 3).fill(Color.yellow.opacity(0.28))
                                : nil
                        )
                    if let translation = translations[line] {
                        Text(translation)
                            .font(lyricFont.font(.system(size: lyricSize * 0.55, weight: .medium, design: style == .paper ? .serif : .rounded), size: lyricSize * 0.55, weight: .medium))
                            .lyricAlignment(textAlign)
                            .italic()
                            .foregroundStyle(style == .aura ? TranslatedLine.color : ink.opacity(0.6))
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Player Style

    private var playerLayout: some View {
        VStack(spacing: 0) {
            artworkImage
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                .padding(.top, 4)

            VStack(spacing: 2) {
                Text(song.title).font(.system(size: 14, weight: .bold, design: .rounded))
                Text(song.artist).font(.system(size: 11.5, weight: .medium, design: .rounded)).opacity(0.65)
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.top, 10)

            Spacer(minLength: 8)
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line)
                        .font(lyricFont.font(.system(size: min(lyricSize, 21 * fontScale), weight: isCurrent ? .bold : .medium, design: .rounded), size: min(lyricSize, 21 * fontScale), weight: isCurrent ? .bold : .medium))
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? .white : .white.opacity(0.35))
                        .shadow(color: isCurrent && activeLineIndex != nil ? .white.opacity(0.6) : .clear, radius: 8)
                }
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)

            Spacer(minLength: 12)
            progress
            transport.padding(.top, 8)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
    }

    private var progress: some View {
        let position = time ?? 0
        let total = duration ?? song.duration
        let fraction = total > 0 ? min(position / total, 1) : 0.35
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(.white).frame(width: geo.size.width * fraction)
                    Circle().fill(.white).frame(width: 9, height: 9)
                        .offset(x: geo.size.width * fraction - 4.5)
                }
            }
            .frame(height: 4)
            HStack {
                Text(formatTime(position))
                Spacer()
                Text(total > 0 ? "-" + formatTime(max(0, total - position)) : "")
            }
            .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Image(systemName: "shuffle").font(.system(size: 12, weight: .semibold)).opacity(0.6)
            Image(systemName: "backward.fill").font(.system(size: 16))
            Image(systemName: "pause.fill")
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(Circle().fill(.white))
            Image(systemName: "forward.fill").font(.system(size: 16))
            Image(systemName: "heart.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.pink)
        }
        .foregroundStyle(.white)
    }

    // MARK: - VHS Style

    private var vhsLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity((Int(elapsed * 2) % 2 == 0) ? 1.0 : 0.25)
                    Text("REC")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Text("SP")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "battery.75percent")
                    Text("AUTO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)

            let tcSecs = Int(elapsed)
            let tcMillis = Int((elapsed - Double(tcSecs)) * 100)
            Text(String(format: "%02d:%02d:%02d.%02d", tcSecs / 3600, (tcSecs % 3600) / 60, tcSecs % 60, tcMillis))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
                .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.6), radius: 4)
                .padding(.top, 4)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line.uppercased())
                        .font(lyricFont.font(.system(size: lyricSize, weight: .heavy, design: .monospaced), size: lyricSize, weight: .heavy))
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                        .shadow(color: isCurrent ? Color.cyan.opacity(0.7) : .clear, radius: 6)
                }
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                    Text(song.artist.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("PLAY ▶")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
            }
            .foregroundStyle(.white)
        }
        .padding(24)
    }

    // MARK: - Cassette Style

    private var cassetteLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )

                VStack(spacing: 8) {
                    HStack {
                        Text("SIDE A")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Spacer()
                        Text(song.title)
                            .font(.custom("Bradley Hand", size: 13).weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("C-60")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 52)

                        HStack(spacing: 36) {
                            CassetteSpool(rotation: elapsed * 120)
                            Rectangle().fill(Color(red: 0.35, green: 0.18, blue: 0.12)).frame(width: 36, height: 16)
                            CassetteSpool(rotation: elapsed * 120)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                .background(Color(red: 0.94, green: 0.92, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8)
            }
            .frame(height: 120)

            Spacer(minLength: 10)
            lyricsBlock
            Spacer(minLength: 10)
            footer
        }
        .padding(22)
    }

    // MARK: - Vinyl Style

    private var vinylLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 14)

            HStack(spacing: -24) {
                artworkImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: -4, y: 4)
                    .zIndex(2)

                VinylDisc(artwork: song.artwork, rotation: elapsed * 90)
                    .frame(width: 116, height: 116)
                    .zIndex(1)
            }
            .padding(.vertical, 6)

            Spacer(minLength: 12)
            lyricsBlock
            Spacer(minLength: 12)
            footer
        }
        .padding(22)
    }

    // MARK: - Glass Style

    private var glassLayout: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let artwork = song.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(song.title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 9.5, weight: .medium))
                        .opacity(0.6)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 6 + CGFloat(sin(elapsed * 5 + Double(i) * 1.5)) * 5)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(.black.opacity(0.75)))
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line)
                        .font(lyricFont.font(.system(size: lyricSize, weight: .bold, design: .rounded), size: lyricSize, weight: .bold))
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                        .shadow(color: isCurrent && activeLineIndex != nil ? Color.accentColor.opacity(0.9) : .clear, radius: 10)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.8), Color.purple.opacity(0.6), Color.white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )

            Spacer(minLength: 16)
            footer
        }
        .padding(22)
    }

    // MARK: - Receipt Style

    private var receiptLayout: some View {
        VStack(spacing: 0) {
            ReceiptPerforation()
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 8)

            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("*** OPENNOTCHI ARCHIVE ***")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    HStack {
                        Text("AUDIO #1024")
                        Spacer()
                        if activeLineIndex != nil {
                            Text("TIME: \(formatTime(elapsed))")
                                .foregroundStyle(Color.red)
                        } else {
                            Text("TRACK CASSETTE")
                        }
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .opacity(0.7)
                    Text("------------------------------------")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.35)
                    HStack {
                        Text(song.title.uppercased())
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(song.artist.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    }
                    Text("------------------------------------")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.35)
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        HStack(alignment: .top, spacing: 6) {
                            Text(isCurrent && activeLineIndex != nil ? "►" : String(format: "%02d", index + 1))
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(isCurrent && activeLineIndex != nil ? Color.red : Color.black.opacity(0.45))
                            Text(line)
                                .font(lyricFont.font(.system(size: min(lyricSize, 15 * fontScale), weight: isCurrent ? .bold : .regular, design: .monospaced), size: min(lyricSize, 15 * fontScale), weight: isCurrent ? .bold : .regular))
                                .lyricAlignment(textAlign)
                                .foregroundStyle(isCurrent ? Color.black : Color.black.opacity(0.35))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isCurrent && activeLineIndex != nil ? Color.black.opacity(0.06) : Color.clear)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 6)

                VStack(spacing: 3) {
                    BarcodePattern(animatedOffset: activeLineIndex != nil ? elapsed : 0)
                        .frame(height: 28)
                    Text("THANK YOU FOR LISTENING")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.95, blue: 0.92))
            .foregroundStyle(Color.black.opacity(0.85))

            ReceiptPerforation(inverted: true)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }

    // MARK: - Polaroid Style

    private var polaroidLayout: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                artworkImage
                    .frame(width: 220, height: 175)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 4) {
                            Text(song.title.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .lineLimit(1)
                            if activeLineIndex != nil {
                                Text("• \(formatTime(elapsed))")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.55))
                        .padding(7)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.prefix(4).enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        Text(line)
                            .font(lyricFont.font(.custom("Bradley Hand", size: min(lyricSize * 0.62, 16 * fontScale)).weight(isCurrent ? .bold : .medium), size: min(lyricSize * 0.62, 16 * fontScale), weight: isCurrent ? .bold : .medium))
                            .lyricAlignment(textAlign)
                            .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                            .scaleEffect(isCurrent && activeLineIndex != nil ? 1.02 : 1.0, anchor: .leading)
                    }
                    Text("— \(song.artist)")
                        .font(.custom("Bradley Hand", size: 11))
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.top, 2)
                }
                .foregroundStyle(ink)
                .minimumScaleFactor(0.5)
                .frame(width: 220, alignment: .topLeading)
            }
            .padding(12)
            .background(Color(red: 0.99, green: 0.98, blue: 0.96))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            .rotationEffect(.degrees(-2.5 + (activeLineIndex != nil ? sin(elapsed * 1.5) * 0.8 : 0)))

            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    @ViewBuilder private var artworkImage: some View {
        if let artwork = song.artwork {
            Image(nsImage: artwork).resizable().scaledToFill()
        } else {
            Rectangle().fill(.white.opacity(0.15)).overlay(Image(systemName: "music.note").foregroundStyle(.white.opacity(0.6)))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 10, weight: .bold))
            Text("OpenNotchi")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle((backdrop != nil ? Color.white : ink).opacity(0.6))
    }
}

// MARK: - Helper Views & Shapes

private struct CassetteSpool: View {
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
            Circle()
                .fill(Color.black)
                .frame(width: 10, height: 10)
            ForEach(0..<6) { i in
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 2, height: 8)
                    .offset(y: -9)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

private struct VinylDisc: View {
    let artwork: NSImage?
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 100, height: 100)
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 80, height: 80)
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: 60, height: 60)

            if let artwork = artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle().fill(Color.red).frame(width: 36, height: 36)
            }

            Circle().fill(Color.black).frame(width: 8, height: 8)
        }
        .rotationEffect(.degrees(rotation))
    }
}

private struct VHSScanlines: View {
    var offset: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = offset.truncatingRemainder(dividingBy: 4)
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1.5)
                context.fill(Path(rect), with: .color(Color.black.opacity(0.35)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ReceiptPerforation: Shape {
    var inverted = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth: CGFloat = 8
        let toothHeight = rect.height
        let count = Int(rect.width / toothWidth)

        path.move(to: CGPoint(x: 0, y: inverted ? 0 : toothHeight))
        for i in 0..<count {
            let x = CGFloat(i) * toothWidth
            let mid = x + toothWidth / 2
            let next = x + toothWidth
            if inverted {
                path.addLine(to: CGPoint(x: mid, y: toothHeight))
                path.addLine(to: CGPoint(x: next, y: 0))
            } else {
                path.addLine(to: CGPoint(x: mid, y: 0))
                path.addLine(to: CGPoint(x: next, y: toothHeight))
            }
        }
        return path
    }
}

private struct BarcodePattern: View {
    var animatedOffset: Double = 0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<32) { i in
                let dynamicH: CGFloat = animatedOffset > 0 ? CGFloat(abs(sin(animatedOffset * 3 + Double(i) * 0.7))) : 1.0
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: (i % 3 == 0) ? 2.5 : ((i % 5 == 0) ? 4.0 : 1.2))
                    .scaleEffect(y: 0.6 + dynamicH * 0.4, anchor: .bottom)
            }
        }
    }
}

private struct Grain: View {
    let opacity: Double
    var dark = false

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(1 << 31)
            }
            for _ in 0..<2600 {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 0.8, height: 0.8)
                context.fill(Path(rect), with: .color((dark ? Color.black : .white).opacity(opacity * (0.4 + next()))))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CameraCaptureSheet: View {
    let onCapture: (NSImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var request = 0

    var body: some View {
        VStack(spacing: 14) {
            CameraPreview(
                cameraID: AppSettings.shared.mirrorCameraID,
                captureRequest: request,
                onCapture: { photo in
                    onCapture(NSImage(cgImage: photo, size: NSSize(width: photo.width, height: photo.height)))
                    dismiss()
                }
            )
            .frame(width: 480, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button { request += 1 } label: { Label("Take Photo", systemImage: "camera.fill") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
    }
}
