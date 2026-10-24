import Foundation
import CryptoKit
import SQLite3

struct NineRouterQuota: Equatable {
    var name: String
    var used: Double
    var total: Double
    var remaining: Double
    var remainingPercentage: Double
    var resetAt: Date?
    var unlimited: Bool

    var isExhausted: Bool {
        if unlimited { return false }
        if total > 0 && used >= total { return true }
        return remainingPercentage <= 0.0
    }
}

struct NineRouterConnection: Identifiable, Equatable {
    var id: String
    var provider: String
    var name: String
    var email: String?
    var priority: Int
    var isActive: Bool
    var authType: String
    var testStatus: String?
    var lastError: String?
    var errorCode: Int?
    var plan: String?
    var quotas: [NineRouterQuota] = []
    var todayTokens: Int = 0
    var todayCost: Double = 0.0
    var days: [Int] = [Int](repeating: 0, count: 7)
}

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
        guard let machineId = try? String(contentsOf: machineIdFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let secret = try? String(contentsOf: cliSecretFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              !machineId.isEmpty, !secret.isEmpty else {
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
               let reset = sessionQuota.resetAt, reset > .now {
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

    private func readConnectionsFromDb() -> [NineRouterConnection] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbFile.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_close(db) }

        var result: [NineRouterConnection] = []
        let query = "SELECT id, provider, authType, name, email, priority, isActive, data FROM providerConnections ORDER BY priority ASC, id ASC;"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(stmt, 0),
                      let provC = sqlite3_column_text(stmt, 1),
                      let authC = sqlite3_column_text(stmt, 2) else { continue }

                let id = String(cString: idC)
                let provider = String(cString: provC)
                let authType = String(cString: authC)
                let name = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                let email = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                let priority = Int(sqlite3_column_int(stmt, 5))
                let isActive = sqlite3_column_int(stmt, 6) == 1

                var testStatus: String? = nil
                var lastError: String? = nil
                var errorCode: Int? = nil

                if let dataC = sqlite3_column_text(stmt, 7) {
                    let jsonStr = String(cString: dataC)
                    if let d = jsonStr.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                        testStatus = obj["testStatus"] as? String
                        lastError = obj["lastError"] as? String
                        errorCode = obj["errorCode"] as? Int
                    }
                }

                result.append(NineRouterConnection(
                    id: id,
                    provider: provider,
                    name: name,
                    email: email,
                    priority: priority,
                    isActive: isActive,
                    authType: authType,
                    testStatus: testStatus,
                    lastError: lastError,
                    errorCode: errorCode
                ))
            }
        }

        return result
    }

    private func enrichWithUsageHistory(connections: inout [NineRouterConnection]) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbFile.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        // Today's usage
        let todaySql = """
        SELECT coalesce(sum(promptTokens + completionTokens), 0), coalesce(sum(cost), 0.0)
        FROM usageHistory
        WHERE connectionId = ? AND date(timestamp, 'localtime') = date('now', 'localtime');
        """

        var todayStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, todaySql, -1, &todayStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(todayStmt) }
            for i in connections.indices {
                sqlite3_reset(todayStmt)
                sqlite3_bind_text(todayStmt, 1, (connections[i].id as NSString).utf8String, -1, nil)
                if sqlite3_step(todayStmt) == SQLITE_ROW {
                    connections[i].todayTokens = Int(sqlite3_column_int64(todayStmt, 0))
                    connections[i].todayCost = sqlite3_column_double(todayStmt, 1)
                }
            }
        }

        // 7-day sparkline
        let daysSql = """
        SELECT date(timestamp, 'localtime') as d, coalesce(sum(promptTokens + completionTokens), 0)
        FROM usageHistory
        WHERE connectionId = ? AND date(timestamp, 'localtime') >= date('now', 'localtime', '-6 days')
        GROUP BY d ORDER BY d ASC;
        """

        var daysStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, daysSql, -1, &daysStmt, nil) == SQLITE_OK {
            defer { sqlite3_finalize(daysStmt) }

            // Build array of last 7 date keys in YYYY-MM-DD
            let cal = Calendar.current
            let now = Date()
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            var dateKeys: [String] = []
            for d in (0..<7).reversed() {
                if let dt = cal.date(byAdding: .day, value: -d, to: now) {
                    dateKeys.append(df.string(from: dt))
                }
            }

            for i in connections.indices {
                sqlite3_reset(daysStmt)
                sqlite3_bind_text(daysStmt, 1, (connections[i].id as NSString).utf8String, -1, nil)
                var map: [String: Int] = [:]
                while sqlite3_step(daysStmt) == SQLITE_ROW {
                    if let dC = sqlite3_column_text(daysStmt, 0) {
                        let dateStr = String(cString: dC)
                        let tokens = Int(sqlite3_column_int64(daysStmt, 1))
                        map[dateStr] = tokens
                    }
                }
                var counts = [Int](repeating: 0, count: 7)
                for (idx, key) in dateKeys.enumerated() {
                    counts[idx] = map[key] ?? 0
                }
                connections[i].days = counts
            }
        }
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
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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
                        let remainingPct = (qDict["remainingPercentage"] as? NSNumber)?.doubleValue ?? (total > 0 ? max(0, 100.0 - (used / total * 100.0)) : 100.0)
                        let unlimited = (qDict["unlimited"] as? Bool) ?? false

                        var resetAt: Date? = nil
                        if let resetStr = qDict["resetAt"] as? String {
                            resetAt = isoFractional.date(from: resetStr) ?? isoPlain.date(from: resetStr)
                        }

                        parsedQuotas.append(NineRouterQuota(
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
              let url = URL(string: "http://127.0.0.1:20128/api/providers/\(id)") else {
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
