import AppKit
import SwiftUI

enum DevViewMode: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case ports = "Ports"
    case system = "System"
    case tools = "Tools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .ports: return "network"
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
                case .system:
                    FullSystemView()
                case .tools:
                    FullToolsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 1)
        .onAppear {
            portInspector.startAutoRefresh()
            audioDevice.refreshDevices()
            stats.start()
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

// MARK: - Color Picker Card

private struct ColorPickerCard: View {
    @EnvironmentObject private var colorPicker: ColorPickerManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Color Eyedropper", systemImage: "eyedropper.halffull")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    colorPicker.sampleColor()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 9, weight: .bold))
                        Text("Pick")
                            .font(.system(size: 9, weight: .semibold))
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .help("Pick a color from anywhere on screen")
            }

            if let current = colorPicker.currentColor {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(current.color)
                        .frame(width: 24, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: current.color.opacity(0.3), radius: 3)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(current.hex)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text(current.rgb)
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 2)

                    Menu {
                        Button("Copy HEX (\(current.hex))") {
                            colorPicker.copyFormat(current, format: .hex)
                        }
                        Button("Copy RGB (\(current.rgb))") {
                            colorPicker.copyFormat(current, format: .rgb)
                        }
                        Button("Copy HSL (\(current.hsl))") {
                            colorPicker.copyFormat(current, format: .hsl)
                        }
                        Button("Copy Swift Snippet") {
                            colorPicker.copyFormat(current, format: .swift)
                        }
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Copy color in different formats")
                }

                if !colorPicker.recentColors.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(colorPicker.recentColors.prefix(6)) { item in
                            Button {
                                colorPicker.copyFormat(item, format: .hex)
                            } label: {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Copy \(item.hex)")
                        }
                    }
                    .padding(.top, 1)
                }
            } else {
                Button {
                    colorPicker.sampleColor()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 9))
                        Text("Click to pick pixel color")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
            }

            if let feedback = colorPicker.copiedFeedback {
                Text(feedback)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)))
    }
}

// MARK: - Audio & Mic Controls Card

private struct AudioControlsCard: View {
    @EnvironmentObject private var audioDevice: AudioDeviceManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Audio & Mic Control", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            // Mic Mute Toggle Button
            Button {
                audioDevice.toggleInputMute()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: audioDevice.isMicMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(audioDevice.isMicMuted ? .white : .green)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle().fill(audioDevice.isMicMuted ? Color.red.opacity(0.85) : Color.green.opacity(0.18))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(audioDevice.isMicMuted ? "Microphone Muted" : "Microphone Live")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(audioDevice.isMicMuted ? .red : .primary)
                            .lineLimit(1)
                        Text(audioDevice.defaultInputName)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    Image(systemName: audioDevice.isMicMuted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 10))
                        .foregroundStyle(audioDevice.isMicMuted ? .red : .secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .help(audioDevice.isMicMuted ? "Click to Unmute Microphone" : "Click to Mute Microphone")

            // Audio Output Device Selector Menu
            Menu {
                ForEach(audioDevice.outputDevices) { device in
                    Button {
                        audioDevice.setOutputDevice(device.id)
                    } label: {
                        HStack {
                            Image(systemName: device.icon)
                            Text(device.name)
                            if device.isDefaultOutput {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: outputDeviceIcon(name: audioDevice.defaultOutputName))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(accent.highlight)

                    Text(audioDevice.defaultOutputName)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Switch Audio Output Device")

            // Microphone Input Device Selector Menu
            Menu {
                ForEach(audioDevice.inputDevices) { device in
                    Button {
                        audioDevice.setInputDevice(device.id)
                    } label: {
                        HStack {
                            Image(systemName: device.icon)
                            Text(device.name)
                            if device.isDefaultInput {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: inputDeviceIcon(name: audioDevice.defaultInputName))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(audioDevice.isMicMuted ? .red : .green)

                    Text(audioDevice.defaultInputName)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.05)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Switch Microphone Input Device")
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)))
    }

    private func outputDeviceIcon(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") { return "airpodspro" }
        if lower.contains("headphone") { return "headphones" }
        if lower.contains("display") || lower.contains("hdmi") { return "display" }
        if lower.contains("macbook") || lower.contains("speaker") { return "laptopcomputer" }
        return "hifispeaker.fill"
    }

    private func inputDeviceIcon(name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpod") { return "airpodspro" }
        if lower.contains("iphone") { return "iphone" }
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("headphone") || lower.contains("headset") { return "headphones" }
        return "mic.fill"
    }
}

// MARK: - Port Inspector Card (Used in Overview and Dedicated)

private struct PortInspectorCard: View {
    @EnvironmentObject private var portInspector: PortInspector
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(spacing: 6) {
            // Toolbar: Clean 1-line toolbar that never wraps
            HStack(spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(accent.highlight)
                    Text("Localhost Ports")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                    Text("(\(portInspector.filteredPorts.count))")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                Spacer(minLength: 4)

                // Dev Filter Toggle
                Button {
                    portInspector.filterDevOnly.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: portInspector.filterDevOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 9))
                        Text(portInspector.filterDevOnly ? "Dev Only" : "All Ports")
                            .font(.system(size: 9, weight: .medium))
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(portInspector.filterDevOnly ? accent.color.opacity(0.3) : .white.opacity(0.1)))
                    .foregroundStyle(portInspector.filterDevOnly ? accent.highlight : .secondary)
                }
                .buttonStyle(.plain)

                // Search mini field
                HStack(spacing: 3) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    TextField("Port/PID", text: $portInspector.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .frame(width: 58)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)))

                // Refresh Button
                Button {
                    portInspector.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(portInspector.isLoading ? 360 : 0))
                        .animation(portInspector.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: portInspector.isLoading)
                        .padding(4)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Refresh active ports")
            }

