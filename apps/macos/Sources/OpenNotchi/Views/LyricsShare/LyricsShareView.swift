import AppKit
import AVFoundation
import Combine
import SwiftUI

struct LyricsShareView: View {
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
