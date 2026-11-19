import AppKit
import SwiftUI

/// One chat message bubble with sleek glassmorphic styling, fenced code blocks with copy, and AI action pills.
struct ChatBubble: View {
    let message: AIAssistant.Message
    let isStreaming: Bool
    let canRegenerate: Bool
    let onRegenerate: () -> Void
    var changes: [NotchiBrain.Change] = []
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false
    @State private var copied = false
    @State private var copiedBlockIdx: Int?
    @State private var undone: Set<UUID> = []

    private var isUser: Bool { message.role == "user" }

    private struct Segment: Identifiable {
        let id: Int
        let isCode: Bool
        let language: String
        let text: String
    }

    private var segments: [Segment] {
        let raw = message.content
        guard !isUser, raw.contains("```") else {
            return [Segment(id: 0, isCode: false, language: "", text: raw)]
        }
        var out: [Segment] = []
        let lines = raw.components(separatedBy: "\n")
        var inCode = false
        var lang = ""
        var buf: [String] = []
        var idx = 0

        func flush() {
            let joined = buf.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inCode {
                out.append(Segment(id: idx, isCode: inCode, language: lang, text: joined))
                idx += 1
            }
            buf.removeAll()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                flush()
                if inCode {
                    inCode = false
                    lang = ""
                } else {
                    inCode = true
                    lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
            } else {
                buf.append(line)
            }
        }
        flush()
        return out.isEmpty ? [Segment(id: 0, isCode: false, language: "", text: raw)] : out
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
            } else {
                // Sleek AI avatar badge
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accent.highlight.opacity(0.32), accent.highlight.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(Circle().strokeBorder(accent.highlight.opacity(0.42), lineWidth: 0.8))
                    Image(systemName: "sparkles")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(accent.highlight)
                }
                .frame(width: 22, height: 22)
                .padding(.top, 2)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
                if let attachments = message.attachments, !attachments.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(attachments, id: \.self) { a in
                            Label(a, systemImage: "paperclip")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.white.opacity(0.08)))
                        }
                    }
                }

                if let images = message.images, !images.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, b64 in
                            if let img = Data(base64Encoded: b64).flatMap(NSImage.init(data:)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 96, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(.white.opacity(0.15), lineWidth: 0.75)
                                    )
                            }
                        }
                    }
                }

                // Main Bubble Card
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(segments) { seg in
                        if seg.isCode {
                            codeBlockCard(seg)
                        } else {
                            let isLast = seg.id == segments.last?.id
                            (Text(renderMarkdown(seg.text)) + Text(isStreaming && isLast ? " ▋" : "").foregroundColor(accent.highlight))
                                .font(.system(size: 12, weight: .regular))
                                .lineSpacing(2.5)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8.5)
                .background {
                    let shape = UnevenRoundedRectangle(
                        topLeadingRadius: isUser ? 15 : 6,
                        bottomLeadingRadius: 15,
                        bottomTrailingRadius: isUser ? 6 : 15,
                        topTrailingRadius: 15,
                        style: .continuous
                    )
                    if isUser {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [accent.highlight.opacity(0.38), accent.highlight.opacity(0.22)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(shape.strokeBorder(accent.highlight.opacity(0.38), lineWidth: 0.75))
                    } else {
                        shape
                            .fill(Color.white.opacity(0.065))
                            .overlay(
                                shape.strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.16), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                            )
                    }
                }
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)

                // Applied AI Action Chips (e.g. Custom Theme / Animation / Setting changed)
                if !changes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(changes) { c in
                            HStack(spacing: 6) {
                                Image(systemName: undone.contains(c.id) ? "arrow.uturn.backward.circle" : "wand.and.stars")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(undone.contains(c.id) ? Color.secondary : Color.green)
                                Text(c.label)
                                    .strikethrough(undone.contains(c.id))
                                    .foregroundStyle(undone.contains(c.id) ? Color.secondary : Color.white.opacity(0.92))
                                    .lineLimit(1)
                                if c.undo != nil && !undone.contains(c.id) {
                                    Spacer(minLength: 4)
                                    Button("Undo") {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                            NotchiBrain.undo(c)
                                            undone.insert(c.id)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(accent.highlight)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(accent.highlight.opacity(0.15)))
                                }
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.green.opacity(0.09))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.green.opacity(0.26), lineWidth: 0.8)
                            )
                    )
                }

                // Assistant Hover Action Bar
                if !isUser && !isStreaming {
                    HStack(spacing: 8) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            copied = true
                            Task { try? await Task.sleep(for: .seconds(1.2)); copied = false }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(.white.opacity(hovering ? 0.08 : 0.04)))
                        }
                        if canRegenerate {
                            Button(action: onRegenerate) {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2.5)
                                    .background(Capsule().fill(.white.opacity(hovering ? 0.08 : 0.04)))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(hovering || canRegenerate ? 1 : 0)
                }
            }

            if !isUser { Spacer(minLength: 42) }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.14)) { hovering = h } }
    }

    private func codeBlockCard(_ seg: Segment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(seg.language.isEmpty ? "code" : seg.language.lowercased())
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(seg.text, forType: .string)
                    copiedBlockIdx = seg.id
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        if copiedBlockIdx == seg.id { copiedBlockIdx = nil }
                    }
                } label: {
                    Label(copiedBlockIdx == seg.id ? "Copied" : "Copy", systemImage: copiedBlockIdx == seg.id ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(copiedBlockIdx == seg.id ? .green : .white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.05))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(seg.text)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(red: 0.88, green: 0.94, blue: 1.0))
                    .textSelection(.enabled)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
            }
        }
        .background(Color.black.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
        )
    }

    private func renderMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// Three dots pulsing smoothly while waiting for the first token.
struct TypingIndicator: View {
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.22))
                    .overlay(Circle().strokeBorder(tint.opacity(0.4), lineWidth: 0.8))
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 22, height: 22)

            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 4.5) {
                    ForEach(0..<3) { i in
                        let wave = max(0, sin((t * 6.2) - Double(i) * 0.75))
                        Circle()
                            .fill(tint)
                            .frame(width: 5.5, height: 5.5)
                            .offset(y: -3.2 * wave)
                            .opacity(0.4 + 0.6 * wave)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.065))
                        .overlay(
                            UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                        )
                )
            }
        }
        .accessibilityLabel("Thinking")
    }
}
