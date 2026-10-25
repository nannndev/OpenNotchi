import AppKit
import CryptoKit
import SQLite3

/// Service to interact directly with 9router daemon (port 20128) and SQLite database (~/.9router/db/data.sqlite).
final class NineRouterService {
    static let shared = NineRouterService()

    private let fileManager = FileManager.default
    private var homeDir: URL { fileManager.homeDirectoryForCurrentUser }
    private var routerDir: URL { homeDir.appendingPathComponent(".9router") }
    private var dbFile: URL { routerDir.appendingPathComponent("db/data.sqlite") }
    private var machineIdFile: URL { routerDir.appendingPathComponent("machine-id") }
    private var cliSecretFile: URL { routerDir.appendingPathComponent("auth/cli-secret") }

    var isAvailable: Bool {
        fileManager.fileExists(atPath: dbFile.path)
    }

    private init() {}

    /// Computes the x-9r-cli-token required by 9router's local daemon API:
    /// SHA256(machineId + "9r-cli-auth" + cliSecret)[0..<16]
    func getAuthToken() -> String? {
        guard
            let machineId = try? String(contentsOf: machineIdFile, encoding: .utf8).trimmingCharacters(
                in: .whitespacesAndNewlines),
            let secret = try? String(contentsOf: cliSecretFile, encoding: .utf8).trimmingCharacters(
                in: .whitespacesAndNewlines),
            !machineId.isEmpty, !secret.isEmpty
        else {
            return nil
        }
        let raw = machineId + "9r-cli-auth" + secret
        let digest = SHA256.hash(data: Data(raw.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }

    /// Fetches all accounts / connections from 9router and builds their reports.
    func fetchReports() -> [UsageReport] {
        guard isAvailable else { return [] }

        // 1. Read all connections from SQLite
        var connections = readConnectionsFromDb()
        guard !connections.isEmpty else { return [] }

        // 2. Query token usage and daily history from SQLite for all connections
        enrichWithUsageHistory(connections: &connections)

        // 3. If 9router daemon is running, augment with live quota data
        enrichWithLiveQuotas(connections: &connections)

        // 4. Map each connection to a UsageReport
        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return connections.map { conn in
            let tool: AgentTool
            switch conn.provider.lowercased() {
            case "codex": tool = .codex
            case "antigravity": tool = .antigravity
            case "commandcode": tool = .commandcode
            default: tool = .claude
            }

            let displayName: String
            if !conn.name.isEmpty && conn.name != "-" {
                displayName = conn.name
            } else if let email = conn.email, !email.isEmpty {
                displayName = email
            } else {
                displayName = tool.displayName
            }

            let account = AIAccount(
                id: UUID(uuidString: conn.id) ?? UUID(),
                name: displayName,
                tool: tool,
                dir: "~/.9router",
                connectionId: conn.id,
                email: conn.email,
                priority: conn.priority,
                isActive: conn.isActive
            )

            var report = UsageReport(account: account, found: true)
            report.today = UsageTotals(tokens: conn.todayTokens, cost: conn.todayCost)
            report.days = conn.days
            report.quotas = conn.quotas
            report.planName = conn.plan
            report.testStatus = conn.testStatus
            report.lastError = conn.lastError
            report.isFrom9Router = true

            // Set running 5h block if active
            if let sessionQuota = conn.quotas.first(where: { $0.name.contains("session") || $0.name.contains("5h") }),
                let reset = sessionQuota.resetAt, reset > .now
            {
                let start = reset.addingTimeInterval(-5 * 3600)
                report.block = (start: start, tokens: UsageTotals(tokens: conn.todayTokens, cost: conn.todayCost))
            }

            // Set Codex rate limits if Codex
            if tool == .codex {
                var primaryWindow: RateWindow?
                var secondaryWindow: RateWindow?
                for q in conn.quotas {
                    let w = RateWindow(
                        usedPercent: 100.0 - q.remainingPercentage,
                        windowMinutes: q.name.contains("weekly") ? 10080 : 300,
                        resetsAt: q.resetAt ?? .now
                    )
                    if q.name.contains("session") || q.name.contains("5h") || primaryWindow == nil {
                        primaryWindow = w
                    } else {
                        secondaryWindow = w
                    }
                }
                report.limits = CodexLimits(planType: conn.plan, primary: primaryWindow, secondary: secondaryWindow)
            }

            return report
        }
    }

    // MARK: - SQLite Direct Access

    /// Runs `sql` read-only against 9router's database, calling `row` for each result row.
    /// Returns false when the database can't be opened or the query is invalid.
    @discardableResult
    private func query(_ sql: String, _ args: [Any] = [], row: (Row) -> Void) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbFile.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return false
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            switch arg {
            case let n as Int: sqlite3_bind_int64(stmt, Int32(i + 1), Int64(n))
            default: sqlite3_bind_text(stmt, Int32(i + 1), "\(arg)", -1, Self.transient)
            }
        }
        while sqlite3_step(stmt) == SQLITE_ROW { row(Row(stmt: stmt)) }
        return true
    }

