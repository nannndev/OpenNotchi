import SwiftUI

struct UsageSection: View {
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
