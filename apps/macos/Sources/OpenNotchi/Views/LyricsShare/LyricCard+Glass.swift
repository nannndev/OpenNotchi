import SwiftUI

/// Glass style: frosted panels with a waveform.
extension LyricCard {
    var glassLayout: some View {
        VStack(spacing: 0) {
            glassPillHeader
            Spacer(minLength: 16)
            glassLyricsBox
            Spacer(minLength: 16)
            footer
        }
        .padding(22)
    }

    var glassPillHeader: some View {
        HStack(spacing: 10) {
            glassArtwork
            glassSongMeta
            Spacer()
            glassWaveform
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(.black.opacity(0.75)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    @ViewBuilder
    var glassArtwork: some View {
        if let artwork = song.artwork {
            Image(nsImage: artwork)
                .resizable()
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
        }
    }

    var glassSongMeta: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(song.title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
            Text(song.artist)
                .font(.system(size: 9.5, weight: .medium))
                .opacity(0.6)
                .lineLimit(1)
        }
    }

    var glassWaveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { i in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: waveformBarHeight(index: i))
            }
        }
    }

    func waveformBarHeight(index: Int) -> CGFloat {
        let wave = sin(elapsed * 5.0 + Double(index) * 1.5)
        return CGFloat(6.0 + wave * 5.0)
    }

    var glassLyricsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                let isCurrent = activeLineIndex == nil || activeLineIndex == index
                Text(line)
                    .font(
                        lyricFont.font(
                            .system(size: lyricSize, weight: .bold, design: .rounded), size: lyricSize, weight: .bold)
                    )
                    .lyricAlignment(textAlign)
                    .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                    .shadow(
                        color: isCurrent && activeLineIndex != nil ? Color.accentColor.opacity(0.9) : .clear, radius: 10
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.8), Color.purple.opacity(0.6), Color.white.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
}