            // Ports List
            if portInspector.filteredPorts.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                    Text(portInspector.isLoading ? "Scanning local ports…" : "No listening servers detected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(portInspector.filteredPorts) { port in
                            PortRow(port: port)
                        }
                    }
                }
            }

            // Status feedback banner
            if let status = portInspector.statusMessage {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 9))
                    Text(status)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
    }
}

private struct PortRow: View {
    @EnvironmentObject private var portInspector: PortInspector
    @Environment(\.notchAccent) private var accent
    let port: ListeningPort
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Port badge
            Text(":\(port.port)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(port.isDevServer ? accent.highlight : .primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(port.isDevServer ? accent.color.opacity(0.25) : .white.opacity(0.12))
                )
                .fixedSize()

            // Command / PID
            HStack(spacing: 4) {
                Image(systemName: port.icon)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                Text(port.command)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)

                Text("PID \(port.pid)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            Spacer(minLength: 4)

            // Quick Actions: Open & Kill
            HStack(spacing: 5) {
                Button {
                    portInspector.openPort(port)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 10))
                        Text("Open")
                            .font(.system(size: 9, weight: .semibold))
                            .fixedSize()
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(.blue.opacity(0.25)))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help("Open http://localhost:\(port.port)")

                Button {
                    portInspector.killPortProcess(port)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(hovering ? .red : .secondary)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(.white.opacity(hovering ? 0.2 : 0.08)))
                }
                .buttonStyle(.plain)
                .help("Kill PID \(port.pid)")
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(hovering ? 0.08 : 0.03))
        )
        .onHover { hovering = $0 }
    }
}

// MARK: - System Stats & Network Speedometer Card

private struct SystemStatsCard: View {
    @EnvironmentObject private var stats: SystemStatsManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent.highlight)
                Text("Network & Stats")
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                Spacer()
            }

            // Network Speeds
            HStack(spacing: 5) {
                // Download Speed
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Down")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(stats.formattedDown)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .fixedSize()
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.04)))

                // Upload Speed
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                    Text("Up")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(stats.formattedUp)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .fixedSize()
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.04)))
            }

            // CPU & RAM Usage
            HStack(spacing: 6) {
                // CPU
                VStack(spacing: 2) {
                    HStack {
                        Text("CPU")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stats.formattedCPU)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(stats.cpuUsage > 0.75 ? Color.orange : accent.color)
                                .frame(width: geo.size.width * CGFloat(min(max(stats.cpuUsage, 0), 1)))
                        }
                    }
                    .frame(height: 3)
                }

                // RAM
                VStack(spacing: 2) {
                    HStack {
                        Text("RAM")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stats.formattedRAM)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.12))
                            Capsule().fill(stats.ramUsage > 0.85 ? Color.red : Color.indigo)
                                .frame(width: geo.size.width * CGFloat(min(max(stats.ramUsage, 0), 1)))
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)))
    }
}

// MARK: - Full Views (Dedicated Modes)

private struct FullPortsView: View {
    @EnvironmentObject private var portInspector: PortInspector
    @Environment(\.notchAccent) private var accent

