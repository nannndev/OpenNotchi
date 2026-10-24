# AI features: shared spec (macOS + Windows)

Both apps implement the same three features with the same behavior, labels and defaults. Everything is **off by default** (opt-in in Settings), because the site promises "No account, no tracking". Nothing leaves the computer except Ask AI requests the user sends to a provider they configured with their own key.

## 1. AI tab (new notch tab "AI", icon: sparkles)

Three sections, top to bottom (or segmented: Agents · Usage · Ask):

### 1a. Agents: live status of AI coding agents
Show each agent session active in the last 30 minutes as a row: tool icon (Claude Code / Codex), project name (last path component of cwd), state chip, time since last activity. Most recent first, max 5.

States: `working` (accent, animated), `needs you` (orange: waiting for permission or input), `done` (green), `idle` (grey, >5 min since done).

**Sources, both platforms:**
- **Log polling (zero setup, always on when the feature is enabled).** Every 2 s, stat the newest session files; only re-read files whose mtime changed, and only the tail (last ~64 KB).
  - Claude Code: `<configDir>/projects/*/*.jsonl` (skip `*/subagents/*`). Each line is JSON. The last `type:"assistant"` line with `message.stop_reason`:
    `tool_use` → working; `end_turn` → done. A `type:"user"` line after it → working. File not written for >5 min after done → idle. `cwd` and `sessionId` are on the lines.
  - Codex: `<codexHome>/sessions/YYYY/MM/DD/rollout-*.jsonl`. `payload.type` `task_started` → working, `task_complete` → done. `session_meta.payload.cwd` gives the project.
- **Hooks (optional, instant + "needs you").** The app listens on `127.0.0.1:47823` (loopback only, reject other hosts) and accepts `POST /hook/claude` with the Claude Code hook JSON on the body (`hook_event_name`, `session_id`, `cwd`, `message`). Map: `UserPromptSubmit`/`PreToolUse` → working, `Notification` → needs you (show `message`), `Stop` → done. Settings has **Install Claude Code hooks** / **Remove**: merges entries into `<configDir>/settings.json` (keep every existing key and hook; write a `.bak` first; idempotent; identify ours by the URL). Hook command: `curl -s -m 2 -X POST -H "Content-Type: application/json" --data-binary @- http://127.0.0.1:47823/hook/claude` (curl ships with macOS and Windows 10+). If the port is taken, log it and keep log polling.
- **Peek:** when a session goes working → done or → needs you, show the existing banner/peek pill for ~4 s: "Claude Code finished · <project>" / "Claude Code needs you · <project>". Setting: "Notify when an agent finishes" (default on once the feature is enabled).
- Clicking a row: activate the terminal app if possible (macOS: open the app that's frontmost-capable, e.g. `NSWorkspace` activate Terminal/iTerm/Ghostty/VS Code by bundle id found running; Windows: best effort, skip if not trivial).

### 1b. Usage: multiple accounts
Settings has a list of **accounts**: `{ name, tool: "claude" | "codex", dir }`. Defaults on first enable: `Claude Code` → `~/.claude`, `Codex` → `~/.codex` (only if the dir exists). User can add more dirs (e.g. a second `CLAUDE_CONFIG_DIR`) and rename/remove.

Per account card:
- **Claude Code:** tokens and estimated cost for **today** and the **current 5-hour block** (block starts at the first message after a ≥5 h gap, floored to the hour, like ccusage), plus a small 7-day bar sparkline. Read `type:"assistant"` lines' `message.usage` (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`) and `message.model`; **dedupe by `message.id` + `requestId`** (the same message is logged several times). Cost from a built-in per-model price table (USD per million tokens, input/output/cache-write/cache-read), labelled "estimate"; unknown models count tokens only. Scan incrementally (cache per file: size + parsed totals) so a big `projects` folder stays cheap; rescan at most every 60 s.
- **Codex:** latest `token_count` event's `rate_limits.primary` / `.secondary` → progress bars "5h" / "weekly" (label from `window_minutes`) with `used_percent` and "resets in Xh" from `resets_at` (unix s), plus `plan_type`. Tokens today from `token_count.info.last_token_usage` summed over today's events.
- Empty/missing dir → card says "No sessions found in <dir>".

Notch closed (live activity): if any Codex window is ≥ 80% used, or a Claude block is active, the closed pill may show a compact meter; keep it subtle and behind a setting "Show usage in the closed notch" (default off).

### 1c. Ask AI
Text field + quick actions on the **clipboard text** or the **current lyric line**: Summarize, Fix writing, Translate (to the user's language), Explain lyric. Answer appears below, selectable, with Copy. Esc / clear button resets.

**Providers (Settings › AI › Provider):**
- macOS only: **Apple Intelligence (on-device)** via the Foundation Models framework, shown only when available (`#available(macOS 26, *)` + `SystemLanguageModel.default.availability == .available`). Default when available.
- **Ollama** (local): base URL default `http://127.0.0.1:11434`, model name text field (default `llama3.2`). `POST /api/chat`, `stream: false`.
- **Anthropic API**: key + model (default `claude-haiku-5-5`, also offer `claude-sonnet-5-5`). Load the `claude-api` skill before writing this call. Messages API, `max_tokens` 1024.
- **OpenAI-compatible**: base URL (default `https://api.openai.com/v1`) + key + model.
- Keys are stored in the **Keychain** (macOS) / **Windows Credential Manager** (Windows), never in UserDefaults/localStorage/settings files. Show a "Test" button.
- Short system prompt: answer concisely, plain text, no markdown headings.

## Settings › AI (both apps)
Master toggle "Enable AI features" (off). Then: Agents (toggle, Install/Remove hooks, notify toggle), Usage (accounts list, closed-notch meter toggle), Ask AI (provider + fields + Test). One line under the master toggle: "Agent status and usage are read from files on this computer. Ask AI sends your text only to the provider you choose."

## Not in scope
Approving agent permissions from the notch; scraping claude.ai / chatgpt.com subscription limits via cookies; org admin-key usage APIs.
