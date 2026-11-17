import Foundation

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
    var geminiOAuthClientId: String?
    var geminiOAuthConfigured: Bool?

    enum CodingKeys: String, CodingKey {
        case geminiOAuthClientId = "gemini_oauth_client_id"
        case geminiOAuthConfigured = "gemini_oauth_configured"
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
        Self.cachedBinaryURL != nil || isRunning
    }

    /// The binary location doesn't change while the app runs; checked once.
    private static let cachedBinaryURL: URL? = NotchiGatewayService.shared.binaryURL

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
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return false }
            // Something else may own the port; only adopt a real notchi-gateway.
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            return json?["service"] as? String == "notchi-gateway"
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
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/poll") else {
            throw AIError("Invalid poll URL")
        }
        let json = try await sendJSONReturningDict(url: url, method: "POST", body: ["session_id": sessionId])
        return json["status"] as? String ?? "pending"
    }

    func completeOAuth(provider: String, sessionId: String, callback: String) async throws {
        _ = await ensureRunning()
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
        _ = await ensureRunning()
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
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/settings") else { return }
        try await sendJSON(url: url, method: "POST", body: fields)
    }

    func fetchCombos() async -> [String: [String]] {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/combos"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let wrapper = try? JSONDecoder().decode([String: [String: [String]]].self, from: data) else { return [:] }
        return wrapper["combos"] ?? [:]
    }

    func saveCombo(name: String, targets: [String]) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/combos") else { return }
        try await sendJSON(url: url, method: "POST", body: ["name": name, "targets": targets])
    }

    func deleteCombo(name: String) async throws {
        _ = await ensureRunning()
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/combos/\(encoded)") else { return }
        try await sendJSON(url: url, method: "DELETE", body: [:])
    }

    /// Makes a tiny live request with the account; returns (ok, message).
    func testAccount(provider: String, id: String) async -> (ok: Bool, message: String) {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/accounts/\(provider)/test") else { return (false, "Invalid URL") }
        guard let json = try? await sendJSONReturningDict(url: url, method: "POST", body: ["account_id": id]) else {
            return (false, "Gateway didn't answer")
        }
        if json["valid"] as? Bool == true {
            let ms = json["latency_ms"] as? Int
            return (true, ms.map { "Works (\($0) ms)" } ?? "Works")
        }
        return (false, json["error"] as? String ?? "Test failed")
    }

    /// Google OAuth client for Gemini CLI logins (Google requires the user's own client).
    func saveGeminiOAuthClient(id: String, secret: String) async throws {
        _ = await ensureRunning()
        guard let url = URL(string: "\(Self.baseURL)/gateway/admin/settings") else { return }
        var body: [String: Any] = ["gemini_oauth_client_id": id.trimmingCharacters(in: .whitespacesAndNewlines)]
        let s = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { body["gemini_oauth_client_secret"] = s }
        try await sendJSON(url: url, method: "POST", body: body)
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

    // MARK: - Usage & Analytics (HTTP API)

    /// Blocking GET for the usage/analytics readers, which run on background queues.
    /// Returns nil when the gateway isn't running; it is started elsewhere on demand.
    private func getSync(_ path: String) -> [String: Any]? {
        guard let url = URL(string: Self.baseURL + path) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        let sem = DispatchSemaphore(value: 0)
        var out: [String: Any]?
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            if let data, (resp as? HTTPURLResponse)?.statusCode == 200 {
                out = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 6)
        return out
    }

    /// The caller's UTC offset in minutes (east positive), so days match the local calendar.
    private static var tzOffsetMin: Int { TimeZone.current.secondsFromGMT() / 60 }

    /// Deterministic UUID for a gateway account id (e.g. "codex:1a2b3c4d"), so SwiftUI identity is stable.
    static func stableUUID(_ key: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (i, b) in key.utf8.enumerated() { bytes[i % 16] = bytes[i % 16] &* 31 &+ b }
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    /// One report per connected subscription account. Blocking; call off the main thread.
    func fetchReports() -> [UsageReport] {
        guard let json = getSync("/gateway/admin/accounts/usage?days=7&tz_offset_min=\(Self.tzOffsetMin)"),
              let rows = json["usage"] as? [[String: Any]] else { return [] }
        let now = Date().timeIntervalSince1970
        return rows.map { a in
            let provider = a["provider"] as? String ?? ""
            let id = a["account_id"] as? String ?? ""
            let enabled = a["enabled"] as? Bool ?? true
            let lastError = a["last_error"] as? String
            let coolingUntil = (a["cooling_until"] as? Double).flatMap { $0 > now ? $0 : nil }
            let label = (a["label"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let email = (a["email"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let account = AIAccount(
                id: Self.stableUUID(id),
                name: label ?? email ?? GatewayProvider.name(provider),
                tool: AgentTool(rawValue: provider) ?? .claude,
                dir: "~/.notchi-gateway",
                connectionId: id,
                email: email,
                priority: (a["sort_order"] as? Int).map { $0 + 1 },
                isActive: enabled
            )
            var report = UsageReport(account: account, found: true)
            report.provider = provider
            report.days = (a["days"] as? [Int]) ?? report.days
            report.today = UsageTotals(tokens: a["today_tokens"] as? Int ?? 0)
            report.planName = a["plan"] as? String
            report.lastError = lastError
            report.coolingUntil = coolingUntil.map(Date.init(timeIntervalSince1970:))
            report.testStatus = !enabled ? "paused" : coolingUntil != nil ? "unavailable" : lastError == nil ? "active" : "error"
            report.isFromGateway = true
            return report
        }
    }

    /// Request history for the Analytics tab. Blocking; call off the main thread.
    func analytics(days: Int?) -> (days: [DayStat], models: [ModelStat], recent: [RecentRequest], todayModels: [(model: String, tokens: Int, cost: Double)]) {
        var path = "/gateway/admin/analytics?tz_offset_min=\(Self.tzOffsetMin)"
        if let days { path += "&days=\(days)" }
        guard let json = getSync(path) else { return ([], [], [], []) }
        let dayStats = (json["days"] as? [[String: Any]] ?? []).map {
            DayStat(date: $0["date"] as? String ?? "", requests: $0["requests"] as? Int ?? 0, input: $0["input"] as? Int ?? 0,
                    cached: $0["cached"] as? Int ?? 0, output: $0["output"] as? Int ?? 0, cost: $0["cost"] as? Double ?? 0)
        }
        let models = (json["models"] as? [[String: Any]] ?? []).map {
            ModelStat(id: "\($0["model"] as? String ?? "auto")|\($0["provider"] as? String ?? "")", tokens: $0["tokens"] as? Int ?? 0, cost: 0)
        }
        let recent = (json["recent"] as? [[String: Any]] ?? []).enumerated().map { i, r in
            RecentRequest(id: Int64(i), date: Date(timeIntervalSince1970: r["ts"] as? Double ?? 0), model: r["model"] as? String ?? "auto",
                          provider: r["provider"] as? String ?? "", input: r["input"] as? Int ?? 0, output: r["output"] as? Int ?? 0,
                          ok: r["ok"] as? Bool ?? true)
        }
        let today = (json["top_models"] as? [[String: Any]] ?? []).map {
            (model: $0["model"] as? String ?? "auto", tokens: $0["tokens"] as? Int ?? 0, cost: 0.0)
        }
        return (dayStats, models, recent, today)
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
