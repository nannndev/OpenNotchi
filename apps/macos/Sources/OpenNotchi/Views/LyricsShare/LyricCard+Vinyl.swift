import SwiftUI

/// Vinyl style: a spinning record.
extension LyricCard {
    var vinylLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 14)

            HStack(spacing: -24) {
                artworkImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: -4, y: 4)
                    .zIndex(2)

                VinylDisc(artwork: song.artwork, rotation: elapsed * 90)
                    .frame(width: 116, height: 116)
                    .zIndex(1)
            }
            .padding(.vertical, 6)

            Spacer(minLength: 12)
            lyricsBlock
            Spacer(minLength: 12)
            footer
        }
        .padding(22)
    }
}
