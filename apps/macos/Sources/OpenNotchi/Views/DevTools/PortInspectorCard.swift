import SwiftUI

struct PortInspectorCard: View {
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

struct PortRow: View {
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
