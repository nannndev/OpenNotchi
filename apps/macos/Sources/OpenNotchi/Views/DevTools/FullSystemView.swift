import SwiftUI

struct FullSystemView: View {
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
