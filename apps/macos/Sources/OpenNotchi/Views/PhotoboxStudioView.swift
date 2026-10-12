import AppKit
import SwiftUI

/// Active photobox editing session.
struct PhotoboxSession: Identifiable {
    let id = UUID()
    var photos: [CGImage]
    var style: StripStyle
    var format: StripFormat
    var info: StripInfo
    var stickers: [PlacedSticker] = []
}

enum StickerTab: String, CaseIterable, Identifiable {
    case cute = "Cute"
    case y2k = "Y2K"
    case stamps = "Stamps"
    case custom = "Text"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cute: return "sparkles"
        case .y2k: return "star.fill"
        case .stamps: return "seal.fill"
        case .custom: return "character.cursor.ibeam"
        }
    }
}

struct PhotoboxStudioView: View {
    @Binding var session: PhotoboxSession
    let onFinish: (URL) -> Void
    let onCancel: () -> Void

    @Environment(\.notchAccent) private var accent
    @State private var selectedTab: StickerTab = .cute
    @State private var selectedStickerID: UUID? = nil
    @State private var previewImage: NSImage? = nil
    @State private var isRendering = false
    @State private var customText: String = ""
    @State private var customBadgeColor: String = "red"
    @State private var copiedToast = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: Canvas & Interactive Stickers
            canvasSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))

            // Subtle divider
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)

            // Right: Sticker Drawer & Export Toolbar
            controlsSection
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

    // MARK: - Canvas Section

    private var canvasSection: some View {
        VStack(spacing: 6) {
            // Canvas mini-bar
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
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Canvas Area
            GeometryReader { geo in
                ZStack {
                    if let image = previewImage {
                        let imgAspect = image.size.width / max(1, image.size.height)
                        let containerAspect = geo.size.width / max(1, geo.size.height)
                        let imgW = containerAspect > imgAspect ? geo.size.height * imgAspect : geo.size.width
                        let imgH = containerAspect > imgAspect ? geo.size.height : geo.size.width / max(0.01, imgAspect)
                        let originX = (geo.size.width - imgW) / 2
                        let originY = (geo.size.height - imgH) / 2

                        // Base Photo Strip
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imgW, height: imgH)
                            .shadow(color: .black.opacity(0.5), radius: 14, y: 4)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .onTapGesture {
                                selectedStickerID = nil
                            }

                        // Interactive Stickers Overlay
                        ForEach($session.stickers) { $sticker in
                            let posX = originX + sticker.x * imgW
                            let posY = originY + sticker.y * imgH
                            let isSelected = selectedStickerID == sticker.id

                            InteractiveStickerView(
                                sticker: $sticker,
                                isSelected: isSelected,
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
                            .position(x: posX, y: posY)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(0.8)
                    }

                    if copiedToast {
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
            }
            .padding(.bottom, 6)
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 8) {
            // Top Bar: Style & Format Picker
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
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // Sticker Tab Bar
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
            .padding(.horizontal, 8)

            // Sticker Drawer Content
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

            // Selected Sticker Inspector (if a sticker is selected)
            if let id = selectedStickerID,
               let index = session.stickers.firstIndex(where: { $0.id == id }) {
                selectedStickerInspector(sticker: $session.stickers[index])
                    .padding(.horizontal, 8)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            // Bottom Actions Bar
            bottomActionsBar
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Sticker Catalog Views

    private func stickerGrid(_ items: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
            ForEach(items, id: \.self) { emoji in
                Button {
                    addSticker(content: emoji, isBadge: false)
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
                    addSticker(content: stamp.text, isBadge: true, color: stamp.color)
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
                                .fill(badgeColor(stamp.color).opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(badgeColor(stamp.color).opacity(0.8), lineWidth: 1.2)
                        )
                        .foregroundStyle(badgeColor(stamp.color))
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
                        .fill(badgeColor(c))
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
                    addSticker(content: trimmed, isBadge: true, color: customBadgeColor)
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

    private func selectedStickerInspector(sticker: Binding<PlacedSticker>) -> some View {
        HStack(spacing: 8) {
            // Scale controls
            HStack(spacing: 4) {
                Button {
                    sticker.wrappedValue.scale = max(0.5, sticker.wrappedValue.scale - 0.2)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)

                Text(String(format: "%.1fx", sticker.wrappedValue.scale))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .frame(width: 26)

                Button {
                    sticker.wrappedValue.scale = min(2.5, sticker.wrappedValue.scale + 0.2)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Rotate controls
            Button {
                sticker.wrappedValue.rotation = (sticker.wrappedValue.rotation - 15).truncatingRemainder(dividingBy: 360)
            } label: {
                Image(systemName: "rotate.left")
                    .font(.system(size: 9))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)

            Button {
                sticker.wrappedValue.rotation = (sticker.wrappedValue.rotation + 15).truncatingRemainder(dividingBy: 360)
            } label: {
                Image(systemName: "rotate.right")
                    .font(.system(size: 9))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)

            // Delete
            Button {
                session.stickers.removeAll { $0.id == sticker.wrappedValue.id }
                selectedStickerID = nil
            } label: {
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

    // MARK: - Bottom Actions Bar

    private var bottomActionsBar: some View {
        VStack(spacing: 6) {
            // Primary Save Button
            Button {
                saveAndFinish()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("Save & Keep")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white))
                .foregroundStyle(.black)
            }
            .buttonStyle(.plain)

            // Secondary Action Icons: Copy, AirDrop, Print
            HStack(spacing: 8) {
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Copy strip image to clipboard")

                Button {
                    airDropStrip()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "airdrop")
                        Text("AirDrop")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Send strip via AirDrop")

                Button {
                    printStrip()
                } label: {
                    Image(systemName: "printer")
                        .font(.system(size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .help("Print photo strip")
            }
        }
    }

    // MARK: - Helpers

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
              let url = MirrorPhotos.save(highRes, name: "Photobox") else { return }
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
              let url = MirrorPhotos.save(highRes, name: "Photobox") else { return }
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

    private func badgeColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "pink": return Color(red: 0.95, green: 0.25, blue: 0.60)
        case "green": return Color(red: 0.12, green: 0.65, blue: 0.40)
        case "black": return Color(white: 0.2)
        case "gold": return Color(red: 0.92, green: 0.65, blue: 0.15)
        case "blue": return Color(red: 0.20, green: 0.58, blue: 0.95)
        case "purple": return Color(red: 0.70, green: 0.35, blue: 0.90)
        default: return Color(red: 0.90, green: 0.20, blue: 0.20) // red
        }
    }
}

// MARK: - Interactive Sticker View

private struct InteractiveStickerView: View {
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

    private func stampBadgeView(_ sticker: PlacedSticker) -> some View {
        let color = badgeColor(sticker.badgeColor)
        return Text(sticker.content.uppercased())
            .font(.system(size: 12 * sticker.scale, weight: .heavy))
            .tracking(1.5)
            .padding(.horizontal, 8 * sticker.scale)
            .padding(.vertical, 4 * sticker.scale)
            .background(
                RoundedRectangle(cornerRadius: 4 * sticker.scale)
                    .fill(color.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4 * sticker.scale)
                    .stroke(color.opacity(0.9), lineWidth: 2 * sticker.scale)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3 * sticker.scale)
                    .stroke(color.opacity(0.5), lineWidth: 0.8 * sticker.scale)
                    .padding(2 * sticker.scale)
            )
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
    }

    private func badgeColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "pink": return Color(red: 0.95, green: 0.25, blue: 0.60)
        case "green": return Color(red: 0.12, green: 0.65, blue: 0.40)
        case "black": return Color(white: 0.2)
        case "gold": return Color(red: 0.92, green: 0.65, blue: 0.15)
        case "blue": return Color(red: 0.20, green: 0.58, blue: 0.95)
        case "purple": return Color(red: 0.70, green: 0.35, blue: 0.90)
        default: return Color(red: 0.90, green: 0.20, blue: 0.20) // red
        }
    }
}
