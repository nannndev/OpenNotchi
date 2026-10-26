import SwiftUI

/// Cassette style: a tape with spinning spools.
extension LyricCard {
    var cassetteLayout: some View {
        VStack(spacing: 0) {
            header.padding(.bottom, 12)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                    )

                VStack(spacing: 8) {
                    HStack {
                        Text("SIDE A")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Spacer()
                        Text(song.title)
                            .font(.custom("Bradley Hand", size: 13).weight(.bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .lineLimit(1)
                        Spacer()
                        Text("C-60")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.8))
                            .frame(height: 52)

                        HStack(spacing: 36) {
                            CassetteSpool(rotation: elapsed * 120)
                            Rectangle().fill(Color(red: 0.35, green: 0.18, blue: 0.12)).frame(width: 36, height: 16)
                            CassetteSpool(rotation: elapsed * 120)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                }
                .background(Color(red: 0.94, green: 0.92, blue: 0.86))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(8)
            }
            .frame(height: 120)

            Spacer(minLength: 10)
            lyricsBlock
            Spacer(minLength: 10)
            footer
        }
        .padding(22)
    }
}
