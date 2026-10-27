#if DEBUG
import AppKit

/// Assert-based checks for the AI log parsing, run with `OpenNotchi --ai-selftest [claudeDir codexDir]`.
/// With folders given it also prints what the AI tab would show for them.
enum AISelfTest {
    static func run(_ args: [String]) -> Never {
        var failures = 0
        func check(_ ok: Bool, _ name: String, line: Int = #line) {
            print(ok ? "  ok   \(name)" : "  FAIL \(name) (line \(line))")
            if !ok { failures += 1 }
        }

        print("Claude usage dedupe")
        func usageLine(_ id: String, _ req: String, _ out: Int) -> String {
            #"{"type":"assistant","timestamp":"2026-10-24T04:00:00.000Z","requestId":"\#(req)","message":{"id":"\#(id)","model":"claude-opus-5-5","usage":{"input_tokens":3,"output_tokens":\#(out),"cache_creation_input_tokens":10,"cache_read_input_tokens":20}}}"#
        }
        let entries = AIUsage.dedupe([usageLine("m1", "r1", 5), usageLine("m1", "r1", 9), usageLine("m2", "r2", 4), usageLine("m1", "r9", 1)].compactMap(AIUsage.parseClaudeLine))
        check(entries.count == 3, "same message.id+requestId counted once, other requestId kept")
        let m1 = entries.first { $0.key == "m1:r1" }
        check(m1?.tokens == [3, 9, 10, 20], "last logged copy wins")
        check(m1.map { abs(AIUsage.cost($0) - 246e-6) < 1e-12 } == true, "opus-5-5 cost from price table")
        let ref = #"{"type":"assistant","timestamp":"2026-10-24T04:00:00Z","requestRef":"r","message":{"id":"m","usage":{"output_tokens":2}}}"#
        check(AIUsage.parseClaudeLine(ref)?.key == "m:r", "requestRef fallback, timestamp without fraction")
        check(AIUsage.parseClaudeLine(#"{"type":"user","message":{"id":"m","usage":{}}}"#) == nil, "user lines ignored")
        check(AIUsage.cost(.init(ts: .now, model: "gpt-9", key: "", tokens: [1, 1, 0, 0])) == 0, "unknown model: tokens only")

        print("Chat stream parsing")
        check(AIAssistant.sseDelta(#"data: {"choices":[{"delta":{"content":"Hi"}}]}"#) == "Hi", "content delta")
        check(AIAssistant.sseDelta(#"data: {"choices":[{"delta":{"role":"assistant"}}]}"#) == nil, "role-only chunk ignored")
        check(AIAssistant.sseDelta("data: [DONE]") == nil, "done marker ignored")
        check(AIAssistant.sseDelta(": keep-alive") == nil, "comment line ignored")
        check(AIAssistant.Message(role: "user", content: "q", context: "ctx").full == "ctx\n\nq", "context goes before the prompt")

        print("Notchi action block")
        let reply = "Switching you to Aurora.\n```notchi\n{\"set\": {\"theme\": \"aurora\", \"lyrics\": true, \"hoverDelay\": 0.2}, \"tab\": \"Timer\"}\n```"
        let parsed = NotchiBrain.split(reply)
        check(parsed.text == "Switching you to Aurora.", "block hidden from the chat text")
        check(parsed.actions?.set?["theme"]?.text == "aurora", "string value")
        check(parsed.actions?.set?["lyrics"]?.text == "true", "bool value")
        check(parsed.actions?.set?["hoverDelay"]?.text == "0.2", "number value")
        check(parsed.actions?.tab == "Timer", "tab")
        check(NotchiBrain.split("Half done ```notchi {\"set\":").text == "Half done", "partial block hidden while streaming")
        check(NotchiBrain.split("No changes.").actions == nil, "plain reply has no actions")
        check(NotchiBrain.split("Okay.\n```notchi\n{\"play\": \"Hindia Evaluasi\"}\n```").actions?.play == "Hindia Evaluasi", "play query")

        print("Spotify search parsing")
        let search = #"{"tracks":{"items":[{"uri":"spotify:track:1","name":"Evaluasi","duration_ms":201000,"artists":[{"name":"Hindia"}],"album":{"name":"Menari","images":[{"url":"https://i/640"},{"url":"https://i/64"}]}},{"name":"no uri"}]}}"#
        let tracks = MusicSearch.parseSpotify(Data(search.utf8))
        check(tracks.count == 1, "items without a uri are skipped")
        check(tracks.first?.artist == "Hindia" && tracks.first?.duration == 201, "artist and duration")
        check(tracks.first?.artworkURL?.absoluteString == "https://i/64", "smallest artwork for rows")
        check(NotchiBrain.split("```notchi\nnot json\n```").actions == nil, "bad JSON ignored")

        print("5-hour block")
        let t = { (h: Double, m: Double) in Date(timeIntervalSince1970: h * 3600 + m * 60) }
        let ts = [t(1, 10), t(2, 0), t(7, 30), t(8, 15)]
        check(AIUsage.blockStart(ts, now: t(9, 0)) == t(7, 0), "starts after ≥5h gap, floored to hour")
        check(AIUsage.blockStart(ts, now: t(12, 1)) == nil, "ended block is nil")
        let busy = (0..<12).map { t(1, 30 + Double($0) * 30) }
        check(AIUsage.blockStart(busy, now: t(7, 0)) == t(6, 0), "continuous use rolls into a new block after 5h")
        check(AIUsage.blockStart([], now: t(7, 0)) == nil, "no entries")

        print("Agent state from log tails")
        let toolUse = #"{"type":"assistant","cwd":"/Users/me/code/notch","sessionId":"s1","message":{"stop_reason":"tool_use"}}"#
        let end = #"{"type":"assistant","cwd":"/Users/me/code/notch","sessionId":"s1","message":{"stop_reason":"end_turn"}}"#
        let user = #"{"type":"user","sessionId":"s1","message":{"role":"user"}}"#
        let meta = #"{"type":"user","isMeta":true,"message":{"role":"user"}}"#
        let s = AgentLogs.claudeState([toolUse])
        check(s.state == .working && projectName(s.cwd) == "notch" && s.sessionId == "s1", "tool_use → working, cwd + session id")
        check(AgentLogs.claudeState([toolUse, end]).state == .done, "end_turn → done")
        check(AgentLogs.claudeState([end, user]).state == .working, "later user line → working")
        check(AgentLogs.claudeState([end, meta]).state == .done, "meta user line ignored")
        check(AgentLogs.claudeState(["not json", #"{"type":"summary"}"#]).state == nil, "no state from junk")
        let started = #"{"type":"event_msg","payload":{"type":"task_started"}}"#
        let complete = #"{"type":"event_msg","payload":{"type":"task_complete"}}"#
        check(AgentLogs.codexState([started]) == .working, "codex task_started → working")
        check(AgentLogs.codexState([started, complete]) == .done, "codex task_complete → done")
        let now = Date()
        let old = AgentSession(tool: .claude, id: "a", project: "p", state: .done, updatedAt: now.addingTimeInterval(-6 * 60))
        check(AgentLogs.merge([old], hooks: [:], now: now).first?.state == .idle, "done >5 min → idle")
        let hook = HookEvent(["hook_event_name": "Notification", "session_id": "a", "cwd": "/x/p", "message": "Needs permission"])!
        let merged = AgentLogs.merge([old], hooks: ["a": (hook, now)], now: now)
        check(merged.first?.state == .needsYou && merged.first?.message == "Needs permission", "newer hook overrides log state")
        check(merged.first?.cwd == "/x/p", "hook fills in the working directory the log lacked")
        let hookOnly = AgentLogs.merge([], hooks: ["a": (hook, now)], now: now).first
        check(hookOnly?.cwd == "/x/p" && hookOnly?.project == "p", "hook-only session keeps cwd and project")
        check(AgentState.working.mood == .busy && AgentState.needsYou.mood == .alert, "agent state → Notchi mood")
        check(AgentLogs.peekTitle(previous: .working, next: merged[0]) == "Claude Code needs you · p", "peek text needs you")
        var done = merged[0]; done.state = .done
        check(AgentLogs.peekTitle(previous: .working, next: done) == "Claude Code finished · p", "peek text finished")
        check(AgentLogs.peekTitle(previous: nil, next: done) == nil, "no peek for sessions first seen as done")

        print("Antigravity state")
        let agUser = #"{"type":"USER_INPUT","content":"Fix the build\nActive Document: /Users/yubidev/work/notch/src/main.rs"}"#
        let agStateUser = AgentLogs.antigravityState([agUser])
        check(agStateUser.state == .working && agStateUser.cwd.contains("notch") == true, "antigravity USER_INPUT → working + project cwd")
        let agAsk = #"{"type":"PLANNER_RESPONSE","content":"Which approach?","tool_calls":[{"function":{"name":"ask_question","arguments":"{\"question\":\"Choose\"}"}}]}"#
        let agStateAsk = AgentLogs.antigravityState([agUser, agAsk])
        check(agStateAsk.state == .needsYou && agStateAsk.message == "Choose", "antigravity ask_question → needs_you + message")
        let agDone = #"{"type":"PLANNER_RESPONSE","status":"DONE","content":"All tests passed!"}"#
        let agStateDone = AgentLogs.antigravityState([agUser, agDone])
        check(agStateDone.state == .done, "antigravity status DONE without tools → done")

        print("Codex rate limits")
        let codex = #"{"timestamp":"2026-09-15T07:57:21.537Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":20,"total_tokens":120}},"rate_limits":{"primary":{"used_percent":82.5,"window_minutes":300,"resets_at":1784685946},"secondary":{"used_percent":3.0,"window_minutes":10080,"resets_at":1785000000},"plan_type":"plus"}}}"#
        let c = AIUsage.parseCodexLine(codex)
        check(c?.1 == 120, "tokens from last_token_usage.total_tokens")
        check(c?.2?.planType == "plus" && c?.2?.primary == RateWindow(usedPercent: 82.5, windowMinutes: 300, resetsAt: Date(timeIntervalSince1970: 1784685946)), "primary window + plan")
        check(c?.2?.primary?.label == "5h" && c?.2?.secondary?.label == "weekly", "window labels")
        let nulls = #"{"timestamp":"2026-09-15T07:57:21Z","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":7,"output_tokens":3}},"rate_limits":{"primary":null,"secondary":null}}}"#
        check(AIUsage.parseCodexLine(nulls)?.1 == 10 && AIUsage.parseCodexLine(nulls)?.2 == nil, "null limits → nil, input+output fallback")

        print("Hook JSON and HTTP")
        let ev = { (name: String) in HookEvent(["hook_event_name": name, "session_id": "s", "cwd": "/a/b/proj"]) }
        check(ev("UserPromptSubmit")?.state == .working && ev("PreToolUse")?.state == .working, "prompt / tool → working")
        check(ev("Notification")?.state == .needsYou && ev("Stop")?.state == .done, "notification → needs you, stop → done")
        check(ev("SessionStart") == nil && ev("Stop")?.project == "proj", "other events ignored, project from cwd")
        let raw = Data("POST /hook/claude HTTP/1.1\r\nHost: 127.0.0.1:47823\r\nContent-Length: 54\r\n\r\n{\"hook_event_name\":\"Stop\",\"session_id\":\"s\",\"cwd\":\"/x\"}".utf8)
        check(HookHTTP.parse(raw.prefix(raw.count - 5)) == nil, "waits for the full Content-Length")
        if let req = HookHTTP.parse(raw) {
            let r = HookHTTP.route(line: req.line, headers: req.headers, body: req.body)
            check(r.status == 204 && r.event?.state == .done, "valid hook → 204 + event")
            check(HookHTTP.route(line: req.line, headers: ["host": "evil.example:47823"], body: req.body).status == 403, "foreign Host → 403")
            check(HookHTTP.route(line: req.line, headers: req.headers.merging(["origin": "https://x"]) { $1 }, body: req.body).status == 403, "browser Origin → 403")
            check(HookHTTP.route(line: "GET / HTTP/1.1", headers: req.headers, body: Data()).status == 404, "other path → 404")
        } else { check(false, "parse full request") }

        print("settings.json merge")
        let original: [String: Any] = ["model": "opus", "hooks": [
            "Stop": [["hooks": [["type": "command", "command": "say done"]]]],
            "PostToolUse": [["matcher": "Edit", "hooks": [["type": "command", "command": "fmt"]]]],
        ]]
        let once = try! ClaudeHooks.merge(original)
        let twice = try! ClaudeHooks.merge(once)
        let hooks = once["hooks"] as! [String: Any]
        check(once["model"] as? String == "opus", "other keys kept")
        check((hooks["Stop"] as! [Any]).count == 2 && (hooks["PostToolUse"] as! [Any]).count == 1, "existing hooks kept, ours added")
        check(ClaudeHooks.events.allSatisfy { hooks[$0] != nil }, "all four events installed")
        check(NSDictionary(dictionary: once).isEqual(to: twice), "idempotent")
        check(NSDictionary(dictionary: ClaudeHooks.strip(once)).isEqual(to: original), "remove takes only ours")
        check(ClaudeHooks.strip(try! ClaudeHooks.merge([:])).isEmpty, "remove from empty leaves no hooks key")

        // Same flow on disk, in a temp folder.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("opennotchi-hooks-\(UUID())")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let before = try! JSONSerialization.data(withJSONObject: original)
        try! before.write(to: tmp.appendingPathComponent("settings.json"))
        try! ClaudeHooks.apply(dir: tmp, install: true)
        check(ClaudeHooks.isInstalled(dir: tmp), "installed on disk")
        check((try? Data(contentsOf: tmp.appendingPathComponent("settings.json.bak"))) == before, ".bak holds the original")
        let installed = try! Data(contentsOf: tmp.appendingPathComponent("settings.json"))
        try! ClaudeHooks.apply(dir: tmp, install: true)
        check((try? Data(contentsOf: tmp.appendingPathComponent("settings.json"))) == installed, "second install leaves the file unchanged")
        try! ClaudeHooks.apply(dir: tmp, install: false)
        let removed = (try? JSONSerialization.jsonObject(with: Data(contentsOf: tmp.appendingPathComponent("settings.json")))) as? [String: Any]
        check(!ClaudeHooks.isInstalled(dir: tmp) && removed.map { NSDictionary(dictionary: $0).isEqual(to: original) } == true, "remove restores the original content")
        try! Data("{not json".utf8).write(to: tmp.appendingPathComponent("settings.json"))
        check((try? ClaudeHooks.apply(dir: tmp, install: true)) == nil, "invalid JSON is left alone")
        try? FileManager.default.removeItem(at: tmp)

        print("Chat attachments")
        let attachDir = FileManager.default.temporaryDirectory.appendingPathComponent("notchi-attach-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: attachDir, withIntermediateDirectories: true)
        let txt = attachDir.appendingPathComponent("notes.txt")
        try? "hello notes".write(to: txt, atomically: true, encoding: .utf8)
        if case .text(let name, let body) = ChatAttachment.load(txt) {
            check(name == "notes.txt" && body == "hello notes", "text file read as text")
        } else { check(false, "text file read as text") }
        let rich = NSAttributedString(string: "hello from word")
        let docx = attachDir.appendingPathComponent("letter.docx")
        try? rich.data(from: NSRange(location: 0, length: rich.length), documentAttributes: [
            .documentType: NSAttributedString.DocumentType.officeOpenXML,
        ]).write(to: docx)
        if case .text(_, let body) = ChatAttachment.load(docx) {
            check(body.contains("hello from word"), "Word .docx read as text")
        } else { check(false, "Word .docx read as text") }
        let rtf = attachDir.appendingPathComponent("memo.rtf")
        try? rich.rtf(from: NSRange(location: 0, length: rich.length), documentAttributes: [:])?.write(to: rtf)
        if case .text(_, let body) = ChatAttachment.load(rtf) {
            check(body.contains("hello from word") && !body.contains("rtf1"), "RTF read as plain text, not markup")
        } else { check(false, "RTF read as plain text, not markup") }
        let png = attachDir.appendingPathComponent("dot.png")
        let dot = NSImage(size: NSSize(width: 4, height: 4))
        dot.lockFocus(); NSColor.red.setFill(); NSRect(x: 0, y: 0, width: 4, height: 4).fill(); dot.unlockFocus()
        try? NSBitmapImageRep(data: dot.tiffRepresentation!)?.representation(using: .png, properties: [:])?.write(to: png)
        if case .image = ChatAttachment.load(png) { check(true, "image file read as image") } else { check(false, "image file read as image") }
        let bin = attachDir.appendingPathComponent("blob.bin")
        try? Data([0xFF, 0xFE, 0x00, 0xC3, 0x28]).write(to: bin)
        check(ChatAttachment.load(bin) == nil, "binary file rejected")
        try? FileManager.default.removeItem(at: attachDir)

        print("Live crypto")
        check(MarketManager.binancePair(for: "BTC-USD") == "BTCUSDT", "BTC-USD → BTCUSDT")
        check(MarketManager.binancePair(for: "BBCA.JK") == nil && MarketManager.binancePair(for: "^JKSE") == nil,
              "stocks and indices stay on Yahoo")
        check(MarketManager.binancePair(for: "-USD") == nil, "empty base rejected")
        let binance = Data(#"[{"symbol":"BTCUSDT","price":"79782.01"},{"symbol":"ETHUSDT","price":"bad"}]"#.utf8)
        check(MarketManager.parseBinancePrices(binance) == ["BTCUSDT": 79782.01], "Binance prices parsed, bad rows skipped")
        let yahooQuote = Quote(symbol: "BTC-USD", name: "Bitcoin", price: 79000, previousClose: 78000, currency: "USD",
                               isMarketOpen: true, points: [1, 2], priceTime: now.addingTimeInterval(-120))
        let liveQuote = Quote(symbol: "BTC-USD", name: "Bitcoin", price: 79800, previousClose: 78000, currency: "USD",
                              isMarketOpen: true, points: [1], priceTime: now, isLive: true)
        let mergedQuote = MarketManager.merge(yahoo: yahooQuote, over: liveQuote)
        check(mergedQuote.price == 79800 && mergedQuote.points == [1, 2] && mergedQuote.isLive,
              "Yahoo refresh keeps the newer live price, takes its sparkline")
        check(MarketManager.merge(yahoo: yahooQuote, over: nil).price == 79000, "no live price: Yahoo's")
        check(QuoteCard.delayLabel(since: now.addingTimeInterval(-600), now: now) == "10m", "10 min delay label")
        check(QuoteCard.delayLabel(since: now.addingTimeInterval(-20), now: now) == nil, "fresh price: no label")

        print("Analytics period change")
        check(AnalyticsSection.change(120, 100) == "▲ 20%", "increase")
        check(AnalyticsSection.change(60, 100) == "▼ 40%", "decrease")
        check(AnalyticsSection.change(5, 0) == "new", "nothing before")
        check(AnalyticsSection.change(0, 0) == "–", "nothing either time")
        check(AnalyticsSection.change(5, nil) == nil, "no previous period (All)")
        let refDate = ISO8601DateFormatter().date(from: "2026-10-27T12:00:00Z")!
        check(AnalyticsSection.dateKey(daysAgo: 6, from: refDate) == "2026-10-21", "7D window starts 6 days back")

        print("9router quotas")
        func quota(_ name: String, _ pct: Double) -> NineRouterQuota {
            NineRouterQuota(name: name, used: 0, total: 1000, remaining: 0, remainingPercentage: pct, resetAt: nil, unlimited: false)
        }
        let antigravity = NineRouterService.displayQuotas([
            quota("claude-opus-5-5-high", 100), quota("gemini-3.8-flash-low", 77), quota("gemini_session", 77),
            quota("claude_gpt_session", 100), quota("gemini_weekly", 92), quota("claude_gpt_weekly", 100),
        ])
        check(antigravity.map(\.name) == ["Gemini (5h)", "Claude & GPT (5h)", "Gemini (Weekly)", "Claude & GPT (Weekly)"], "pools only, dashboard labels and order")
        check(antigravity.first?.remainingPercentage == 77, "pool keeps its numbers")
        let claude = NineRouterService.displayQuotas([quota("weekly (7d)", 2), quota("session (5h)", 82)])
        check(claude.map(\.name) == ["session (5h)", "weekly (7d)"], "no pools: every quota, sorted")

        print(failures == 0 ? "\nAll checks passed." : "\n\(failures) check(s) FAILED.")

        if args.count >= 2 {
            print("\nReal data")
            let accounts = [AIAccount(name: "Claude Code", tool: .claude, dir: args[0]), AIAccount(name: "Codex", tool: .codex, dir: args[1])]
            var cache: [AgentSession] = []
            let since = Date.now.addingTimeInterval(-30 * 60)
            for a in accounts {
                let files = a.tool == .claude
                    ? AgentLogs.claudeLogs(a.url, recursive: false)
                    : AgentLogs.codexDayDirs(a.url, 2).flatMap { AgentLogs.jsonlFiles(in: $0) }
                cache += files.filter { $0.1 >= since }.compactMap { AgentLogs.readSession(tool: a.tool, url: $0.0, mtime: $0.1) }
            }
            print("Agents (last 30 min):")
            for s in AgentLogs.merge(cache, hooks: [:], now: .now).prefix(5) {
                print("  \(s.tool.displayName) · \(s.project) · \(s.state.label) · \(Int(Date.now.timeIntervalSince(s.updatedAt)))s ago")
            }
            for a in accounts {
                let start = Date()
                let r = AIUsage.report(a)
                print("\(a.name) (\(a.dir)) found=\(r.found) scanned in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
                print("  today: \(r.today.tokens) tokens (\(formatTokens(r.today.tokens))) \(formatCost(r.today.cost))")
                if let b = r.block { print("  block from \(b.start): \(formatTokens(b.tokens.tokens)) \(formatCost(b.tokens.cost))") }
                print("  7 days: \(r.days.map(formatTokens))")
                if let l = r.limits {
                    print("  plan \(l.planType ?? "-")")
                    for w in [l.primary, l.secondary].compactMap({ $0 }) { print("  \(w.label) \(w.usedPercent)% \(resetsIn(w.resetsAt))") }
                }
            }
            let t0 = Date()
            _ = AIUsage.report(accounts[0])
            print("Claude rescan (cached): \(String(format: "%.3f", Date().timeIntervalSince(t0)))s")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
#endif
