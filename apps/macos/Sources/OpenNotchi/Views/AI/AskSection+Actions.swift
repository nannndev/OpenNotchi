import AppKit
import SwiftUI

/// New chat, quick actions, sending and streaming the reply.
extension AskSection {
    func newChat() {
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

    func quick(_ action: QuickAction) {
        if action == .explain {
            guard let line = lyricLine else { return }
            send(action.prompt(line, song: media.info.map { ($0.title, $0.artist) }))
        } else {
            guard let clip = NSPasteboard.general.string(forType: .string),
                !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                error = "The clipboard has no text."
                return
            }
            send(action.prompt(clip))
        }
    }

    /// The attached context, sent ahead of the prompt.
    func contextBlock(_ context: Set<ChatContext>) -> String {
        var parts: [String] = []
        if context.contains(.clipboard), let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
            parts.append("Clipboard:\n\(clip.prefix(6000))")
        }
        if context.contains(.song), let info = media.info {
            parts.append(
                "Now playing: \"\(info.title)\" by \(info.artist)"
                    + (lyricLine.map { ". Current lyric: \"\($0)\"" } ?? ""))
        }
        if context.contains(.usage) {
            let lines = usage.reports.map { r in
                let quotas = r.quotas.map {
                    "\($0.name) \($0.unlimited ? "unlimited" : "\(Int($0.remainingPercentage))% left")"
                }.joined(separator: ", ")
                return
                    "- \(r.account.name) (\(r.account.tool.displayName), \(r.account.isActive ? "on" : "off")): \(formatTokens(r.today.tokens)) tokens today\(quotas.isEmpty ? "" : "; \(quotas)")"
            }
            parts.append("My AI accounts in 9router:\n" + lines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }

    func send(_ prompt: String, context: Set<ChatContext>? = nil) {
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
            store.append(
                .init(
                    role: "user", content: prompt, context: block.isEmpty ? nil : block,
                    attachments: labels.isEmpty ? nil : labels, images: images.isEmpty ? nil : images))
        }
        run()
    }

    func regenerate() {
        guard task == nil else { return }
        error = nil
        if messages.last?.role == "assistant" { store.removeLast() }
        guard messages.last?.role == "user" else { return }
        run()
    }

    func run() {
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
                    let applied = withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        NotchiBrain.apply(actions, vm: vm)
                    }
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

    func stop() {
        task?.cancel()
        task = nil
        streaming = false
    }
}
