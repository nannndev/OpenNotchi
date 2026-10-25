import SwiftUI

/// Left side of the studio: the rendered strip with draggable stickers on top.
struct StudioCanvas: View {
    @Binding var session: PhotoboxSession
    @Binding var selectedStickerID: UUID?
    let previewImage: NSImage?
    let copiedToast: Bool

    var body: some View {
        VStack(spacing: 6) {
            toolbar
                .padding(.horizontal, 14)
                .padding(.top, 8)

            GeometryReader { geo in
                ZStack {
                    if let image = previewImage {
                        strip(image, in: geo.size)
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    if copiedToast {
                        toast
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Label("\(session.stickers.count) stickers", systemImage: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            if !session.stickers.isEmpty {
                Button {
                    if !session.stickers.isEmpty {
                        session.stickers.removeLast()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Undo last sticker")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        session.stickers.removeAll()
                        selectedStickerID = nil
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.red.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .help("Remove all stickers")
            }
        }
    }

    /// The strip fitted into `size`, with each sticker placed by its normalized position on it.
    @ViewBuilder
    private func strip(_ image: NSImage, in size: CGSize) -> some View {
        let imgAspect = image.size.width / max(1, image.size.height)
        let containerAspect = size.width / max(1, size.height)
        let imgW = containerAspect > imgAspect ? size.height * imgAspect : size.width
        let imgH = containerAspect > imgAspect ? size.height : size.width / max(0.01, imgAspect)
        let originX = (size.width - imgW) / 2
        let originY = (size.height - imgH) / 2

        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: imgW, height: imgH)
            .shadow(color: .black.opacity(0.5), radius: 14, y: 4)
            .position(x: size.width / 2, y: size.height / 2)
            .onTapGesture {
                selectedStickerID = nil
            }

        ForEach($session.stickers) { $sticker in
            InteractiveStickerView(
                sticker: $sticker,
                isSelected: selectedStickerID == sticker.id,
                onSelect: {
                    selectedStickerID = sticker.id
                },
                onDelete: {
                    session.stickers.removeAll { $0.id == sticker.id }
                    if selectedStickerID == sticker.id { selectedStickerID = nil }
                },
                onDrag: { translation in
                    let newX = sticker.x + translation.width / imgW
                    let newY = sticker.y + translation.height / imgH
                    sticker.x = min(max(newX, 0.05), 0.95)
                    sticker.y = min(max(newY, 0.05), 0.95)
                }
            )
            .position(x: originX + sticker.x * imgW, y: originY + sticker.y * imgH)
        }
    }

    private var toast: some View {
        VStack {
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Copied to clipboard!")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.black.opacity(0.85)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, 12)
        }
    }
}
