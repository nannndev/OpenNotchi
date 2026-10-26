import SwiftUI

/// VHS style: tape overlay text and scanlines.
extension LyricCard {
    var vhsLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity((Int(elapsed * 2) % 2 == 0) ? 1.0 : 0.25)
                    Text("REC")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Text("SP")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "battery.75percent")
                    Text("AUTO")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .foregroundStyle(.white)

            let tcSecs = Int(elapsed)
            let tcMillis = Int((elapsed - Double(tcSecs)) * 100)
            Text(String(format: "%02d:%02d:%02d.%02d", tcSecs / 3600, (tcSecs % 3600) / 60, tcSecs % 60, tcMillis))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
                .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.6), radius: 4)
                .padding(.top, 4)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    let isCurrent = activeLineIndex == nil || activeLineIndex == index
                    Text(line.uppercased())
                        .font(
                            lyricFont.font(
                                .system(size: lyricSize, weight: .heavy, design: .monospaced), size: lyricSize,
                                weight: .heavy)
                        )
                        .lyricAlignment(textAlign)
                        .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.35))
                        .shadow(color: isCurrent ? Color.cyan.opacity(0.7) : .clear, radius: 6)
                }
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                    Text(song.artist.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("PLAY ▶")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.2, green: 1.0, blue: 0.4))
            }
            .foregroundStyle(.white)
        }
        .padding(24)
    }
}
