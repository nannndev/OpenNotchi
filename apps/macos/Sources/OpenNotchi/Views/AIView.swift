import AppKit
import Charts
import SwiftUI

/// The AI tab: agent status, usage per account, and Ask AI.
struct AIView: View {
    enum Section: String, CaseIterable {
        case usage = "Quota & Accounts"
        case analytics = "Analytics"
        case agents = "Agents"
        case ask = "Ask"

        var icon: String {
            switch self {
            case .usage: return "chart.bar.xaxis"
            case .analytics: return "chart.xyaxis.line"
            case .agents: return "cpu"
            case .ask: return "sparkles"
            }
        }
    }

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var agents: AgentMonitor
    @EnvironmentObject private var vm: NotchViewModel
    @AppStorage("aiSection") private var section: Section = .usage

    private var activeAgentCount: Int {
        agents.sessions.filter { $0.state == .working || $0.state == .needsYou }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Interactive Tab Bar & Expand/Collapse Controller
            HStack(spacing: 8) {
                // Custom Pill Tab Switcher
                HStack(spacing: 4) {
                    ForEach(Section.allCases, id: \.self) { s in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                section = s
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: s.icon)
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(s.rawValue)
                                    .font(.system(size: 11, weight: section == s ? .bold : .medium))
                                if s == .agents && activeAgentCount > 0 {
                                    Circle()
                                        .fill(agents.sessions.contains(where: { $0.state == .needsYou }) ? Color.orange : Color.cyan)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .foregroundStyle(section == s ? Color.white : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                ZStack {
                                    if section == s {
                                        Capsule()
                                            .fill(Color.white.opacity(0.18))
                                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 0.8))
                                    } else {
                                        Capsule()
                                            .fill(Color.clear)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                )

                Spacer()

                // Expand / Collapse Notch Button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        vm.isAiExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: vm.isAiExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(vm.isAiExpanded ? "Compact" : "Expand")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(vm.isAiExpanded ? Color.cyan : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(vm.isAiExpanded ? Color.cyan.opacity(0.18) : Color.white.opacity(0.06))
                            .overlay(Capsule().stroke(vm.isAiExpanded ? Color.cyan.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)
                .help(vm.isAiExpanded ? "Collapse notch to standard height" : "Expand notch downward for spacious view")
            }
            .padding(.horizontal, 4)

            Group {
                switch section {
                case .usage: UsageSection()
                case .analytics: AnalyticsSection()
                case .agents: AgentsSection()
                case .ask: AskSection()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 4)
    }
}

private func emptyState(_ text: String, icon: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.secondary)
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

private extension AgentTool {
    var tint: Color {
        switch self {
        case .claude: return .orange
        case .antigravity: return Color(red: 0.65, green: 0.45, blue: 0.98)
        case .codex: return .green
        case .commandcode: return .cyan
        }
    }
}

/// Provider logo, falling back to the SF Symbol when the bundled PNG is missing (e.g. `swift run`).
private struct ToolLogo: View {
    let tool: AgentTool
    var size: CGFloat = 20

    var body: some View {
        if let logo = tool.logo {
            Image(nsImage: logo)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        } else {
            Image(systemName: tool.icon)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(tool.tint)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.24).fill(tool.tint.opacity(0.18)))
        }
    }
}

// MARK: - Agents

private struct AgentsSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var agents: AgentMonitor

    /// Needs-you first, then working, done, idle; newest first inside each group.
    private var sorted: [AgentSession] {
        let rank: [AgentState: Int] = [.needsYou: 0, .working: 1, .done: 2, .idle: 3]
        return agents.sessions.sorted {
            (rank[$0.state] ?? 9, $1.updatedAt) < (rank[$1.state] ?? 9, $0.updatedAt)
        }
    }

    private func count(_ state: AgentState) -> Int {
        agents.sessions.filter { $0.state == state }.count
    }

    var body: some View {
        if !settings.aiAgents {
            emptyState("Agent status is off in Settings › AI.", icon: "terminal")
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    statPill(count(.needsYou), "needs you", .orange)
                    statPill(count(.working), "working", .cyan)
                    statPill(count(.done), "done", .green)
                    Spacer()
                    ForEach([AgentTool.claude, .codex, .antigravity, .commandcode], id: \.self) { launchButton($0) }
                }
                .padding(.horizontal, 2)

                if agents.sessions.isEmpty {
                    emptyAgents
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 6)], spacing: 6) {
                            ForEach(sorted) { AgentRow(session: $0) }
                        }
                        .padding(.horizontal, 2)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sorted.map(\.id))
                    }
                }
            }
        }
    }

    private func statPill(_ n: Int, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(n)").font(.system(size: 11, weight: .bold).monospacedDigit())
            Text(label).font(.system(size: 9.5, weight: .medium))
        }
        .foregroundStyle(n > 0 ? tint : Color.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill((n > 0 ? tint : .white).opacity(n > 0 ? 0.15 : 0.05)))
    }

    private func launchButton(_ tool: AgentTool) -> some View {
        Button {
            AgentMonitor.activateTerminal(for: tool)
        } label: {
            ToolLogo(tool: tool, size: 20)
        }
        .buttonStyle(.plain)
        .help("Open \(tool.displayName)")
        .accessibilityLabel("Open \(tool.displayName)")
    }

    private var emptyAgents: some View {
        VStack(spacing: 10) {
            HStack(spacing: -6) {
                ForEach([AgentTool.claude, .codex, .antigravity, .commandcode], id: \.self) { tool in
                    ToolLogo(tool: tool, size: 34)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                }
            }
            VStack(spacing: 3) {
                Text("No agents running")
                    .font(.system(size: 12.5, weight: .bold))
                Text("Start Claude Code, Codex, Antigravity or Command Code. Progress and approval prompts show up here.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AgentRow: View {
    let session: AgentSession
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false
    @State private var pulse = false

    private var stateColor: Color {
        switch session.state {
        case .working: return .cyan
        case .needsYou: return .orange
        case .done: return .green
        case .idle: return .gray
        }
    }

    var body: some View {
        Button {
            AgentMonitor.activateTerminal(for: session.tool)
        } label: {
            HStack(spacing: 9) {
                toolIcon
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(session.project.isEmpty ? session.tool.displayName : session.project)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text(timeAgo(session.updatedAt, now: context.date))
                                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 6, height: 6)
                            .opacity(session.state == .working && pulse ? 0.3 : 1)
                        Text(session.state.label.capitalized)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(stateColor)
                        Text("· \(session.tool.displayName)")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    if let msg = session.message, !msg.isEmpty {
                        Text(msg)
                            .font(.system(size: 10))
                            .foregroundStyle(session.state == .needsYou ? Color.orange.opacity(0.9) : Color.secondary)
                            .lineLimit(2)
                    }
                }
                if hovering {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay(alignment: .leading) {
                // State stripe along the leading edge.
                RoundedRectangle(cornerRadius: 2)
                    .fill(stateColor)
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .help(session.message ?? "Open the session")
        .accessibilityLabel("\(session.tool.displayName), \(session.project), \(session.state.label)")
    }

    private var toolIcon: some View {
        ToolLogo(tool: session.tool, size: 28)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 11)
            .fill(session.state == .needsYou ? Color.orange.opacity(0.12) : Color.white.opacity(hovering ? 0.08 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(session.state == .needsYou ? Color.orange.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private func timeAgo(_ date: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "now" }
        return s < 3600 ? "\(s / 60)m" : "\(s / 3600)h"
    }
}

// MARK: - Usage & Quotas

private struct UsageSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var usage: AIUsageManager
    @EnvironmentObject private var vm: NotchViewModel
    @State private var selectedFilter: String = "ALL"
    @AppStorage("usageLayout") private var layout: UsageLayout = .cards

    enum UsageLayout: String, CaseIterable {
        case cards, compact, list
        var icon: String {
            switch self {
            case .cards: return "rectangle.grid.3x2"
            case .compact: return "square.grid.4x3.fill"
            case .list: return "list.bullet"
            }
        }
    }

    private var totalTokens: Int {
        usage.reports.reduce(0) { $0 + $1.today.tokens }
    }

    private var totalCost: Double {
        usage.reports.reduce(0) { $0 + $1.today.cost }
    }

    private var activeCount: Int {
        usage.reports.filter { $0.account.isActive && $0.found }.count
    }

    private var healthState: (label: String, color: Color) {
        if usage.reports.contains(where: { $0.account.isActive && $0.quota.health == .exhausted }) {
            return ("Exhausted", .red)
        }
        if usage.reports.contains(where: { $0.account.isActive && $0.quota.health == .warning }) {
            return ("Warning", .orange)
        }
        return ("Healthy", .green)
    }

    private var providerFilters: [String] {
        var set: [String] = ["ALL"]
        for r in usage.reports {
            let key = r.account.tool.rawValue.uppercased()
            if !set.contains(key) {
                set.append(key)
            }
        }
        return set
    }

    private var filteredReports: [UsageReport] {
        if selectedFilter == "ALL" { return usage.reports }
        return usage.reports.filter { $0.account.tool.rawValue.uppercased() == selectedFilter }
    }

    var body: some View {
        if usage.reports.isEmpty && !usage.scanning && settings.aiAccounts.isEmpty && !usage.is9RouterConnected {
            emptyState("Add Claude Code, Codex, or Antigravity in Settings › AI.", icon: "chart.bar")
        } else if usage.reports.isEmpty && usage.scanning {
            VStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Connecting to 9router & analyzing accounts…")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 8) {
                // Aggregated Summary Strip with 9router status, Totals, and Live Refresh
                HStack(spacing: 10) {
                    if usage.is9RouterConnected {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("9router")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.green)
                            Text("(\(usage.reports.count))")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                    }

                    summaryItem(label: "Today's Tokens", val: formatTokens(totalTokens))
                    if totalCost > 0 {
                        summaryItem(label: "Est. Spend", val: formatCost(totalCost))
                    }
                    summaryItem(label: "System Health", val: healthState.label, tint: healthState.color)
                    summaryItem(label: "Active Accounts", val: "\(activeCount)/\(usage.reports.count)")

                    Spacer(minLength: 4)

                    Button {
                        usage.refresh(force: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                                .rotationEffect(.degrees(usage.scanning ? 360 : 0))
                                .animation(usage.scanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: usage.scanning)
                            Text("Refresh")
                                .font(.system(size: 9.5, weight: .semibold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .foregroundStyle(usage.scanning ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh All Accounts & Quotas")
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                )

                // Provider Filter Pills (e.g. ALL (7), CLAUDE (4), ANTIGRAVITY (1), CODEX (1))
                HStack(spacing: 6) {
                    if providerFilters.count > 2 {
                        ForEach(providerFilters, id: \.self) { filter in
                            let count = filter == "ALL" ? usage.reports.count : usage.reports.filter { $0.account.tool.rawValue.uppercased() == filter }.count
                            Button {
                                selectedFilter = filter
                            } label: {
                                HStack(spacing: 4) {
                                    Text(filter == "ALL" ? "All" : filter.capitalized)
                                        .font(.system(size: 10, weight: selectedFilter == filter ? .bold : .medium))
                                    Text("\(count)")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(selectedFilter == filter ? Color.primary : Color.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.white.opacity(selectedFilter == filter ? 0.2 : 0.08)))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(selectedFilter == filter ? Color.white.opacity(0.18) : Color.white.opacity(0.04)))
                                .overlay(Capsule().stroke(Color.white.opacity(selectedFilter == filter ? 0.3 : 0.06), lineWidth: 0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    layoutPicker
                }
                .padding(.horizontal, 2)

                switch layout {
                case .cards:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(filteredReports) { UsageCard(report: $0) }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                case .compact:
                    HStack(alignment: .top, spacing: 8) {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 6)], spacing: 6) {
                                ForEach(filteredReports) { CompactUsageTile(report: $0) }
                            }
                            .padding(2)
                        }
                        if !usage.topModels.isEmpty { TopModelsPanel(models: usage.topModels) }
                    }
                case .list:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(filteredReports) { UsageListRow(report: $0) }
                        }
                        .padding(2)
                    }
                }
            }
            .onAppear { usage.refresh() }
        }
    }

    private var layoutPicker: some View {
        HStack(spacing: 2) {
            ForEach(UsageLayout.allCases, id: \.self) { l in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { layout = l }
                } label: {
                    Image(systemName: l.icon)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(layout == l ? Color.primary : Color.secondary)
                        .frame(width: 22, height: 18)
                        .background(Capsule().fill(Color.white.opacity(layout == l ? 0.18 : 0)))
                }
                .buttonStyle(.plain)
                .help("\(l.rawValue.capitalized) layout")
                .accessibilityLabel("\(l.rawValue.capitalized) layout")
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    private func summaryItem(label: String, val: String, tint: Color? = nil) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).textCase(.uppercase)
            Text(val).font(.system(size: 10.5, weight: .bold)).foregroundStyle(tint ?? .primary).monospacedDigit()
        }
    }
}

private struct UsageCard: View {
    let report: UsageReport
    @Environment(\.notchAccent) private var accent
    @EnvironmentObject private var usage: AIUsageManager
    @EnvironmentObject private var vm: NotchViewModel
    @State private var isHovering = false

    private var toolTint: Color { report.account.tool.tint }

    private var healthColor: Color {
        if !report.account.isActive { return .gray }
        switch report.quota.health {
        case .healthy: return .green
        case .warning: return .orange
        case .exhausted: return .red
        }
    }

    private var healthLabel: String {
        if !report.account.isActive { return "OFF" }
        if report.testStatus == "unavailable" || (report.lastError?.contains("rate_limit") == true) {
            return "RATE LIMIT"
        }
        return report.quota.health.rawValue.uppercased()
    }

    var body: some View {
        let q = report.quota
        let cardHeight: CGFloat = vm.isAiExpanded ? 260 : 210

        VStack(alignment: .leading, spacing: 6) {
            // Header: Tool Icon, Name, Provider & Priority, Interactive ON/OFF Toggle & Health Pill
            HStack(spacing: 6) {
                ToolLogo(tool: report.account.tool, size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(report.account.name)
                        .font(.system(size: 11.5, weight: .bold))
                        .lineLimit(1)
                    HStack(spacing: 3) {
                        Text(report.account.tool.displayName)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        if let p = report.account.priority {
                            Text("· P\(p)")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(toolTint)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Interactive 9router ON / OFF Toggle Pill
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        usage.toggleAccountActive(
                            id: report.account.id,
                            connectionId: report.account.connectionId,
                            active: !report.account.isActive
                        )
                    }
                } label: {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(report.account.isActive ? Color.green : Color.gray)
                            .frame(width: 5, height: 5)
                        Text(report.account.isActive ? "ON" : "OFF")
                            .font(.system(size: 8, weight: .heavy))
                    }
                    .foregroundStyle(report.account.isActive ? Color.green : Color.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(report.account.isActive ? Color.green.opacity(0.18) : Color.white.opacity(0.08))
                            .overlay(Capsule().stroke(report.account.isActive ? Color.green.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 0.8))
                    )
                }
                .buttonStyle(.plain)
                .help(report.account.isActive ? "Active in 9router. Click to toggle OFF." : "Inactive. Click to toggle ON.")

                // Health status badge
                Text(healthLabel)
                    .font(.system(size: 7.5, weight: .heavy))
                    .foregroundStyle(healthColor)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(healthColor.opacity(0.18)).overlay(Capsule().stroke(healthColor.opacity(0.35), lineWidth: 0.8)))
            }

            if !report.found {
                note("No logs found in \(report.account.dir)")
            } else if report.isFrom9Router {
                // 9router Quota Bars (e.g. session 5h and weekly 7d, or multiple models)
                if !report.quotas.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(report.quotas, id: \.name) { q in
                            NineRouterQuotaBar(quota: q)
                        }
                    }
                } else if let plan = report.planName {
                    stat("Plan", plan)
                }

                stat("Today", "\(formatTokens(report.today.tokens)) \(report.today.cost > 0 ? "· " + formatCost(report.today.cost) : "tokens")")
                sparkline
            } else {
                // Quota bar / Block gauge (Directory Fallback)
                if report.account.tool == .codex {
                    if let w = report.limits?.primary { LimitBar(window: w) }
                    if let w = report.limits?.secondary { LimitBar(window: w) }
                    if report.limits == nil { note("No rate limits reported yet") }
                } else if let block = report.block {
                    VStack(alignment: .leading, spacing: 3) {
                        stat("5h block", formatTokens(block.tokens.tokens))
                        let pct = min(100, max(0, q.percent))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.12)).frame(height: 5.5)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: q.health == .exhausted ? [.orange, .red] : [accent.highlight.opacity(0.8), accent.highlight],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(3.5, geo.size.width * CGFloat(pct / 100)), height: 5.5)
                            }
                        }
                        .frame(height: 5.5)
                        if let resets = q.resetsText {
                            note("\(resets) \(block.tokens.cost > 0 ? "· " + formatCost(block.tokens.cost) : "")")
                        }
                    }
                } else {
                    stat("5h block", "Idle (None active)")
                }

                stat("Today", "\(formatTokens(report.today.tokens)) \(report.today.cost > 0 ? "· " + formatCost(report.today.cost) : "tokens")")
                sparkline
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(width: 230, height: cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(.white.opacity(isHovering ? 0.08 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(healthColor.opacity(report.account.isActive ? 0.25 : 0.08), lineWidth: 1))
        )
        .opacity(report.account.isActive ? 1.0 : 0.55)
        .onHover { isHovering = $0 }
    }

    private var sparkline: some View {
        let peak = max(1, report.days.max() ?? 1)
        return HStack(alignment: .bottom, spacing: 2.5) {
            ForEach(Array(report.days.enumerated()), id: \.offset) { i, tokens in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == report.days.count - 1 ? accent.highlight : .white.opacity(0.25))
                    .frame(height: max(2, 20 * CGFloat(tokens) / CGFloat(peak)))
            }
        }
        .frame(height: 20, alignment: .bottom)
        .help("Tokens per day, last 7 days")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.system(size: 10.5))
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(2)
    }
}

