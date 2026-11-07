import AVFoundation
import CoreImage
import SwiftUI
import UniformTypeIdentifiers
import Vision

/// Look applied to the mirror, rendered with Core Image.
enum MirrorEffect: String, CaseIterable, Identifiable {
    case natural, glam, vivid, warm, cool, sunset, cyberpunk, y2k, matcha, film, vhs, cinema, dreamy, mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .glam: return "Glam"
        case .vivid: return "Vivid"
        case .warm: return "Golden"
        case .cool: return "Arctic"
        case .sunset: return "Sunset"
        case .cyberpunk: return "Cyber"
        case .y2k: return "Y2K"
        case .matcha: return "Matcha"
        case .film: return "90s Film"
        case .vhs: return "VHS"
        case .cinema: return "Cinema"
        case .dreamy: return "Dreamy"
        case .mono: return "Noir"
        }
    }

    var category: String {
        switch self {
        case .natural, .glam, .vivid, .dreamy: return "Popular"
        case .warm, .cool, .sunset, .matcha: return "Aesthetic"
        case .y2k, .film, .vhs: return "Vintage"
        case .cyberpunk, .cinema, .mono: return "Cinema"
        }
    }

    /// Swatch colors for the picker.
    var swatch: [Color] {
        switch self {
        case .natural: return [Color(white: 0.85), Color(white: 0.55)]
        case .glam: return [Color(red: 1.0, green: 0.75, blue: 0.85), Color(red: 0.95, green: 0.5, blue: 0.68)]
        case .vivid: return [.pink, .orange]
        case .warm: return [.orange, Color(red: 0.8, green: 0.4, blue: 0.2)]
        case .cool: return [.cyan, .blue]
        case .sunset: return [Color(red: 1.0, green: 0.45, blue: 0.35), Color(red: 0.85, green: 0.2, blue: 0.55)]
        case .cyberpunk: return [Color(red: 1.0, green: 0.1, blue: 0.75), Color(red: 0.0, green: 0.85, blue: 1.0)]
        case .y2k: return [Color(red: 0.95, green: 0.65, blue: 1.0), Color(red: 0.45, green: 0.4, blue: 0.95)]
        case .matcha: return [Color(red: 0.62, green: 0.82, blue: 0.58), Color(red: 0.32, green: 0.52, blue: 0.36)]
        case .film: return [Color(red: 0.9, green: 0.8, blue: 0.6), Color(red: 0.45, green: 0.35, blue: 0.3)]
        case .vhs: return [Color(red: 0.95, green: 0.55, blue: 0.35), Color(red: 0.35, green: 0.25, blue: 0.5)]
        case .cinema: return [Color(red: 0.1, green: 0.65, blue: 0.72), Color(red: 0.92, green: 0.48, blue: 0.18)]
        case .dreamy: return [Color(red: 1, green: 0.85, blue: 0.95), .purple]
        case .mono: return [.white, .black]
        }
    }

    func apply(to image: CIImage) -> CIImage {
        let extent = image.extent
        switch self {
        case .natural:
            return image
        case .glam:
            return image
                .applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 9, kCIInputIntensityKey: 0.35])
                .cropped(to: extent)
                .applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": 0.35, "inputHighlightAmount": 0.92])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.05, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 1.01, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: 1.02, w: 0),
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.08, kCIInputBrightnessKey: 0.02, kCIInputContrastKey: 1.03])
        case .vivid:
            return image
                .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.5])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.15, kCIInputContrastKey: 1.08])
        case .warm:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.08, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.01, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0.88, w: 0),
            ])
        case .cool:
            return image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.92, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1.0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1.1, w: 0),
            ])
        case .sunset:
            return image
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.14, y: 0.02, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.95, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0.04, y: 0, z: 0.92, w: 0),
                ])
                .applyingFilter("CIVibrance", parameters: ["inputAmount": 0.35])
        case .cyberpunk:
            return image
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.08, y: 0, z: 0.12, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.92, z: 0.05, w: 0),
                    "inputBVector": CIVector(x: 0.10, y: 0.06, z: 1.18, w: 0),
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.28, kCIInputContrastKey: 1.14])
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.7, kCIInputRadiusKey: 1.8])
        case .y2k:
            return image
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.16])
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.05, y: 0, z: 0.06, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.98, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0.05, y: 0, z: 1.08, w: 0),
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.22, kCIInputContrastKey: 1.15])
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.85, kCIInputRadiusKey: 1.6])
        case .matcha:
            return image
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 0.94, y: 0.03, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0.02, y: 1.05, z: 0.02, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0.03, z: 0.88, w: 0),
                    "inputBiasVector": CIVector(x: 0.01, y: 0.02, z: 0.01, w: 0),
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.88, kCIInputContrastKey: 0.96])
        case .film:
            return image
                .applyingFilter("CIPhotoEffectInstant")
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.9, kCIInputRadiusKey: 1.6])
        case .vhs:
            return image
                .applyingFilter("CIPhotoEffectTransfer")
                .applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 6, kCIInputIntensityKey: 0.3])
                .cropped(to: extent)
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.8, kCIInputRadiusKey: 1.7])
        case .cinema:
            return image
                .applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: 1.08, y: 0.02, z: -0.04, w: 0),
                    "inputGVector": CIVector(x: 0, y: 0.99, z: 0.02, w: 0),
                    "inputBVector": CIVector(x: -0.05, y: 0.06, z: 1.08, w: 0),
                ])
                .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.12, kCIInputSaturationKey: 1.05])
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.65, kCIInputRadiusKey: 1.9])
        case .mono:
            return image
                .applyingFilter("CIPhotoEffectNoir")
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.6, kCIInputRadiusKey: 2])
        case .dreamy:
            return image
                .applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 14, kCIInputIntensityKey: 0.7])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.9, kCIInputBrightnessKey: 0.03])
                .cropped(to: extent)
        }
    }
}

