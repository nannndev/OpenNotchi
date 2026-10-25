import SwiftUI

/// Scale, rotate and delete controls for the selected sticker.
struct StickerInspector: View {
    @Binding var sticker: PlacedSticker
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Button {
                    sticker.scale = max(0.5, sticker.scale - 0.2)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Text(String(format: "%.1fx", sticker.scale))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .frame(width: 26)

                Button {
                    sticker.scale = min(2.5, sticker.scale + 0.2)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                sticker.rotation = (sticker.rotation - 15).truncatingRemainder(dividingBy: 360)
            } label: {
                Image(systemName: "rotate.left")
                    .font(.system(size: 9))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)

            Button {
                sticker.rotation = (sticker.rotation + 15).truncatingRemainder(dividingBy: 360)
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 9))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.red.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
    }
}
