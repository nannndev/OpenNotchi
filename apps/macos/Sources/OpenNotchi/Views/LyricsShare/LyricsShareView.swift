import AVFoundation
import AppKit
import Combine
import SwiftUI

struct LyricsShareView: View {
    @State var song: SharedSong
    @State var selection: ClosedRange<Int>

    // Settings
    @State var mode: ShareMode = .photo
    @State var style: LyricCardStyle = .aura
    @State var aspectRatio: CardAspectRatio = .portrait
    @State var showTranslation = false
    @State var toast: String?

    // Custom media backgrounds
    @State var backdrop: NSImage?
    @State var backdropBlur: Double = 12
    @State var backdropZoom: Double = 1
    @State var lyricFont: LyricFont = .auto
    @State var fontScale: Double = 1
    @State var textAlign: TextAlignment?
    @State var customVideoURL: URL?
    @State var musicURL: URL?
    @State var videoAssetGenerator: AVAssetImageGenerator?
    @State var videoPreviewFrame: NSImage?
    @State var videoDuration: Double = 0

    // Video preview & export state
    @State var isPlaying = true
    @State var previewElapsed: Double = 0
    @State var duration: Double = 15
    @State var isRendering = false
    @State var renderProgress: Double = 0

    // Sheets
    @State var cameraTarget: PhotoTarget?
    @State var showRecordVideoSheet = false

    let originalArtwork: (NSImage?, ArtworkPalette?)
    let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

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

    static let maxLines = 8
    var chosen: [String] { selection.map { song.lines[$0] } }
    var hasTranslations: Bool { chosen.contains { song.translations[$0] != nil } }

    var songStartTime: Double {
        song.times[selection.lowerBound] ?? 0
    }

    var activeLineOffset: Int {
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

    var card: some View {
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

    var previewScale: CGFloat {
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

    var topToolbar: some View {
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

    func modePill(_ target: ShareMode, icon: String, title: String) -> some View {
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

    func ratioPill(_ target: CardAspectRatio, label: String) -> some View {
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

    var cardPreviewArea: some View {
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

    func flash(_ text: String) {
        withAnimation { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            withAnimation { toast = nil }
        }
    }
}