private struct NineRouterQuotaBar: View {
    let quota: NineRouterQuota
    @Environment(\.notchAccent) private var accent

    private var barColor: Color {
        if quota.remainingPercentage <= 10 { return .red }
        if quota.remainingPercentage <= 30 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(quota.name)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(quota.unlimited ? "Unlimited" : "\(Int(quota.remainingPercentage.rounded()))% left")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(barColor)
            }
            .font(.system(size: 9.5))

            if !quota.unlimited {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(barColor)
                            .frame(width: max(2, geo.size.width * CGFloat(min(100.0, max(0.0, quota.remainingPercentage)) / 100.0)))
                    }
                }
                .frame(height: 4.5)
            }

            // Prominent reset info displaying both relative countdown and exact local time
            HStack(spacing: 3) {
                if let resets = quota.resetAt, resets > .now {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text(formatResetDetail(resets))
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.85))
                } else if quota.unlimited {
                    Image(systemName: "infinity")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.secondary)
                    Text("Unlimited quota")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                } else if quota.remainingPercentage >= 99.0 {
                    Image(systemName: "sparkles")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.green)
                    Text("Full · 5h window starts on use")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 7.5))
                        .foregroundStyle(.secondary)
                    Text("Rolling window")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LimitBar: View {
    let window: RateWindow

    var body: some View {
        let pct = min(100, max(0, window.usedPercent))
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(window.label).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(pct.rounded()))%").fontWeight(.semibold).monospacedDigit()
            }
            .font(.system(size: 11))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.1))
                    Capsule().fill(pct >= 80 ? Color.orange : .green).frame(width: geo.size.width * pct / 100)
                }
            }
            .frame(height: 5)
            HStack(spacing: 3) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.cyan)
                Text(formatResetDetail(window.resetsAt))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Compact & list layouts

