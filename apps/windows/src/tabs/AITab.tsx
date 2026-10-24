import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import { Bot, Check, ClipboardPaste, Copy, Music2, SendHorizontal, Terminal, X } from "lucide-react"
import { useEffect, useRef, useState, type CSSProperties } from "react"
import {
  formatCost,
  mergeSessions,
  transitionPeek,
  formatTokens,
  QUICK_ACTIONS,
  quickPrompt,
  resetsIn,
  STATE_LABELS,
  timeAgo,
  TOOL_NAMES,
  userLanguage,
  windowLabel,
  type AgentSession,
  type AgentState,
  type HookEvent,
  type QuickAction,
  type RateWindow,
  type UsageReport,
} from "../ai"
import type { NowPlaying } from "../media"
import { useSettings } from "../settings"

type Section = "agents" | "usage" | "ask"

export function AITab({
  sessions,
  usage,
  lyricLine,
  np,
}: {
  sessions: AgentSession[]
  usage: UsageReport[] | null
  lyricLine: string | null
  np: NowPlaying | null
}) {
  const [settings] = useSettings()
  const [section, setSection] = useState<Section>(settings.aiAgents ? "agents" : "usage")
  const now = Date.now()

  return (
    <div className="tab-ai">
      <div className="segmented ai-segments">
        {(["agents", "usage", "ask"] as const).map((s) => (
          <button key={s} className={section === s ? "active" : ""} onClick={() => setSection(s)}>
            {s === "agents" ? "Agents" : s === "usage" ? "Usage" : "Ask"}
          </button>
        ))}
      </div>
      <div className="ai-body">
        {section === "agents" &&
          (!settings.aiAgents ? (
            <div className="ai-empty">Agent status is off in Settings › AI.</div>
          ) : sessions.length === 0 ? (
            <div className="ai-empty">No Claude Code or Codex sessions in the last 30 minutes.</div>
          ) : (
            <div className="ai-agents">
              {sessions.map((s) => (
                <div key={s.sessionId} className="ai-agent-row" title={s.message ?? undefined}>
                  {s.tool === "claude" ? <Terminal size={13} /> : <Bot size={13} />}
                  <span className="ai-agent-project">{s.project || TOOL_NAMES[s.tool]}</span>
                  <span className="ai-agent-msg">{s.state === "needs_you" ? s.message : TOOL_NAMES[s.tool]}</span>
                  <span className={`ai-chip ${s.state}`}>{STATE_LABELS[s.state]}</span>
                  <span className="ai-agent-time">{timeAgo(s.updatedAt, now)}</span>
                </div>
              ))}
            </div>
          ))}

        {section === "usage" &&
          (settings.aiAccounts.length === 0 ? (
            <div className="ai-empty">Add a Claude Code or Codex folder in Settings › AI.</div>
          ) : !usage ? (
            <div className="ai-empty">Reading usage…</div>
          ) : (
            <div className="ai-usage">
              {usage.map((r, i) => (
                <UsageCard key={i} r={r} now={now} />
              ))}
            </div>
          ))}

        {section === "ask" && <AskPanel lyricLine={lyricLine} np={np} />}
      </div>
    </div>
  )
}

