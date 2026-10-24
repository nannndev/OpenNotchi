import Foundation

struct UsageTotals: Equatable {
    var tokens = 0
    /// Estimated USD; only models in the price table add to it.
    var cost = 0.0
}

struct RateWindow: Equatable {
    var usedPercent: Double
    var windowMinutes: Int
    var resetsAt: Date

    /// "5h" / "weekly" / "1d" from the window length.
    var label: String {
        if windowMinutes == 10080 { return "weekly" }
        if windowMinutes % 1440 == 0 { return "\(windowMinutes / 1440)d" }
        return windowMinutes % 60 == 0 ? "\(windowMinutes / 60)h" : "\(windowMinutes)m"
    }
}

struct CodexLimits: Equatable {
    var planType: String?
    var primary: RateWindow?
    var secondary: RateWindow?
}

struct UsageReport: Identifiable {
    var account: AIAccount
    var id: UUID { account.id }
    /// False when the folder has no session logs.
    var found = false
    var today = UsageTotals()
    /// The running 5-hour block (Claude Code).
    var block: (start: Date, tokens: UsageTotals)?
    /// Tokens per local day, oldest first, today last.
    var days = [Int](repeating: 0, count: 7)
    var limits: CodexLimits?
}

/// Token usage from Claude Code and Codex logs. Pure helpers are static so they can be self-checked.
enum AIUsage {
    struct Entry {
        var ts: Date
        var model: String
        /// message.id + requestId: Claude Code logs the same message several times.
        var key: String
        /// input, output, cache write, cache read
        var tokens: [Int]
        var total: Int { tokens.reduce(0, +) }
    }

    /// USD per million tokens: input, output, cache write (5 min), cache read. Most specific id first.
    static let prices: [(String, [Double])] = [
        ("claude-fable-5-1", [10, 50, 12.5, 0.25]),
        ("claude-mythos-5-1", [10, 50, 12.5, 0.25]),
        ("claude-fable-5", [10, 50, 12.5, 1]),
        ("claude-mythos-5", [10, 50, 12.5, 1]),
        ("claude-opus-5-5", [4, 20, 5, 0.2]),
        ("claude-opus-5", [5, 25, 6.25, 0.5]),
        ("claude-opus-4-8", [5, 25, 6.25, 0.5]),
        ("claude-opus-4-7", [5, 25, 6.25, 0.5]),
        ("claude-opus-4-6", [5, 25, 6.25, 0.5]),
        ("claude-opus-4-5", [5, 25, 6.25, 0.5]),
        ("claude-sonnet-5-5", [2, 10, 2.5, 0.2]),
        ("claude-sonnet-5", [2, 10, 2.5, 0.2]),
        ("claude-sonnet-4", [3, 15, 3.75, 0.3]),
        ("claude-haiku-5-5", [0.1, 0.5, 0.125, 0.01]),
        ("claude-haiku-4-5", [1, 5, 1.25, 0.1]),
    ]

    static func cost(_ e: Entry) -> Double {
        guard let p = prices.first(where: { e.model.contains($0.0) })?.1 else { return 0 }
        return zip(e.tokens, p).reduce(0) { $0 + Double($1.0) * $1.1 / 1e6 }
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static func date(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s) ?? isoPlain.date(from: s)
    }

    static func parseClaudeLine(_ line: some StringProtocol) -> Entry? {
        guard line.contains("\"usage\""), let v = jsonObject(line), v["type"] as? String == "assistant",
              let m = v["message"] as? [String: Any], let u = m["usage"] as? [String: Any],
              let id = m["id"] as? String, let ts = date(v["timestamp"] as? String) else { return nil }
        // Newer Claude Code versions log `requestRef` instead of `requestId`.
        let req = v["requestId"] as? String ?? v["requestRef"] as? String ?? ""
        let n = { (k: String) in u[k] as? Int ?? 0 }
        return Entry(ts: ts, model: m["model"] as? String ?? "", key: "\(id):\(req)",
                     tokens: [n("input_tokens"), n("output_tokens"), n("cache_creation_input_tokens"), n("cache_read_input_tokens")])
    }

    /// One entry per key (the last logged copy, with final output tokens), sorted by time.
    static func dedupe(_ entries: [Entry]) -> [Entry] {
        Dictionary(entries.map { ($0.key, $0) }, uniquingKeysWith: { _, last in last }).values.sorted { $0.ts < $1.ts }
    }