/// The quota closest to running out, which is what decides whether an account is usable.
private func tightestQuota(_ report: UsageReport) -> NineRouterQuota? {
    report.quotas.filter { !$0.unlimited }.min { $0.remainingPercentage < $1.remainingPercentage }
}

private func quotaColor(_ remaining: Double) -> Color {
    remaining <= 10 ? .red : remaining <= 30 ? .orange : .green
}

/// ON/OFF switch shared by the compact and list layouts.
private struct AccountToggle: View {
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
private struct CompactUsageTile: View {
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
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(hovering ? 0.08 : 0.04)))
        .opacity(report.account.isActive ? 1 : 0.5)
        .onHover { hovering = $0 }
        .help(tight.flatMap { $0.resetAt }.map { formatResetDetail($0) } ?? report.account.tool.displayName)
    }
}

/// One line per account with a thin bar for every quota.
private struct UsageListRow: View {
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
private struct TopModelsPanel: View {
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

// MARK: - Analytics (9router usage history)

private struct AnalyticsSection: View {
    enum Range: String, CaseIterable {
        case today = "Today", week = "7D", month = "30D", all = "All"
        var days: Int? {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    enum Metric: String, CaseIterable { case tokens = "Tokens", requests = "Requests", cost = "Cost" }

    @Environment(\.notchAccent) private var accent
    @AppStorage("analyticsRange") private var range: Range = .week
    @State private var metric: Metric = .tokens
    @State private var days: [NineRouterService.DayStat] = []
    @State private var recent: [NineRouterService.RecentRequest] = []

    private var total: NineRouterService.DayStat {
        days.reduce(into: NineRouterService.DayStat(date: "", requests: 0, input: 0, cached: 0, output: 0, cost: 0)) {
            $0.requests += $1.requests; $0.input += $1.input; $0.cached += $1.cached; $0.output += $1.output; $0.cost += $1.cost
        }
    }

    var body: some View {
        if !NineRouterService.shared.isAvailable {
            emptyState("Install 9router to see request history and analytics.", icon: "chart.xyaxis.line")
        } else {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    stat("Requests", total.requests.formatted(), .primary)
                    stat("Input", formatTokens(total.input), .orange)
                    stat("Cached", formatTokens(total.cached), .cyan)
                    stat("Output", formatTokens(total.output), .green)
                    stat("Est. cost", formatCost(total.cost), .yellow)
                }

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            segmented(Metric.allCases, selection: $metric)
                            Spacer()
                            segmented(Range.allCases, selection: $range)
                        }
                        chart
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))

