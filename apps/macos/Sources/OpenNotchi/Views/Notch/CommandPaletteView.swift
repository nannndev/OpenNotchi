import AppKit
import SwiftUI

/// Quick command palette (`⌘K`) inside the open notch for switching tabs,
/// running AI / Gateway actions, controlling media & audio, and developer tools.
struct CommandPaletteView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var timer: TimerManager
    @EnvironmentObject private var audio: AudioDeviceManager
    @EnvironmentObject private var ports: PortInspector
    @EnvironmentObject private var aiUsage: AIUsageManager
    @Environment(\.notchAccent) private var accent

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool

    private struct CommandItem: Identifiable {
        let id: String
        let category: String
        let title: String
        let subtitle: String?
        let icon: String
        let tint: Color
        let badge: String?
        let keywords: [String]
        let run: () -> Void
    }

    private var allItems: [CommandItem] {
        var items: [CommandItem] = []
        let visible = settings.visibleTabs

        // 1. Tabs (every NotchTab, with ⌘1..⌘9 badges for visible ones)
        for tab in NotchTab.allCases {
            let enabled = settings.isTabEnabled(tab)
            let shortcut: String? = visible.firstIndex(of: tab).flatMap { $0 < 9 ? "⌘\($0 + 1)" : nil }
            items.append(CommandItem(
                id: "tab.\(tab.rawValue)",
                category: "Tabs",
                title: tab.rawValue,
                subtitle: enabled ? "Switch to \(tab.rawValue)" : "Enable & open \(tab.rawValue)",
                icon: tab.icon,
                tint: accent.highlight,
                badge: shortcut ?? (enabled ? nil : "Enable"),
                keywords: ["tab", "open", "switch", tab.rawValue.lowercased()],
                run: {
                    if !enabled { settings.setTabEnabled(tab, true) }
                    vm.selectTab(tab)
                }
            ))
        }

        // 2. AI & eay-gateway
        items.append(contentsOf: [
            CommandItem(
                id: "ai.ask",
                category: "AI & Gateway",
                title: "Ask AI…",
                subtitle: "Open Notchi assistant chat",
                icon: "sparkles",
                tint: .cyan,
                badge: nil,
                keywords: ["ai", "ask", "chat", "prompt", "notchi"],
                run: { openAISection("Ask") }
            ),
            CommandItem(
                id: "ai.usage",
                category: "AI & Gateway",
                title: "AI Quota & Accounts",
                subtitle: "Inspect connected accounts & live quotas",
                icon: "chart.bar.xaxis",
                tint: .green,
                badge: nil,
                keywords: ["ai", "quota", "accounts", "usage", "limits"],
                run: { openAISection("Quota & Accounts") }
            ),
            CommandItem(
                id: "ai.analytics",
                category: "AI & Gateway",
                title: "AI Analytics & Cost",
                subtitle: "Token breakdown, cache hits & recent requests",
                icon: "chart.xyaxis.line",
                tint: .purple,
                badge: nil,
                keywords: ["ai", "analytics", "cost", "tokens", "cached", "history"],
                run: { openAISection("Analytics") }
            ),
            CommandItem(
                id: "gw.refresh",
                category: "AI & Gateway",
                title: "Refresh Gateway Quotas",
                subtitle: "Force-sync live provider & account quotas",
                icon: "arrow.clockwise",
                tint: .green,
                badge: nil,
                keywords: ["gateway", "refresh", "quota", "sync"],
                run: { aiUsage.refresh(force: true) }
            ),
            CommandItem(
                id: "gw.round_robin",
                category: "AI & Gateway",
                title: "Gateway Routing: Round-Robin",
                subtitle: "Distribute requests evenly across active accounts",
                icon: "arrow.triangle.2.circlepath",
                tint: .blue,
                badge: nil,
                keywords: ["gateway", "routing", "round robin", "strategy"],
                run: { Task { try? await NotchiGatewayService.shared.updateRouting(["routing_strategy": "round_robin"]) } }
            ),
            CommandItem(
                id: "gw.fill_first",
                category: "AI & Gateway",
                title: "Gateway Routing: Fill-First",
                subtitle: "Use primary account in priority order before falling back",
                icon: "arrow.down.to.line",
                tint: .orange,
                badge: nil,
                keywords: ["gateway", "routing", "fill first", "priority", "strategy"],
                run: { Task { try? await NotchiGatewayService.shared.updateRouting(["routing_strategy": "fill_first"]) } }
            ),
            CommandItem(
                id: "gw.copy_url",
                category: "AI & Gateway",
                title: "Copy Gateway Endpoint URL",
                subtitle: NotchiGatewayService.v1BaseURL,
                icon: "doc.on.doc",
                tint: .secondary,
                badge: "v1",
                keywords: ["gateway", "copy", "endpoint", "url", "openai", "20129"],
                run: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(NotchiGatewayService.v1BaseURL, forType: .string)
                }
            ),
        ])

        // 3. Media & Audio
        items.append(contentsOf: [
            CommandItem(
                id: "media.playpause",
                category: "Media & Audio",
                title: (media.info?.isPlaying ?? false) ? "Pause Music" : "Play Music",
                subtitle: media.info.map { "\($0.title) · \($0.artist)" } ?? "Toggle playback",
                icon: (media.info?.isPlaying ?? false) ? "pause.fill" : "play.fill",
                tint: .pink,
                badge: nil,
                keywords: ["music", "play", "pause", "spotify", "media"],
                run: { media.playPause() }
            ),
            CommandItem(
                id: "media.next",
                category: "Media & Audio",
                title: "Next Track",
                subtitle: nil,
                icon: "forward.fill",
                tint: .pink,
                badge: nil,
                keywords: ["music", "next", "skip", "track"],
                run: { media.nextTrack() }
            ),
            CommandItem(
                id: "media.previous",
                category: "Media & Audio",
                title: "Previous Track",
                subtitle: nil,
                icon: "backward.fill",
                tint: .pink,
                badge: nil,
                keywords: ["music", "previous", "back", "track"],
                run: { media.previousTrack() }
            ),
            CommandItem(
                id: "media.lyrics_overlay",
                category: "Media & Audio",
                title: "Toggle Desktop Lyrics",
                subtitle: settings.lyricsOverlayEnabled ? "Currently On" : "Currently Off",
                icon: "captions.bubble.fill",
                tint: .cyan,
                badge: settings.lyricsOverlayEnabled ? "On" : "Off",
                keywords: ["lyrics", "desktop", "overlay", "floating", "karaoke"],
                run: { settings.lyricsOverlayEnabled.toggle() }
            ),
        ])

        for device in audio.outputDevices {
            items.append(CommandItem(
                id: "audio.out.\(device.id)",
                category: "Media & Audio",
                title: "Audio Output: \(device.name)",
                subtitle: device.isDefaultOutput ? "Current default output" : "Switch system audio output",
                icon: device.icon,
                tint: .mint,
                badge: device.isDefaultOutput ? "Active" : nil,
                keywords: ["audio", "output", "speaker", "headphones", "sound", device.name.lowercased()],
                run: { audio.setOutputDevice(device.id) }
            ))
        }

        // 4. Developer & Tools
        items.append(contentsOf: [
            CommandItem(
                id: "dev.pomodoro",
                category: "Developer & Tools",
                title: "Start 25m Pomodoro Timer",
                subtitle: "Start a 25-minute focus countdown",
                icon: "timer",
                tint: .orange,
                badge: "25m",
                keywords: ["timer", "pomodoro", "focus", "25"],
                run: {
                    settings.timerTabEnabled = true
                    timer.reset()
                    timer.setDuration(minutes: 25)
                    timer.start()
                    vm.selectTab(.timer)
                }
            ),
            CommandItem(
                id: "dev.eyedropper",
                category: "Developer & Tools",
                title: "Pick Screen Color (Eyedropper)",
                subtitle: "Sample any pixel on screen as HEX / RGB / Swift",
                icon: "eyedropper",
                tint: .yellow,
                badge: nil,
                keywords: ["color", "picker", "eyedropper", "hex", "sample"],
                run: {
                    vm.isCommandPaletteOpen = false
                    ColorPickerManager.shared.sampleColor()
                }
            ),
        ])

        for port in ports.ports.filter(\.isDevServer).prefix(5) {
            items.append(CommandItem(
                id: "dev.kill.\(port.id)",
                category: "Developer & Tools",
                title: "Kill Port :\(port.port) (\(port.command))",
                subtitle: "Terminate PID \(port.pid) at \(port.address)",
                icon: "xmark.octagon.fill",
                tint: .red,
                badge: ":\(port.port)",
                keywords: ["kill", "port", String(port.port), port.command.lowercased(), "server"],
                run: { ports.killPortProcess(port) }
            ))
        }

        // 5. Appearance
        for theme in NotchTheme.allCases {
            items.append(CommandItem(
                id: "theme.\(theme.rawValue)",
                category: "Appearance",
                title: "Theme: \(theme.displayName)",
                subtitle: nil,
                icon: "paintbrush.fill",
                tint: .purple,
                badge: settings.theme == theme ? "Active" : nil,
                keywords: ["theme", "appearance", "look", theme.displayName.lowercased()],
                run: { settings.theme = theme }
            ))
        }

        return items
    }

    private var filteredItems: [CommandItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allItems }
        return allItems.filter { item in
            item.title.lowercased().contains(q)
                || item.category.lowercased().contains(q)
                || (item.subtitle?.lowercased().contains(q) ?? false)
                || item.keywords.contains(where: { $0.contains(q) })
        }
    }

    private func searchHeader(list: [CommandItem]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent.highlight)
            TextField("Type a command, tab, theme, or port…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($isSearchFocused)
                .onSubmit { runHighlighted(in: list) }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button {
                close()
            } label: {
                Text("ESC")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    }

    private func row(_ item: CommandItem, selected isSelected: Bool) -> some View {
        Button {
            execute(item)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(item.tint)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6).fill(item.tint.opacity(0.15)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let sub = item.subtitle {
                        Text(sub)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(badge == "Active" ? .green : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(badge == "Active" ? Color.green.opacity(0.16) : Color.white.opacity(0.08))
                        )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .id(item.id)
    }

    var body: some View {
        let list = filteredItems

        ZStack {
            Color.black.opacity(0.45)
                .contentShape(Rectangle())
                .onTapGesture { close() }

            VStack(spacing: 0) {
                searchHeader(list: list)

                Divider().overlay(Color.white.opacity(0.1))

                if list.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("No matching commands")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(list.enumerated()), id: \.element.id) { idx, item in
                                    if idx == 0 || list[idx - 1].category != item.category {
                                        Text(item.category)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)
                                            .padding(.horizontal, 10)
                                            .padding(.top, idx == 0 ? 4 : 8)
                                            .padding(.bottom, 2)
                                    }

                                    row(item, selected: idx == min(selectedIndex, list.count - 1))
                                            .onHover { hovering in
                                            if hovering { selectedIndex = idx }
                                        }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }
                        .onChange(of: selectedIndex) { _, idx in
                            if idx < list.count {
                                withAnimation(.easeOut(duration: 0.12)) {
                                    proxy.scrollTo(list[idx].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 520, maxHeight: 245)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 20, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .onKeyPress(.upArrow) {
            guard !list.isEmpty else { return .ignored }
            selectedIndex = (selectedIndex - 1 + list.count) % list.count
            return .handled
        }
        .onKeyPress(.downArrow) {
            guard !list.isEmpty else { return .ignored }
            selectedIndex = (selectedIndex + 1) % list.count
            return .handled
        }
        .onKeyPress(.return) {
            runHighlighted(in: list)
            return .handled
        }
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onAppear {
            selectedIndex = 0
            ports.refresh()
            DispatchQueue.main.async {
                AppDelegate.shared?.screenManager?.activeController?.panel.makeKeyAndOrderFront(nil)
                isSearchFocused = true
            }
        }
    }

    private func openAISection(_ rawSection: String) {
        settings.aiEnabled = true
        UserDefaults.standard.set(rawSection, forKey: "aiSection")
        vm.selectTab(.ai)
    }

    private func runHighlighted(in list: [CommandItem]) {
        guard !list.isEmpty else { return }
        let idx = min(max(0, selectedIndex), list.count - 1)
        execute(list[idx])
    }

    private func execute(_ item: CommandItem) {
        close()
        item.run()
    }

    private func close() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
            vm.isCommandPaletteOpen = false
        }
    }
}
