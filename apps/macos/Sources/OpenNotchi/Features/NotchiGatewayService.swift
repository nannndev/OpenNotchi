import Foundation
import SQLite3

struct GatewayProviderInfo: Identifiable, Decodable {
    let id: String
    let alias: String
    let name: String
    let family: String
    let defaultBaseUrl: String?
    let baseUrl: String?
    let needsKey: Bool
    let enabled: Bool
    let connected: Bool
    let models: [String]
    let customModels: [String]?
    let seedModels: [String]?
    let latencyMs: Int?
    let error: String?
    let syncedCount: Int?
    let modelsSyncedAt: Double?

    enum CodingKeys: String, CodingKey {
        case id, alias, name, family, enabled, connected, models, error
        case syncedCount = "synced_count"
        case modelsSyncedAt = "models_synced_at"
        case defaultBaseUrl = "default_base_url"
        case baseUrl = "base_url"
        case needsKey = "needs_key"
        case customModels = "custom_models"
        case seedModels = "seed_models"
        case latencyMs = "latency_ms"
    }
}

struct GatewayOAuthProviderMeta: Identifiable, Decodable {
    let id: String
    let alias: String
    let name: String
}

struct GatewayStats: Decodable {
    let requests: Int
    let inputTokens: Int
    let outputTokens: Int
    let errors: Int
    let activeKeys: Int
    let connectedProviders: Int

    enum CodingKeys: String, CodingKey {
        case requests, errors
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case activeKeys = "active_keys"
        case connectedProviders = "connected_providers"
    }
}

struct GatewayOAuthStart {
    let sessionId: String
    let authUrl: String?
    let userCode: String?
    let flow: String
    let intervalSeconds: Int
}

struct GatewayOAuthAccount: Identifiable, Decodable {
    let id: String
    let provider: String
    let label: String?
    let email: String?
    let enabled: Bool
    let plan: String?
    let isFree: Bool?
    let coolingUntil: Double?

    enum CodingKeys: String, CodingKey {
        case id, provider, label, email, enabled, plan
        case isFree = "is_free"
        case coolingUntil = "cooling_until"
    }

    var displayName: String {
        if let label, !label.isEmpty { return label }
        if let email, !email.isEmpty { return email }
        return id
    }
}

struct GatewayRoutingSettings: Decodable {
    var routingStrategy: String
    var fallbackOrder: String
    var providerPriority: [String]
    var autoModelsPerProvider: Int
    var cooldownSecs: Int

    enum CodingKeys: String, CodingKey {
        case routingStrategy = "routing_strategy"
        case fallbackOrder = "fallback_order"
        case providerPriority = "provider_priority"
        case autoModelsPerProvider = "auto_models_per_provider"
        case cooldownSecs = "cooldown_secs"
    }
}

struct GatewayRoutingState: Decodable {
    var settings: GatewayRoutingSettings
    /// Effective provider order `auto` uses right now (connected providers only).
    var autoOrder: [String]

    enum CodingKeys: String, CodingKey {
        case settings
        case autoOrder = "auto_order"
    }
}

struct GatewayAccountsState: Decodable {
    let accounts: [GatewayOAuthAccount]
    let models: [String: [String]]
    let aliases: [String: String]
    let providerEnabled: [String: Bool]?
    let providers: [GatewayOAuthProviderMeta]?

    enum CodingKeys: String, CodingKey {
        case accounts, models, aliases, providers
        case providerEnabled = "provider_enabled"
    }
}

/// Manages the bundled/local `notchi-gateway` Rust daemon and its HTTP admin/inference APIs.
final class NotchiGatewayService: ObservableObject {
    static let shared = NotchiGatewayService()

    static let defaultPort = 20129
    static let baseURL = "http://127.0.0.1:\(defaultPort)"
    static let v1BaseURL = "\(baseURL)/v1"

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var process: Process?
    private let lock = NSLock()
    private let fileManager = FileManager.default

    private init() {}