                    recentList
                }
            }
            .task(id: range) {
                // Re-read every 10 s while visible; SQLite reads are cheap but stay off the main thread.
                while !Task.isCancelled {
                    let range = range
                    let (d, r) = await Task.detached(priority: .utility) {
                        (NineRouterService.shared.dailyStats(days: range.days), NineRouterService.shared.recentRequests(limit: 20))
                    }.value
                    days = d
                    recent = r
                    try? await Task.sleep(for: .seconds(10))
                }
            }
        }
    }

    private func value(_ d: NineRouterService.DayStat) -> Double {
        switch metric {
        case .tokens: return Double(d.input + d.output)
        case .requests: return Double(d.requests)
        case .cost: return d.cost
        }
    }

    private var chart: some View {
        Chart(days) { d in
            AreaMark(x: .value("Day", d.date), y: .value(metric.rawValue, value(d)))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [accent.highlight.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Day", d.date), y: .value(metric.rawValue, value(d)))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accent.highlight)
            if days.count <= 1 {
                PointMark(x: .value("Day", d.date), y: .value(metric.rawValue, value(d)))
                    .foregroundStyle(accent.highlight)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { v in
                AxisValueLabel {
                    if let s = v.as(String.self) { Text(String(s.suffix(5))).font(.system(size: 8)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { v in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let n = v.as(Double.self) {
                        Text(metric == .cost ? formatCost(n) : formatTokens(Int(n))).font(.system(size: 8))
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent requests")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 3) {
                    ForEach(recent) { r in
                        HStack(spacing: 5) {
                            if let tool = AgentTool(rawValue: r.provider) {
                                ToolLogo(tool: tool, size: 12)
                            } else {
                                Circle().fill(r.ok ? Color.green : .red).frame(width: 5, height: 5)
                            }
                            Text(r.model)
                                .font(.system(size: 9.5, design: .monospaced))
                                .foregroundStyle(r.ok ? Color.primary : .red)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text("\(formatTokens(r.input))↑ \(formatTokens(r.output))↓")
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(.secondary)
                            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                                Text(ago(r.date, now: ctx.date))
                                    .font(.system(size: 9).monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 26, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 250)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))
    }

    private func stat(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(tint).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.04)))
    }

    private func segmented<T: RawRepresentable & Hashable>(_ items: [T], selection: Binding<T>) -> some View where T.RawValue == String {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selection.wrappedValue = item }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 9.5, weight: selection.wrappedValue == item ? .bold : .medium))
                        .foregroundStyle(selection.wrappedValue == item ? Color.primary : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(.white.opacity(selection.wrappedValue == item ? 0.18 : 0)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Capsule().fill(.white.opacity(0.06)))
    }

    private func ago(_ date: Date, now: Date) -> String {
        let s = max(0, Int(now.timeIntervalSince(date)))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return s < 86400 ? "\(s / 3600)h" : "\(s / 86400)d"
    }
}

// MARK: - Ask

private struct AskSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @Environment(\.notchAccent) private var accent
    @State private var text = ""
    @State private var answer: String?
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var copied = false

    private var lyricLine: String? {
        guard let info = media.info else { return nil }
        return lyrics.currentLine(at: info.position(at: .now))
    }

    var body: some View {
        VStack(spacing: 7) {
            // Header with provider info
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent.highlight)
                    Text("Ask AI")
                        .font(.system(size: 11, weight: .bold))
                    Text("(\(settings.aiProvider.displayName))")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let lyricLine, !lyricLine.isEmpty {
                    Text("Now playing lyric detected")
                        .font(.system(size: 9))
                        .foregroundStyle(accent.highlight)
                }
            }
            .padding(.horizontal, 2)

            // Input bar
            HStack(spacing: 6) {
                TextField("Ask anything…", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                    .onSubmit { send(text) }
                    .onExitCommand(perform: reset)

                if task != nil {
                    ProgressView().controlSize(.small)
                } else {
                    iconButton("arrow.up.circle.fill", help: "Send") { send(text) }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if answer != nil || error != nil || !text.isEmpty {
                    iconButton("xmark.circle.fill", help: "Clear", action: reset)
                }
            }

            // Quick Action Pills
            HStack(spacing: 6) {
                ForEach(QuickAction.allCases) { action in
                    Button { quick(action) } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .disabled(task != nil || (action == .explain && lyricLine == nil))
                    .help(action == .explain ? "Uses the current lyric line" : "Uses the text on the clipboard")
                }
                Spacer()
            }

            // Response Box
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if let error {
                        Text(error).foregroundStyle(.orange)
                    } else if let answer {
                        Text(answer).textSelection(.enabled)
                    } else {
                        Text("Type a question, or use a quick action on the clipboard or current song lyric. Powered by \(settings.aiProvider.displayName).")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 11.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.03)))
            .overlay(alignment: .bottomTrailing) {
                if let answer {
                    iconButton(copied ? "checkmark" : "doc.on.doc", help: "Copy Answer") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(answer, forType: .string)
                        copied = true
                    }
                    .padding(6)
                }
            }
        }
    }

    private func iconButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(accent.highlight)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func quick(_ action: QuickAction) {
        if action == .explain {
            guard let line = lyricLine else { return }
            send(action.prompt(line, song: media.info.map { ($0.title, $0.artist) }))
        } else {
            guard let clip = NSPasteboard.general.string(forType: .string), !clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                error = "The clipboard has no text."
                return
            }
            send(action.prompt(clip))
        }
    }

    private func send(_ prompt: String) {
        let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, task == nil else { return }
        (answer, error, copied) = (nil, nil, false)
        task = Task { @MainActor in
            do {
                answer = try await AIAssistant.ask(prompt, settings: settings)
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
            task = nil
        }
    }

    private func reset() {
        task?.cancel()
        (task, text, answer, error, copied) = (nil, "", nil, nil, false)
    }
}
