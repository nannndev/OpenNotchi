import SwiftUI

enum DevViewMode: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case ports = "Ports"
    case ci = "CI / Builds"
    case system = "System"
    case tools = "Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .ports: return "network"
        case .ci: return "checkmark.seal.fill"
        case .system: return "speedometer"
        case .tools: return "hammer"
        }
    }
}

struct DevToolsView: View {
    @EnvironmentObject private var portInspector: PortInspector
    @EnvironmentObject private var colorPicker: ColorPickerManager
    @EnvironmentObject private var audioDevice: AudioDeviceManager
    @EnvironmentObject private var stats: SystemStatsManager
    @EnvironmentObject private var ciMonitor: CIBuildMonitor
    @Environment(\.notchAccent) private var accent

    @AppStorage("devViewMode") private var selectedMode: DevViewMode = .overview
    @AppStorage("devShowPorts") private var showPorts: Bool = true
    @AppStorage("devShowStats") private var showStats: Bool = true
    @AppStorage("devShowTools") private var showTools: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            // Mode Selector & Customization Header Bar
            HStack(spacing: 6) {
                // Segmented view mode pills
                HStack(spacing: 2) {
                    ForEach(DevViewMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                selectedMode = mode
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 9, weight: .semibold))
                                Text(mode.rawValue)
                                    .font(.system(size: 10, weight: selectedMode == mode ? .semibold : .medium))
                                    .fixedSize()

                                if mode == .ports && !portInspector.filteredPorts.isEmpty {
                                    Text("\(portInspector.filteredPorts.count)")
                                        .font(.system(size: 8, weight: .bold).monospacedDigit())
                                        .padding(.horizontal, 3.5)
                                        .padding(.vertical, 0.5)
                                        .background(Capsule().fill(.white.opacity(0.2)))
                                } else if mode == .ci && ciMonitor.hasActiveBuild {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 5, height: 5)
                                }
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(selectedMode == mode ? accent.color.opacity(0.35) : .white.opacity(0.06))
                            )
                            .foregroundStyle(selectedMode == mode ? accent.highlight : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 4)

                // Customize Menu (Visible Widgets in Overview)
                Menu {
                    Section("Visible in Overview") {
                        Toggle("Localhost Ports", isOn: $showPorts)
                        Toggle("System & Network Stats", isOn: $showStats)
                        Toggle("Quick Tools (Color & Mic)", isOn: $showTools)
                    }
                    Divider()
                    Button("Reset Overview Layout") {
                        showPorts = true
                        showStats = true
                        showTools = true
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9))
                        Text("Customize")
                            .font(.system(size: 9, weight: .medium))
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.08)))
                    .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Customize Dev tab widgets")
            }
            .padding(.horizontal, 2)

            // Content Area
            Group {
                switch selectedMode {
                case .overview:
                    overviewView
                case .ports:
                    FullPortsView()
                case .ci:
                    FullCIBuildsView()
                case .system:
                    FullSystemView()
                case .tools:
                    FullToolsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 1)
        .task {
            // Wait for the tab to settle: swiping past Dev shouldn't each time start port scans, CoreAudio
            // queries and `gh`/`ps` processes. A cancelled task (tab left) skips them.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            portInspector.startAutoRefresh()
            audioDevice.refreshDevices()
            stats.start()
            ciMonitor.refresh()
            ciMonitor.scanLocalBuilds()
        }
        .onDisappear {
            portInspector.stopAutoRefresh()
        }
    }

    @ViewBuilder
    private var overviewView: some View {
        if showPorts && (showStats || showTools) {
            // Balanced 2-Column Split: Left 235pt, Right expands to ~370pt (NO squished text!)
            HStack(spacing: 8) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        if showTools {
                            ColorPickerCard()
                            AudioControlsCard()
                        }
                        if showStats {
                            SystemStatsCard()
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(width: 235)

                PortInspectorCard()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if showPorts && !showStats && !showTools {
            PortInspectorCard()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !showPorts && (showStats || showTools) {
            HStack(spacing: 8) {
                if showTools {
                    VStack(spacing: 6) {
                        ColorPickerCard()
                        AudioControlsCard()
                    }
                    .frame(maxWidth: .infinity)
                }
                if showStats {
                    SystemStatsCard()
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                Text("All widgets hidden in Overview")
                    .font(.system(size: 11, weight: .semibold))
                Text("Use 'Customize' above to choose widgets to show.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Button("Enable All") {
                    showPorts = true
                    showStats = true
                    showTools = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
