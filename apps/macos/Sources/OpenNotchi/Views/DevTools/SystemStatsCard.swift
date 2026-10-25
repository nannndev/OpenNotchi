import SwiftUI

struct SystemStatsCard: View {
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