function UsageCard({ r, now }: { r: UsageReport; now: number }) {
  const max = Math.max(1, ...r.days)
  return (
    <div className="ai-card">
      <div className="ai-card-head">
        <strong>{r.name}</strong>
        {r.limits?.planType && <span className="ai-plan">{r.limits.planType}</span>}
      </div>
      {!r.found ? (
        <div className="ai-card-empty">No sessions found in {r.dir}</div>
      ) : r.tool === "codex" ? (
        <>
          {r.limits?.primary && <LimitBar w={r.limits.primary} now={now} />}
          {r.limits?.secondary && <LimitBar w={r.limits.secondary} now={now} />}
          {!r.limits && <div className="ai-card-empty">No rate limits reported yet</div>}
          <div className="ai-stat">
            <span>Today</span>
            <b>{formatTokens(r.today.tokens)} tokens</b>
          </div>
        </>
      ) : (
        <>
          <div className="ai-stat">
            <span>Today</span>
            <b>
              {formatTokens(r.today.tokens)} · {formatCost(r.today.cost)}
            </b>
          </div>
          <div className="ai-stat">
            <span>5h block</span>
            <b>{r.block ? `${formatTokens(r.block.tokens)} · ${formatCost(r.block.cost)}` : "not active"}</b>
          </div>
          {r.block && <div className="ai-card-note">{resetsIn(r.block.end, now)} · cost estimate</div>}
          <div className="ai-spark" title="Tokens per day, last 7 days">
            {r.days.map((d, i) => (
              <i key={i} style={{ height: `${Math.max(4, (d / max) * 100)}%` }} className={i === r.days.length - 1 ? "today" : ""} />
            ))}
          </div>
        </>
      )}
    </div>
  )
}

function LimitBar({ w, now }: { w: RateWindow; now: number }) {
  const pct = Math.min(100, Math.max(0, w.usedPercent))
  return (
    <div className="ai-limit">
      <div className="ai-stat">
        <span>{windowLabel(w.windowMinutes)}</span>
        <b>{Math.round(pct)}%</b>
      </div>
      <div className={`ai-bar ${pct >= 80 ? "hot" : ""}`} style={{ "--p": `${pct}%` } as CSSProperties} />
      <div className="ai-card-note">{resetsIn(w.resetsAt * 1000, now)}</div>
    </div>
  )
}

function providerFields(s: ReturnType<typeof useSettings>[0]) {
  if (s.aiProvider === "anthropic") return { provider: "anthropic", baseUrl: "", model: s.aiAnthropicModel }
  if (s.aiProvider === "openai") return { provider: "openai", baseUrl: s.aiOpenaiUrl, model: s.aiOpenaiModel }
  return { provider: "ollama", baseUrl: s.aiOllamaUrl, model: s.aiOllamaModel }
}

/** Sends a prompt with the provider from Settings; used by the Ask panel and the Settings "Test" button. */
export function askAi(settings: ReturnType<typeof useSettings>[0], prompt: string): Promise<string> {
  return invoke<string>("ask_ai", { req: { ...providerFields(settings), prompt } })
}

function AskPanel({ lyricLine, np }: { lyricLine: string | null; np: NowPlaying | null }) {
  const [settings] = useSettings()
  const [input, setInput] = useState("")
  const [answer, setAnswer] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [copied, setCopied] = useState(false)
  const [clip, setClip] = useState("")

  useEffect(() => {
    navigator.clipboard?.readText().then(setClip).catch(() => {})
  }, [])

  const reset = () => {
    setInput("")
    setAnswer(null)
    setError(null)
  }

  const run = async (prompt: string) => {
    setBusy(true)
    setError(null)
    setAnswer(null)
    try {
      setAnswer(await askAi(settings, prompt))
    } catch (e) {
      setError(String(e))
    } finally {
      setBusy(false)
    }
  }

  const quick = async (action: QuickAction) => {
    const lyric = lyricLine && lyricLine !== "♪" ? lyricLine : null
    const clipboard = action === "explain" ? "" : (await navigator.clipboard?.readText().catch(() => "")) || clip
    const text = action === "explain" ? lyric : input.trim() || clipboard.trim() || lyric
    if (!text) return setError(action === "explain" ? "No lyric line is showing right now." : "Copy some text first, or type it in the box.")
    run(quickPrompt(action, text, userLanguage(navigator.language), action === "explain" && np ? np : undefined))
  }

  const copy = () =>
    answer &&
    navigator.clipboard.writeText(answer).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 1200)
    })

  return (
    <div className="ai-ask" onKeyDown={(e) => e.key === "Escape" && reset()}>
      <div className="ai-ask-row">
        <input
          className="ai-ask-input"
          placeholder="Ask anything…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && input.trim() && !busy && run(input.trim())}
        />
        {(input || answer || error) && (
          <button className="prompter-btn" onClick={reset} title="Clear (Esc)" aria-label="Clear">
            <X size={12} />
          </button>
        )}
        <button className="prompter-btn primary" disabled={!input.trim() || busy} onClick={() => run(input.trim())} aria-label="Send">
          <SendHorizontal size={12} />
        </button>
      </div>
      <div className="ai-quick">
        {QUICK_ACTIONS.map((a) => (
          <button key={a.id} className="prompter-btn" disabled={busy} onClick={() => quick(a.id)}>
            {a.id === "explain" ? <Music2 size={11} /> : <ClipboardPaste size={11} />}
            {a.label}
          </button>
        ))}
      </div>
      <div className="ai-answer">
        {busy ? (
          <span className="muted">Thinking…</span>
        ) : error ? (
          <span className="ai-error">{error}</span>
        ) : answer ? (
          <>
            <button className="ai-copy" onClick={copy} title="Copy">
              {copied ? <Check size={12} /> : <Copy size={12} />}
            </button>
            <p>{answer}</p>
          </>
        ) : (
          <span className="muted">Quick actions use the text box, else your clipboard; Explain lyric uses the current line.</span>
        )}
      </div>
    </div>
  )
}