    var body: some View {
        VStack(spacing: 6) {
            // Expansive Toolbar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "network")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent.highlight)
                    Text("Localhost Port Inspector")
                        .font(.system(size: 13, weight: .bold))
                    Text("(\(portInspector.filteredPorts.count) active)")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Dev Filter Toggle
                Button {
                    portInspector.filterDevOnly.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: portInspector.filterDevOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 10))
                        Text(portInspector.filterDevOnly ? "Dev Servers Only" : "All Listening Ports")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(portInspector.filterDevOnly ? accent.color.opacity(0.3) : .white.opacity(0.1)))
                    .foregroundStyle(portInspector.filterDevOnly ? accent.highlight : .secondary)
                }
                .buttonStyle(.plain)

                // Search Bar
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    TextField("Filter by port, PID, node, python…", text: $portInspector.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .frame(width: 130)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.08)))

                // Refresh Button
                Button {
                    portInspector.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(portInspector.isLoading ? 360 : 0))
                        .animation(portInspector.isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: portInspector.isLoading)
                        .padding(5)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Refresh active ports")
            }
            .padding(.horizontal, 2)

            // Table / List
            if portInspector.filteredPorts.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                    Text(portInspector.isLoading ? "Scanning local ports…" : "No listening servers detected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(portInspector.filteredPorts) { port in
                            FullPortRow(port: port)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
    }
}

private struct FullPortRow: View {
    @EnvironmentObject private var portInspector: PortInspector
    @Environment(\.notchAccent) private var accent
    let port: ListeningPort
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Port badge
            Text(":\(port.port)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(port.isDevServer ? accent.highlight : .primary)
                .frame(width: 60, alignment: .leading)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(port.isDevServer ? accent.color.opacity(0.25) : .white.opacity(0.12))
                )

            // Process info & badge
            HStack(spacing: 6) {
                Image(systemName: port.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(port.command)
                    .font(.system(size: 12, weight: .semibold))

                Text("PID \(port.pid)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                if port.isDevServer {
                    Text("DEV SERVER")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(accent.highlight)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(accent.color.opacity(0.2)))
                }
            }

            Spacer()

            // Localhost URL preview
            Text("http://localhost:\(port.port)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Action Buttons
            HStack(spacing: 6) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("http://localhost:\(port.port)", forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Copy URL")

                Button {
                    portInspector.openPort(port)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 10))
                        Text("Open Browser")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(.blue.opacity(0.25)))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button {
                    portInspector.killPortProcess(port)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                        Text("Kill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(hovering ? Color.red.opacity(0.3) : .white.opacity(0.08)))
                    .foregroundStyle(hovering ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .help("Terminate process (PID \(port.pid))")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(hovering ? 0.08 : 0.03))
        )
        .onHover { hovering = $0 }
    }
}

private struct FullSystemView: View {
    @EnvironmentObject private var stats: SystemStatsManager
    @Environment(\.notchAccent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            // Left Card: Live Network Speedometer
            VStack(alignment: .leading, spacing: 8) {
                Label("Network Speedometer", systemImage: "network")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent.highlight)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)
                            Text("Download")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(stats.formattedDown)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.cyan)
                            Text("Upload")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text(stats.formattedUp)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)))
                }

                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 9))
                    Text("Wi-Fi / Network")
                        .font(.system(size: 10, design: .monospaced))
                    Spacer()
                    Text("Live Bandwidth Polling")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))

            // Right Card: Hardware CPU & RAM
            VStack(alignment: .leading, spacing: 8) {
                Label("Hardware Load", systemImage: "cpu")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent.highlight)

                VStack(spacing: 6) {
                    // CPU load
                    VStack(spacing: 3) {
                        HStack {
                            Text("CPU Usage")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(stats.formattedCPU)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12))
                                Capsule().fill(stats.cpuUsage > 0.75 ? Color.orange : accent.color)
                                    .frame(width: geo.size.width * CGFloat(min(max(stats.cpuUsage, 0), 1)))
                            }
                        }
                        .frame(height: 5)
                    }

                    // RAM allocation
                    VStack(spacing: 3) {
                        HStack {
                            Text("Memory (RAM)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(stats.formattedRAM) (\(String(format: "%.1f/%.1f GB", stats.ramUsedGB, stats.ramTotalGB)))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12))
                                Capsule().fill(stats.ramUsage > 0.85 ? Color.red : Color.indigo)
                                    .frame(width: geo.size.width * CGFloat(min(max(stats.ramUsage, 0), 1)))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
        }
    }
}

private struct FullToolsView: View {
    @EnvironmentObject private var colorPicker: ColorPickerManager
    @EnvironmentObject private var audioDevice: AudioDeviceManager
    @EnvironmentObject private var vm: NotchViewModel
    @Environment(\.notchAccent) private var accent

