import AppKit

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

    /// Transcripts under an Antigravity IDE home (`<dir>/brain/*/.system_generated/logs/transcript.jsonl`).
    static func antigravityTranscripts(_ ideHome: URL) -> [(URL, Date)] {
        let brain = ideHome.appendingPathComponent("brain")
        guard let dirs = try? FileManager.default.contentsOfDirectory(at: brain, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var out: [(URL, Date)] = []
        for d in dirs where (try? d.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let transcript = d.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            if let date = (try? transcript.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) {
                out.append((transcript, date))
            }
        }
        return out
    }

    /// State, cwd and optional prompt/question from an Antigravity transcript tail.
    static func antigravityState(_ lines: [String]) -> (state: AgentState?, cwd: String, message: String?) {
        var state: AgentState? = nil
        var cwd = ""
        var message: String? = nil

        for line in lines {
            guard let v = jsonObject(line) else { continue }

            if cwd.isEmpty {
                if let content = v["content"] as? String {
                    if let arrowRange = content.range(of: " -> ") {
                        let before = String(content[..<arrowRange.lowerBound])
                        if let lastWs = before.rangeOfCharacter(from: CharacterSet(charactersIn: "\n \"'"), options: .backwards) {
                            let cand = String(before[lastWs.upperBound...]).trimmingCharacters(in: .whitespaces)
                            if cand.hasPrefix("/") || cand.contains(":") { cwd = cand }
                        }
                    }
                    if cwd.isEmpty, let docRange = content.range(of: "Active Document: ") {
                        let doc = String(content[docRange.upperBound...])
                        let endRange = doc.rangeOfCharacter(from: CharacterSet(charactersIn: "\n<\"\r"))
                        let pathStr = String(doc[..<(endRange?.lowerBound ?? doc.endIndex)]).trimmingCharacters(in: .whitespaces)
                        let path = URL(fileURLWithPath: pathStr)
                        if !path.pathExtension.isEmpty {
                            let parent = path.deletingLastPathComponent()
                            cwd = (parent.lastPathComponent == "src" || parent.lastPathComponent == "lib")
                                ? parent.deletingLastPathComponent().path
                                : parent.path
                        } else {
                            cwd = path.path
                        }
                    }
                }
            }

            if let toolCalls = v["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    let name = tc["name"] as? String ?? (tc["function"] as? [String: Any])?["name"] as? String
                    var args = tc["args"] as? [String: Any]
                    if args == nil, let fn = tc["function"] as? [String: Any] {
                        if let dict = fn["arguments"] as? [String: Any] {
                            args = dict
                        } else if let str = fn["arguments"] as? String, let parsed = jsonObject(str) {
                            args = parsed
                        }
                    }

                    if let args = args {
                        for key in ["Cwd", "DirectoryPath", "SearchPath", "TargetFile", "AbsolutePath"] {
                            if let val = args[key] as? String {
                                let unquoted = val.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                                if unquoted.hasPrefix("/") || unquoted.contains(":") {
                                    let path = URL(fileURLWithPath: unquoted)
                                    if !path.pathExtension.isEmpty {
                                        let parent = path.deletingLastPathComponent()
                                        cwd = (parent.lastPathComponent == "src" || parent.lastPathComponent == "lib")
                                            ? parent.deletingLastPathComponent().path
                                            : parent.path
                                    } else {
                                        cwd = path.path
                                    }
                                    break
                                }
                            }
                        }
                    }
                    if name == "ask_question" {
                        state = .needsYou
                        if let args = args {
                            if let q = args["question"] as? String {
                                message = q
                            } else if let q = args["questions"] as? String {
                                message = q
                            } else if let qList = args["questions"] as? [[String: Any]],
                                      let firstQ = qList.first?["question"] as? String {
                                message = firstQ
                            }
                        }
                    }
                }
            }

            switch v["type"] as? String {
            case "USER_INPUT":
                state = .working
            case "PLANNER_RESPONSE":
                let tools = v["tool_calls"] as? [[String: Any]] ?? []
                let isAskQ = tools.contains { tc in
                    let name = tc["name"] as? String ?? (tc["function"] as? [String: Any])?["name"] as? String
                    return name == "ask_question"
                }
                if isAskQ {
                    state = .needsYou
                } else if !tools.isEmpty {
                    state = .working
                } else if (v["status"] as? String) == "DONE" {
                    state = .done
                }
            case let t? where t.hasPrefix("RUN_") || t.hasPrefix("VIEW_") || t.hasPrefix("REPLACE_") || t.hasPrefix("WRITE_") || t.hasPrefix("EXEC_"):
                state = .working
            default:
                break
            }
        }
        return (state, cwd, message)
    }

    static func readSession(tool: AgentTool, url: URL, mtime: Date) -> AgentSession? {
        let lines = tailLines(url)
        var state: AgentState?, cwd = "", sid = "", msg: String? = nil
        if tool == .claude {
            (state, cwd, sid) = claudeState(lines)
        } else if tool == .codex {
            let meta = firstLine(url)?["payload"] as? [String: Any]
            (state, cwd, sid) = (codexState(lines), meta?["cwd"] as? String ?? "", meta?["id"] as? String ?? "")
        } else {
            let res = antigravityState(lines)
            state = res.state
            cwd = res.cwd
            let convId = url.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            sid = convId.isEmpty ? url.deletingPathExtension().lastPathComponent : convId
            msg = res.message
        }
        guard let state else { return nil }
        return AgentSession(tool: tool, id: sid.isEmpty ? url.deletingPathExtension().lastPathComponent : sid,
                            project: projectName(cwd), state: state, updatedAt: mtime, message: msg)
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