/// Real-time TikTok-style camera adjustments (exposure, contrast, saturation, warmth, beauty glow, vignette, zoom, flip).
struct CameraAdjustments: Equatable {
    var brightness: Double = 0.0   // -0.4 ... 0.4
    var contrast: Double = 1.0     // 0.6 ... 1.5
    var saturation: Double = 1.0   // 0.0 ... 1.8
    var warmth: Double = 0.0       // -1.0 ... 1.0
    var glow: Double = 0.0         // 0.0 ... 1.0
    var vignette: Double = 0.0     // 0.0 ... 1.0
    var zoom: Double = 1.0         // 1.0 ... 2.5
    var isMirrored: Bool = true

    var isModified: Bool {
        abs(brightness) > 0.01 || abs(contrast - 1.0) > 0.01 || abs(saturation - 1.0) > 0.01
            || abs(warmth) > 0.01 || glow > 0.01 || vignette > 0.01 || zoom > 1.01 || !isMirrored
    }

    func apply(to source: CIImage) -> CIImage {
        let extent = source.extent
        var image = source

        // 1. Zoom crop around center
        let clampedZoom = min(max(zoom, 1.0), 2.5)
        if clampedZoom > 1.01 {
            let cropW = extent.width / clampedZoom
            let cropH = extent.height / clampedZoom
            let cropX = extent.minX + (extent.width - cropW) / 2.0
            let cropY = extent.minY + (extent.height - cropH) / 2.0
            let cropped = image.cropped(to: CGRect(x: cropX, y: cropY, width: cropW, height: cropH))
            let translated = cropped.transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
            let scaled = translated.transformed(by: CGAffineTransform(scaleX: clampedZoom, y: clampedZoom))
            image = scaled.transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY)).cropped(to: extent)
        }

        // 2. Brightness, Contrast, Saturation
        if abs(brightness) > 0.005 || abs(contrast - 1.0) > 0.005 || abs(saturation - 1.0) > 0.005 {
            image = image.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: brightness * 0.45,
                kCIInputContrastKey: contrast,
                kCIInputSaturationKey: saturation,
            ])
        }

        // 3. Warmth / Temperature
        if abs(warmth) > 0.01 {
            let rGain = 1.0 + warmth * 0.14
            let bGain = 1.0 - warmth * 0.14
            let gGain = 1.0 + warmth * 0.02
            image = image.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: rGain, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: gGain, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: bGain, w: 0),
            ])
        }

        // 4. Soft Beauty Glow
        if glow > 0.01 {
            image = image
                .applyingFilter("CIHighlightShadowAdjust", parameters: [
                    "inputShadowAmount": glow * 0.4,
                    "inputHighlightAmount": 1.0 - glow * 0.08,
                ])
                .applyingFilter("CIBloom", parameters: [
                    kCIInputRadiusKey: 10.0,
                    kCIInputIntensityKey: glow * 0.65,
                ])
                .cropped(to: extent)
        }

        // 5. Vignette
        if vignette > 0.01 {
            image = image.applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: vignette * 1.5,
                kCIInputRadiusKey: 1.75,
            ])
        }

        return image.cropped(to: extent)
    }
}

/// What's behind you in the mirror. Blur and album art cut you out with Vision's person segmentation.
enum MirrorBackground: String, CaseIterable, Identifiable {
    case none, blur, album

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Original background"
        case .blur: return "Portrait blur"
        case .album: return "Album art of the song playing"
        }
    }

    var icon: String {
        switch self {
        case .none: return "person.crop.rectangle"
        case .blur: return "person.crop.rectangle.fill"
        case .album: return "music.note.house.fill"
        }
    }
}

