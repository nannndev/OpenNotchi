import AppKit
import AVFoundation
import CoreGraphics
import CoreVideo
import SwiftUI

/// Generates MP4 lyric videos with hardware-accelerated AVAssetWriter.
enum LyricVideoGenerator {

    enum VideoError: LocalizedError {
        case writerCreationFailed
        case frameExtractionFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .writerCreationFailed: return "Failed to initialize video writer."
            case .frameExtractionFailed: return "Could not generate video frames."
            case .cancelled: return "Export cancelled."
            }
        }
    }

    /// Renders a video using SwiftUI views rendered via ImageRenderer at 30 fps.
    @MainActor
    static func renderVideo(
        duration: Double,
        fps: Int = 30,
        size: CGSize,
        scale: CGFloat = 3.0,
        backgroundVideoURL: URL? = nil,
        frameBuilder: @escaping (Double, NSImage?) -> AnyView,
        onProgress: @escaping (Double) -> Void
    ) async throws -> URL {
        let totalFrames = max(1, Int(duration * Double(fps)))
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        let pixelSize = CGSize(width: pixelWidth, height: pixelHeight)

        let folder = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0].appendingPathComponent("OpenNotchi")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let outputURL = folder.appendingPathComponent("Lyrics Video \(formatter.string(from: .now)).mp4")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw VideoError.writerCreationFailed
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelWidth,
            AVVideoHeightKey: pixelHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourceBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: pixelWidth,
            kCVPixelBufferHeightKey as String: pixelHeight,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw VideoError.writerCreationFailed
        }
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Setup background video reader if provided
        var bgGenerator: AVAssetImageGenerator?
        var bgDuration: Double = 0
        if let bgURL = backgroundVideoURL {
            let asset = AVURLAsset(url: bgURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            generator.maximumSize = pixelSize
            bgGenerator = generator
            bgDuration = (try? await asset.load(.duration).seconds) ?? 0
        }

        // Loop through frames
        for frameIndex in 0..<totalFrames {
            let currentTime = Double(frameIndex) / Double(fps)
            let presentationTime = CMTime(value: Int64(frameIndex), timescale: Int32(fps))

            // Extract background frame if video is provided
            var bgImage: NSImage?
            if let generator = bgGenerator, bgDuration > 0 {
                let loopTime = currentTime.truncatingRemainder(dividingBy: bgDuration)
                let cmTime = CMTime(seconds: loopTime, preferredTimescale: 600)
                if let cg = try? generator.copyCGImage(at: cmTime, actualTime: nil) {
                    bgImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                }
            }

            // Build SwiftUI view for this time point
            let view = frameBuilder(currentTime, bgImage)
                .frame(width: size.width, height: size.height)

            let renderer = ImageRenderer(content: view)
            renderer.scale = scale

            guard let renderedCG = renderer.cgImage else {
                continue
            }

            // Wait until writer is ready
            var spinCount = 0
            while !writerInput.isReadyForMoreMediaData && spinCount < 100 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                spinCount += 1
            }

            if let pixelBuffer = pixelBuffer(from: renderedCG, size: pixelSize) {
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }

            onProgress(Double(frameIndex + 1) / Double(totalFrames))

            // Yield briefly to keep UI smooth and cancellation responsive
            if frameIndex % 5 == 0 {
                await Task.yield()
            }
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        return outputURL
    }

    /// Muxes `audioURL` (from `start` seconds, trimmed to the video length) into the rendered video, replacing it in place.
    static func addAudio(to videoURL: URL, from audioURL: URL, startingAt start: Double) async throws -> URL {
        let video = AVURLAsset(url: videoURL)
        let audio = AVURLAsset(url: audioURL)
        let videoDuration = try await video.load(.duration)
        guard let videoTrack = try await video.loadTracks(withMediaType: .video).first,
              let audioTrack = try await audio.loadTracks(withMediaType: .audio).first else {
            throw VideoError.frameExtractionFailed
        }
        let audioDuration = try await audio.load(.duration)
        // Song file may be shorter than the lyric offset (e.g. a clip); fall back to its beginning.
        let startTime = CMTime(seconds: start, preferredTimescale: 600) < audioDuration ? CMTime(seconds: start, preferredTimescale: 600) : .zero
        let audioLength = audioDuration - startTime

        let composition = AVMutableComposition()
        let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compVideo?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
        // Repeat the audio when it's shorter than the video (e.g. a short background clip's own sound).
        var cursor = CMTime.zero
        while audioLength > .zero && cursor < videoDuration {
            let chunk = CMTimeMinimum(audioLength, videoDuration - cursor)
            try compAudio?.insertTimeRange(CMTimeRange(start: startTime, duration: chunk), of: audioTrack, at: cursor)
            cursor = cursor + chunk
        }

        let tempURL = videoURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".mp4")
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoError.writerCreationFailed
        }
        session.outputURL = tempURL
        session.outputFileType = .mp4
        await session.export()
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: tempURL)
            throw session.error ?? VideoError.writerCreationFailed
        }
        _ = try FileManager.default.replaceItemAt(videoURL, withItemAt: tempURL)
        return videoURL
    }

    private static func pixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let pixelData = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
