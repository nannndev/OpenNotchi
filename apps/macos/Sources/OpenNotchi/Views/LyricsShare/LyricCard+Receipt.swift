import SwiftUI

/// Receipt style: a printed till receipt.
extension LyricCard {
    var receiptLayout: some View {
        VStack(spacing: 0) {
            ReceiptPerforation()
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 8)

            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("*** OPENNOTCHI ARCHIVE ***")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    HStack {
                        Text("AUDIO #1024")
                        Spacer()
                        if activeLineIndex != nil {
                            Text("TIME: \(formatTime(elapsed))")
                                .foregroundStyle(Color.red)
                        } else {
                            Text("TRACK CASSETTE")
                        }
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .opacity(0.7)
                    Text("------------------------------------")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.35)
                    HStack {
                        Text(song.title.uppercased())
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        Text(song.artist.uppercased())
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                    }
                    Text("------------------------------------")
                        .font(.system(size: 9, design: .monospaced))
                        .opacity(0.35)
                }

                Spacer(minLength: 6)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        let isCurrent = activeLineIndex == nil || activeLineIndex == index
                        HStack(alignment: .top, spacing: 6) {
                            Text(isCurrent && activeLineIndex != nil ? "►" : String(format: "%02d", index + 1))
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    isCurrent && activeLineIndex != nil ? Color.red : Color.black.opacity(0.45))
                            Text(line)
                                .font(
                                    lyricFont.font(
                                        .system(
                                            size: min(lyricSize, 15 * fontScale), weight: isCurrent ? .bold : .regular,
                                            design: .monospaced), size: min(lyricSize, 15 * fontScale),
                                        weight: isCurrent ? .bold : .regular)
                                )
                                .lyricAlignment(textAlign)
                                .foregroundStyle(isCurrent ? Color.black : Color.black.opacity(0.35))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isCurrent && activeLineIndex != nil ? Color.black.opacity(0.06) : Color.clear)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 6)

                VStack(spacing: 3) {
                    BarcodePattern(animatedOffset: activeLineIndex != nil ? elapsed : 0)
                        .frame(height: 28)
                    Text("THANK YOU FOR LISTENING")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.95, blue: 0.92))
            .foregroundStyle(Color.black.opacity(0.85))

            ReceiptPerforation(inverted: true)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.92))
                .frame(height: 8)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
    }
}
