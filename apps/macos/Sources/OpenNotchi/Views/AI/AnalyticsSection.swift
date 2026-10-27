import Charts
import SwiftUI

struct AnalyticsSection: View {
    enum Range: String, CaseIterable {
        case today = "Today"
        case week = "7D"
        case month = "30D"
        case all = "All"
        var days: Int? {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    enum Metric: String, CaseIterable {
        case tokens = "Tokens"
        case requests = "Requests"
        case cost = "Cost"
    }

    @Environment(\.notchAccent) private var accent
    @AppStorage("analyticsRange") private var range: Range = .week
    @State private var metric: Metric = .tokens
    @State private var days: [NineRouterService.DayStat] = []
    /// The same number of days just before `days`, for the change badges; empty for All.
    @State private var previous: [NineRouterService.DayStat] = []
    @State private var models: [NineRouterService.ModelStat] = []
    @State private var recent: [NineRouterService.RecentRequest] = []
    @State private var selectedDate: String?

    var body: some View {
        if !NineRouterService.shared.isAvailable {
            emptyState("Install 9router to see request history and analytics.", icon: "chart.xyaxis.line")
        } else {
            VStack(spacing: 8) {
                statsRow

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

                    VStack(spacing: 8) {
                        modelBreakdown
                        recentList
                    }
                    .frame(width: 250)
                }
            }
            .task(id: range) {
                // Re-read every 10 s while visible; SQLite reads are cheap but stay off the main thread.
                while !Task.isCancelled {
                    let days = range.days
                    let snapshot = await Task.detached(priority: .utility) { Self.load(days: days) }.value
                    self.days = snapshot.days
                    previous = snapshot.previous
                    models = snapshot.models
                    recent = snapshot.recent
                    try? await Task.sleep(for: .seconds(10))
                }
            }
        }
    }

    private struct Snapshot {
        var days: [NineRouterService.DayStat]
        var previous: [NineRouterService.DayStat]
        var models: [NineRouterService.ModelStat]
        var recent: [NineRouterService.RecentRequest]
    }

    /// Everything the tab shows for a window of `days` (nil = all history). Blocking; call off the main thread.
    nonisolated private static func load(days: Int?) -> Snapshot {
        let service = NineRouterService.shared
        var previous: [NineRouterService.DayStat] = []
        if let n = days {
            // The n days before the current window; rows only exist for days with usage, so cut by date.
            let start = dateKey(daysAgo: n - 1)
            previous = service.dailyStats(days: 2 * n).filter { $0.date < start }
        }
        return Snapshot(
            days: service.dailyStats(days: days), previous: previous, models: service.modelStats(days: days),
            recent: service.recentRequests(limit: 20))
    }

    private func total(_ days: [NineRouterService.DayStat]) -> NineRouterService.DayStat {
        days.reduce(into: NineRouterService.DayStat(date: "", requests: 0, input: 0, cached: 0, output: 0, cost: 0)) {
            $0.requests += $1.requests
            $0.input += $1.input
            $0.cached += $1.cached
            $0.output += $1.output
            $0.cost += $1.cost
        }
    }

    // MARK: Chart

    /// One stacked segment of a day's bar.
    private struct Segment: Identifiable {
        let date: String
        let kind: String
        let value: Double
        var id: String { date + kind }
    }

