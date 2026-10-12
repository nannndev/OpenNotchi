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
    @State private var captureRequest = 0
    @State private var countdown: Int?
    @State private var flash = false
    @State private var bursts: [UUID] = []
    @State private var savedPhoto: URL?

    var body: some View {
        VStack(spacing: 4) {
            CameraPreview(
                effect: settings.mirrorEffect,
                ringLight: settings.mirrorRingLight,
                background: settings.mirrorBackground,
                artwork: settings.mirrorBackground == .album ? media.artwork?.cgImage(forProposedRect: nil, context: nil, hints: nil) : nil,
                musicPlaying: media.info?.isPlaying ?? false,
                gesturesEnabled: settings.mirrorGestures,
                cameraID: settings.mirrorCameraID,
                captureRequest: captureRequest,
                onGesture: handle,
                onCapture: captured
            )
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
            .overlay(alignment: .top) {
                if let shots = boothShots {
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { i in
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
            .overlay(alignment: .topLeading) {
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
            .overlay(alignment: .trailing) {
                VStack(spacing: 10) {
                    ShutterButton(action: { startCountdown() })
                    PhotoboxButton(action: startPhotobox)
                }
                .padding(.trailing, 12)
                .opacity(isHovering && countdown == nil && boothShots == nil ? 1 : 0)
            }
            .overlay(alignment: .bottom) {
                MirrorControls()
                    .padding(8)
                    .opacity(isHovering ? 1 : 0)
            }
            .shadow(color: settings.mirrorRingLight ? .white.opacity(0.35) : .clear, radius: 12)
            .onHover { inside in
                withAnimation(.easeInOut(duration: 0.2)) { isHovering = inside }
            }
            .animation(.easeInOut(duration: 0.25), value: settings.mirrorRingLight)

            ResizeHandle()
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

    /// Four shots with a countdown before each, then a strip in the chosen style.
    private func startPhotobox() {
        guard countdown == nil, !boothBusy else { return }
        boothBusy = true
        boothShots = []
        Task { @MainActor in
            for i in 0..<4 {
                await countdownAndShoot(from: i == 0 ? 3 : 2)
                // Wait for the frame to come back from the camera.
                for _ in 0..<20 where (boothShots?.count ?? 0) <= i {
                    try? await Task.sleep(for: .milliseconds(50))
                }
                try? await Task.sleep(for: .milliseconds(450))
            }
            let shots = boothShots ?? []
            withAnimation { boothShots = nil }
            let style = settings.stripStyle
            let info = StripInfo(caption: settings.stripCaption, date: .now, songTitle: media.info?.title, artist: media.info?.artist, artwork: media.artwork)
            let url = await Task.detached(priority: .userInitiated) {
                PhotoStripComposer.compose(shots, style: style, info: info).flatMap { MirrorPhotos.save($0, name: "Photobox") }
            }.value
            boothBusy = false
            if let url { photoSaved(url) }
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

/// Photos and strips go to ~/Pictures/OpenNotchi.
enum MirrorPhotos {
    static func save(_ image: CGImage, name: String) -> URL? {
        let folder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenNotchi")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = folder.appendingPathComponent("\(name) \(formatter.string(from: .now)).jpg")
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]),
              (try? data.write(to: url)) != nil else { return nil }
        return url
    }
}

private struct PhotoboxButton: View {
    @EnvironmentObject private var settings: AppSettings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.black.opacity(0.5)))
                .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 6)
        }
        .buttonStyle(.plain)
        .help("Photobox: 4 shots in a \(settings.stripStyle.displayName) strip")
    }
}

private struct ShutterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().stroke(.white, lineWidth: 3).frame(width: 38, height: 38)
                Circle().fill(.white).frame(width: 29, height: 29)
            }
            .shadow(color: .black.opacity(0.4), radius: 6)
        }
        .buttonStyle(.plain)
        .help("Take a photo (or show ✌️)")
    }
}

/// Thumbnail of the photo that was just taken.
private struct SavedToast: View {
    let url: URL

    var body: some View {
        HStack(spacing: 8) {
            if let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Saved to Tray").font(.system(size: 11, weight: .semibold))
                Text("Pictures › OpenNotchi").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .padding(.trailing, 4)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.6)))
        .onTapGesture { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}

/// Hearts, stars and confetti that shoot up and fall back down.
private struct ConfettiBurst: View {
    private struct Piece {
        let symbol: String
        let color: Color
        let x: Double        // start, as a fraction of the width
        let vx: Double       // points per second
        let vy: Double
        let spin: Double     // degrees per second
        let size: Double
    }

