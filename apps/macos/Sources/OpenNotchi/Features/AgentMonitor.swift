import AppKit
import Network

enum AgentTool: String, Codable, CaseIterable, Identifiable {
    case claude, codex

    var id: String { rawValue }
    var displayName: String { self == .claude ? "Claude Code" : "Codex" }
    var icon: String { self == .claude ? "terminal.fill" : "chevron.left.forwardslash.chevron.right" }
}

enum AgentState: String {
    case working, needsYou = "needs_you", done, idle

    var label: String { self == .needsYou ? "needs you" : rawValue }
}

struct AgentSession: Identifiable, Equatable {
    var tool: AgentTool
    var id: String
    var project: String
    var state: AgentState
    var updatedAt: Date
    var message: String?
}

/// A Claude Code or Codex config folder to read usage (and agent status) from.
struct AIAccount: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var tool: AgentTool
    var dir: String

    private enum CodingKeys: String, CodingKey { case name, tool, dir }

    var url: URL { expandPath(dir) }

    /// `~/.claude` and `~/.codex`, when they exist.
    static var defaults: [AIAccount] {
        [AIAccount(name: "Claude Code", tool: .claude, dir: "~/.claude"), AIAccount(name: "Codex", tool: .codex, dir: "~/.codex")]
            .filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }
}

func expandPath(_ dir: String) -> URL {
    URL(fileURLWithPath: (dir.trimmingCharacters(in: .whitespaces) as NSString).expandingTildeInPath)
}

func projectName(_ cwd: String) -> String {
    URL(fileURLWithPath: cwd).lastPathComponent
}

func jsonObject(_ line: some StringProtocol) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]
}

/// Reading agent state out of Claude Code and Codex session logs. Pure, so it can be self-checked.
enum AgentLogs {
    static let tailBytes: UInt64 = 64 * 1024

    /// The complete lines in the last 64 KB of a file.
    static func tailLines(_ url: URL) -> [String] {
        guard let h = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        let start = size > tailBytes ? size - tailBytes : 0
        try? h.seek(toOffset: start)
        var lines = String(decoding: (try? h.readToEnd()) ?? Data(), as: UTF8.self).split(separator: "\n").map(String.init)
        if start > 0, !lines.isEmpty { lines.removeFirst() } // cut mid-line
        return lines
    }

    /// Working/done from the tail of a Claude Code transcript, plus the last cwd and session id seen.
    static func claudeState(_ lines: [String]) -> (state: AgentState?, cwd: String, sessionId: String) {
        var (state, cwd, sid): (AgentState?, String, String) = (nil, "", "")
        for line in lines {
            guard let v = jsonObject(line) else { continue }
            if let c = v["cwd"] as? String { cwd = c }
            if let s = v["sessionId"] as? String { sid = s }
            switch v["type"] as? String {
            case "assistant":
                if let reason = (v["message"] as? [String: Any])?["stop_reason"] as? String {
                    state = reason == "tool_use" ? .working : .done
                }
            case "user" where v["isMeta"] as? Bool != true:
                state = .working
            default: break
            }
        }
        return (state, cwd, sid)
    }

    static func codexState(_ lines: [String]) -> AgentState? {
        lines.filter { $0.contains("task_") }.compactMap(jsonObject).reduce(nil) { state, v in
            switch (v["payload"] as? [String: Any])?["type"] as? String {
            case "task_started": return .working
            case "task_complete": return .done
            default: return state
            }
        }
    }

