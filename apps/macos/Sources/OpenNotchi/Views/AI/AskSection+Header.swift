import SwiftUI

/// Top bar: provider/model picker and chat sessions.
extension AskSection {
    var header: some View {
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
}
