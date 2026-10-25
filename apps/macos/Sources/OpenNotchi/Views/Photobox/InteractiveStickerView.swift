import SwiftUI

/// A sticker on the canvas: tap to select, drag to move, × to delete.
struct InteractiveStickerView: View {
    @Binding var sticker: PlacedSticker
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onDrag: (CGSize) -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            if sticker.isBadge {
                stampBadgeView(sticker)
            } else {
                Text(sticker.content)
                    .font(.system(size: 32 * sticker.scale))
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }

            // Selection ring & Quick Delete button
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(-6)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.red, .white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 10, y: -10)
                    }
                    Spacer()
                }
            }
        }
        .rotationEffect(.degrees(sticker.rotation))
        .offset(dragOffset)
        .onTapGesture {
            onSelect()
        }
        .gesture(
            DragGesture()
                .onChanged { val in
                    onSelect()
                    dragOffset = val.translation
                }
                .onEnded { val in
                    onDrag(val.translation)
                    dragOffset = .zero
                }
        )
    }

    // Sizes are worked out up front: one long chain of `x * scale` modifiers was too slow
    // for the compiler to type-check on CI.
    private func stampBadgeView(_ sticker: PlacedSticker) -> some View {
        let color = stampColor(sticker.badgeColor)
        let s: CGFloat = sticker.scale
        let fontSize: CGFloat = 12 * s
        let outer = RoundedRectangle(cornerRadius: 4 * s)
        let inner = RoundedRectangle(cornerRadius: 3 * s)
        let outerLine: CGFloat = 2 * s
        let innerLine: CGFloat = 0.8 * s
        let innerInset: CGFloat = 2 * s

        let label = Text(sticker.content.uppercased())
            .font(.system(size: fontSize, weight: .heavy))
            .tracking(1.5)
            .padding(.horizontal, 8 * s)
            .padding(.vertical, 4 * s)
        let framed =
            label
            .background(outer.fill(color.opacity(0.12)))
            .overlay(outer.stroke(color.opacity(0.9), lineWidth: outerLine))
            .overlay(inner.stroke(color.opacity(0.5), lineWidth: innerLine).padding(innerInset))
        return
            framed
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
    }
}