/** Agent sessions from the logs every 2 s plus live hook events, and a peek on working → done / needs you. */
export function useAgents(enabled: boolean, onPeek: (text: string) => void): AgentSession[] {
  const [settings] = useSettings()
  const [logs, setLogs] = useState<AgentSession[]>([])
  const [hooks, setHooks] = useState<Record<string, HookEvent & { at: number }>>({})
  const prev = useRef<Record<string, AgentState>>({})
  const dirs = (tool: string) => settings.aiAccounts.filter((a) => a.tool === tool).map((a) => a.dir)
  const claudeDirs = dirs("claude")
  const codexDirs = dirs("codex")
  const key = JSON.stringify([claudeDirs, codexDirs])

  useEffect(() => {
    if (!enabled) return setLogs([])
    const poll = () => invoke<AgentSession[]>("agent_sessions", { claudeDirs, codexDirs }).then(setLogs).catch(() => {})
    poll()
    const id = setInterval(poll, 2000)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, key])

  useEffect(() => {
    if (!enabled) return
    invoke("set_hook_server", { on: true }).catch((e) => console.warn(e))
    const unlisten = listen<HookEvent>("agent-hook", ({ payload }) =>
      setHooks((h) => ({ ...h, [payload.sessionId]: { ...payload, at: Date.now() } })),
    )
    return () => {
      invoke("set_hook_server", { on: false }).catch(() => {})
      unlisten.then((f) => f())
    }
  }, [enabled])

  const sessions = enabled ? mergeSessions(logs, hooks, Date.now()) : []
  const signature = sessions.map((s) => `${s.sessionId}:${s.state}`).join()
  useEffect(() => {
    const next: Record<string, AgentState> = {}
    for (const s of sessions) {
      const text = transitionPeek(prev.current[s.sessionId], s)
      if (text && settings.aiNotify) onPeek(text)
      next[s.sessionId] = s.state
    }
    prev.current = next
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [signature])
  return sessions
}

/** Usage per account, rescanned every 60 s while AI features are on. */
export function useUsage(enabled: boolean): UsageReport[] | null {
  const [settings] = useSettings()
  const [usage, setUsage] = useState<UsageReport[] | null>(null)
  const key = JSON.stringify(settings.aiAccounts)
  useEffect(() => {
    if (!enabled || !settings.aiAccounts.length) return setUsage(null)
    const poll = () =>
      invoke<UsageReport[]>("ai_usage", { accounts: settings.aiAccounts, tzOffsetMin: new Date().getTimezoneOffset() })
        .then(setUsage)
        .catch(() => {})
    poll()
    const id = setInterval(poll, 60_000)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, key])
  return usage
}