/// Mirrored camera preview at the camera's best resolution. The session runs only while the view is on screen.
struct CameraPreview: NSViewRepresentable {
    var effect: MirrorEffect = .natural
    var adjustments: CameraAdjustments = AppSettings.shared.cameraAdjustments
    var ringLight = false
    var background: MirrorBackground = .none
    /// Artwork used by the album background; it gently pulses while music plays.
    var artwork: CGImage?
    var musicPlaying = false
    var gesturesEnabled = false
    var cameraID: String = ""
    /// Bumped by the view to request a photo.
    var captureRequest = 0
    var onGesture: (MirrorGesture) -> Void = { _ in }
    /// A full-resolution frame with the current look, after `captureRequest` changes.
    var onCapture: (CGImage) -> Void = { _ in }

    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        updateNSView(view, context: context)
        view.start(cameraID: cameraID)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {
        nsView.update(
            effect: effect,
            adjustments: adjustments,
            ringLight: ringLight,
            background: background,
            artwork: artwork,
            musicPlaying: musicPlaying,
            gestures: gesturesEnabled
        )
        nsView.onGesture = onGesture
        nsView.onCapture = onCapture
        nsView.requestCapture(captureRequest)
        nsView.switchCamera(to: cameraID)
    }

    static func dismantleNSView(_ nsView: CameraPreviewView, coordinator: ()) {
        nsView.stop()
    }

    /// Cameras to choose from, built-in first.
    nonisolated static var cameras: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
    }
}

