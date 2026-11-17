import SwiftUI

struct SearchableDropdownOption: Identifiable {
    let id: String
    let title: String
    var subtitle: String? = nil
    var badgeText: String? = nil
    var badgeColor: Color = .secondary
    var icon: AnyView? = nil
}

/// Reusable searchable popover dropdown for long option lists across OpenNotchi modules.
struct SearchableDropdown: View {
    let options: [SearchableDropdownOption]
    let selectedId: String
    var placeholder: String = "Search…"
    var width: CGFloat = 310
    var maxHeight: CGFloat = 280
    var compact: Bool = false
    let onSelect: (String) -> Void

    @State private var open = false
    @State private var query = ""
    @State private var hoveredId: String?
    @State private var lockedNotch = false

    private var current: SearchableDropdownOption? {
        options.first { $0.id == selectedId } ?? options.first
    }

    private var filtered: [SearchableDropdownOption] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return options }
        return options.filter {
            $0.title.lowercased().contains(q)
                || $0.id.lowercased().contains(q)
                || ($0.subtitle?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        Button {
            query = ""
            open.toggle()
        } label: {
            HStack(spacing: compact ? 5 : 8) {
                if let cur = current {
                    if let icon = cur.icon {
                        icon
                    }
                    Text(cur.title)
                        .font(.system(size: compact ? 11 : 12, weight: .semibold))
                        .lineLimit(1)
                    if !compact, let badge = cur.badgeText {
                        badgePill(badge, color: cur.badgeColor)
                    }
                }
                if !compact { Spacer() }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4.5 : 6.5)
            .background(
                RoundedRectangle(cornerRadius: compact ? 7 : 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 7 : 8)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onChange(of: open) { _, isOpen in
            if isOpen && !lockedNotch {
                lockedNotch = true
                NotchViewModel.activePopoverCount += 1
            } else if !isOpen && lockedNotch {
                lockedNotch = false
                NotchViewModel.activePopoverCount = max(0, NotchViewModel.activePopoverCount - 1)
            }
        }
        .onDisappear {
            if lockedNotch {
                lockedNotch = false
                NotchViewModel.activePopoverCount = max(0, NotchViewModel.activePopoverCount - 1)
            }
        }
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(placeholder, text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))

                Divider()

                ScrollView {
                    LazyVStack(spacing: 2) {
                        if filtered.isEmpty {
                            Text("No matches")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(filtered) { item in
                                let isSelected = item.id == selectedId
                                let isHovered = hoveredId == item.id
                                Button {
                                    onSelect(item.id)
                                    open = false
                                } label: {
                                    HStack(spacing: 8) {
                                        if let icon = item.icon {
                                            icon
                                        }
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.title)
                                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                                                .lineLimit(1)
                                            if let sub = item.subtitle, !sub.isEmpty {
                                                Text(sub)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        if let badge = item.badgeText {
                                            badgePill(badge, color: item.badgeColor)
                                        }
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10.5, weight: .bold))
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(isSelected ? Color.accentColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    hoveredId = hovering ? item.id : (hoveredId == item.id ? nil : hoveredId)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: maxHeight)
            }
            .frame(width: width)
        }
    }

    private func badgePill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}
