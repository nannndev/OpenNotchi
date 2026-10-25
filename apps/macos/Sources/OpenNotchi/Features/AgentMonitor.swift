import AppKit
import Network

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
            } else if a.tool == .codex {
                for day in AgentLogs.codexDayDirs(a.url, 2) { files += AgentLogs.jsonlFiles(in: day).map { (.codex, $0.0, $0.1) } }
            } else if a.tool == .antigravity {
                files += AgentLogs.antigravityTranscripts(a.url).map { (.antigravity, $0.0, $0.1) }
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
                               title: title, subtitle: s.message,
                               // "Needs you" waits longer: you may be in another window.
                               duration: s.state == .done ? 5 : 10,
                               kind: s.state == .done ? .success : .attention))
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
