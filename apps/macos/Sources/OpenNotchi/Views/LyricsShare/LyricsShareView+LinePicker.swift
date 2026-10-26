import SwiftUI

/// Left column: pick up to `maxLines` consecutive lyric lines.
extension LyricsShareView {
    var linePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Lyrics")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(selection.count) of \(Self.maxLines) lines")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(song.lines.indices, id: \.self) { index in
                            let isOn = selection.contains(index)
                            Button {
                                toggleLine(index)
                            } label: {
                                Text(song.lines[index])
                                    .font(.system(size: 12.5, weight: isOn ? .semibold : .medium))
                                    .foregroundStyle(isOn ? .white : .secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        selectionShape(index).fill(isOn ? Color.accentColor.opacity(0.35) : .clear)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
                .onAppear { proxy.scrollTo(selection.lowerBound, anchor: .center) }
            }

            if hasTranslations {
                Divider().opacity(0.2).padding(.horizontal, 12)
                Toggle("Include translation", isOn: $showTranslation)
                    .font(.system(size: 11.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }

    func selectionShape(_ index: Int) -> UnevenRoundedRectangle {
        let top: CGFloat = index == selection.lowerBound ? 7 : 0
        let bottom: CGFloat = index == selection.upperBound ? 7 : 0
        return UnevenRoundedRectangle(
            topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
    }

    func toggleLine(_ index: Int) {
        selection = Self.nextSelection(selection, tapping: index, maxLines: Self.maxLines)
        // Auto update duration if synced
        if let start = song.times[selection.lowerBound], let end = song.times[selection.upperBound] {
            let autoDur = max(5.0, min(30.0, (end - start) + 3.5))
            duration = autoDur
        }
    }

    static func nextSelection(_ range: ClosedRange<Int>, tapping index: Int, maxLines: Int) -> ClosedRange<Int> {
        if range.count > 1, index == range.lowerBound { return (index + 1)...range.upperBound }
        if range.count > 1, index == range.upperBound { return range.lowerBound...(index - 1) }
        if range.contains(index) { return range.lowerBound...index }
        let stretched = min(index, range.lowerBound)...max(index, range.upperBound)
        return stretched.count <= maxLines ? stretched : index...index
    }
}
