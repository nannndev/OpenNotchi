import SwiftUI

/// Message list and the suggestion chips shown on an empty chat.
extension AskSection {
    var conversation: some View {
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
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(
                                    with: .scale(
                                        scale: 0.96, anchor: m.role == "user" ? .bottomTrailing : .bottomLeading)),
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

    var suggestions: some View {
        VStack(spacing: 8) {
            Text("What can I help with?")
                .font(.system(size: 13, weight: .bold))
            HStack(spacing: 6) {
                ForEach(QuickAction.allCases) { action in
                    Button {
                        quick(action)
                    } label: {
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
                suggestion("Make my notch look nicer", icon: "paintpalette") {
                    send("Make my notch look nicer. Pick a theme, accent and animation that go well together.")
                }
                suggestion("What can Notchi do?", icon: "questionmark.circle") {
                    send("What can OpenNotchi do? Give me a quick tour.")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .transition(.opacity)
    }

    func suggestion(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent.highlight)
        }
        .buttonStyle(.plain)
    }
}