    /// Start of the 5-hour block holding the latest entry, if it's still running (ccusage rules: a block
    /// starts at the first message after a ≥5 h gap or after the previous block ends, floored to the hour).
    static func blockStart(_ sorted: [Date], now: Date) -> Date? {
        let fiveH: TimeInterval = 5 * 3600
        var start: Date?, last = Date.distantPast
        for t in sorted {
            if start == nil || t >= start!.addingTimeInterval(fiveH) || t.timeIntervalSince(last) >= fiveH {
                start = Date(timeIntervalSince1970: (t.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
            }
            last = t
        }
        guard let start, now < start.addingTimeInterval(fiveH), now.timeIntervalSince(last) < fiveH else { return nil }
        return start
    }

    /// A Codex `token_count` event: (time, tokens of that turn, rate limits if reported).
    static func parseCodexLine(_ line: some StringProtocol) -> (Date, Int, CodexLimits?)? {
        guard let v = jsonObject(line), let p = v["payload"] as? [String: Any], p["type"] as? String == "token_count",
              let ts = date(v["timestamp"] as? String) else { return nil }
        let last = (p["info"] as? [String: Any])?["last_token_usage"] as? [String: Any] ?? [:]
        let tokens = last["total_tokens"] as? Int ?? (last["input_tokens"] as? Int ?? 0) + (last["output_tokens"] as? Int ?? 0)
        let rl = p["rate_limits"] as? [String: Any] ?? [:]
        func window(_ k: String) -> RateWindow? {
            guard let w = rl[k] as? [String: Any], let used = (w["used_percent"] as? NSNumber)?.doubleValue else { return nil }
            return RateWindow(usedPercent: used, windowMinutes: w["window_minutes"] as? Int ?? 0,
                              resetsAt: Date(timeIntervalSince1970: (w["resets_at"] as? NSNumber)?.doubleValue ?? 0))
        }
        let limits = CodexLimits(planType: rl["plan_type"] as? String, primary: window("primary"), secondary: window("secondary"))
        return (ts, tokens, limits.primary == nil && limits.secondary == nil ? nil : limits)
    }

    // MARK: Scanning

    /// Parsed entries per transcript; logs are append-only, so only new bytes are read on a rescan.
    private static var fileCache: [URL: (offset: UInt64, entries: [Entry])] = [:]
    private static let lock = NSLock()

    private static func entries(of url: URL, size: UInt64) -> [Entry] {
        var (offset, entries) = fileCache[url].flatMap { $0.offset <= size ? $0 : nil } ?? (0, [])
        if offset < size, let h = try? FileHandle(forReadingFrom: url) {
            defer { try? h.close() }
            try? h.seek(toOffset: offset)
            let data = (try? h.read(upToCount: Int(size - offset))) ?? Data()
            // Only complete lines; a half-written last line is read again next time.
            if let nl = data.lastIndex(of: UInt8(ascii: "\n")) {
                let complete = data[..<data.index(after: nl)]
                entries += complete.split(separator: UInt8(ascii: "\n")).compactMap { parseClaudeLine(String(decoding: $0, as: UTF8.self)) }
                offset += UInt64(complete.count)
            }
        }
        fileCache[url] = (offset, entries)
        return entries
    }

    private static func daysAgo(_ date: Date, now: Date) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 99
    }

    static func claudeReport(_ account: AIAccount, now: Date = .now) -> UsageReport {
        lock.lock(); defer { lock.unlock() }
        let weekAgo = now.addingTimeInterval(-8 * 86400)
        let logs = AgentLogs.claudeLogs(account.url, recursive: true)
        var all: [Entry] = []
        for (url, mtime) in logs where mtime >= weekAgo {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init) ?? 0
            all += entries(of: url, size: size)
        }
        let list = dedupe(all.filter { $0.ts >= weekAgo })
        var r = UsageReport(account: account, found: !logs.isEmpty)
        for e in list {
            let ago = daysAgo(e.ts, now: now)
            if (0..<7).contains(ago) { r.days[6 - ago] += e.total }
            if ago == 0 { r.today.tokens += e.total; r.today.cost += cost(e) }
        }
        if let start = blockStart(list.map(\.ts), now: now) {
            var t = UsageTotals()
            for e in list where e.ts >= start { t.tokens += e.total; t.cost += cost(e) }
            r.block = (start, t)
        }
        return r
    }

