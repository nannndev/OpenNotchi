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
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var media: MediaManager
    @EnvironmentObject var lyrics: LyricsManager
    @EnvironmentObject var usage: AIUsageManager
    @Environment(\.notchAccent) var accent
    @ObservedObject var store = ChatStore.shared
    @State var text = ""
    @State var error: String?
    @State var task: Task<Void, Never>?
    @State var streaming = false
    @State var attached: Set<ChatContext> = []
    @State var routerModels: [String] = []
    /// Pending images (base64 JPEG) and files (name, text) for the next message.
    @State var pendingImages: [String] = []
    @State var pendingFiles: [(name: String, body: String)] = []
    @State var dropTargeted = false
    /// Settings Notchi changed per assistant message index, shown under that bubble.
    @State var changes: [Int: [NotchiBrain.Change]] = [:]
    @EnvironmentObject var vm: NotchViewModel
    @FocusState var focused: Bool

    var messages: [AIAssistant.Message] { store.current?.messages ?? [] }

    var providerLabel: String {
        switch settings.aiProvider {
        case .ninerouter: return "9router · \(settings.aiNineRouterModel.isEmpty ? "auto" : settings.aiNineRouterModel)"
        case .anthropic: return "Anthropic · \(settings.aiAnthropicModel)"
        case .openai: return settings.aiOpenaiModel
        case .ollama: return "Ollama · \(settings.aiOllamaModel)"
        case .apple: return "Apple Intelligence"
        }
    }

    var lyricLine: String? {
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
                    .overlay(
                        Label("Drop to attach", systemImage: "paperclip").font(.system(size: 12, weight: .semibold))
                    )
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }
}