    /// Tokens split into fresh input, cached input and output (promptTokens already includes the cached part);
    /// requests and cost are a single segment.
    private var segments: [Segment] {
        days.flatMap { d -> [Segment] in
            switch metric {
            case .tokens:
                return [
                    Segment(date: d.date, kind: "Input", value: Double(max(0, d.input - d.cached))),
                    Segment(date: d.date, kind: "Cached", value: Double(d.cached)),
                    Segment(date: d.date, kind: "Output", value: Double(d.output)),
                ]
            case .requests: return [Segment(date: d.date, kind: "Requests", value: Double(d.requests))]
            case .cost: return [Segment(date: d.date, kind: "Cost", value: d.cost)]
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(segments) { s in
                BarMark(x: .value("Day", s.date), y: .value(metric.rawValue, s.value), width: .ratio(0.7))
                    .foregroundStyle(by: .value("Kind", s.kind))
                    .opacity(selectedDate == nil || selectedDate == s.date ? 1 : 0.35)
                    .cornerRadius(2)
            }
            if let selectedDate, let day = days.first(where: { $0.date == selectedDate }) {
                RuleMark(x: .value("Day", selectedDate))
                    .foregroundStyle(.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(
                        position: .top, spacing: 2,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        tooltip(day)
                    }
            }
        }
        .chartForegroundStyleScale([
            "Input": Color.orange, "Cached": Color.cyan, "Output": Color.green,
            "Requests": accent.highlight, "Cost": Color.yellow,
        ])
        .chartLegend(metric == .tokens ? .visible : .hidden)
        .chartLegend(position: .top, alignment: .trailing, spacing: 4)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { v in
                AxisValueLabel {
                    if let s = v.as(String.self) { Text(String(s.suffix(5))).font(.system(size: 8)) }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { v in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let n = v.as(Double.self) { Text(format(n)).font(.system(size: 8)) }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .overlay {
            if days.isEmpty {
                Text("No requests in this range").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }

    private func format(_ n: Double) -> String {
        metric == .cost ? formatCost(n) : formatTokens(Int(n))
    }

    private func tooltip(_ d: NineRouterService.DayStat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(d.date).font(.system(size: 9, weight: .bold))
            tooltipRow("Requests", d.requests.formatted(), .primary)
            tooltipRow("Input", formatTokens(d.input), .orange)
            tooltipRow("Cached", formatTokens(d.cached), .cyan)
            tooltipRow("Output", formatTokens(d.output), .green)
            tooltipRow("Cost", formatCost(d.cost), .yellow)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func tooltipRow(_ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value).monospacedDigit()
        }
        .font(.system(size: 9))
        .frame(width: 120)
    }

    // MARK: Side panels

    /// Share of tokens per model in the selected range, top 4 plus the rest.
    private var modelBreakdown: some View {
        let total = max(1, models.reduce(0) { $0 + $1.tokens })
        return VStack(alignment: .leading, spacing: 5) {
            sectionTitle("Top models")
            if models.isEmpty {
                Text("No usage yet").font(.system(size: 9.5)).foregroundStyle(.tertiary)
            }
            ForEach(models.prefix(4)) { m in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if let tool = AgentTool(rawValue: m.provider) { ToolLogo(tool: tool, size: 11) }
                        Text(m.model)
                            .font(.system(size: 9.5, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        Text("\(formatTokens(m.tokens)) · \(formatCost(m.cost))")
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        Capsule().fill(.white.opacity(0.06))
                            .overlay(alignment: .leading) {
                                Capsule().fill(accent.highlight)
                                    .frame(width: geo.size.width * CGFloat(m.tokens) / CGFloat(total))
                            }
                    }
                    .frame(height: 4)
                }
            }
            if models.count > 4 {
                let rest = models.dropFirst(4).reduce(0) { $0 + $1.tokens }
                Text("+\(models.count - 4) more · \(formatTokens(rest))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("Recent requests")
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
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.04)))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    // MARK: Stats

    private var statsRow: some View {
        let now = total(days)
        // An empty previous period still counts (as zero) unless the range is All.
        let before = range.days == nil ? nil : total(previous)
        return HStack(spacing: 6) {
            stat(
                "Requests", now.requests.formatted(), .primary, Double(now.requests), before.map { Double($0.requests) }
            )
            stat("Input", formatTokens(now.input), .orange, Double(now.input), before.map { Double($0.input) })
            stat("Cached", formatTokens(now.cached), .cyan, Double(now.cached), before.map { Double($0.cached) })
            stat("Output", formatTokens(now.output), .green, Double(now.output), before.map { Double($0.output) })
            stat("Est. cost", formatCost(now.cost), .yellow, now.cost, before?.cost)
        }
    }

    /// A total with its change against the previous period of the same length, when there is one.
    private func stat(_ label: String, _ value: String, _ tint: Color, _ now: Double, _ before: Double?) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(tint).lineLimit(1)
            if let change = Self.change(now, before) {
                Text(change)
                    .font(.system(size: 8, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .help("vs the previous \(range.rawValue == "Today" ? "day" : range.rawValue)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.04)))
    }

    /// Local YYYY-MM-DD for `daysAgo` days before today, matching 9router's `dateKey`.
    nonisolated static func dateKey(daysAgo: Int, from now: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now)
    }

    /// "▲ 12%" / "▼ 40%" / "new"; nil without a previous period to compare with.
    static func change(_ now: Double, _ before: Double?) -> String? {
        guard let before else { return nil }
        if before == 0 { return now == 0 ? "–" : "new" }
        let pct = Int(((now - before) / before * 100).rounded())
        if pct == 0 { return "±0%" }
        return pct > 0 ? "▲ \(pct)%" : "▼ \(-pct)%"
    }

    private func segmented<T: RawRepresentable & Hashable>(_ items: [T], selection: Binding<T>) -> some View
    where T.RawValue == String {
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
