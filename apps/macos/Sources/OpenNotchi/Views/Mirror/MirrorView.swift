import AVFoundation
import SwiftUI

struct MirrorView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var tray: TrayStore
    @EnvironmentObject private var media: MediaManager
    @State private var isHovering = false
    /// Photos taken so far in a photobox session; nil when taking single photos.
    @State private var boothShots: [CGImage]?
    @State private var boothBusy = false
    @State private var choosingStrip = false
    @EnvironmentObject private var vm: NotchViewModel
    @State private var captureRequest = 0
    @State private var countdown: Int?
    @State private var flash = false
    @State private var bursts: [UUID] = []
    @State private var savedPhoto: URL?
    @State private var studioSession: PhotoboxSession?
    @State private var cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var filterBanner: MirrorEffect?

    var body: some View {
        VStack(spacing: 4) {
            cameraSource
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay { gridOverlay }
                .overlay { ringLightGlow }
                .overlay {
                    ForEach(bursts, id: \.self) { id in
                        ConfettiBurst()
                            .task {
                                try? await Task.sleep(for: .seconds(2.4))
                                bursts.removeAll { $0 == id }
                            }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .allowsHitTesting(false)
                }
                .overlay {
                    if let countdown {
                        Text("\(countdown)")
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .shadow(color: .black.opacity(0.5), radius: 10)
                            .id(countdown)
                            .transition(.scale(scale: 1.6).combined(with: .opacity))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .opacity(flash ? 0.9 : 0)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    if let savedPhoto {
                        SavedToast(url: savedPhoto)
                            .padding(8)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .top) {
                    if boothShots != nil {
                        boothProgress
                    } else if let effect = filterBanner {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(LinearGradient(colors: effect.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 11, height: 11)
                            Text(effect.displayName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                            Text("· \(effect.category)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.black.opacity(0.6)))
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.8))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .topLeading) { gestureHint }
                .overlay(alignment: .trailing) {
                    VStack(spacing: 8) {
                        ShutterButton(action: { startCountdown(from: settings.mirrorTimerSeconds) })
                        PhotoboxButton {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { choosingStrip = true }
                        }
                        // Timer Quick Toggle (0s / 3s / 5s)
                        Button {
                            let choices = [0, 3, 5]
                            let idx = choices.firstIndex(of: settings.mirrorTimerSeconds) ?? 1
                            settings.mirrorTimerSeconds = choices[(idx + 1) % choices.count]
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 9, weight: .bold))
                                Text(settings.mirrorTimerSeconds == 0 ? "0s" : "\(settings.mirrorTimerSeconds)s")
                                    .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                            }
                            .foregroundStyle(settings.mirrorTimerSeconds == 0 ? .white.opacity(0.8) : .yellow)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.black.opacity(0.55)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Self-timer: \(settings.mirrorTimerSeconds == 0 ? "Instant" : "\(settings.mirrorTimerSeconds) seconds")")

                        // Zoom Quick Cycle (1x / 1.25x / 1.5x / 2x)
                        Button {
                            let steps: [Double] = [1.0, 1.25, 1.5, 2.0]
                            let next = steps.first(where: { $0 > settings.mirrorZoom + 0.05 }) ?? 1.0
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settings.mirrorZoom = next
                            }
                        } label: {
                            Text(String(format: "%.1fx", settings.mirrorZoom))
                                .font(.system(size: 9.5, weight: .bold).monospacedDigit())
                                .foregroundStyle(settings.mirrorZoom > 1.01 ? .cyan : .white.opacity(0.8))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.black.opacity(0.55)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Camera zoom (\(String(format: "%.1fx", settings.mirrorZoom)))")
                    }
                    .padding(.trailing, 10)
                    .opacity(isHovering && countdown == nil && boothShots == nil && !choosingStrip && studioSession == nil ? 1 : 0)
                }
                .overlay { stripPicker }
                .overlay { studio }
                .overlay(alignment: .bottom) {
                    MirrorControls()
                        .padding(8)
                        .opacity(isHovering && !choosingStrip && studioSession == nil ? 1 : 0)
                }
                .shadow(color: settings.mirrorRingLight ? .white.opacity(0.35) : .clear, radius: 12)
                .onHover { inside in
                    withAnimation(.easeInOut(duration: 0.2)) { isHovering = inside }
                }
                .animation(.easeInOut(duration: 0.25), value: settings.mirrorRingLight)

            ResizeHandle()
        }
        // Keep notch open during countdown, photobox shooting, or while in Studio
        .onChange(of: boothBusy || countdown != nil || studioSession != nil) { _, busy in
            vm.holdOpen = busy
            vm.isStudioOpen = studioSession != nil
        }
        .onChange(of: settings.mirrorEffect) { _, newEffect in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                filterBanner = newEffect
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1300))
                if filterBanner == newEffect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        filterBanner = nil
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openStripPicker)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { choosingStrip = true }
        }
        .onAppear {
            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
        .onDisappear {
            vm.holdOpen = false
            vm.isStudioOpen = false
        }
    }

    /// The live camera, a sample portrait in demo mode, or a prompt when camera access is missing.
    @ViewBuilder
    private var cameraSource: some View {
        if media.isDemo {
            // Demo mode (screenshots, marketing): a sample portrait instead of the real camera.
            // Fills whatever space it's given without asking for more.
            Color.black.overlay {
                Image(decorative: PhotoStripComposer.samplePhotos[1], scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .clipped()
        } else if cameraAuthStatus == .denied || cameraAuthStatus == .restricted {
            CameraAccessPrompt(
                icon: "camera.slash.fill",
                title: "Camera Access Restricted",
                message: "OpenNotchi needs camera access to preview your camera and take photobox snapshots.",
                buttonTitle: "Open Privacy Settings"
            ) {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
            }
        } else if cameraAuthStatus == .notDetermined {
            CameraAccessPrompt(
                icon: "camera.fill",
                title: "Camera Access Required",
                message: "Grant camera access to use Mirror and photobox booth features.",
                buttonTitle: "Allow Camera Access"
            ) {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        cameraAuthStatus = granted ? .authorized : .denied
                    }
                }
            }
        } else {
            CameraPreview(
                effect: settings.mirrorEffect,
                adjustments: settings.cameraAdjustments,
                ringLight: settings.mirrorRingLight,
                background: settings.mirrorBackground,
                artwork: settings.mirrorBackground == .album
                    ? media.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil) : nil,
                musicPlaying: media.info?.isPlaying ?? false,
                gesturesEnabled: settings.mirrorGestures,
                cameraID: settings.mirrorCameraID,
                captureRequest: captureRequest,
                onGesture: handle,
                onCapture: captured
            )
        }
    }

    /// One dot per photobox shot, filled as they're taken.
    @ViewBuilder
    private var boothProgress: some View {
        if let shots = boothShots {
            HStack(spacing: 6) {
                ForEach(0..<settings.stripShots, id: \.self) { i in
                    Circle()
                        .fill(i < shots.count ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.black.opacity(0.5)))
            .padding(8)
        }
    }

    @ViewBuilder
    private var gestureHint: some View {
        if isHovering && settings.mirrorGestures && savedPhoto == nil && boothShots == nil {
            Text("✌️ photo   👍 confetti   ✋ light")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(8)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var stripPicker: some View {
        if choosingStrip && studioSession == nil {
            StripPicker(
                onStart: {
                    withAnimation { choosingStrip = false }
                    startPhotobox()
                },
                onOpenStudio: {
                    withAnimation { choosingStrip = false }
                    openStudioWithDemo()
                },
                onClose: { withAnimation { choosingStrip = false } }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    @ViewBuilder
    private var studio: some View {
        if let session = studioSession {
            PhotoboxStudioView(
                session: Binding(get: { session }, set: { studioSession = $0 }),
                onFinish: { url in
                    photoSaved(url)
                    bursts.append(UUID())
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        studioSession = nil
                    }
                },
                onCancel: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        studioSession = nil
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    @ViewBuilder
    private var gridOverlay: some View {
        if settings.mirrorGrid {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                Path { path in
                    path.move(to: CGPoint(x: w / 3, y: 0))
                    path.addLine(to: CGPoint(x: w / 3, y: h))
                    path.move(to: CGPoint(x: 2 * w / 3, y: 0))
                    path.addLine(to: CGPoint(x: 2 * w / 3, y: h))
                    path.move(to: CGPoint(x: 0, y: h / 3))
                    path.addLine(to: CGPoint(x: w, y: h / 3))
                    path.move(to: CGPoint(x: 0, y: 2 * h / 3))
                    path.addLine(to: CGPoint(x: w, y: 2 * h / 3))
                }
                .stroke(.white.opacity(0.28), lineWidth: 0.8)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var ringLightGlow: some View {
        // Ring light: a soft white glow around the edge, like the real thing.
        if settings.mirrorRingLight {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                .blur(radius: 4)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private func handle(_ gesture: MirrorGesture) {
        switch gesture {
        case .peace: startCountdown(from: max(1, settings.mirrorTimerSeconds))
        case .thumbsUp: bursts.append(UUID())
        case .openPalm: settings.mirrorRingLight.toggle()
        }
    }

    /// Countdown (or instant if 0), flash, photo.
    private func startCountdown(from start: Int = 3) {
        guard countdown == nil, !boothBusy else { return }
        Task { @MainActor in await countdownAndShoot(from: start) }
    }

    @MainActor
    private func countdownAndShoot(from start: Int) async {
        if start > 0 {
            for n in stride(from: start, through: 1, by: -1) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { countdown = n }
                try? await Task.sleep(for: .milliseconds(800))
            }
            withAnimation(.easeOut(duration: 0.15)) { countdown = nil }
        }
        captureRequest += 1
        flash = true
        withAnimation(.easeOut(duration: 0.5)) { flash = false }
        NSSound(named: "Tink")?.play()
    }

    /// The chosen number of shots with a countdown before each, then a strip in the chosen style and format.
    private func startPhotobox() {
        guard countdown == nil, !boothBusy else { return }
        boothBusy = true
        boothShots = []
        Task { @MainActor in
            let total = settings.stripShots
            for i in 0..<total {
                await countdownAndShoot(from: i == 0 ? 3 : 2)
                if media.isDemo { captured(PhotoStripComposer.samplePhotos[i % PhotoStripComposer.samplePhotos.count]) }
                // Wait for the frame to come back from the camera.
                for _ in 0..<20 where (boothShots?.count ?? 0) <= i {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                try? await Task.sleep(for: .milliseconds(450))
            }
            let shots = boothShots ?? []
            withAnimation { boothShots = nil }
            let style = settings.stripStyle
            let format = settings.stripFormat
            let info = StripInfo(caption: settings.stripCaption, media: media)
            boothBusy = false
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                studioSession = PhotoboxSession(photos: shots, style: style, format: format, info: info)
            }
        }
    }

    private func openStudioWithDemo() {
        let samples = PhotoStripComposer.samplePhotos
        let shots = (0..<settings.stripShots).map { samples[$0 % samples.count] }
        let style = settings.stripStyle
        let format = settings.stripFormat
        let info = StripInfo(caption: settings.stripCaption, media: media, sample: true)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            studioSession = PhotoboxSession(photos: shots, style: style, format: format, info: info)
        }
    }

    private func captured(_ image: CGImage) {
        if boothShots != nil {
            boothShots?.append(image)
            return
        }
        Task.detached(priority: .userInitiated) {
            if let url = MirrorPhotos.save(image, name: "Mirror") {
                await MainActor.run { photoSaved(url) }
            }
        }
    }

    private func photoSaved(_ url: URL) {
        tray.add([url])
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { savedPhoto = url }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut(duration: 0.3)) {
                if savedPhoto == url { savedPhoto = nil }
            }
        }
    }
}

extension Notification.Name {
    /// Opens the photobox style picker (the `photobox` command).
    static let openStripPicker = Notification.Name("io.github.opennotchi.openStripPicker")
}
