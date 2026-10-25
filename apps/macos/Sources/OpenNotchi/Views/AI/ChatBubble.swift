import AppKit
import SwiftUI

struct ChatBubble: View {
    let message: AIAssistant.Message
    let isStreaming: Bool
    let canRegenerate: Bool
    let onRegenerate: () -> Void
    var changes: [NotchiBrain.Change] = []
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false
    @State private var copied = false
    @State private var undone: Set<UUID> = []

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if let attachments = message.attachments {
                    HStack(spacing: 4) {
                        ForEach(attachments, id: \.self) { a in
                            Label(a, systemImage: "paperclip")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let images = message.images {
                    HStack(spacing: 4) {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, b64 in
                            if let img = Data(base64Encoded: b64).flatMap(NSImage.init(data:)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                }
                (Text(rendered) + Text(isStreaming ? " ▍" : "").foregroundColor(accent.highlight))
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 13,
                            bottomLeadingRadius: isUser ? 13 : 4,
                            bottomTrailingRadius: isUser ? 4 : 13,
                            topTrailingRadius: 13
                        )
                        .fill(isUser ? accent.highlight.opacity(0.28) : .white.opacity(0.07))
                    )
                if !changes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(changes) { c in
                            HStack(spacing: 6) {
                                Image(systemName: undone.contains(c.id) ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                                    .foregroundStyle(undone.contains(c.id) ? Color.secondary : Color.green)
                                Text(c.label).strikethrough(undone.contains(c.id)).lineLimit(1)
                                if c.undo != nil && !undone.contains(c.id) {
                                    Button("Undo") {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            NotchiBrain.undo(c)
                                            undone.insert(c.id)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(accent.highlight)
                                }
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1)))
                }
                if !isUser && !isStreaming {
                    HStack(spacing: 10) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            copied = true
                            Task { try? await Task.sleep(for: .seconds(1.2)); copied = false }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        if canRegenerate {
                            Button(action: onRegenerate) { Label("Regenerate", systemImage: "arrow.clockwise") }
                        }
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(hovering || canRegenerate ? 1 : 0)
                    .padding(.leading, 4)
                }
            }
            if !isUser { Spacer(minLength: 60) }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }

    /// Light markdown (bold, italics, code, links); falls back to plain text.
    private var rendered: AttributedString {
        (try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(message.content)
    }
}

/// Three dots bouncing in turn while waiting for the first token.
struct TypingIndicator: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                        .offset(y: -3 * max(0, sin((t * 6) - Double(i) * 0.7)))
                        .opacity(0.5 + 0.5 * max(0, sin((t * 6) - Double(i) * 0.7)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(UnevenRoundedRectangle(topLeadingRadius: 13, bottomLeadingRadius: 4, bottomTrailingRadius: 13, topTrailingRadius: 13).fill(.white.opacity(0.07)))
        }
        .accessibilityLabel("Thinking")
    }
}
