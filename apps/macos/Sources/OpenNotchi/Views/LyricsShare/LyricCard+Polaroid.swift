import SwiftUI

/// Polaroid style: a photo print with handwritten lyrics.
extension LyricCard {
    var polaroidLayout: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                artworkImage
                    .frame(width: 220, height: 175)
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 4) {
                            Text(song.title.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .lineLimit(1)
                            if activeLineIndex != nil {
                                Text("• \(formatTime(elapsed))")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color.red)
                            }
                        }
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.55))
                        .padding(7)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.prefix(4).enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        Text(line)
                            .font(
                                lyricFont.font(
                                    .custom("Bradley Hand", size: min(lyricSize * 0.62, 16 * fontScale)).weight(
                                        isCurrent ? .bold : .medium), size: min(lyricSize * 0.62, 16 * fontScale),
                                    weight: isCurrent ? .bold : .medium)
                            )
                            .lyricAlignment(textAlign)
                            .foregroundStyle(isCurrent ? ink : ink.opacity(0.35))
                            .scaleEffect(isCurrent && activeLineIndex != nil ? 1.02 : 1.0, anchor: .leading)
                    }
                    Text("— \(song.artist)")
                        .font(.custom("Bradley Hand", size: 11))
                        .foregroundStyle(ink.opacity(0.55))
                        .padding(.top, 2)
                }
                .foregroundStyle(ink)
                .minimumScaleFactor(0.5)
                .frame(width: 220, alignment: .topLeading)
            }
            .padding(12)
            .background(Color(red: 0.99, green: 0.98, blue: 0.96))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
            .rotationEffect(.degrees(-2.5 + (activeLineIndex != nil ? sin(elapsed * 1.5) * 0.8 : 0)))

            Spacer(minLength: 0)
            footer
        }
        .padding(.top, 24)
        .padding(.bottom, 18)
    }
}
