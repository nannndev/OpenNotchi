import AVFoundation
import CoreImage
import SwiftUI

/// Look applied to the mirror, rendered with Core Image.
enum MirrorEffect: String, CaseIterable, Identifiable {
    case natural, vivid, warm, cool, film, mono, dreamy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .vivid: return "Vivid"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .film: return "Film"
        case .mono: return "Mono"
        case .dreamy: return "Dreamy"
        }
    }

    /// Swatch colors for the picker.
    var swatch: [Color] {
        switch self {
        case .natural: return [Color(white: 0.85), Color(white: 0.55)]
        case .vivid: return [.pink, .orange]
        case .warm: return [.orange, Color(red: 0.8, green: 0.4, blue: 0.2)]
        case .cool: return [.cyan, .blue]
        case .film: return [Color(red: 0.9, green: 0.8, blue: 0.6), Color(red: 0.45, green: 0.35, blue: 0.3)]
        case .mono: return [.white, .black]
        case .dreamy: return [Color(red: 1, green: 0.85, blue: 0.95), .purple]
        }
    }

    func apply(to image: CIImage) -> CIImage {
        switch self {
        case .natural:
            return image
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
        case .film:
            return image
                .applyingFilter("CIPhotoEffectInstant")
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.9, kCIInputRadiusKey: 1.6])
        case .mono:
            return image
                .applyingFilter("CIPhotoEffectNoir")
                .applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.6, kCIInputRadiusKey: 2])
        case .dreamy:
            return image
                .applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: 14, kCIInputIntensityKey: 0.7])
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.9, kCIInputBrightnessKey: 0.03])
                .cropped(to: image.extent)
        }
    }
}

/// Mirrored camera preview at the camera's best resolution. The session runs only while the view is on screen.
struct CameraPreview: NSViewRepresentable {
    var effect: MirrorEffect = .natural
    var ringLight = false
    var cameraID: String = ""

    func makeNSView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.update(effect: effect, ringLight: ringLight)
        view.start(cameraID: cameraID)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewView, context: Context) {
        nsView.update(effect: effect, ringLight: ringLight)
        nsView.switchCamera(to: cameraID)
    }

    static func dismantleNSView(_ nsView: CameraPreviewView, coordinator: ()) {
        nsView.stop()
    }

    /// Cameras to choose from, built-in first.
    static var cameras: [AVCaptureDevice] {
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
    private var ringLight = false
    private var currentCameraID: String?

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

    func update(effect: MirrorEffect, ringLight: Bool) {
        lock.withLock {
            self.effect = effect
            self.ringLight = ringLight
        }
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
        let (target, effect, ringLight) = lock.withLock { (targetPixels, self.effect, self.ringLight) }

        var image = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = image.extent
        // Mirror horizontally, then scale to fill the view and crop the center.
        image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -extent.width, y: 0))
        let scale = max(target.width / extent.width, target.height / extent.height)
        image = image.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: 1])
        let crop = CGRect(
            x: (image.extent.width - target.width) / 2,
            y: (image.extent.height - target.height) / 2,
            width: target.width,
            height: target.height
        ).integral
        image = image.cropped(to: crop)

        if ringLight {
            image = image
                .applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: 0.45])
                .applyingFilter("CIHighlightShadowAdjust", parameters: ["inputShadowAmount": 0.6, "inputHighlightAmount": 0.9])
        }
        image = effect.apply(to: image).cropped(to: crop)

        guard let cgImage = context.createCGImage(image, from: crop) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.layer?.contents = cgImage
        }
    }
}