    static func codexReport(_ account: AIAccount, now: Date = .now) -> UsageReport {
        var r = UsageReport(account: account)
        var latest: (Date, CodexLimits)?
        // Eight day folders cover the weekly window and a local "today" that spans two UTC dates.
        for day in AgentLogs.codexDayDirs(account.url, 8) {
            for (url, mtime) in AgentLogs.jsonlFiles(in: day) {
                r.found = true
                guard mtime >= now.addingTimeInterval(-8 * 86400), let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                for line in text.split(separator: "\n") where line.contains("token_count") {
                    guard let (ts, tokens, limits) = parseCodexLine(line) else { continue }
                    let ago = daysAgo(ts, now: now)
                    if (0..<7).contains(ago) { r.days[6 - ago] += tokens }
                    if let limits, latest.map({ ts > $0.0 }) ?? true { latest = (ts, limits) }
                }
            }
        }
        r.today.tokens = r.days[6]
        r.limits = latest?.1
        return r
    }

    static func report(_ account: AIAccount, now: Date = .now) -> UsageReport {
        account.tool == .codex ? codexReport(account, now: now) : claudeReport(account, now: now)
    }
}

/// Usage per configured account, rescanned at most every 60 s while AI features are on.
final class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    @Published private(set) var reports: [UsageReport] = []
    private var timer: Timer?
    private var accounts: [AIAccount] = []
    private var lastScan = Date.distantPast
    private var scanning = false

    func configure(enabled: Bool, accounts: [AIAccount]) {
        let changed = accounts != self.accounts
        self.accounts = accounts
        guard enabled else {
            timer?.invalidate()
            timer = nil
            reports = []
            return
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.refresh() }
        }
        if changed { lastScan = .distantPast }
        refresh()
    }

    func refresh() {
        guard !scanning, Date.now.timeIntervalSince(lastScan) >= 55 else { return }
        scanning = true
        lastScan = .now
        let accounts = accounts
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let reports = accounts.map { AIUsage.report($0) }
            DispatchQueue.main.async {
                self?.reports = reports
                self?.scanning = false
            }
        }
    }

    /// The compact closed-notch meter: a Codex window at ≥ 80 %, else an active Claude block's elapsed share.
    var closedMeter: (label: String, fraction: Double, hot: Bool)? {
        for r in reports {
            for w in [r.limits?.primary, r.limits?.secondary].compactMap({ $0 }) where w.usedPercent >= 80 && w.resetsAt > .now {
                return ("\(w.label) \(Int(w.usedPercent.rounded()))%", w.usedPercent / 100, true)
            }
        }
        guard let block = reports.compactMap(\.block).first(where: { $0.start.addingTimeInterval(5 * 3600) > .now }) else { return nil }
        return (formatTokens(block.tokens.tokens), Date.now.timeIntervalSince(block.start) / (5 * 3600), false)
    }
}

/// 1234 → "1.2K", 93176220 → "93M".
func formatTokens(_ n: Int) -> String {
    guard n >= 1000 else { return "\(n)" }
    let (v, unit): (Double, String) = n < 1_000_000 ? (Double(n) / 1e3, "K") : n < 1_000_000_000 ? (Double(n) / 1e6, "M") : (Double(n) / 1e9, "B")
    return (v < 10 ? String(format: "%.1f", v) : "\(Int(v.rounded()))").replacingOccurrences(of: ".0", with: "") + unit
}

func formatCost(_ usd: Double) -> String {
    usd >= 100 ? "$\(Int(usd.rounded()))" : String(format: "$%.2f", usd)
}

/// "resets in 3h 20m" / "resets in 2d".
func resetsIn(_ date: Date, now: Date = .now) -> String {
    let m = max(0, Int((date.timeIntervalSince(now) / 60).rounded()))
    if m >= 2880 { return "resets in \(Int((Double(m) / 1440).rounded()))d" }
    if m >= 60 { return "resets in \(m / 60)h" + (m % 60 > 0 ? " \(m % 60)m" : "") }
    return "resets in \(m)m"
}
