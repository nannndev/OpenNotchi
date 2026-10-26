import AppKit
import SwiftUI

/// Sticker studio for a finished photobox session: decorate the strip, then save, copy, AirDrop or print it.
struct PhotoboxStudioView: View {
    @Binding var session: PhotoboxSession
    let onFinish: (URL) -> Void
    let onCancel: () -> Void

    @State private var selectedStickerID: UUID? = nil
    @State private var previewImage: NSImage? = nil
    @State private var isRendering = false
    @State private var copiedToast = false

    var body: some View {
        HStack(spacing: 0) {
            StudioCanvas(
                session: $session,
                selectedStickerID: $selectedStickerID,
                previewImage: previewImage,
                copiedToast: copiedToast
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.85))

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)

            controls
                .frame(width: 275)
                .background(Color(white: 0.11))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            updateBasePreview()
        }
        .onChange(of: session.style) { updateBasePreview() }
        .onChange(of: session.format) { updateBasePreview() }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            stylePicker
                .padding(.horizontal, 10)
                .padding(.top, 8)

            StickerDrawer { content, isBadge, color in
                addSticker(content: content, isBadge: isBadge, color: color)
            }

            if let id = selectedStickerID,
                let index = session.stickers.firstIndex(where: { $0.id == id })
            {
                StickerInspector(sticker: $session.stickers[index]) {
                    session.stickers.removeAll { $0.id == id }
                    selectedStickerID = nil
                }
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            StudioActionsBar(
                onSave: saveAndFinish,
                onCopy: copyToClipboard,
                onAirDrop: airDropStrip,
                onPrint: printStrip
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private var stylePicker: some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Style", selection: $session.style) {
                    ForEach(StripStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 10))
                    Text(session.style.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.white.opacity(0.12)))
                .foregroundStyle(.white)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                Picker("Format", selection: $session.format) {
                    ForEach(StripFormat.allCases) { format in
                        Label(format.displayName, systemImage: format.icon).tag(format)
                    }
                }
            } label: {
                Image(systemName: session.format.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.12)))
                    .foregroundStyle(.white)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .padding(6)
                    .background(Circle().fill(.white.opacity(0.12)))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel")
        }
    }

    private func addSticker(content: String, isBadge: Bool, color: String = "red") {
        let sticker = PlacedSticker(
            content: content,
            isBadge: isBadge,
            badgeColor: color,
            x: 0.5 + CGFloat.random(in: -0.15...0.15),
            y: 0.4 + CGFloat.random(in: -0.15...0.2),
            scale: 1.0,
            rotation: Double.random(in: -10...10)
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            session.stickers.append(sticker)
            selectedStickerID = sticker.id
        }
        NSSound(named: "Pop")?.play()
    }

    private func updateBasePreview() {
        isRendering = true
        let photos = session.photos
        let style = session.style
        let format = session.format
        let info = session.info

        Task.detached(priority: .userInitiated) {
            if let cg = PhotoStripComposer.compose(photos, style: style, format: format, info: info, stickers: []) {
                let ns = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                await MainActor.run {
                    self.previewImage = ns
                    self.isRendering = false
                }
            }
        }
    }

    private func generateHighResComposite() -> CGImage? {
        PhotoStripComposer.compose(
            session.photos,
            style: session.style,
            format: session.format,
            info: session.info,
            stickers: session.stickers
        )
    }

    private func saveAndFinish() {
        guard let highRes = generateHighResComposite(),
            let url = MirrorPhotos.save(highRes, name: "Photobox")
        else { return }
        NSSound(named: "Tink")?.play()
        onFinish(url)
    }

    private func copyToClipboard() {
        guard let highRes = generateHighResComposite() else { return }
        let ns = NSImage(cgImage: highRes, size: NSSize(width: highRes.width, height: highRes.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([ns])
        NSSound(named: "Pop")?.play()
        withAnimation { copiedToast = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedToast = false }
        }
    }

    private func airDropStrip() {
        guard let highRes = generateHighResComposite(),
            let url = MirrorPhotos.save(highRes, name: "Photobox")
        else { return }
        AirDropService.send([url])
    }

    private func printStrip() {
        guard let highRes = generateHighResComposite() else { return }
        let ns = NSImage(cgImage: highRes, size: NSSize(width: highRes.width, height: highRes.height))
        let imageView = NSImageView(image: ns)
        imageView.frame = NSRect(x: 0, y: 0, width: highRes.width, height: highRes.height)
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        let op = NSPrintOperation(view: imageView, printInfo: printInfo)
        op.showsPrintPanel = true
        op.run()
    }
}
