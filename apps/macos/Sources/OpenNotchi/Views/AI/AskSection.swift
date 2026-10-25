import AppKit
import SwiftUI

/// Extra context the user can attach to the next prompt.
enum ChatContext: String, CaseIterable, Identifiable {
    case clipboard, song, usage

    var id: String { rawValue }
    var label: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .song: return "Now playing"
        case .usage: return "My AI usage"
        }
    }
    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .song: return "music.note"
        case .usage: return "chart.bar.xaxis"
        }
    }
}

struct AskSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var usage: AIUsageManager
    @Environment(\.notchAccent) private var accent
    @ObservedObject private var store = ChatStore.shared
    @State private var text = ""
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var streaming = false
    @State private var attached: Set<ChatContext> = []
    @State private var routerModels: [String] = []
    /// Pending images (base64 JPEG) and files (name, text) for the next message.
    @State private var pendingImages: [String] = []
    @State private var pendingFiles: [(name: String, body: String)] = []
    @State private var dropTargeted = false
    /// Settings Notchi changed per assistant message index, shown under that bubble.
    @State private var changes: [Int: [NotchiBrain.Change]] = [:]
    @EnvironmentObject private var vm: NotchViewModel
    @FocusState private var focused: Bool

    private var messages: [AIAssistant.Message] { store.current?.messages ?? [] }

    private var providerLabel: String {
        switch settings.aiProvider {
        case .ninerouter: return "9router · \(settings.aiNineRouterModel.isEmpty ? "auto" : settings.aiNineRouterModel)"
        case .anthropic: return "Anthropic · \(settings.aiAnthropicModel)"
        case .openai: return settings.aiOpenaiModel
        case .ollama: return "Ollama · \(settings.aiOllamaModel)"
        case .apple: return "Apple Intelligence"
        }
    }

    private var lyricLine: String? {
        guard let info = media.info else { return nil }
        return lyrics.currentLine(at: info.position(at: .now))
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            conversation
            composer
        }
        .onExitCommand { if task != nil { stop() } }
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted) { providers in
            for p in providers {
                if p.canLoadObject(ofClass: URL.self) {
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        if let url { Task { @MainActor in addFile(url) } }
                    }
                } else if p.canLoadObject(ofClass: NSImage.self) {
                    _ = p.loadObject(ofClass: NSImage.self) { img, _ in
                        if let img = img as? NSImage, let b64 = ChatAttachment.jpegBase64(img) {
                            Task { @MainActor in withAnimation { pendingImages.append(b64) } }
                        }
                    }
                }
            }
            return true
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accent.highlight, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(RoundedRectangle(cornerRadius: 14).fill(accent.highlight.opacity(0.08)))
                    .overlay(Label("Drop to attach", systemImage: "paperclip").font(.system(size: 12, weight: .semibold)))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }

    // MARK: Header: model + sessions

    private var header: some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Provider", selection: $settings.aiProvider) {
                    ForEach(AIProvider.available) { Text($0.displayName).tag($0) }
                }
                if settings.aiProvider == .ninerouter {
                    Picker("Model", selection: $settings.aiNineRouterModel) {
                        Text("Automatic").tag("")
                        ForEach(routerModels, id: \.self) { Text($0).tag($0) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").foregroundStyle(accent.highlight)
                    Text(providerLabel).lineLimit(1)
                }
                .font(.system(size: 10, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Where your prompts go")
            .task(id: settings.aiProvider) {
                if settings.aiProvider == .ninerouter { routerModels = await NineRouterService.shared.models() }
            }

            Spacer()

            Menu {
                Button("New chat", systemImage: "square.and.pencil") { newChat() }
                if !store.sessions.isEmpty {
                    Divider()
                    ForEach(store.sessions.prefix(15)) { session in
                        Button {
                            stop()
                            changes = [:]
                            withAnimation(.easeInOut(duration: 0.2)) { store.currentID = session.id }
                        } label: {
                            Text(session.title)
                            Text(session.updatedAt.formatted(.relative(presentation: .named)))
                        }
                    }
                    if let id = store.currentID {
                        Divider()
                        Button("Delete this chat", systemImage: "trash", role: .destructive) {
                            withAnimation { store.delete(id) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(store.current?.title ?? "New chat").lineLimit(1).frame(maxWidth: 160)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Chat history")

            Button(action: newChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New chat")
            .accessibilityLabel("New chat")
        }
        .padding(.horizontal, 2)
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    if messages.isEmpty && error == nil {
                        suggestions
                    }
                    ForEach(Array(messages.enumerated()), id: \.offset) { i, m in
                        ChatBubble(
                            message: m,
                            isStreaming: streaming && i == messages.count - 1,
                            canRegenerate: task == nil && i == messages.count - 1 && m.role == "assistant",
                            onRegenerate: regenerate,
                            changes: changes[i] ?? []
                        )
                        .id(i)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: m.role == "user" ? .bottomTrailing : .bottomLeading)),
                            removal: .opacity
                        ))
                    }
                    if task != nil && !streaming {
                        TypingIndicator(tint: accent.highlight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                    }
                    if let error {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error).textSelection(.enabled)
                            Spacer(minLength: 4)
                            Button("Retry", action: regenerate).buttonStyle(.plain).fontWeight(.semibold)
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.orange.opacity(0.12)))
                        .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 2)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: messages.count)
                .animation(.easeOut(duration: 0.2), value: task != nil)
            }
            .onChange(of: messages.last?.content) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: store.currentID) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .frame(maxHeight: .infinity)
    }

    private var suggestions: some View {
        VStack(spacing: 8) {
            Text("What can I help with?")
                .font(.system(size: 13, weight: .bold))
            HStack(spacing: 6) {
                ForEach(QuickAction.allCases) { action in
                    Button { quick(action) } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Capsule().fill(.white.opacity(0.08)))
                            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(action == .explain && lyricLine == nil)
                    .help(action == .explain ? "Uses the current lyric line" : "Uses the text on the clipboard")
                }
            }
            HStack(spacing: 14) {
                if usage.is9RouterConnected {
                    suggestion("How's my AI usage today?", icon: "chart.bar.xaxis") {
                        send("How is my AI usage looking? Anything close to its limit?", context: [.usage])
                    }
                }
                suggestion("Make my notch look nicer", icon: "paintpalette") { send("Make my notch look nicer. Pick a theme, accent and animation that go well together.") }
                suggestion("What can Notchi do?", icon: "questionmark.circle") { send("What can OpenNotchi do? Give me a quick tour.") }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .transition(.opacity)
    }

    private func suggestion(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent.highlight)
        }
        .buttonStyle(.plain)
    }

    // MARK: Composer

    private var composer: some View {
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
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? accent.highlight.opacity(0.5) : .white.opacity(0.08), lineWidth: 1))
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
                .disabled(task == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty && pendingFiles.isEmpty)
                .help(task != nil ? "Stop (Esc)" : "Send (Return)")
                .accessibilityLabel(task != nil ? "Stop" : "Send")
            }
        }
    }

    // MARK: Attachments

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white, .black.opacity(0.6))
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
        .accessibilityLabel("Remove attachment")
    }

    private func addFile(_ url: URL) {
        switch ChatAttachment.load(url) {
        case .image(let b64): withAnimation { pendingImages.append(b64) }
        case .text(let name, let body): withAnimation { pendingFiles.append((name, body)) }
        case nil: error = "Can't read \(url.lastPathComponent). Images, PDFs and text files work."
        }
    }

    private func pickFiles() {
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

    private func takeScreenshot() {
        vm.holdOpen = true
        Task {
            if let b64 = await ChatAttachment.screenshot() {
                withAnimation { pendingImages.append(b64) }
            }
            vm.holdOpen = false
            focused = true
        }
    }

    private func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            urls.forEach(addFile)
        } else if let img = NSImage(pasteboard: pb), let b64 = ChatAttachment.jpegBase64(img) {
            withAnimation { pendingImages.append(b64) }
        }
    }

    // MARK: Actions

    private func newChat() {
        stop()
        withAnimation(.easeInOut(duration: 0.2)) {
            store.newSession()
            error = nil
            attached = []
            pendingImages = []
            pendingFiles = []
            changes = [:]
        }
        focused = true
    }

    private func quick(_ action: QuickAction) {
        if action == .explain {
            guard let line = lyricLine else { return }
            send(action.prompt(line, song: media.info.map { ($0.title, $0.artist) }))
        } else {
            guard let clip = NSPasteboard.general.string(forType: .string), !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                error = "The clipboard has no text."
                return
            }
            send(action.prompt(clip))
        }
    }

    /// The attached context, sent ahead of the prompt.
    private func contextBlock(_ context: Set<ChatContext>) -> String {
        var parts: [String] = []
        if context.contains(.clipboard), let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
            parts.append("Clipboard:\n\(clip.prefix(6000))")
        }
        if context.contains(.song), let info = media.info {
            parts.append("Now playing: \"\(info.title)\" by \(info.artist)" + (lyricLine.map { ". Current lyric: \"\($0)\"" } ?? ""))
        }
        if context.contains(.usage) {
            let lines = usage.reports.map { r in
                let quotas = r.quotas.map { "\($0.name) \($0.unlimited ? "unlimited" : "\(Int($0.remainingPercentage))% left")" }.joined(separator: ", ")
                return "- \(r.account.name) (\(r.account.tool.displayName), \(r.account.isActive ? "on" : "off")): \(formatTokens(r.today.tokens)) tokens today\(quotas.isEmpty ? "" : "; \(quotas)")"
            }
            parts.append("My AI accounts in 9router:\n" + lines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }

    private func send(_ prompt: String, context: Set<ChatContext>? = nil) {
        var prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard task == nil, !prompt.isEmpty || !pendingImages.isEmpty || !pendingFiles.isEmpty else { return }
        if prompt.isEmpty { prompt = pendingImages.isEmpty ? "What's in this file?" : "What's in this image?" }
        let ctx = context ?? attached
        let files = pendingFiles.map { "File \($0.name):\n\($0.body)" }
        let block = ([contextBlock(ctx)] + files).filter { !$0.isEmpty }.joined(separator: "\n\n")
        let labels = ChatContext.allCases.filter(ctx.contains).map(\.label) + pendingFiles.map(\.name)
        let images = pendingImages
        text = ""
        error = nil
        attached = []
        pendingImages = []
        pendingFiles = []
        withAnimation {
            store.append(.init(role: "user", content: prompt, context: block.isEmpty ? nil : block,
                               attachments: labels.isEmpty ? nil : labels, images: images.isEmpty ? nil : images))
        }
        run()
    }

    private func regenerate() {
        guard task == nil else { return }
        error = nil
        if messages.last?.role == "assistant" { store.removeLast() }
        guard messages.last?.role == "user" else { return }
        run()
    }

    private func run() {
        let history = messages
        let system = NotchiBrain.systemPrompt
        task = Task { @MainActor in
            var answer = ""
            do {
                try await AIAssistant.chat(history, system: system, settings: settings) { delta in
                    if !streaming {
                        streaming = true
                        withAnimation { store.append(.init(role: "assistant", content: "")) }
                    }
                    answer += delta
                    store.updateLast(NotchiBrain.split(answer).text)
                }
                // Apply any settings the model asked for, keep only the readable part in the chat.
                let (shown, actions) = NotchiBrain.split(answer)
                store.updateLast(shown.isEmpty ? "Done." : shown, persist: true)
                if let actions {
                    let applied = withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { NotchiBrain.apply(actions, vm: vm) }
                    if !applied.isEmpty { withAnimation { changes[messages.count - 1] = applied } }
                }
            } catch is CancellationError {
                if streaming { store.updateLast(answer, persist: true) }
            } catch {
                if streaming && answer.isEmpty { store.removeLast() }
                withAnimation { self.error = error.localizedDescription }
            }
            streaming = false
            task = nil
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        streaming = false
    }
}

/// One message. User on the right in the accent color, assistant on the left with copy / regenerate on hover.