    /// One result row; NULL columns read as nil / 0 instead of crashing.
    /// SQLite's SQLITE_TRANSIENT (copy the bound text now); the C macro doesn't import into Swift.
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private struct Row {
        let stmt: OpaquePointer?
        func text(_ i: Int32) -> String? { sqlite3_column_text(stmt, i).map { String(cString: $0) } }
        func int(_ i: Int32) -> Int { Int(sqlite3_column_int64(stmt, i)) }
        func double(_ i: Int32) -> Double { sqlite3_column_double(stmt, i) }
    }

    private func readConnectionsFromDb() -> [NineRouterConnection] {
        var result: [NineRouterConnection] = []
        query(
            "SELECT id, provider, authType, name, email, priority, isActive, data FROM providerConnections ORDER BY priority ASC, id ASC;"
        ) { r in
            guard let id = r.text(0), let provider = r.text(1), let authType = r.text(2) else { return }
            let data = r.text(7).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
            result.append(
                NineRouterConnection(
                    id: id,
                    provider: provider,
                    name: r.text(3) ?? "",
                    email: r.text(4),
                    priority: r.int(5),
                    isActive: r.int(6) == 1,
                    authType: authType,
                    testStatus: data?["testStatus"] as? String,
                    lastError: data?["lastError"] as? String,
                    errorCode: data?["errorCode"] as? Int
                ))
        }
        return result
    }

