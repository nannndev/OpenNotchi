import SwiftUI

/// Sticker catalog: tabs for emoji sets, ready-made stamps and a custom text stamp.
struct StickerDrawer: View {
    /// Called with the sticker content, whether it's a stamp, and the stamp's color name.
    let onAdd: (String, Bool, String) -> Void

    @Environment(\.notchAccent) private var accent
    @State private var selectedTab: StickerTab = .cute
    @State private var customText: String = ""
    @State private var customBadgeColor: String = "red"

    var body: some View {
        VStack(spacing: 8) {
            tabBar
                .padding(.horizontal, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    switch selectedTab {
                    case .cute:
                        stickerGrid(StickerPresets.cute)
                    case .y2k:
                        stickerGrid(StickerPresets.y2k)
                    case .stamps:
                        stampsGrid
                    case .custom:
                        customTextEditor
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 180)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(StickerTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 9))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(selectedTab == tab ? accent.color.opacity(0.35) : .white.opacity(0.06))
                    )
                    .foregroundStyle(selectedTab == tab ? accent.highlight : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stickerGrid(_ items: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
            ForEach(items, id: \.self) { emoji in
                Button {
                    onAdd(emoji, false, "red")
                } label: {
                    Text(emoji)
                        .font(.system(size: 22))
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stampsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(StickerPresets.stamps) { stamp in
                Button {
                    onAdd(stamp.text, true, stamp.color)
                } label: {
                    Text(stamp.text)
                        .font(.system(size: 9, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(stampColor(stamp.color).opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(stampColor(stamp.color).opacity(0.8), lineWidth: 1.2)
                        )
                        .foregroundStyle(stampColor(stamp.color))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customTextEditor: some View {
        VStack(spacing: 6) {
            TextField("Type word (e.g. BFF)", text: $customText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))

            HStack(spacing: 6) {
                ForEach(["red", "pink", "green", "black", "gold", "blue"], id: \.self) { c in
                    Circle()
                        .fill(stampColor(c))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().strokeBorder(Color.white, lineWidth: customBadgeColor == c ? 2 : 0)
                        )
                        .onTapGesture { customBadgeColor = c }
                }
                Spacer()
                Button {
                    let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onAdd(trimmed, true, customBadgeColor)
                    customText = ""
                } label: {
                    Text("+ Stamp")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.color))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }
}