    static func firstLine(_ url: URL) -> [String: Any]? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        // session_meta carries the whole base prompt, so the first line can be long.
        let data = (try? h.read(upToCount: 512 * 1024)) ?? Data()
        return data.split(separator: UInt8(ascii: "\n"), maxSplits: 1).first.flatMap { jsonObject(String(decoding: $0, as: UTF8.self)) }
    }

    static func readSession(tool: AgentTool, url: URL, mtime: Date) -> AgentSession? {
        let lines = tailLines(url)
        var state: AgentState?, cwd = "", sid = ""
        if tool == .claude {
            (state, cwd, sid) = claudeState(lines)
        } else {
            let meta = firstLine(url)?["payload"] as? [String: Any]
            (state, cwd, sid) = (codexState(lines), meta?["cwd"] as? String ?? "", meta?["id"] as? String ?? "")
        }
        guard let state else { return nil }
        return AgentSession(tool: tool, id: sid.isEmpty ? url.deletingPathExtension().lastPathComponent : sid,
                            project: projectName(cwd), state: state, updatedAt: mtime)
    }

    static func jsonlFiles(in dir: URL) -> [(URL, Date)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "jsonl" }.compactMap { url in
            (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map { (url, $0) }
        }
    }

    static func subdirsNewestFirst(_ dir: URL) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    /// The newest `n` day folders under `<codexHome>/sessions/YYYY/MM/DD` (name order is date order).
    static func codexDayDirs(_ codexHome: URL, _ n: Int) -> [URL] {
        var out: [URL] = []
        for y in subdirsNewestFirst(codexHome.appendingPathComponent("sessions")) {
            for m in subdirsNewestFirst(y) {
                for d in subdirsNewestFirst(m) {
                    if out.count == n { return out }
                    out.append(d)
                }
            }
        }
        return out
    }

    /// Claude Code transcripts: `projects/*/*.jsonl`, plus nested subagent logs when `recursive`.
    static func claudeLogs(_ configDir: URL, recursive: Bool) -> [(URL, Date)] {
        var out: [(URL, Date)] = []
        var stack = subdirsNewestFirst(configDir.appendingPathComponent("projects"))
        while let dir = stack.popLast() {
            out += jsonlFiles(in: dir)
            if recursive { stack += subdirsNewestFirst(dir) }
        }
        return out
    }

    /// Log sessions with the latest hook event laid over them: a hook newer than the log's last write wins
    /// (that's how "needs you" shows), hook-only sessions are added, done turns go idle after 5 min.
    static func merge(_ logs: [AgentSession], hooks: [String: (HookEvent, Date)], now: Date) -> [AgentSession] {
        var byId = Dictionary(logs.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a.updatedAt > b.updatedAt ? a : b })
        for (event, at) in hooks.values where now.timeIntervalSince(at) <= 30 * 60 {
            if var s = byId[event.sessionId] {
                guard at >= s.updatedAt.addingTimeInterval(-1) else { continue }
                s.state = event.state
                s.updatedAt = max(s.updatedAt, at)
                s.message = event.message
                if s.project.isEmpty { s.project = event.project }
                byId[event.sessionId] = s
            } else {
                byId[event.sessionId] = AgentSession(tool: .claude, id: event.sessionId, project: event.project,
                                                     state: event.state, updatedAt: at, message: event.message)
            }
        }
        return byId.values
            .map { s in
                var s = s
                if s.state == .done && now.timeIntervalSince(s.updatedAt) > 5 * 60 { s.state = .idle }
                return s
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Peek text when a session goes working → done, or into needs you; nil otherwise.
    static func peekTitle(previous: AgentState?, next: AgentSession) -> String? {
        let name = "\(next.tool.displayName) \(next.state == .done ? "finished" : "needs you") · \(next.project)"
        if next.state == .needsYou, let previous, previous != .needsYou { return name }
        if next.state == .done, previous == .working || previous == .needsYou { return name }
        return nil
    }
}

// MARK: - Hooks

struct HookEvent: Equatable {
    var sessionId: String
    var project: String
    var state: AgentState
    var message: String?

    /// Maps a Claude Code hook payload to a session state.
    init?(_ v: [String: Any]) {
        switch v["hook_event_name"] as? String {
        case "UserPromptSubmit", "PreToolUse": state = .working
        case "Notification": state = .needsYou
        case "Stop": state = .done
        default: return nil
        }
        guard let sid = v["session_id"] as? String else { return nil }
        sessionId = sid
        project = projectName(v["cwd"] as? String ?? "")
        message = v["message"] as? String
    }
}

/// Minimal HTTP/1.1 for the hook listener.
enum HookHTTP {
    static let port: UInt16 = 47823
    static let url = "http://127.0.0.1:47823/hook/claude"
    static let maxBody = 1 << 20

