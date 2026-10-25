import SwiftUI

struct AmbientMusicAuraView: View {
    let palette: ArtworkPalette?
    let isPlaying: Bool
    @Environment(\.notchAccent) private var accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = sin(t * 0.8) * 0.08
            let primaryColor = palette?.backgroundTop ?? accent.color.opacity(0.3)
            let accentColor = palette?.accent ?? accent.color

            ZStack {
                // Left orb behind artwork
                Circle()
                    .fill(primaryColor.opacity(0.35 + pulse))
                    .frame(width: 170, height: 170)
                    .offset(x: -160, y: 10)
                    .blur(radius: 50)

                // Center-right orb behind player
                Ellipse()
                    .fill(accentColor.opacity(0.28 - pulse))
                    .frame(width: 240, height: 140)
                    .offset(x: 40, y: -5)
                    .blur(radius: 55)
            }
            .allowsHitTesting(false)
        }
    }
}
