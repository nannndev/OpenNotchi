import AppKit

/// Small renders of every style for pickers, shared by Settings and the Mirror tab.
@MainActor
final class StripPreviews: ObservableObject {
    static let shared = StripPreviews()

    @Published private(set) var images: [StripStyle: NSImage] = [:]
    private var key: String?
    private var task: Task<Void, Never>?

    /// Re-renders when the caption or the song changes; cheap to call repeatedly.
    func update(caption: String, info: StripInfo, shots: Int = 4, format: StripFormat = .strip) {
        let newKey = "\(caption)|\(info.songTitle ?? "")|\(info.artist ?? "")|\(shots)|\(format.rawValue)"
        guard newKey != key else { return }
        key = newKey
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: .milliseconds(250))  // debounce typing
            guard !Task.isCancelled else { return }
            var info = info
            info.caption = caption
            let rendered = await Task.detached(priority: .userInitiated) { [info] () -> [StripStyle: NSImage] in
                var result: [StripStyle: NSImage] = [:]
                let samples = PhotoStripComposer.samplePhotos
                let photos = (0..<shots).map { samples[$0 % samples.count] }
                for style in StripStyle.allCases {
                    guard let full = PhotoStripComposer.compose(photos, style: style, format: format, info: info),
                        let small = Self.downscaled(full, width: 400)
                    else { continue }
                    result[style] = NSImage(cgImage: small, size: NSSize(width: small.width, height: small.height))
                }
                return result
            }.value
            guard !Task.isCancelled else { return }
            images = rendered
        }
    }

    nonisolated private static func downscaled(_ image: CGImage, width: Int) -> CGImage? {
        let height = Int(Double(image.height) * Double(width) / Double(image.width))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let ctx = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