    private let pieces: [Piece] = (0..<34).map { _ in
        let kinds: [(String, Color)] = [
            ("heart.fill", .pink), ("heart.fill", .red), ("star.fill", .yellow),
            ("hand.thumbsup.fill", .white), ("capsule.fill", .cyan), ("capsule.fill", .green),
            ("capsule.fill", .orange), ("sparkle", .white),
        ]
        let kind = kinds.randomElement()!
        return Piece(
            symbol: kind.0,
            color: kind.1,
            x: .random(in: 0.3...0.7),
            vx: .random(in: -170...170),
            vy: .random(in: 260...420),
            spin: .random(in: -360...360),
            size: .random(in: 10...20)
        )
    }
    private let start = Date.now

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(start)
                ZStack {
                    ForEach(pieces.indices, id: \.self) { i in
                        let piece = pieces[i]
                        let gravity = 420.0
                        let x = piece.x * geo.size.width + piece.vx * t
                        let y = geo.size.height + 10 - piece.vy * t + gravity * t * t / 2
                        Image(systemName: piece.symbol)
                            .font(.system(size: piece.size))
                            .foregroundStyle(piece.color)
                            .rotationEffect(.degrees(piece.spin * t))
                            .position(x: x, y: y)
                            .opacity(max(0, 1 - max(0, t - 1.4) / 0.8))
                    }
                }
            }
        }
    }
}

/// Looks, portrait blur, ring light, gestures and the camera picker, shown while the pointer is over the mirror.
private struct MirrorControls: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MirrorEffect.allCases) { effect in
                let selected = settings.mirrorEffect == effect
                Button {
                    settings.mirrorEffect = effect
                } label: {
                    Circle()
                        .fill(LinearGradient(colors: effect.swatch, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(.white, lineWidth: selected ? 2 : 0).padding(-3))
                }
                .buttonStyle(.plain)
                .help(effect.displayName)
            }

            Text(settings.mirrorEffect.displayName)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 46, alignment: .leading)
                .padding(.leading, 2)

            Divider().frame(height: 16)

            Menu {
                Picker("Background", selection: $settings.mirrorBackground) {
                    ForEach(MirrorBackground.allCases) { Label($0.displayName, systemImage: $0.icon).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: settings.mirrorBackground.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(settings.mirrorBackground == .none ? .white : .cyan)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Background: \(settings.mirrorBackground.displayName)")

            Menu {
                Picker("Photobox strip", selection: $settings.stripStyle) {
                    ForEach(StripStyle.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Button(settings.stripCaption.isEmpty ? "Custom Text…" : "Text: “\(settings.stripCaption)”…") {
                    askForCaption()
                }
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: settings.stripStyle.swatch, startPoint: .top, endPoint: .bottom))
                    .frame(width: 11, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.7), lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Photobox strip: \(settings.stripStyle.displayName)")
            toggle(isOn: $settings.mirrorRingLight, on: "light.max", off: "light.min", tint: .yellow, help: "Ring light")
            toggle(isOn: $settings.mirrorGestures, on: "hand.raised.fill", off: "hand.raised.slash", tint: .green, help: "Hand gestures: ✌️ photo, 👍 confetti, ✋ ring light")

            let cameras = CameraPreview.cameras
            if cameras.count > 1 {
                Menu {
                    ForEach(cameras, id: \.uniqueID) { camera in
                        Button {
                            settings.mirrorCameraID = camera.uniqueID
                        } label: {
                            if camera.uniqueID == settings.mirrorCameraID {
                                Label(camera.localizedName, systemImage: "checkmark")
                            } else {
                                Text(camera.localizedName)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 12, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Camera")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.black.opacity(0.55)))
        .background(Capsule().fill(.ultraThinMaterial))
    }

    /// Small text prompt; the notch panel itself is a poor place to type.
    private func askForCaption() {
        let alert = NSAlert()
        alert.messageText = "Text on your photobox strip"
        alert.informativeText = "Leave it empty to use each style's own title."
        let field = NSTextField(string: settings.stripCaption)
        field.placeholderString = "e.g. bestie day out ✨"
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            settings.stripCaption = String(field.stringValue.prefix(40))
        }
    }

    private func toggle(isOn: Binding<Bool>, on: String, off: String, tint: Color, help: String) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: isOn.wrappedValue ? on : off)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? tint : .white)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Grabber under the mirror: drag to make the notch taller, double-click to toggle short and tall.
private struct ResizeHandle: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var vm: NotchViewModel
    @State private var startHeight: Double?
    @State private var isHovering = false

    var body: some View {
        Capsule()
            .fill(.white.opacity(isHovering || startHeight != nil ? 0.6 : 0.25))
            .frame(width: isHovering || startHeight != nil ? 54 : 40, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 10)
            .contentShape(Rectangle())
            .onHover { inside in
                withAnimation(.easeInOut(duration: 0.15)) { isHovering = inside }
                inside ? NSCursor.resizeUpDown.push() : NSCursor.pop()
            }
            .gesture(
                // Global coordinates, because the view itself moves as the notch grows.
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = startHeight ?? vm.openSize.height
                        if startHeight == nil {
                            startHeight = start
                            vm.isResizing = true
                        }
                        settings.mirrorHeight = clamp(start + value.translation.height)
                    }
                    .onEnded { _ in
                        startHeight = nil
                        vm.isResizing = false
                    }
            )
            .onTapGesture(count: 2) {
                let tall = settings.mirrorHeight > (NotchViewModel.defaultOpenHeight + NotchViewModel.maxOpenHeight) / 2
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    settings.mirrorHeight = tall ? NotchViewModel.defaultOpenHeight : NotchViewModel.maxOpenHeight
                }
            }
            .help("Drag to resize · double-click to toggle")
    }

    private func clamp(_ height: Double) -> Double {
        min(max(height, NotchViewModel.defaultOpenHeight), NotchViewModel.maxOpenHeight)
    }
}
