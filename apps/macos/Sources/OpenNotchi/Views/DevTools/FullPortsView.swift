import AppKit
import SwiftUI

struct FullPortsView: View {
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

struct FullPortRow: View {
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
