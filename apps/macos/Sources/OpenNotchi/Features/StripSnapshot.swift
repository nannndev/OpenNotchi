#if DEBUG
import AppKit

/// Renders every strip style × format to PNGs, run with `OpenNotchi --strip-snapshot <dir>`.
/// Diff two runs (`cmp`) to check a PhotoStrip refactor changed no pixels.
enum StripSnapshot {
    static func run(_ args: [String]) -> Never {
        let dir = URL(fileURLWithPath: args.first ?? "strip-snapshot")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let date = Date(timeIntervalSince1970: 1_790_000_000)  // fixed so footers don't change between runs
        let infos = [
            ("plain", StripInfo(date: date)),
            (
                "song",
                StripInfo(
                    caption: "  best day ever ", date: date, songTitle: "Midnight Drive", artist: "The Placeholders"
                )
            ),
        ]
        let stickers = [
            PlacedSticker(content: "🎀", x: 0.2, y: 0.3, scale: 1.2, rotation: 15),
            PlacedSticker(content: "APPROVED", isBadge: true, badgeColor: "red", x: 0.7, y: 0.6, rotation: -10),
        ]
        var count = 0
        for style in StripStyle.allCases {
            for format in StripFormat.allCases {
                for shots in [1, 4] {
                    for (tag, info) in infos {
                        let photos = (0..<shots).map {
                            PhotoStripComposer.samplePhotos[$0 % PhotoStripComposer.samplePhotos.count]
                        }
                        guard
                            let image = PhotoStripComposer.compose(
                                photos, style: style, format: format, info: info, stickers: stickers),
                            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
                        else {
                            print("  FAIL \(style) \(format) \(shots) \(tag)")
                            exit(1)
                        }
                        try? png.write(to: dir.appendingPathComponent("\(style)-\(format)-\(shots)-\(tag).png"))
                        count += 1
                    }
                }
            }
        }
        print("wrote \(count) strips to \(dir.path)")
        exit(0)
    }
}
#endif
