import AppKit
import SwiftUI

/// Text field, attached context, pending images/files and send button.
extension AskSection {
    var composer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                ForEach(ChatContext.allCases) { ctx in
                    let on = attached.contains(ctx)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if on { attached.remove(ctx) } else { attached.insert(ctx) }
                        }
                    } label: {
                        Label(ctx.label, systemImage: on ? "checkmark" : ctx.icon)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(on ? accent.highlight : .secondary)
                            .padding(.horizontal, 7)
                            .frame(height: 19)
                            .background(Capsule().fill(on ? accent.highlight.opacity(0.16) : .white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .disabled(ctx == .song && media.info == nil || ctx == .usage && !usage.is9RouterConnected)
                    .help("Attach \(ctx.label.lowercased()) to your next message")
                }
                Spacer()
                Button(action: pickFiles) {
                    Image(systemName: "paperclip").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Attach images or files (or drop them here, or ⌘V an image)")
                .accessibilityLabel("Attach files")
                Button(action: takeScreenshot) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Capture part of the screen")
                .accessibilityLabel("Screenshot")
            }

            if !pendingImages.isEmpty || !pendingFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pendingImages.enumerated()), id: \.offset) { i, b64 in
                            if let img = Data(base64Encoded: b64).flatMap(NSImage.init(data:)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) { removeButton { pendingImages.remove(at: i) } }
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        ForEach(Array(pendingFiles.enumerated()), id: \.offset) { i, f in
                            Label(f.name, systemImage: "doc.text")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                                .overlay(alignment: .topTrailing) { removeButton { pendingFiles.remove(at: i) } }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                TextField(messages.isEmpty ? "Ask anything…" : "Reply…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { send(text) }
                    .onPasteCommand(of: [.image, .fileURL]) { _ in pasteFromClipboard() }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    focused ? accent.highlight.opacity(0.5) : .white.opacity(0.08), lineWidth: 1))
                    )
                    .animation(.easeOut(duration: 0.15), value: focused)

                Button {
                    if task != nil { stop() } else { send(text) }
                } label: {
                    Image(systemName: task != nil ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accent.highlight)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(
                    task == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty
                        && pendingFiles.isEmpty
                )
                .help(task != nil ? "Stop (Esc)" : "Send (Return)")
                .accessibilityLabel(task != nil ? "Stop" : "Send")
            }
        }
    }

    func removeButton(_ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white, .black.opacity(0.6))
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
        .accessibilityLabel("Remove attachment")
    }

    func addFile(_ url: URL) {
        switch ChatAttachment.load(url) {
        case .image(let b64): withAnimation { pendingImages.append(b64) }
        case .text(let name, let body): withAnimation { pendingFiles.append((name, body)) }
        case nil: error = "Can't read \(url.lastPathComponent). Images, PDFs and text files work."
        }
    }

    func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        // The notch panel floats above everything; bring the app forward so the picker isn't hidden.
        NSApp.activate(ignoringOtherApps: true)
        vm.holdOpen = true
        panel.begin { response in
            vm.holdOpen = false
            if response == .OK { panel.urls.forEach(addFile) }
        }
    }

    func takeScreenshot() {
        vm.holdOpen = true
        Task {
            if let b64 = await ChatAttachment.screenshot() {
                withAnimation { pendingImages.append(b64) }
            }
            vm.holdOpen = false
            focused = true
        }
    }

    func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
            !urls.isEmpty
        {
            urls.forEach(addFile)
        } else if let img = NSImage(pasteboard: pb), let b64 = ChatAttachment.jpegBase64(img) {
            withAnimation { pendingImages.append(b64) }
        }
    }
}
