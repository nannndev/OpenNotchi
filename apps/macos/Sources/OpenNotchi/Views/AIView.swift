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
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 6)], spacing: 6) {
                                ForEach(filteredReports) { CompactUsageTile(report: $0) }
                            }
                            .padding(2)
                        }
                        .frame(maxWidth: .infinity)
                        if !usage.topModels.isEmpty { TopModelsPanel(models: usage.topModels) }
                    }
                case .list:
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(filteredReports) { UsageListRow(report: $0) }
                        }
                        .padding(2)
                    }
                    .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Extra context the user can attach to the next prompt.
private enum ChatContext: String, CaseIterable, Identifiable {
    case clipboard, song, usage

    var id: String { rawValue }
    var label: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .song: return "Now playing"
        case .usage: return "My AI usage"
        }
    }
    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .song: return "music.note"
        case .usage: return "chart.bar.xaxis"
        }
    }
}

private struct AskSection: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var lyrics: LyricsManager
    @EnvironmentObject private var usage: AIUsageManager
    @Environment(\.notchAccent) private var accent
    @ObservedObject private var store = ChatStore.shared
    @State private var text = ""
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var streaming = false
    @State private var attached: Set<ChatContext> = []
    @State private var routerModels: [String] = []
    /// Pending images (base64 JPEG) and files (name, text) for the next message.
    @State private var pendingImages: [String] = []
    @State private var pendingFiles: [(name: String, body: String)] = []
    @State private var dropTargeted = false
    /// Settings Notchi changed per assistant message index, shown under that bubble.
    @State private var changes: [Int: [NotchiBrain.Change]] = [:]
    @EnvironmentObject private var vm: NotchViewModel
    @FocusState private var focused: Bool

    private var messages: [AIAssistant.Message] { store.current?.messages ?? [] }

    private var providerLabel: String {
        switch settings.aiProvider {
        case .ninerouter: return "9router · \(settings.aiNineRouterModel.isEmpty ? "auto" : settings.aiNineRouterModel)"
        case .anthropic: return "Anthropic · \(settings.aiAnthropicModel)"
        case .openai: return settings.aiOpenaiModel
        case .ollama: return "Ollama · \(settings.aiOllamaModel)"
        case .apple: return "Apple Intelligence"
        }
    }

    private var lyricLine: String? {
        guard let info = media.info else { return nil }
        return lyrics.currentLine(at: info.position(at: .now))
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            conversation
            composer
        }
        .onExitCommand { if task != nil { stop() } }
        .onDrop(of: [.fileURL, .image], isTargeted: $dropTargeted) { providers in
            for p in providers {
                if p.canLoadObject(ofClass: URL.self) {
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        if let url { Task { @MainActor in addFile(url) } }
                    }
                } else if p.canLoadObject(ofClass: NSImage.self) {
                    _ = p.loadObject(ofClass: NSImage.self) { img, _ in
                        if let img = img as? NSImage, let b64 = ChatAttachment.jpegBase64(img) {
                            Task { @MainActor in withAnimation { pendingImages.append(b64) } }
                        }
                    }
                }
            }
            return true
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accent.highlight, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .background(RoundedRectangle(cornerRadius: 14).fill(accent.highlight.opacity(0.08)))
                    .overlay(Label("Drop to attach", systemImage: "paperclip").font(.system(size: 12, weight: .semibold)))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }

    // MARK: Header: model + sessions

    private var header: some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Provider", selection: $settings.aiProvider) {
                    ForEach(AIProvider.available) { Text($0.displayName).tag($0) }
                }
                if settings.aiProvider == .ninerouter {
                    Picker("Model", selection: $settings.aiNineRouterModel) {
                        Text("Automatic").tag("")
                        ForEach(routerModels, id: \.self) { Text($0).tag($0) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles").foregroundStyle(accent.highlight)
                    Text(providerLabel).lineLimit(1)
                }
                .font(.system(size: 10, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Where your prompts go")
            .task(id: settings.aiProvider) {
                if settings.aiProvider == .ninerouter { routerModels = await NineRouterService.shared.models() }
            }

            Spacer()

            Menu {
                Button("New chat", systemImage: "square.and.pencil") { newChat() }
                if !store.sessions.isEmpty {
                    Divider()
                    ForEach(store.sessions.prefix(15)) { session in
                        Button {
                            stop()
                            changes = [:]
                            withAnimation(.easeInOut(duration: 0.2)) { store.currentID = session.id }
                        } label: {
                            Text(session.title)
                            Text(session.updatedAt.formatted(.relative(presentation: .named)))
                        }
                    }
                    if let id = store.currentID {
                        Divider()
                        Button("Delete this chat", systemImage: "trash", role: .destructive) {
                            withAnimation { store.delete(id) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(store.current?.title ?? "New chat").lineLimit(1).frame(maxWidth: 160)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Chat history")

            Button(action: newChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New chat")
            .accessibilityLabel("New chat")
        }
        .padding(.horizontal, 2)
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    if messages.isEmpty && error == nil {
                        suggestions
                    }
                    ForEach(Array(messages.enumerated()), id: \.offset) { i, m in
                        ChatBubble(
                            message: m,
                            isStreaming: streaming && i == messages.count - 1,
                            canRegenerate: task == nil && i == messages.count - 1 && m.role == "assistant",
                            onRegenerate: regenerate,
                            changes: changes[i] ?? []
                        )
                        .id(i)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: m.role == "user" ? .bottomTrailing : .bottomLeading)),
                            removal: .opacity
                        ))
                    }
                    if task != nil && !streaming {
                        TypingIndicator(tint: accent.highlight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                    }
                    if let error {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(error).textSelection(.enabled)
                            Spacer(minLength: 4)
                            Button("Retry", action: regenerate).buttonStyle(.plain).fontWeight(.semibold)
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.orange.opacity(0.12)))
                        .transition(.opacity)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 2)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: messages.count)
                .animation(.easeOut(duration: 0.2), value: task != nil)
            }
            .onChange(of: messages.last?.content) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: store.currentID) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
        .frame(maxHeight: .infinity)
    }

    private var suggestions: some View {
        VStack(spacing: 8) {
            Text("What can I help with?")
                .font(.system(size: 13, weight: .bold))
            HStack(spacing: 6) {
                ForEach(QuickAction.allCases) { action in
                    Button { quick(action) } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Capsule().fill(.white.opacity(0.08)))
                            .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .disabled(action == .explain && lyricLine == nil)
                    .help(action == .explain ? "Uses the current lyric line" : "Uses the text on the clipboard")
                }
            }
            HStack(spacing: 14) {
                if usage.is9RouterConnected {
                    suggestion("How's my AI usage today?", icon: "chart.bar.xaxis") {
                        send("How is my AI usage looking? Anything close to its limit?", context: [.usage])
                    }
                }
                suggestion("Make my notch look nicer", icon: "paintpalette") { send("Make my notch look nicer. Pick a theme, accent and animation that go well together.") }
                suggestion("What can Notchi do?", icon: "questionmark.circle") { send("What can OpenNotchi do? Give me a quick tour.") }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .transition(.opacity)
    }

    private func suggestion(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent.highlight)
        }
        .buttonStyle(.plain)
    }

    // MARK: Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                ForEach(ChatContext.allCases) { ctx in
                    let on = attached.contains(ctx)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if on { attached.remove(ctx) } else { attached.insert(ctx) }
                        }
                    } label: {
                        Label(ctx.label, systemImage: on ? "checkmark" : ctx.icon)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(on ? accent.highlight : .secondary)
                            .padding(.horizontal, 7)
                            .frame(height: 19)
                            .background(Capsule().fill(on ? accent.highlight.opacity(0.16) : .white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .disabled(ctx == .song && media.info == nil || ctx == .usage && !usage.is9RouterConnected)
                    .help("Attach \(ctx.label.lowercased()) to your next message")
                }
                Spacer()
                Button(action: pickFiles) {
                    Image(systemName: "paperclip").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Attach images or files (or drop them here, or ⌘V an image)")
                .accessibilityLabel("Attach files")
                Button(action: takeScreenshot) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Capture part of the screen")
                .accessibilityLabel("Screenshot")
            }

            if !pendingImages.isEmpty || !pendingFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(pendingImages.enumerated()), id: \.offset) { i, b64 in
                            if let img = Data(base64Encoded: b64).flatMap(NSImage.init(data:)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) { removeButton { pendingImages.remove(at: i) } }
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        ForEach(Array(pendingFiles.enumerated()), id: \.offset) { i, f in
                            Label(f.name, systemImage: "doc.text")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(height: 26)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))
                                .overlay(alignment: .topTrailing) { removeButton { pendingFiles.remove(at: i) } }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                TextField(messages.isEmpty ? "Ask anything…" : "Reply…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .lineLimit(1...4)
                    .focused($focused)
                    .onSubmit { send(text) }
                    .onPasteCommand(of: [.image, .fileURL]) { _ in pasteFromClipboard() }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? accent.highlight.opacity(0.5) : .white.opacity(0.08), lineWidth: 1))
                    )
                    .animation(.easeOut(duration: 0.15), value: focused)

                Button {
                    if task != nil { stop() } else { send(text) }
                } label: {
                    Image(systemName: task != nil ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(accent.highlight)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(task == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingImages.isEmpty && pendingFiles.isEmpty)
                .help(task != nil ? "Stop (Esc)" : "Send (Return)")
                .accessibilityLabel(task != nil ? "Stop" : "Send")
            }
        }
    }

    // MARK: Attachments

    private func removeButton(_ action: @escaping () -> Void) -> some View {
        Button { withAnimation { action() } } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.white, .black.opacity(0.6))
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
        .accessibilityLabel("Remove attachment")
    }

    private func addFile(_ url: URL) {
        switch ChatAttachment.load(url) {
        case .image(let b64): withAnimation { pendingImages.append(b64) }
        case .text(let name, let body): withAnimation { pendingFiles.append((name, body)) }
        case nil: error = "Can't read \(url.lastPathComponent). Images, PDFs and text files work."
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        // The notch panel floats above everything; bring the app forward so the picker isn't hidden.
        NSApp.activate(ignoringOtherApps: true)
        vm.holdOpen = true
        panel.begin { response in
            vm.holdOpen = false
            if response == .OK { panel.urls.forEach(addFile) }
        }
    }

    private func takeScreenshot() {
        vm.holdOpen = true
        Task {
            if let b64 = await ChatAttachment.screenshot() {
                withAnimation { pendingImages.append(b64) }
            }
            vm.holdOpen = false
            focused = true
        }
    }

    private func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            urls.forEach(addFile)
        } else if let img = NSImage(pasteboard: pb), let b64 = ChatAttachment.jpegBase64(img) {
            withAnimation { pendingImages.append(b64) }
        }
    }

    // MARK: Actions

    private func newChat() {
        stop()
        withAnimation(.easeInOut(duration: 0.2)) {
            store.newSession()
            error = nil
            attached = []
            pendingImages = []
            pendingFiles = []
            changes = [:]
        }
        focused = true
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

    /// The attached context, sent ahead of the prompt.
    private func contextBlock(_ context: Set<ChatContext>) -> String {
        var parts: [String] = []
        if context.contains(.clipboard), let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
            parts.append("Clipboard:\n\(clip.prefix(6000))")
        }
        if context.contains(.song), let info = media.info {
            parts.append("Now playing: \"\(info.title)\" by \(info.artist)" + (lyricLine.map { ". Current lyric: \"\($0)\"" } ?? ""))
        }
        if context.contains(.usage) {
            let lines = usage.reports.map { r in
                let quotas = r.quotas.map { "\($0.name) \($0.unlimited ? "unlimited" : "\(Int($0.remainingPercentage))% left")" }.joined(separator: ", ")
                return "- \(r.account.name) (\(r.account.tool.displayName), \(r.account.isActive ? "on" : "off")): \(formatTokens(r.today.tokens)) tokens today\(quotas.isEmpty ? "" : "; \(quotas)")"
            }
            parts.append("My AI accounts in 9router:\n" + lines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n")
    }

    private func send(_ prompt: String, context: Set<ChatContext>? = nil) {
        var prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard task == nil, !prompt.isEmpty || !pendingImages.isEmpty || !pendingFiles.isEmpty else { return }
        if prompt.isEmpty { prompt = pendingImages.isEmpty ? "What's in this file?" : "What's in this image?" }
        let ctx = context ?? attached
        let files = pendingFiles.map { "File \($0.name):\n\($0.body)" }
        let block = ([contextBlock(ctx)] + files).filter { !$0.isEmpty }.joined(separator: "\n\n")
        let labels = ChatContext.allCases.filter(ctx.contains).map(\.label) + pendingFiles.map(\.name)
        let images = pendingImages
        text = ""
        error = nil
        attached = []
        pendingImages = []
        pendingFiles = []
        withAnimation {
            store.append(.init(role: "user", content: prompt, context: block.isEmpty ? nil : block,
                               attachments: labels.isEmpty ? nil : labels, images: images.isEmpty ? nil : images))
        }
        run()
    }

    private func regenerate() {
        guard task == nil else { return }
        error = nil
        if messages.last?.role == "assistant" { store.removeLast() }
        guard messages.last?.role == "user" else { return }
        run()
    }

    private func run() {
        let history = messages
        let system = NotchiBrain.systemPrompt
        task = Task { @MainActor in
            var answer = ""
            do {
                try await AIAssistant.chat(history, system: system, settings: settings) { delta in
                    if !streaming {
                        streaming = true
                        withAnimation { store.append(.init(role: "assistant", content: "")) }
                    }
                    answer += delta
                    store.updateLast(NotchiBrain.split(answer).text)
                }
                // Apply any settings the model asked for, keep only the readable part in the chat.
                let (shown, actions) = NotchiBrain.split(answer)
                store.updateLast(shown.isEmpty ? "Done." : shown, persist: true)
                if let actions {
                    let applied = withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { NotchiBrain.apply(actions, vm: vm) }
                    if !applied.isEmpty { withAnimation { changes[messages.count - 1] = applied } }
                }
            } catch is CancellationError {
                if streaming { store.updateLast(answer, persist: true) }
            } catch {
                if streaming && answer.isEmpty { store.removeLast() }
                withAnimation { self.error = error.localizedDescription }
            }
            streaming = false
            task = nil
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
        streaming = false
    }
}

/// One message. User on the right in the accent color, assistant on the left with copy / regenerate on hover.
private struct ChatBubble: View {
    let message: AIAssistant.Message
    let isStreaming: Bool
    let canRegenerate: Bool
    let onRegenerate: () -> Void
    var changes: [NotchiBrain.Change] = []
    @Environment(\.notchAccent) private var accent
    @State private var hovering = false
    @State private var copied = false
    @State private var undone: Set<UUID> = []

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if let attachments = message.attachments {
                    HStack(spacing: 4) {
                        ForEach(attachments, id: \.self) { a in
                            Label(a, systemImage: "paperclip")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let images = message.images {
                    HStack(spacing: 4) {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, b64 in
                            if let img = Data(base64Encoded: b64).flatMap(NSImage.init(data:)) {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 90, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                }
                (Text(rendered) + Text(isStreaming ? " ▍" : "").foregroundColor(accent.highlight))
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 13,
                            bottomLeadingRadius: isUser ? 13 : 4,
                            bottomTrailingRadius: isUser ? 4 : 13,
                            topTrailingRadius: 13
                        )
                        .fill(isUser ? accent.highlight.opacity(0.28) : .white.opacity(0.07))
                    )
                if !changes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(changes) { c in
                            HStack(spacing: 6) {
                                Image(systemName: undone.contains(c.id) ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                                    .foregroundStyle(undone.contains(c.id) ? Color.secondary : Color.green)
                                Text(c.label).strikethrough(undone.contains(c.id)).lineLimit(1)
                                if c.undo != nil && !undone.contains(c.id) {
                                    Button("Undo") {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            NotchiBrain.undo(c)
                                            undone.insert(c.id)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(accent.highlight)
                                }
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.08)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.25), lineWidth: 1)))
                }
                if !isUser && !isStreaming {
                    HStack(spacing: 10) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            copied = true
                            Task { try? await Task.sleep(for: .seconds(1.2)); copied = false }
                        } label: {
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        if canRegenerate {
                            Button(action: onRegenerate) { Label("Regenerate", systemImage: "arrow.clockwise") }
                        }
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(hovering || canRegenerate ? 1 : 0)
                    .padding(.leading, 4)
                }
            }
            if !isUser { Spacer(minLength: 60) }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hovering = h } }
    }

    /// Light markdown (bold, italics, code, links); falls back to plain text.
    private var rendered: AttributedString {
        (try? AttributedString(markdown: message.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(message.content)
    }
}

/// Three dots bouncing in turn while waiting for the first token.
private struct TypingIndicator: View {
    let tint: Color

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                        .offset(y: -3 * max(0, sin((t * 6) - Double(i) * 0.7)))
                        .opacity(0.5 + 0.5 * max(0, sin((t * 6) - Double(i) * 0.7)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(UnevenRoundedRectangle(topLeadingRadius: 13, bottomLeadingRadius: 4, bottomTrailingRadius: 13, topTrailingRadius: 13).fill(.white.opacity(0.07)))
        }
        .accessibilityLabel("Thinking")
    }
}