    /// Locates the `notchi-gateway` binary in the app bundle or local dev paths.
    var binaryURL: URL? {
        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            let bundled = exeDir.appendingPathComponent("notchi-gateway")
            if fileManager.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }
        let bundleMacOS = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/notchi-gateway")
        if fileManager.isExecutableFile(atPath: bundleMacOS.path) {
            return bundleMacOS
        }

        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/notchi-gateway"),
            URL(fileURLWithPath: "/usr/local/bin/notchi-gateway"),
            URL(fileURLWithPath: "/opt/homebrew/bin/notchi-gateway"),
        ]
        for url in candidates where fileManager.isExecutableFile(atPath: url.path) {
            return url
        }

        // Dev fallback when running from the OpenNotchi repo (`apps/macos` -> `apps/gateway`).
        var dir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        for _ in 0..<5 {
            for profile in ["release", "debug"] {
                let candidate = dir.appendingPathComponent("apps/gateway/target/\(profile)/notchi-gateway")
                if fileManager.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    var isAvailable: Bool {
        binaryURL != nil || isRunning
    }

    func startIfNeeded() {
        Task { await ensureRunning() }
    }

    @discardableResult
    func ensureRunning() async -> Bool {
        if await checkHealth() {
            await MainActor.run {
                self.isRunning = true
                self.lastError = nil
            }
            return true
        }

        guard let bin = binaryURL else {
            await MainActor.run {
                self.isRunning = false
                self.lastError = "notchi-gateway binary not found"
            }
            return false
        }

        let started: Bool = lock.withLock {
            if let p = process, p.isRunning {
                return true
            }
            let p = Process()
            p.executableURL = bin
            p.arguments = ["--port", "\(Self.defaultPort)"]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            p.terminationHandler = { [weak self] _ in
                Task { @MainActor in
                    self?.isRunning = false
                }
            }
            do {
                try p.run()
                self.process = p
                return true
            } catch {
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                    self.isRunning = false
                }
                return false
            }
        }

        guard started else { return false }

        // Wait briefly for the HTTP server to bind.
        for _ in 0..<15 {
            if await checkHealth() {
                await MainActor.run {
                    self.isRunning = true
                    self.lastError = nil
                }
                return true
            }
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        await MainActor.run {
            self.isRunning = false
            self.lastError = "Timed out waiting for notchi-gateway on port \(Self.defaultPort)"
        }
        return false
    }

    func stop() {
        lock.withLock {
            if let p = process, p.isRunning {
                p.terminate()
            }
            process = nil
        }
        Task { @MainActor in
            self.isRunning = false
        }
    }

    func restart() async {
        stop()
        try? await Task.sleep(nanoseconds: 250_000_000)
        _ = await ensureRunning()
    }

    func checkHealth() async -> Bool {
        guard let url = URL(string: "\(Self.baseURL)/health") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - Models & Providers Admin APIs

    func models() async -> [String] {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.v1BaseURL)/models") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let list = json["data"] as? [[String: Any]] {
                return list.compactMap { $0["id"] as? String }
            }
        } catch {}
        return []
    }

    func fetchProviders() async -> [GatewayProviderInfo] {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let wrapper = try? JSONDecoder().decode([String: [GatewayProviderInfo]].self, from: data),
               let providers = wrapper["providers"] {
                return providers
            }
            return (try? JSONDecoder().decode([GatewayProviderInfo].self, from: data)) ?? []
        } catch {
            return []
        }
    }

    func fetchAccountsState() async -> GatewayAccountsState? {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(GatewayAccountsState.self, from: data)
        } catch {
            return nil
        }
    }

    func toggleProvider(id: String, enabled: Bool? = nil) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(id)/toggle") else { return }
        var body: [String: Any] = [:]
        if let enabled { body["enabled"] = enabled }
        try await sendJSON(url: url, method: "PATCH", body: body)
    }

    func toggleAccount(provider: String, id: String, enabled: Bool? = nil) async throws {
        _ = await ensureRunning()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/\(encodedId)/toggle") else { return }
        var body: [String: Any] = [:]
        if let enabled { body["enabled"] = enabled }
        try await sendJSON(url: url, method: "PATCH", body: body)
    }

    func addProviderModel(providerId: String, model: String) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(providerId)/models") else { return }
        try await sendJSON(url: url, method: "POST", body: ["model": model])
    }

    func removeProviderModel(providerId: String, model: String) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(providerId)/models") else { return }
        try await sendJSON(url: url, method: "DELETE", body: ["model": model])
    }

    func saveProviderKey(providerId: String, apiKey: String) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(providerId)/key") else { return }
        try await sendJSON(url: url, method: "POST", body: ["api_key": apiKey])
    }

    func connectProvider(id: String, apiKey: String, baseUrl: String? = nil) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(id)/connect") else { return }
        var body: [String: Any] = ["api_key": apiKey]
        if let baseUrl, !baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["base_url"] = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        try await sendJSON(url: url, method: "POST", body: body)
    }

    /// Connects a provider with the key its own CLI/desktop app saved locally (Command Code, MiMo).
    func importLocalKey(providerId: String) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(providerId)/import") else { return }
        _ = try await sendJSONReturningDict(url: url, method: "POST", body: [:])
    }

    func disconnectProvider(id: String) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(id)/disconnect") else { return }
        try await sendJSON(url: url, method: "POST", body: [:])
    }

    func fetchStats() async -> GatewayStats? {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/stats") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(GatewayStats.self, from: data)
        } catch {
            return nil
        }
    }

    func startOAuth(provider: String) async throws -> GatewayOAuthStart {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/start") else {
            throw AIError("Invalid gateway OAuth URL")
        }
        let json = try await sendJSONReturningDict(url: url, method: "POST", body: [:])
        let sessionId = json["session_id"] as? String ?? ""
        if sessionId.isEmpty {
            let err = json["error"] as? String ?? json["message"] as? String ?? "Failed to start OAuth flow"
            throw AIError(err)
        }
        let authUrl = json["auth_url"] as? String ?? json["verification_uri_complete"] as? String ?? json["verification_uri"] as? String
        let userCode = json["user_code"] as? String
        let flow = json["flow"] as? String ?? (userCode != nil ? "device" : "pkce")
        let interval = json["interval"] as? Int ?? 5
        return GatewayOAuthStart(sessionId: sessionId, authUrl: authUrl, userCode: userCode, flow: flow, intervalSeconds: max(2, interval))
    }

    func pollOAuth(provider: String, sessionId: String) async throws -> String {
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/poll") else {
            throw AIError("Invalid poll URL")
        }
        let json = try await sendJSONReturningDict(url: url, method: "POST", body: ["session_id": sessionId])
        return json["status"] as? String ?? "pending"
    }

    func completeOAuth(provider: String, sessionId: String, callback: String) async throws {
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/complete") else {
            throw AIError("Invalid complete URL")
        }
        _ = try await sendJSONReturningDict(url: url, method: "POST", body: [
            "session_id": sessionId,
            "callback": callback,
        ])
    }

    /// Re-fetches a provider's model list from upstream; returns how many models it listed.
    @discardableResult
    func syncProviderModels(providerId: String) async throws -> Int {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/providers/\(providerId)/models/sync") else { return 0 }
        let json = try await sendJSONReturningDict(url: url, method: "POST", body: [:])
        return (json["synced_models"] as? [Any])?.count ?? 0
    }

    func reorderAccounts(provider: String, ids: [String]) async throws {
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/reorder") else { return }
        try await sendJSON(url: url, method: "POST", body: ["account_ids": ids])
    }

    func fetchRouting() async -> GatewayRoutingState? {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/settings") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(GatewayRoutingState.self, from: data)
    }

    /// Saves only the given fields (e.g. `["routing_strategy": "round_robin"]`).
    func updateRouting(_ fields: [String: Any]) async throws {
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/settings") else { return }
        try await sendJSON(url: url, method: "POST", body: fields)
    }

    func fetchCombos() async -> [String: [String]] {
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/combos"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let wrapper = try? JSONDecoder().decode([String: [String: [String]]].self, from: data) else { return [:] }
        return wrapper["combos"] ?? [:]
    }

    func saveCombo(name: String, targets: [String]) async throws {
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/combos") else { return }
        try await sendJSON(url: url, method: "POST", body: ["name": name, "targets": targets])
    }

    func deleteCombo(name: String) async throws {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/combos/\(encoded)") else { return }
        try await sendJSON(url: url, method: "DELETE", body: [:])
    }

    func removeAccount(provider: String, id: String) async throws {
        _ = await ensureRunning()
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/\(encodedId)") else { return }
        try await sendJSON(url: url, method: "DELETE", body: [:])
    }

    private func sendJSONReturningDict(url: URL, method: String, body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = dict["detail"] as? String ?? dict["error"] as? String ?? dict["message"] as? String ?? "Gateway HTTP \(http.statusCode)"
            throw AIError(msg)
        }
        return dict
    }

    // MARK: - SQLite Usage & Analytics (mirrors ~/.notchi-gateway/gateway.db)

    private var gatewayDbFile: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".notchi-gateway/gateway.db")
    }

    var hasDatabase: Bool {
        fileManager.fileExists(atPath: gatewayDbFile.path)
    }

    func fetchReports() -> [UsageReport] {
        guard hasDatabase else { return [] }
        var accounts: [(id: String, provider: String, label: String?, email: String?, lastError: String?, sortOrder: Int, enabled: Bool)] = []
        let ok = queryDb("SELECT id, provider, label, email, last_error, sort_order, COALESCE(enabled, 1) FROM accounts ORDER BY provider, sort_order, connected_at") { stmt in
            accounts.append((
                id: colStr(stmt, 0) ?? "",
                provider: colStr(stmt, 1) ?? "",
                label: colStr(stmt, 2),
                email: colStr(stmt, 3),
                lastError: colStr(stmt, 4),
                sortOrder: Int(sqlite3_column_int(stmt, 5)),
                enabled: sqlite3_column_int(stmt, 6) != 0
            ))
        }
        guard ok, !accounts.isEmpty else { return [] }

        // Per-provider usage totals for today and daily buckets
        let todayKey = Self.dateKey(Date())
        var providerDays: [String: [String: UsageTotals]] = [:]
        _ = queryDb("SELECT provider, ts, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0) FROM usage WHERE ts > 0") { stmt in
            guard let prov = colStr(stmt, 0) else { return }
            let ts = sqlite3_column_double(stmt, 1)
            let tokens = Int(sqlite3_column_int64(stmt, 2) + sqlite3_column_int64(stmt, 3))
            let day = Self.dateKey(Date(timeIntervalSince1970: ts))
            var cur = providerDays[prov, default: [:]][day] ?? UsageTotals()
            cur.tokens += tokens
            providerDays[prov, default: [:]][day] = cur
        }

        return accounts.map { acc in
            let tool: AgentTool
            switch acc.provider.lowercased() {
            case "codex": tool = .codex
            case "antigravity": tool = .antigravity
            case "commandcode": tool = .commandcode
            default: tool = .claude
            }
            let displayName = acc.label.flatMap { $0.isEmpty ? nil : $0 }
                ?? acc.email.flatMap { $0.isEmpty ? nil : $0 }
                ?? tool.displayName

            let account = AIAccount(
                id: UUID(uuidString: acc.id) ?? UUID(),
                name: displayName,
                tool: tool,
                dir: "~/.notchi-gateway",
                connectionId: acc.id,
                email: acc.email,
                priority: acc.sortOrder + 1,
                isActive: acc.enabled
            )
            var report = UsageReport(account: account, found: true)
            let daysMap = providerDays[acc.provider] ?? [:]
            let calendar = Calendar.current
            let last14Days: [Int] = (0..<14).reversed().map { offset in
                let d = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
                return daysMap[Self.dateKey(d)]?.tokens ?? 0
            }
            report.days = last14Days
            report.today = daysMap[todayKey] ?? UsageTotals()
            report.lastError = acc.lastError
            report.testStatus = acc.enabled ? (acc.lastError == nil ? "active" : "error") : "paused"
            return report
        }
    }

    func todayModels() -> [(model: String, tokens: Int, cost: Double)] {
        guard hasDatabase else { return [] }
        let startOfDay = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var out: [(String, Int, Double)] = []
        _ = queryDb("""
            SELECT COALESCE(model, 'auto'), SUM(COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)) AS tok
            FROM usage WHERE ts >= ? GROUP BY model ORDER BY tok DESC LIMIT 8
            """, bind: { stmt in
                sqlite3_bind_double(stmt, 1, startOfDay)
            }) { stmt in
                let m = colStr(stmt, 0) ?? "auto"
                let t = Int(sqlite3_column_int64(stmt, 1))
                out.append((m, t, 0))
            }
        return out
    }

    func dailyStats(days: Int?) -> [DayStat] {
        guard hasDatabase else { return [] }
        var map: [String: DayStat] = [:]
        let minTs: Double = days.map { Date().timeIntervalSince1970 - Double($0) * 86400 } ?? 0
        _ = queryDb("""
            SELECT ts, COALESCE(input_tokens, 0), COALESCE(output_tokens, 0)
            FROM usage WHERE ts >= ?
            """, bind: { stmt in
                sqlite3_bind_double(stmt, 1, minTs)
            }) { stmt in
                let ts = sqlite3_column_double(stmt, 0)
                let key = Self.dateKey(Date(timeIntervalSince1970: ts))
                var d = map[key] ?? DayStat(date: key, requests: 0, input: 0, cached: 0, output: 0, cost: 0)
                d.requests += 1
                d.input += Int(sqlite3_column_int64(stmt, 1))
                d.output += Int(sqlite3_column_int64(stmt, 2))
                map[key] = d
            }
        return map.values.sorted { $0.date < $1.date }
    }

    func modelStats(days: Int?) -> [ModelStat] {
        guard hasDatabase else { return [] }
        let minTs: Double = days.map { Date().timeIntervalSince1970 - Double($0) * 86400 } ?? 0
        var out: [ModelStat] = []
        _ = queryDb("""
            SELECT COALESCE(model, 'auto'), COALESCE(provider, ''),
                   SUM(COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0)) AS tok
            FROM usage WHERE ts >= ? GROUP BY model, provider ORDER BY tok DESC LIMIT 12
            """, bind: { stmt in
                sqlite3_bind_double(stmt, 1, minTs)
            }) { stmt in
                let m = colStr(stmt, 0) ?? "auto"
                let p = colStr(stmt, 1) ?? ""
                let t = Int(sqlite3_column_int64(stmt, 2))
                out.append(ModelStat(id: "\(m)|\(p)", tokens: t, cost: 0))
            }
        return out
    }

    func recentRequests(limit: Int = 20) -> [RecentRequest] {
        guard hasDatabase else { return [] }
        var out: [RecentRequest] = []
        _ = queryDb("""
            SELECT rowid, ts, COALESCE(model, 'auto'), COALESCE(provider, ''),
                   COALESCE(input_tokens, 0), COALESCE(output_tokens, 0),
                   COALESCE(status_code, 200)
            FROM usage ORDER BY ts DESC LIMIT ?
            """, bind: { stmt in
                sqlite3_bind_int(stmt, 1, Int32(limit))
            }) { stmt in
                let rowId = sqlite3_column_int64(stmt, 0)
                let ts = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
                let m = colStr(stmt, 2) ?? "auto"
                let p = colStr(stmt, 3) ?? ""
                let inp = Int(sqlite3_column_int64(stmt, 4))
                let outTok = Int(sqlite3_column_int64(stmt, 5))
                let code = Int(sqlite3_column_int(stmt, 6))
                out.append(RecentRequest(id: rowId, date: ts, model: m, provider: p, input: inp, output: outTok, ok: code < 400))
            }
        return out
    }

    private func queryDb(_ sql: String, bind: ((OpaquePointer) -> Void)? = nil, row: (OpaquePointer) -> Void) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(gatewayDbFile.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return false
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            row(stmt)
        }
        return true
    }

    private func colStr(_ stmt: OpaquePointer, _ idx: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: c)
    }

    private static func dateKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func sendJSON(url: URL, method: String, body: [String: Any]) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
                ?? "Gateway HTTP \(http.statusCode)"
            throw AIError(msg)
        }
    }
}
