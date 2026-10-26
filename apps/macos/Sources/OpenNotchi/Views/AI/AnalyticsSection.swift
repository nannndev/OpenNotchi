import Charts
import SwiftUI

struct AnalyticsSection: View {
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
