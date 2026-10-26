import AppKit
import SwiftUI

struct AccountToggle: View {
    let report: UsageReport
    @EnvironmentObject private var usage: AIUsageManager

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                usage.toggleAccountActive(id: report.account.id, connectionId: report.account.connectionId, active: !report.account.isActive)
            }
        } label: {
            Capsule()
                .fill(report.account.isActive ? Color.green.opacity(0.8) : Color.white.opacity(0.15))
                .frame(width: 22, height: 13)
                .overlay(alignment: report.account.isActive ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 9, height: 9).padding(2)
                }
        }
        .buttonStyle(.plain)
        .help(report.account.isActive ? "Active in 9router. Click to turn off." : "Inactive. Click to turn on.")
        .accessibilityLabel("\(report.account.name) \(report.account.isActive ? "on" : "off")")
    }
}

/// Small tile: ring for the tightest quota, name, today's tokens.
struct CompactUsageTile: View {
    let report: UsageReport
    @State private var hovering = false

    var body: some View {
        let tight = tightestQuota(report)
        let remaining = tight?.remainingPercentage ?? 100
        let tint = report.account.tool.tint

        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: CGFloat(min(100, max(0, remaining)) / 100))
                    .stroke(tight == nil ? tint : quotaColor(remaining), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                ToolLogo(tool: report.account.tool, size: 18)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(report.account.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(tight.map { "\(Int($0.remainingPercentage.rounded()))% · \($0.name)" } ?? (report.quotas.isEmpty ? report.account.tool.displayName : "Unlimited"))
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(tight.map { quotaColor($0.remainingPercentage) } ?? .secondary)
                    .lineLimit(1)
                Text("\(report.account.tool.displayName) · \(formatTokens(report.today.tokens)) today")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            AccountToggle(report: report)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hovering ? 0.08 : 0.04)))
        .opacity(report.account.isActive ? 1 : 0.5)
        .onHover { hovering = $0 }
        .help(tight.flatMap { $0.resetAt }.map { formatResetDetail($0) } ?? report.account.tool.displayName)
    }
}

/// One line per account with a thin bar for every quota.
struct UsageListRow: View {
    let report: UsageReport

    var body: some View {
        HStack(spacing: 8) {
            ToolLogo(tool: report.account.tool, size: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(report.account.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(report.account.tool.displayName)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(report.quotas.prefix(4), id: \.name) { q in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(q.unlimited ? "\(q.name) ∞" : "\(q.name) \(Int(q.remainingPercentage.rounded()))%")
                            .font(.system(size: 8, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.1))
                                Capsule()
                                    .fill(q.unlimited ? Color.green : quotaColor(q.remainingPercentage))
                                    .frame(width: geo.size.width * CGFloat(q.unlimited ? 1 : min(100, max(0, q.remainingPercentage)) / 100))
                            }
                        }
                        .frame(height: 3)
                    }
                    .help(q.resetAt.map { formatResetDetail($0) } ?? q.name)
                }
            }
            .frame(maxWidth: .infinity)

            Text(formatTokens(report.today.tokens))
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
            AccountToggle(report: report)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.04)))
        .opacity(report.account.isActive ? 1 : 0.5)
    }
}

/// Today's busiest models across all 9router accounts, plus a shortcut to its dashboard.
struct TopModelsPanel: View {
    let models: [(model: String, tokens: Int, cost: Double)]
    @Environment(\.notchAccent) private var accent

    var body: some View {
        let peak = max(1, models.first?.tokens ?? 1)
        VStack(alignment: .leading, spacing: 5) {
            Text("Top models today")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(models, id: \.model) { m in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(m.model).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text(formatTokens(m.tokens)).fontWeight(.semibold).monospacedDigit()
                    }
                    .font(.system(size: 9.5))
                    Capsule()
                        .fill(accent.highlight.opacity(0.8))
                        .frame(width: max(3, 150 * CGFloat(m.tokens) / CGFloat(peak)), height: 3)
                }
            }
            Spacer(minLength: 0)
            Button {
                if let url = URL(string: "http://127.0.0.1:20128") { NSWorkspace.shared.open(url) }
            } label: {
                Label("Open 9router", systemImage: "arrow.up.right.square")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open the 9router dashboard in your browser")
        }
        .padding(8)
        .frame(width: 170)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))
    }
}
