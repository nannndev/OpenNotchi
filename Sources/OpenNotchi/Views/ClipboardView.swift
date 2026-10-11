import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardMonitor
    @State private var query = ""
    @State private var copiedID: UUID?

    private var filtered: [ClipboardItem] {
        guard !query.isEmpty else { return clipboard.items }
        return clipboard.items.filter { $0.text?.localizedCaseInsensitiveContains(query) ?? false }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search clipboard", text: $query)
                        .textFieldStyle(.plain)
                }
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))

                if !clipboard.items.isEmpty {
                    Button("Clear") { clipboard.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 22))
                    Text(query.isEmpty ? "Copied items will show up here" : "No matches")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { item in
                            ClipboardRow(item: item, isCopied: copiedID == item.id) {
                                clipboard.copy(item)
                                copiedID = item.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    if copiedID == item.id { copiedID = nil }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ClipboardRow: View {
    @EnvironmentObject private var clipboard: ClipboardMonitor
    let item: ClipboardItem
    let isCopied: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                switch item.content {
                case .text(let text):
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        .lineLimit(1)
                        .truncationMode(.tail)
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("Image")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isCopied {
                    Label("Copied", systemImage: "checkmark")
                        .foregroundStyle(.green)
                } else if hovering {
                    Button { clipboard.remove(item) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                } else if item.date != .distantPast {
                    Text(item.date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(hovering ? 0.1 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
