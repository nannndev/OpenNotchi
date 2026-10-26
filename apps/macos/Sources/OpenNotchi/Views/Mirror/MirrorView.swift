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

    var body: some View {
        VStack(spacing: 4) {
            cameraSource
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .overlay(alignment: .top) { boothProgress }
                .overlay(alignment: .topLeading) { gestureHint }
                .overlay(alignment: .trailing) {
                    VStack(spacing: 10) {
                        ShutterButton(action: { startCountdown() })
                        PhotoboxButton {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { choosingStrip = true }
                        }
                    }
                    .padding(.trailing, 12)
                    .opacity(isHovering && countdown == nil && boothShots == nil && !choosingStrip ? 1 : 0)
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
        case .peace: startCountdown()
        case .thumbsUp: bursts.append(UUID())
        case .openPalm: settings.mirrorRingLight.toggle()
        }
    }

    /// 3, 2, 1, flash, photo.
    private func startCountdown(from start: Int = 3) {
        guard countdown == nil, !boothBusy else { return }
        Task { @MainActor in await countdownAndShoot(from: start) }
    }

    @MainActor
    private func countdownAndShoot(from start: Int) async {
        for n in stride(from: start, through: 1, by: -1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { countdown = n }
            try? await Task.sleep(for: .milliseconds(800))
        }
        withAnimation(.easeOut(duration: 0.15)) { countdown = nil }
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
