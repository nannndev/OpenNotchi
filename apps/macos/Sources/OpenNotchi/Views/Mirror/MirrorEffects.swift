import SwiftUI

/// Thumbnail of the photo that was just taken.
struct SavedToast: View {
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
struct ConfettiBurst: View {
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