    /// (request line, lowercase headers, body) once the request is complete; nil while more bytes are needed.
    static func parse(_ data: Data) -> (line: String, headers: [String: String], body: Data)? {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: data[..<end.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        var headers: [String: String] = [:]
        for line in head.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            headers[line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let length = min(Int(headers["content-length"] ?? "") ?? 0, maxBody)
        let body = data[end.upperBound...]
        guard body.count >= length else { return nil }
        return (head.first ?? "", headers, Data(body.prefix(length)))
    }

    /// Status code for a request, and the event to show if it's a valid hook call.
    static func route(line: String, headers: [String: String], body: Data) -> (status: Int, event: HookEvent?) {
        let hostOK = headers["host"] == "127.0.0.1:\(port)" || headers["host"] == "localhost:\(port)"
        // Browsers always send Origin on cross-site POSTs; curl doesn't. Blocks web pages and DNS rebinding.
        guard hostOK, headers["origin"] == nil else { return (403, nil) }
        guard line.hasPrefix("POST /hook/claude ") else { return (404, nil) }
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        return (204, json.flatMap(HookEvent.init))
    }
}

/// Adds or removes our hook in `<configDir>/settings.json`, keeping every other key and hook.
enum ClaudeHooks {
    static let command = "curl -s -m 2 -X POST -H \"Content-Type: application/json\" --data-binary @- \(HookHTTP.url)"
    static let events = ["UserPromptSubmit", "PreToolUse", "Notification", "Stop"]

    static func isOurs(_ hook: Any) -> Bool {
        ((hook as? [String: Any])?["command"] as? String)?.contains(HookHTTP.url) == true
    }

    /// Removes only our hooks, plus any group or event list that became empty because of that.
    static func strip(_ settings: [String: Any]) -> [String: Any] {
        guard var hooks = settings["hooks"] as? [String: Any], !hooks.isEmpty else { return settings }
        for (event, value) in hooks {
            guard let groups = value as? [Any] else { continue }
            let kept: [Any] = groups.compactMap { group in
                guard var g = group as? [String: Any], let hs = g["hooks"] as? [Any] else { return group }
                let left = hs.filter { !isOurs($0) }
                if left.isEmpty && !hs.isEmpty { return nil }
                g["hooks"] = left
                return g
            }
            if kept.isEmpty && !groups.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
        }
        var out = settings
        out["hooks"] = hooks.isEmpty ? nil : hooks
        return out
    }

    /// Adds our hook to each event. Running it twice changes nothing.
    static func merge(_ settings: [String: Any]) throws -> [String: Any] {
        var out = strip(settings)
        if out["hooks"] != nil && !(out["hooks"] is [String: Any]) { throw AIError("\"hooks\" in settings.json isn't an object") }
        var hooks = out["hooks"] as? [String: Any] ?? [:]
        for event in events {
            if hooks[event] != nil && !(hooks[event] is [Any]) { throw AIError("\"hooks.\(event)\" in settings.json isn't a list") }
            hooks[event] = (hooks[event] as? [Any] ?? []) + [["hooks": [["type": "command", "command": command, "timeout": 5]]]]
        }
        out["hooks"] = hooks
        return out
    }

    static func isInstalled(dir: URL) -> Bool {
        (try? String(contentsOf: dir.appendingPathComponent("settings.json"), encoding: .utf8))?.contains(HookHTTP.url) == true
    }

    /// Writes `settings.json.bak` first; leaves an unreadable settings.json untouched.
    static func apply(dir: URL, install: Bool) throws {
        let path = dir.appendingPathComponent("settings.json")
        let raw = try? Data(contentsOf: path)
        var current: [String: Any] = [:]
        if let raw, !String(decoding: raw, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let obj = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any] else {
                throw AIError("settings.json isn't a valid JSON object, so it was left alone")
            }
            current = obj
        }
        let next = install ? try merge(current) : strip(current)
        if NSDictionary(dictionary: next).isEqual(to: current) && raw != nil { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let raw { try raw.write(to: dir.appendingPathComponent("settings.json.bak"), options: .atomic) }
        var data = try JSONSerialization.data(withJSONObject: next, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        data.append(UInt8(ascii: "\n"))
        try data.write(to: path, options: .atomic)
    }
}

// MARK: - Monitor

/// Live agent sessions from log polling (every 2 s) and the optional hook listener on 127.0.0.1:47823.
final class AgentMonitor: ObservableObject {
    static let shared = AgentMonitor()

    @Published private(set) var sessions: [AgentSession] = []
    /// Set when the hook port couldn't be opened; log polling keeps working.
    @Published private(set) var hookProblem: String?

    var onPeek: ((Banner) -> Void)?

    private var accounts: [AIAccount] = []
    private var timer: Timer?
    private var listener: NWListener?
    private var logSessions: [AgentSession] = []
    private var hooks: [String: (HookEvent, Date)] = [:]
    private var lastStates: [String: AgentState] = [:]
    private let queue = DispatchQueue(label: "io.github.opennotchi.agents", qos: .utility)
    /// Parsed state per transcript, re-read only when its mtime changes. Touched on `queue` only.
    private var cache: [URL: (Date, AgentSession?)] = [:]

    func configure(enabled: Bool, accounts: [AIAccount]) {
        self.accounts = accounts
        guard enabled else {
            timer?.invalidate()
            timer = nil
            listener?.cancel()
            listener = nil
            sessions = []
            lastStates = [:]
            return
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }
            timer?.tolerance = 0.5
        }
        if listener == nil { startListener() }
        poll()
    }

    private func poll() {
        let accounts = accounts
        queue.async { [weak self] in
            guard let self else { return }
            let found = self.scan(accounts)
            DispatchQueue.main.async {
                self.logSessions = found
                self.publish()
            }
        }
    }

    private func scan(_ accounts: [AIAccount]) -> [AgentSession] {
        let since = Date.now.addingTimeInterval(-30 * 60)
        var files: [(AgentTool, URL, Date)] = []
        for a in accounts {
            if a.tool == .claude {
                files += AgentLogs.claudeLogs(a.url, recursive: false).map { (.claude, $0.0, $0.1) }
            } else {
                for day in AgentLogs.codexDayDirs(a.url, 2) { files += AgentLogs.jsonlFiles(in: day).map { (.codex, $0.0, $0.1) } }
            }
        }
        return files.filter { $0.2 >= since }.compactMap { tool, url, mtime in
            if let (m, s) = cache[url], m == mtime { return s }
            let s = AgentLogs.readSession(tool: tool, url: url, mtime: mtime)
            cache[url] = (mtime, s)
            return s
        }
    }

    private func publish() {
        let merged = AgentLogs.merge(logSessions, hooks: hooks, now: .now)
        if AppSettings.shared.aiNotify {
            for s in merged {
                guard let title = AgentLogs.peekTitle(previous: lastStates[s.id], next: s) else { continue }
                onPeek?(Banner(icon: s.state == .done ? "checkmark.circle.fill" : "hand.raised.fill",
                               tint: s.state == .done ? .green : .orange,
                               badge: s.state == .done ? "Done" : "Needs you",
                               title: title, subtitle: s.message, duration: 4))
            }
        }
        lastStates = Dictionary(merged.map { ($0.id, $0.state) }, uniquingKeysWith: { a, _ in a })
        let top = Array(merged.prefix(5))
        if top != sessions { sessions = top }
    }

    // MARK: Hook listener

    private func startListener() {
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: HookHTTP.port)!)
        guard let l = try? NWListener(using: params) else { return failListener("couldn't create the listener") }
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: self?.queue ?? .main)
            self?.receive(conn, Data())
        }
        l.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: DispatchQueue.main.async { self?.hookProblem = nil }
            case .failed(let error): DispatchQueue.main.async { self?.failListener("\(error)") }
            default: break
            }
        }
        l.start(queue: queue)
        listener = l
    }

    private func failListener(_ reason: String) {
        NSLog("OpenNotchi: AI hooks can't listen on 127.0.0.1:\(HookHTTP.port) (\(reason)); using log polling only")
        hookProblem = "Port \(HookHTTP.port) is in use, so hooks are off. Agent status still comes from the logs."
        listener?.cancel()
        listener = nil
    }

    private func receive(_ conn: NWConnection, _ buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, done, error in
            var buffer = buffer
            if let data { buffer.append(data) }
            if let req = HookHTTP.parse(buffer) {
                let (status, event) = HookHTTP.route(line: req.line, headers: req.headers, body: req.body)
                let reason = [204: "No Content", 403: "Forbidden", 404: "Not Found"][status] ?? "Bad Request"
                let reply = "HTTP/1.1 \(status) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
                conn.send(content: Data(reply.utf8), completion: .contentProcessed { _ in conn.cancel() })
                if let event {
                    DispatchQueue.main.async {
                        self?.hooks[event.sessionId] = (event, .now)
                        self?.publish()
                    }
                }
            } else if done || error != nil || buffer.count > HookHTTP.maxBody + 16 * 1024 {
                conn.cancel()
            } else {
                self?.receive(conn, buffer)
            }
        }
    }

    // MARK: Row click

    /// Brings the most likely terminal or editor to the front.
    static func activateTerminal(for tool: AgentTool) {
        let ids = ["com.mitchellh.ghostty", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.microsoft.VSCode",
                   "com.todesktop.230313mzl4w4u92", "dev.zed.Zed", "com.openai.codex", "com.apple.Terminal"]
        let running = NSWorkspace.shared.runningApplications
        for id in ids {
            if let app = running.first(where: { $0.bundleIdentifier == id }) {
                app.activate()
                return
            }
        }
    }
}