    var body: some View {
        HStack(spacing: 10) {
            // Left Card: Color Eyedropper Studio
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Eyedropper Studio", systemImage: "eyedropper.halffull")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent.highlight)
                    Spacer()
                    Button {
                        colorPicker.sampleColor()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.viewfinder")
                            Text("Pick Screen Color")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }

                if let current = colorPicker.currentColor {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(current.color)
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.2), lineWidth: 1))
                            .shadow(color: current.color.opacity(0.4), radius: 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(current.hex)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                            Text(current.rgb)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(current.hsl)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Button("Copy HEX") { colorPicker.copyFormat(current, format: .hex) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            Button("Copy RGB") { colorPicker.copyFormat(current, format: .rgb) }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                        }
                    }

                    if !colorPicker.recentColors.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(colorPicker.recentColors) { item in
                                    Button {
                                        colorPicker.copyFormat(item, format: .hex)
                                    } label: {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 16, height: 16)
                                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Copy \(item.hex)")
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("Click Pick Screen Color to sample any pixel")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))

            // Right Card: Audio & Microphone Hub
            VStack(alignment: .leading, spacing: 8) {
                Label("Audio & Microphone Hub", systemImage: "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(accent.highlight)

                // Mic Mute Live Button
                Button {
                    audioDevice.toggleInputMute()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: audioDevice.isMicMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(audioDevice.isMicMuted ? .white : .green)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(audioDevice.isMicMuted ? Color.red.opacity(0.85) : Color.green.opacity(0.2))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(audioDevice.isMicMuted ? "Microphone Globally Muted" : "Microphone Live & Active")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(audioDevice.isMicMuted ? .red : .primary)
                            Text(audioDevice.defaultInputName)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(audioDevice.isMicMuted ? "MUTED" : "LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(audioDevice.isMicMuted ? .red : .green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(audioDevice.isMicMuted ? Color.red.opacity(0.2) : Color.green.opacity(0.2)))
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.05)))
                }
                .buttonStyle(.plain)

                // Output and Input Device Selectors
                HStack(alignment: .top, spacing: 8) {
                    // Output Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Sound Output:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 3) {
                                ForEach(audioDevice.outputDevices) { device in
                                    Button {
                                        audioDevice.setOutputDevice(device.id)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: device.icon)
                                                .font(.system(size: 9))
                                                .foregroundStyle(device.isDefaultOutput ? accent.highlight : .secondary)

                                            Text(device.name)
                                                .font(.system(size: 9, weight: device.isDefaultOutput ? .semibold : .regular))
                                                .foregroundStyle(device.isDefaultOutput ? .white : .secondary)
                                                .lineLimit(1)

                                            Spacer(minLength: 2)

                                            if device.isDefaultOutput {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(accent.highlight)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(device.isDefaultOutput ? .white.opacity(0.12) : .white.opacity(0.03)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 72)
                    }
                    .frame(maxWidth: .infinity)

                    // Input Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Microphone:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 3) {
                                ForEach(audioDevice.inputDevices) { device in
                                    Button {
                                        audioDevice.setInputDevice(device.id)
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: device.icon)
                                                .font(.system(size: 9))
                                                .foregroundStyle(device.isDefaultInput ? .green : .secondary)

                                            Text(device.name)
                                                .font(.system(size: 9, weight: device.isDefaultInput ? .semibold : .regular))
                                                .foregroundStyle(device.isDefaultInput ? .white : .secondary)
                                                .lineLimit(1)

                                            Spacer(minLength: 2)

                                            if device.isDefaultInput {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3.5)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(device.isDefaultInput ? Color.green.opacity(0.15) : .white.opacity(0.03)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 72)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Dynamic Island HUD Quick Tester
                VStack(alignment: .leading, spacing: 5) {
                    Text("Dynamic Island HUD Tester")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 5) {
                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.volume(level: 0.72, muted: false))
                            }
                        } label: {
                            Label("Volume", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.volume(level: 0, muted: true))
                            }
                        } label: {
                            Label("Mute", systemImage: "speaker.slash.fill")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.red.opacity(0.2)))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.brightness(level: 0.8))
                            }
                        } label: {
                            Label("Sun", systemImage: "sun.max.fill")
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.yellow.opacity(0.2)))
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.close()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                vm.showPeek(.device(
                                    name: "AirPods Pro",
                                    symbol: "airpodspro",
                                    battery: 92,
                                    info: DeviceBatteryInfo(left: 92, right: 92, caseBattery: 85, single: 92)
                                ))
                            }
                        } label: {
                            Label("AirPods 🎧", systemImage: "airpodspro")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Capsule().fill(.green.opacity(0.2)))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
        }
    }
}
