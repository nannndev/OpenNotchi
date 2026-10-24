/** AI features: agent status, usage and Ask AI. Pure helpers here; the file reading is in Rust (src-tauri/src/ai.rs). */

export type AiProvider = "ollama" | "anthropic" | "openai"
export type AgentTool = "claude" | "codex"
export type AgentState = "working" | "needs_you" | "done" | "idle"

export interface AiAccount {
  name: string
  tool: AgentTool
  dir: string
}

/** One row from `agent_sessions`. */
export interface AgentSession {
  tool: AgentTool
  sessionId: string
  project: string
  state: AgentState
  updatedAt: number
  message?: string | null
}

/** Payload of the `agent-hook` event from the local hook listener. */
export interface HookEvent {
  sessionId: string
  project: string
  state: "working" | "needs_you" | "done"
  message: string | null
}

export interface RateWindow {
  usedPercent: number
  windowMinutes: number
  resetsAt: number
}

export interface UsageReport {
  name: string
  tool: AgentTool
  dir: string
  found: boolean
  today: { tokens: number; cost: number }
  block: { start: number; end: number; tokens: number; cost: number } | null
  days: number[]
  limits: { planType: string | null; primary: RateWindow | null; secondary: RateWindow | null } | null
}

export const IDLE_AFTER_MS = 5 * 60_000
export const MAX_AGENT_ROWS = 5

export const TOOL_NAMES: Record<AgentTool, string> = { claude: "Claude Code", codex: "Codex" }
export const STATE_LABELS: Record<AgentState, string> = { working: "working", needs_you: "needs you", done: "done", idle: "idle" }

export const PROVIDERS: { id: AiProvider; name: string }[] = [
  { id: "ollama", name: "Ollama (local)" },
  { id: "anthropic", name: "Anthropic API" },
  { id: "openai", name: "OpenAI-compatible" },
]
export const ANTHROPIC_MODELS = ["claude-haiku-5-5", "claude-sonnet-5-5"]

/**
 * Log sessions with the latest hook event for each laid over them: a hook newer than the log's last write
 * wins (that's how "needs you" shows), sessions only known from hooks are added, done turns idle after 5 min.
 */
export function mergeSessions(
  logs: AgentSession[],
  hooks: Record<string, HookEvent & { at: number }>,
  now: number,
): AgentSession[] {
  const byId = new Map(logs.map((s) => [s.sessionId, { ...s }]))
  for (const h of Object.values(hooks)) {
    if (now - h.at > 30 * 60_000) continue
    const s = byId.get(h.sessionId)
    if (!s) byId.set(h.sessionId, { tool: "claude", sessionId: h.sessionId, project: h.project, state: h.state, updatedAt: h.at, message: h.message })
    else if (h.at >= s.updatedAt - 1000) Object.assign(s, { state: h.state, updatedAt: Math.max(s.updatedAt, h.at), message: h.message, project: s.project || h.project })
  }
  return [...byId.values()]
    .map((s) => (s.state === "done" && now - s.updatedAt > IDLE_AFTER_MS ? { ...s, state: "idle" as const } : s))
    .sort((a, b) => b.updatedAt - a.updatedAt)
    .slice(0, MAX_AGENT_ROWS)
}

/** Peek text when a session moves from working to done or to needs you; null otherwise. */
export function transitionPeek(prev: AgentState | undefined, next: AgentSession): string | null {
  const name = `${TOOL_NAMES[next.tool]} ${next.state === "done" ? "finished" : "needs you"}`
  if (next.state === "needs_you" && prev !== "needs_you" && prev !== undefined) return `${name} · ${next.project}`
  if (next.state === "done" && (prev === "working" || prev === "needs_you")) return `${name} · ${next.project}`
  return null
}

export function timeAgo(ms: number, now: number): string {
  const s = Math.max(0, Math.round((now - ms) / 1000))
  if (s < 60) return "now"
  if (s < 3600) return `${Math.floor(s / 60)}m`
  return `${Math.floor(s / 3600)}h`
}

/** 1234 → "1.2K", 93176220 → "93.2M". */
export function formatTokens(n: number): string {
  if (n < 1000) return String(n)
  const [v, unit] = n < 1e6 ? [n / 1e3, "K"] : n < 1e9 ? [n / 1e6, "M"] : [n / 1e9, "B"]
  return `${v < 10 ? v.toFixed(1) : Math.round(v)}${unit}`.replace(".0", "")
}

export function formatCost(usd: number): string {
  return usd >= 100 ? `$${Math.round(usd)}` : `$${usd.toFixed(2)}`
}

/** "5h" / "weekly" / "24h" from a Codex rate-limit window. */
export function windowLabel(minutes: number): string {
  if (minutes === 10080) return "weekly"
  if (minutes % 1440 === 0) return `${minutes / 1440}d`
  return minutes % 60 === 0 ? `${minutes / 60}h` : `${minutes}m`
}

/** "resets in 3h 20m" / "resets in 2d" from a target time (unix ms). */
export function resetsIn(atMs: number, now: number): string {
  const m = Math.max(0, Math.round((atMs - now) / 60_000))
  if (m >= 2880) return `resets in ${Math.round(m / 1440)}d`
  if (m >= 60) return `resets in ${Math.floor(m / 60)}h${m % 60 ? ` ${m % 60}m` : ""}`
  return `resets in ${m}m`
}

/** The compact closed-notch meter: a Codex window at ≥ 80 %, else an active Claude block's elapsed share. */
export function closedMeter(reports: UsageReport[], now: number): { label: string; percent: number; hot: boolean } | null {
  for (const r of reports) {
    for (const w of [r.limits?.primary, r.limits?.secondary]) {
      if (w && w.usedPercent >= 80 && w.resetsAt * 1000 > now)
        return { label: `${windowLabel(w.windowMinutes)} ${Math.round(w.usedPercent)}%`, percent: w.usedPercent, hot: true }
    }
  }
  const block = reports.find((r) => r.block && r.block.end > now)?.block
  if (!block) return null
  const percent = ((now - block.start) / (block.end - block.start)) * 100
  return { label: formatTokens(block.tokens), percent, hot: false }
}

export type QuickAction = "summarize" | "fix" | "translate" | "explain"

export const QUICK_ACTIONS: { id: QuickAction; label: string }[] = [
  { id: "summarize", label: "Summarize" },
  { id: "fix", label: "Fix writing" },
  { id: "translate", label: "Translate" },
  { id: "explain", label: "Explain lyric" },
]

/** The language to translate into, from the system locale ("English", "Indonesian"…). */
export function userLanguage(locale: string): string {
  try {
    return new Intl.DisplayNames(["en"], { type: "language" }).of(locale.split("-")[0]) ?? "English"
  } catch {
    return "English"
  }
}

export function quickPrompt(action: QuickAction, text: string, language: string, song?: { title: string; artist: string }): string {
  switch (action) {
    case "summarize":
      return `Summarize this in a few sentences:\n\n${text}`
    case "fix":
      return `Fix the spelling, grammar and wording of this text. Reply with the corrected text only:\n\n${text}`
    case "translate":
      return `Translate this into ${language}. Reply with the translation only:\n\n${text}`
    case "explain":
      return `Explain the meaning of this song lyric${song ? ` from "${song.title}" by ${song.artist}` : ""}:\n\n"${text}"`
  }
}
