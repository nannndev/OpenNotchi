import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case features = "Features"
    case media = "Media"
    case mirror = "Mirror"
    case smarthome = "Smarthome"
    case ai = "AI"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .features: return "square.grid.2x2.fill"
        case .media: return "music.note"
        case .mirror: return "camera.fill"
        case .smarthome: return "air.conditioner.horizontal.fill"
        case .ai: return "sparkles"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .pink
        case .features: return .blue
        case .media: return .red
        case .mirror: return .teal
        case .smarthome: return .green
        case .ai: return .purple
        case .about: return .indigo
        }
    }
}

struct SettingsView: View {
    @AppStorage("settingsPane") private var pane: SettingsPane = .general
    @State private var searchText = ""

    private var filteredItems: [SettingItem] {
        guard !searchText.isEmpty else { return [] }
        return SettingItem.all.filter { $0.matches(searchText) }
    }

    private var matchingPanes: [SettingsPane] {
        guard !searchText.isEmpty else { return SettingsPane.allCases }
        let matched = Set(filteredItems.map(\.pane))
        return SettingsPane.allCases.filter { matched.contains($0) }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11, weight: .semibold))
                    TextField("Search settings…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)

                List(selection: $pane) {
                    ForEach(matchingPanes) { item in
                        let matchCount = filteredItems.filter { $0.pane == item }.count
                        HStack {
                            Label {
                                Text(item.rawValue)
                            } icon: {
                                Image(systemName: item.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(item.tint.gradient))
                            }
                            Spacer()
                            if !searchText.isEmpty && matchCount > 0 {
                                Text("\(matchCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.primary.opacity(0.1)))
                            }
                        }
                        .padding(.vertical, 2)
                        .tag(item)
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(width: 200)

            Divider()

            VStack(spacing: 0) {
                if !searchText.isEmpty && !filteredItems.isEmpty {
                    // Quick Search Highlights Banner
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Matches:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(filteredItems) { item in
                                Button {
                                    pane = item.pane
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: item.icon ?? item.pane.icon)
                                            .font(.system(size: 9))
                                        Text(item.title)
                                            .font(.system(size: 11, weight: pane == item.pane ? .bold : .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3.5)
                                    .background(
                                        Capsule().fill(
                                            pane == item.pane
                                                ? item.pane.tint.opacity(0.25) : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(pane == item.pane ? item.pane.tint : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .background(Color.primary.opacity(0.03))
                    Divider()
                } else if !searchText.isEmpty && filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No settings found for \"\(searchText)\"")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Button("Clear Search") { searchText = "" }
                            .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if searchText.isEmpty || !filteredItems.isEmpty {
                    Group {
                        switch pane {
                        case .general: GeneralPane()
                        case .appearance: AppearancePane()
                        case .features: FeaturesPane()
                        case .media: MediaPane()
                        case .mirror: MirrorPane()
                        case .smarthome: SmarthomePane()
                        case .ai: AISettingsPane()
                        case .about: AboutPane()
                        }
                    }
                    .formStyle(.grouped)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(width: 720, height: 580)
    }
}