final class CameraPreviewView: NSView, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "io.github.opennotchi.camera", qos: .userInteractive)
    private let context = CIContext(options: [.cacheIntermediates: false])

    /// Render settings, read on the camera queue.
    private let lock = NSLock()
    private var targetPixels = CGSize(width: 640, height: 360)
    private var effect: MirrorEffect = .natural
    private var adjustments = CameraAdjustments()
    private var ringLight = false
    private var background: MirrorBackground = .none
    private var artwork: CGImage?
    private var artworkImage: CIImage?
    private var musicPlaying = false
    private var gestures = false
    private var pendingCapture = false
    private var currentCameraID: String?
    private var lastCaptureRequest: Int?

    var onGesture: (MirrorGesture) -> Void = { _ in }
    var onCapture: (CGImage) -> Void = { _ in }

    // Vision work, done on the camera queue.
    private let segmentation: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        return request
    }()
    private let handGestures = HandGestureDetector()
    private var lastMask: CIImage?
    private var frameCount = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layout() {
        super.layout()
        updateTargetSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 2
        updateTargetSize()
    }

    /// Frames are rendered at the view's size in pixels, so they stay sharp on Retina screens.
    private func updateTargetSize() {
        let scale = window?.backingScaleFactor ?? 2
        let size = CGSize(width: max(bounds.width, 1) * scale, height: max(bounds.height, 1) * scale)
        lock.withLock { targetPixels = size }
    }

    func update(
        effect: MirrorEffect,
        adjustments: CameraAdjustments,
        ringLight: Bool,
        background: MirrorBackground,
        artwork: CGImage?,
        musicPlaying: Bool,
        gestures: Bool
    ) {
        lock.withLock {
            self.effect = effect
            self.adjustments = adjustments
            self.ringLight = ringLight
            self.background = background
            if artwork !== self.artwork {
                self.artwork = artwork
                artworkImage = artwork.map { CIImage(cgImage: $0) }
            }
            self.musicPlaying = musicPlaying
            self.gestures = gestures
        }
    }

    /// Takes a photo when `request` changes (the first value only records the baseline).
    func requestCapture(_ request: Int) {
        defer { lastCaptureRequest = request }
        guard let last = lastCaptureRequest, request != last else { return }
        lock.withLock { pendingCapture = true }
    }

    func start(cameraID: String) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            self.queue.async { self.configure(cameraID: cameraID) }
        }
    }

    func switchCamera(to cameraID: String) {
        guard currentCameraID != nil, cameraID != currentCameraID else { return }
        queue.async { self.configure(cameraID: cameraID) }
    }

    func stop() {
        queue.async { [session] in session.stopRunning() }
    }

    private func configure(cameraID: String) {
        let cameras = CameraPreview.cameras
        guard let device = cameras.first(where: { $0.uniqueID == cameraID })
            ?? cameras.first(where: { $0.deviceType == .builtInWideAngleCamera })
            ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device) else { return }
        currentCameraID = cameraID

        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        if session.outputs.isEmpty, session.canAddOutput(output) {
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            session.addOutput(output)
        }
        selectBestFormat(for: device)
        session.commitConfiguration()
        if !session.isRunning { session.startRunning() }
    }

    /// Highest resolution up to 1080p that still runs at 30 fps or more.
    private func selectBestFormat(for device: AVCaptureDevice) {
        let candidates = device.formats.filter { format in
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return size.width <= 1920 && format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 29 }
        }
        guard let best = candidates.max(by: {
            let a = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let b = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
            return Int(a.width) * Int(a.height) < Int(b.width) * Int(b.height)
        }), (try? device.lockForConfiguration()) != nil else { return }
        device.activeFormat = best
        device.unlockForConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let (target, effect, adjustments, ringLight, background, artwork, playing, gestures, capture) = lock.withLock {
            defer { pendingCapture = false }
            return (targetPixels, self.effect, self.adjustments, self.ringLight, self.background, artworkImage, musicPlaying, self.gestures, pendingCapture)
        }
        frameCount &+= 1

        // Hand poses about 8 times a second is plenty, and keeps the CPU cool.
        if gestures, frameCount % 4 == 0, let gesture = handGestures.process(pixelBuffer) {
            DispatchQueue.main.async { [weak self] in self?.onGesture(gesture) }
        }

        let frame = look(
            for: CIImage(cvPixelBuffer: pixelBuffer),
            pixelBuffer: pixelBuffer,
            effect: effect,
            adjustments: adjustments,
            ringLight: ringLight,
            background: background,
            artwork: artwork,
            musicPlaying: playing
        )
        if capture, let photo = context.createCGImage(frame, from: frame.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) {
            DispatchQueue.main.async { [weak self] in self?.onCapture(photo) }
        }

        // Scale to fill the view and crop the center.
        let extent = frame.extent
        let scale = max(target.width / extent.width, target.height / extent.height)
        let scaled = frame.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        let crop = CGRect(
            x: scaled.extent.minX + (scaled.extent.width - target.width) / 2,
            y: scaled.extent.minY + (scaled.extent.height - target.height) / 2,
            width: target.width,
            height: target.height
        ).integral

        guard let cgImage = context.createCGImage(scaled, from: crop) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.layer?.contents = cgImage
        }
    }

    /// The full-resolution, mirrored frame with portrait blur, ring light, selected look, and adjustments.
    private func look(
        for source: CIImage,
        pixelBuffer: CVPixelBuffer,
        effect: MirrorEffect,
        adjustments: CameraAdjustments,
        ringLight: Bool,
        background: MirrorBackground,
        artwork: CIImage?,
        musicPlaying: Bool
    ) -> CIImage {
        let extent = source.extent
        var image = source

        if background != .none {
            // Segment every other frame and reuse the mask in between.
            if frameCount % 2 == 0 || lastMask == nil {
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                if (try? handler.perform([segmentation])) != nil, let mask = segmentation.results?.first?.pixelBuffer {
                    let maskImage = CIImage(cvPixelBuffer: mask)
                    lastMask = maskImage.transformed(by: CGAffineTransform(
                        scaleX: extent.width / maskImage.extent.width,
                        y: extent.height / maskImage.extent.height
                    ))
                }
            }
            if let mask = lastMask {
                let backdrop: CIImage
                if background == .album, let artwork {
                    backdrop = albumBackdrop(artwork, extent: extent, musicPlaying: musicPlaying, isMirrored: adjustments.isMirrored)
                } else {
                    backdrop = image
                        .clampedToExtent()
                        .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 22])
                        .cropped(to: extent)
                        .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.04])
                }
                image = image.applyingFilter("CIBlendWithMask", parameters: [
                    kCIInputBackgroundImageKey: backdrop,
                    kCIInputMaskImageKey: mask,
                ])
            }
        } else {
            lastMask = nil
        }

        if adjustments.isMirrored {
            image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0))
        }
        if ringLight {
            image = image
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.45])
                .applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": 0.6, "inputHighlightAmount": 0.9])
        }
        let filtered = effect.apply(to: image).cropped(to: image.extent)
        return adjustments.apply(to: filtered).cropped(to: image.extent)
    }

    /// The artwork filling the frame, softly blurred, breathing slowly while music plays.
    private func albumBackdrop(_ artwork: CIImage, extent: CGRect, musicPlaying: Bool, isMirrored: Bool = true) -> CIImage {
        let scale = max(extent.width / artwork.extent.width, extent.height / artwork.extent.height)
        let scaled = artwork.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centered = scaled.transformed(by: CGAffineTransform(
            translationX: extent.midX - scaled.extent.midX,
            y: extent.midY - scaled.extent.midY
        ))
        // Mirrored later with the rest of the frame, so flip it here to keep text on the cover readable.
        let flipped = isMirrored
            ? centered.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width - 2 * extent.minX, y: 0))
            : centered
        let pulse = musicPlaying ? 0.06 * sin(Date.now.timeIntervalSinceReferenceDate * 2 * .pi / 1.8) : 0
        return flipped
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 6])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.15, kCIInputBrightnessKey: -0.05 + pulse])
            .cropped(to: extent)
    }
}
