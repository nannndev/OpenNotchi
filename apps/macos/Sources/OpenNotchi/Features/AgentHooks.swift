import AppKit

struct HookEvent: Equatable {
    var sessionId: String
    var project: String
    var cwd: String
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
        cwd = v["cwd"] as? String ?? ""
        project = projectName(cwd)
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
