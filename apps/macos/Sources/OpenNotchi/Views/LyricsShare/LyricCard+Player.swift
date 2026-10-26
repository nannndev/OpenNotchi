import SwiftUI

/// Player style: artwork, progress bar and transport like a music app.
extension LyricCard {
    var playerLayout: some View {
        VStack(spacing: 0) {
            artworkImage
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
                .padding(.top, 4)

            VStack(spacing: 2) {
                Text(song.title).font(.system(size: 14, weight: .bold, design: .rounded))
                Text(song.artist).font(.system(size: 11.5, weight: .medium, design: .rounded)).opacity(0.65)
            }
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.top, 10)

            Spacer(minLength: 8)
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line)
                        .font(
                            lyricFont.font(
                                .system(
                                    size: min(lyricSize, 21 * fontScale), weight: isCurrent ? .bold : .medium,
                                    design: .rounded), size: min(lyricSize, 21 * fontScale),
                                weight: isCurrent ? .bold : .medium)
                        )
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? .white : .white.opacity(0.35))
                        .shadow(color: isCurrent && activeLineIndex != nil ? .white.opacity(0.6) : .clear, radius: 8)
                }
            }
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.5)

            Spacer(minLength: 12)
            progress
            transport.padding(.top, 8)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 20)
    }

    var progress: some View {
        let position = time ?? 0
        let total = duration ?? song.duration
        let fraction = total > 0 ? min(position / total, 1) : 0.35
        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule().fill(.white).frame(width: geo.size.width * fraction)
                    Circle().fill(.white).frame(width: 9, height: 9)
                        .offset(x: geo.size.width * fraction - 4.5)
                }
            }
            .frame(height: 4)
            HStack {
                Text(formatTime(position))
                Spacer()
                Text(total > 0 ? "-" + formatTime(max(0, total - position)) : "")
            }
            .font(.system(size: 9.5, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    var transport: some View {
        HStack(spacing: 28) {
            Image(systemName: "shuffle").font(.system(size: 12, weight: .semibold)).opacity(0.6)
            Image(systemName: "backward.fill").font(.system(size: 16))
            Image(systemName: "pause.fill")
                .font(.system(size: 16))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(Circle().fill(.white))
            Image(systemName: "forward.fill").font(.system(size: 16))
            Image(systemName: "heart.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(.pink)
        }
        .foregroundStyle(.white)
    }
}