    private func enrichWithUsageHistory(connections: inout [NineRouterConnection]) {
        // Last 7 local dates, oldest first, as YYYY-MM-DD to match SQLite's date().
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateKeys = (0..<7).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) }
            .map(df.string)

        for i in connections.indices {
            let id = connections[i].id
            query(
                """
                SELECT coalesce(sum(promptTokens + completionTokens), 0), coalesce(sum(cost), 0.0)
                FROM usageHistory
                WHERE connectionId = ? AND date(timestamp, 'localtime') = date('now', 'localtime');
                """, [id]
            ) { r in
                connections[i].todayTokens = r.int(0)
                connections[i].todayCost = r.double(1)
            }

            var tokensByDay: [String: Int] = [:]
            let ok = query(
                """
                SELECT date(timestamp, 'localtime') as d, coalesce(sum(promptTokens + completionTokens), 0)
                FROM usageHistory
                WHERE connectionId = ? AND date(timestamp, 'localtime') >= date('now', 'localtime', '-6 days')
                GROUP BY d ORDER BY d ASC;
                """, [id]
            ) { r in
                if let d = r.text(0) { tokensByDay[d] = r.int(1) }
            }
            if ok { connections[i].days = dateKeys.map { tokensByDay[$0] ?? 0 } }
        }
    }

    /// Today's tokens and cost per model across every 9router account, biggest first.
    func todayModels(limit: Int = 5) -> [(model: String, tokens: Int, cost: Double)] {
        var rows: [(model: String, tokens: Int, cost: Double)] = []
        query(
            """
            SELECT coalesce(model, '?'), coalesce(sum(promptTokens + completionTokens), 0), coalesce(sum(cost), 0.0)
            FROM usageHistory
            WHERE date(timestamp, 'localtime') = date('now', 'localtime')
            GROUP BY model ORDER BY 2 DESC LIMIT ?;
            """, [limit]
        ) { r in
            rows.append((r.text(0) ?? "?", r.int(1), r.double(2)))
        }
        return rows
    }

    struct DayStat: Identifiable {
        var date: String
        var requests: Int
        var input: Int
        var cached: Int
        var output: Int
        var cost: Double
        var id: String { date }
    }

    struct RecentRequest: Identifiable {
        var id: Int64
        var date: Date
        var model: String
        var provider: String
        var input: Int
        var output: Int
        var ok: Bool
    }

    /// Daily totals from 9router's `usageDaily` rollup, oldest first. `days` nil means all history.
    func dailyStats(days: Int?) -> [DayStat] {
        var rows: [DayStat] = []
        query(
            """
            SELECT dateKey,
                   coalesce(json_extract(data, '$.requests'), 0),
                   coalesce(json_extract(data, '$.promptTokens'), 0),
                   coalesce((SELECT sum(json_extract(value, '$.cachedTokens')) FROM json_each(data, '$.byProvider')), 0),
                   coalesce(json_extract(data, '$.completionTokens'), 0),
                   coalesce(json_extract(data, '$.cost'), 0.0)
            FROM usageDaily
            WHERE dateKey >= date('now', 'localtime', ?)
            ORDER BY dateKey ASC;
            """, ["-\((days ?? 100_000) - 1) days"]
        ) { r in
            guard let date = r.text(0) else { return }
            rows.append(
                DayStat(
                    date: date, requests: r.int(1), input: r.int(2), cached: r.int(3), output: r.int(4),
                    cost: r.double(5)))
        }
        return rows
    }

    /// Latest routed requests, newest first.
    func recentRequests(limit: Int = 20) -> [RecentRequest] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var rows: [RecentRequest] = []
        query(
            "SELECT id, timestamp, coalesce(model, '?'), coalesce(provider, ''), promptTokens, completionTokens, coalesce(status, '') FROM usageHistory ORDER BY id DESC LIMIT ?;",
            [limit]
        ) { r in
            rows.append(
                RecentRequest(
                    id: Int64(r.int(0)),
                    date: r.text(1).flatMap(iso.date) ?? .distantPast,
                    model: r.text(2) ?? "?",
                    provider: r.text(3) ?? "",
                    input: r.int(4),
                    output: r.int(5),
                    ok: r.text(6) == "ok"
                ))
        }
        return rows
    }

    /// The local OpenAI-compatible endpoint 9router serves.
    static let baseURL = "http://127.0.0.1:20128/v1"

    /// First active 9router API key, so Ask AI can call the local endpoint without the user pasting it.
    func apiKey() -> String? {
        var key: String?
        query("SELECT key FROM apiKeys WHERE isActive = 1 ORDER BY createdAt ASC LIMIT 1;") { key = $0.text(0) }
        return key
    }

    /// Model ids 9router can route to right now (e.g. "cc/claude-sonnet-5-5"), empty when the daemon is down.
    func models() async -> [String] {
        guard let url = URL(string: Self.baseURL + "/models"),
            let (data, _) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 3)),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]]
        else { return [] }
        return list.compactMap { $0["id"] as? String }
    }

    // MARK: - Live Quota from 9router HTTP Daemon

    /// Pool quotas 9router reports alongside the per-model ones, with the labels its dashboard uses.
    /// Antigravity reports every model separately and also these pools; the models in a pool always share its numbers.
    static let poolLabels: [(key: String, label: String)] = [
        ("gemini_session", "Gemini (5h)"),
        ("claude_gpt_session", "Claude & GPT (5h)"),
        ("gemini_weekly", "Gemini (Weekly)"),
        ("claude_gpt_weekly", "Claude & GPT (Weekly)"),
    ]

    /// Shows only the pools when 9router reports them (like its dashboard), otherwise every quota by name.
    static func displayQuotas(_ quotas: [NineRouterQuota]) -> [NineRouterQuota] {
        let pools = poolLabels.compactMap { pool -> NineRouterQuota? in
            guard var q = quotas.first(where: { $0.name == pool.key }) else { return nil }
            q.name = pool.label
            return q
        }
        return pools.isEmpty ? quotas.sorted { $0.name < $1.name } : pools
    }

    private func enrichWithLiveQuotas(connections: inout [NineRouterConnection]) {
        guard let token = getAuthToken() else { return }

        let isoFractional = ISO8601DateFormatter()
        isoFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()

        let group = DispatchGroup()
        let lock = NSLock()
        var liveData: [String: (plan: String?, quotas: [NineRouterQuota])] = [:]

        for conn in connections {
            let connId = conn.id
            guard let url = URL(string: "http://127.0.0.1:20128/api/usage/\(connId)") else { continue }

            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2.0)
            request.addValue(token, forHTTPHeaderField: "x-9r-cli-token")

            group.enter()
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { group.leave() }
                guard let data, let http = response as? HTTPURLResponse, http.statusCode == 200,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    return
                }

                let plan = json["plan"] as? String
                var parsedQuotas: [NineRouterQuota] = []

                if let quotasObj = json["quotas"] as? [String: Any] {
                    for (qName, qVal) in quotasObj {
                        guard let qDict = qVal as? [String: Any] else { continue }
                        let used = (qDict["used"] as? NSNumber)?.doubleValue ?? 0.0
                        let total = (qDict["total"] as? NSNumber)?.doubleValue ?? 0.0
                        let remaining = (qDict["remaining"] as? NSNumber)?.doubleValue ?? 0.0
                        let remainingPct =
                            (qDict["remainingPercentage"] as? NSNumber)?.doubleValue
                            ?? (total > 0 ? max(0, 100.0 - (used / total * 100.0)) : 100.0)
                        let unlimited = (qDict["unlimited"] as? Bool) ?? false

                        var resetAt: Date? = nil
                        if let resetStr = qDict["resetAt"] as? String {
                            resetAt = isoFractional.date(from: resetStr) ?? isoPlain.date(from: resetStr)
                        }

                        parsedQuotas.append(
                            NineRouterQuota(
                                name: qName,
                                used: used,
                                total: total,
                                remaining: remaining,
                                remainingPercentage: remainingPct,
                                resetAt: resetAt,
                                unlimited: unlimited
                            ))
                    }
                }

                lock.lock()
                liveData[connId] = (plan: plan, quotas: Self.displayQuotas(parsedQuotas))
                lock.unlock()
            }
            task.resume()
        }

        _ = group.wait(timeout: .now() + 2.5)

        for i in connections.indices {
            if let entry = liveData[connections[i].id] {
                if let plan = entry.plan {
                    connections[i].plan = plan
                }
                if !entry.quotas.isEmpty {
                    connections[i].quotas = entry.quotas
                }
            }
        }
    }

    // MARK: - Toggle Connection Active State

    func setConnectionActive(id: String, active: Bool, completion: ((Bool) -> Void)? = nil) {
        // 1. Direct SQLite update
        var db: OpaquePointer?
        if sqlite3_open_v2(dbFile.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK {
            var stmt: OpaquePointer?
            let sql = "UPDATE providerConnections SET isActive = ?, updatedAt = datetime('now') WHERE id = ?;"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, active ? 1 : 0)
                sqlite3_bind_text(stmt, 2, (id as NSString).utf8String, -1, nil)
                _ = sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
            sqlite3_close(db)
        }

        // 2. Notify 9router daemon via HTTP PUT
        guard let token = getAuthToken(),
            let url = URL(string: "http://127.0.0.1:20128/api/providers/\(id)")
        else {
            completion?(true)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue(token, forHTTPHeaderField: "x-9r-cli-token")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["isActive": active])

        URLSession.shared.dataTask(with: request) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                completion?(ok)
            }
        }.resume()
    }
}
