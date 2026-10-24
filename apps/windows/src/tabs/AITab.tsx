import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import { Bot, Check, ClipboardPaste, Copy, Music2, SendHorizontal, Sparkles, Terminal, X } from "lucide-react"
import { useEffect, useRef, useState, type CSSProperties } from "react"
import {
  formatCost,
  formatTokens,
  getAccountQuota,
  mergeSessions,
  transitionPeek,
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
import { transitionBanner, type Banner } from "../banner"

type Section = "usage" | "agents" | "ask"

export function AITab({
  sessions,
  usage,
  onToggleActive,
  lyricLine,
  np,
}: {
  sessions: AgentSession[]
  usage: UsageReport[] | null
  onToggleActive?: (id: string, active: boolean) => void
  lyricLine: string | null
  np: NowPlaying | null
}) {
  const [settings] = useSettings()
  const [section, setSection] = useState<Section>(
    (usage && usage.length > 0) || settings.aiAccounts.length > 0
      ? "usage"
      : settings.aiAgents
      ? "agents"
      : "usage"
  )
  const now = Date.now()

  const totalTokensToday = usage?.reduce((sum, r) => sum + r.today.tokens, 0) ?? 0
  const totalCostToday = usage?.reduce((sum, r) => sum + r.today.cost, 0) ?? 0
  const activeCount = usage?.filter((r) => r.found && r.isActive !== false).length ?? 0

  return (
    <div className="tab-ai">
      <div className="segmented ai-segments">
        {(["usage", "agents", "ask"] as const).map((s) => (
          <button key={s} className={section === s ? "active" : ""} onClick={() => setSection(s)}>
            {s === "usage" ? "Quota & Accounts" : s === "agents" ? "Agents" : "Ask"}
          </button>
        ))}
      </div>
      <div className="ai-body">
        {section === "usage" && (
          <div className="ai-usage-wrap">
            {usage && usage.length > 0 && (
              <div className="ai-summary-bar">
                <div className="ai-summary-item">
                  <span className="ai-summary-label">Today</span>
                  <b className="ai-summary-val">{formatTokens(totalTokensToday)} tokens</b>
                </div>
                {totalCostToday > 0 && (
                  <div className="ai-summary-item">
                    <span className="ai-summary-label">Est. Cost</span>
                    <b className="ai-summary-val">{formatCost(totalCostToday)}</b>
                  </div>
                )}
                <div className="ai-summary-item">
                  <span className="ai-summary-label">Accounts</span>
                  <b className="ai-summary-val">{activeCount} active</b>
                </div>
              </div>
            )}

            {(!usage || usage.length === 0) && settings.aiAccounts.length === 0 ? (
              <div className="ai-empty">No AI accounts found. Connect 9router or add accounts in Settings › AI.</div>
            ) : !usage ? (
              <div className="ai-empty">Reading usage & quotas…</div>
            ) : (
              <div className="ai-usage">
                {usage.map((r, i) => (
                  <UsageCard
                    key={r.id || r.connectionId || i}
                    r={r}
                    now={now}
                    onToggleActive={onToggleActive}
                  />
                ))}
              </div>
            )}
          </div>
        )}

        {section === "agents" &&
          (!settings.aiAgents ? (
            <div className="ai-empty">Agent status is off in Settings › AI.</div>
          ) : sessions.length === 0 ? (
            <div className="ai-empty">No Claude Code, Codex, or Antigravity sessions in the last 30 minutes.</div>
          ) : (
            <div className="ai-agents">
              {sessions.map((s) => (
                <div key={s.sessionId} className="ai-agent-row" title={s.message ?? undefined}>
                  <AgentToolIcon tool={s.tool} />
                  <span className="ai-agent-project">{s.project || TOOL_NAMES[s.tool] || s.tool}</span>
                  <span className="ai-agent-msg">{s.state === "needs_you" ? s.message : TOOL_NAMES[s.tool] || s.tool}</span>
                  <span className={`ai-chip ${s.state}`}>{STATE_LABELS[s.state]}</span>
                  <span className="ai-agent-time">{timeAgo(s.updatedAt, now)}</span>
                </div>
              ))}
            </div>
          ))}

        {section === "ask" && <AskPanel lyricLine={lyricLine} np={np} />}
      </div>
    </div>
  )
}

function AgentToolIcon({ tool }: { tool: string }) {
  const t = tool.toLowerCase()
  if (t === "claude") return <Terminal size={13} className="ai-icon-tool ai-icon-claude" />
  if (t === "antigravity") return <Sparkles size={13} className="ai-icon-tool ai-icon-antigravity" />
  if (t === "commandcode") return <Terminal size={13} className="ai-icon-tool ai-icon-commandcode" />
  return <Bot size={13} className="ai-icon-tool ai-icon-codex" />
}

function UsageCard({
  r,
  now,
  onToggleActive,
}: {
  r: UsageReport
  now: number
  onToggleActive?: (id: string, active: boolean) => void
}) {
  const [expanded, setExpanded] = useState(false)
  const max = Math.max(1, ...r.days)
  const quota = getAccountQuota(r, now)
  const isActive = r.isActive !== false

  const handleToggle = (e: React.MouseEvent) => {
    e.stopPropagation()
    const targetId = r.connectionId || r.id
    if (targetId && onToggleActive) {
      onToggleActive(targetId, !isActive)
    }
  }

  return (
    <div
      className={`ai-card ai-card-${quota.health} ${!isActive ? "ai-card-inactive" : ""} ${r.isFrom9Router ? "ai-card-9router" : ""} ${expanded ? "expanded" : ""}`}
      onClick={() => r.isFrom9Router && setExpanded(!expanded)}
    >
      <div className="ai-card-head">
        <AgentToolIcon tool={r.tool} />
        <div className="ai-card-title-group">
          <strong className="ai-card-title">{r.name}</strong>
          {r.email && <span className="ai-card-email">{r.email}</span>}
        </div>

        {r.isFrom9Router && (
          <button
            type="button"
            className={`ai-toggle-pill ${isActive ? "active" : "inactive"}`}
            onClick={handleToggle}
            title={isActive ? "Active in 9router. Click to toggle OFF." : "Inactive. Click to toggle ON."}
          >
            {isActive ? "ON" : "OFF"}
          </button>
        )}

        <span className={`ai-health-badge ${quota.health}`}>{quota.health}</span>

        {r.isFrom9Router && (
          <span className={`ai-expand-arrow ${expanded ? "expanded" : ""}`} aria-hidden="true">
            ▼
          </span>
        )}
      </div>

      {!r.found ? (
        <div className="ai-card-empty">No sessions found in {r.dir}</div>
      ) : r.isFrom9Router ? (
        <div className="ai-9router-body">
          {r.quotas && r.quotas.length > 0 ? (
            <div className="ai-quota-list">
              {(expanded ? r.quotas : r.quotas.slice(0, 1)).map((q, idx) => {
                const usedPct = q.unlimited ? 0 : Math.min(100, Math.max(0, 100 - q.remainingPercentage))
                const isHot = !q.unlimited && q.remainingPercentage <= 20
                return (
                  <div key={idx} className="ai-quota-item">
                    <div className="ai-stat">
                      <span className="ai-quota-name">{q.name}</span>
                      <b>{q.unlimited ? "Unlimited" : `${Math.round(usedPct)}%`}</b>
                    </div>
                    {!q.unlimited && (
                      <div
                        className={`ai-bar ${isHot ? "hot" : ""}`}
                        style={{ "--p": `${usedPct}%` } as CSSProperties}
                      />
                    )}
                    {q.resetAt && q.resetAt > now && (
                      <div className="ai-card-note">{resetsIn(q.resetAt, now)}</div>
                    )}
                  </div>
                )
              })}
            </div>
          ) : r.planName ? (
            <div className="ai-stat">
              <span>Plan</span>
              <b>{r.planName}</b>
            </div>
          ) : null}

          {expanded && r.planName && (
            <div className="ai-stat">
              <span>Plan</span>
              <b>{r.planName}</b>
            </div>
          )}

          {expanded && r.testStatus && (
            <div className="ai-card-note">Status: {r.testStatus}</div>
          )}

          <div className="ai-stat">
            <span>Today</span>
            <b>
              {formatTokens(r.today.tokens)} {r.today.cost > 0 ? `· ${formatCost(r.today.cost)}` : "tokens"}
            </b>
          </div>

          <div className="ai-spark" title="Tokens per day, last 7 days">
            {r.days.map((d, i) => (
              <i
                key={i}
                style={{ height: `${Math.max(4, (d / max) * 100)}%` }}
                className={i === r.days.length - 1 ? "today" : ""}
              />
            ))}
          </div>
        </div>
      ) : (
        <>
          {r.tool === "codex" ? (
            <>
              {r.limits?.primary && <LimitBar w={r.limits.primary} now={now} />}
              {r.limits?.secondary && <LimitBar w={r.limits.secondary} now={now} />}
              {!r.limits && <div className="ai-card-empty">No rate limits reported yet</div>}
            </>
          ) : r.block ? (
            <div className="ai-limit">
              <div className="ai-stat">
                <span>5h rolling block</span>
                <b>{formatTokens(r.block.tokens)}</b>
              </div>
              <div className={`ai-bar ${quota.health === "exhausted" ? "hot" : ""}`} style={{ "--p": `${quota.percent}%` } as CSSProperties} />
              <div className="ai-card-note">{resetsIn(r.block.end, now)} {r.block.cost > 0 ? `· ${formatCost(r.block.cost)}` : ""}</div>
            </div>
          ) : null}

          <div className="ai-stat">
            <span>Today</span>
            <b>
              {formatTokens(r.today.tokens)} {r.today.cost > 0 ? `· ${formatCost(r.today.cost)}` : "tokens"}
            </b>
          </div>

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

/** Agent sessions from the logs every 2 s plus live hook events, and a banner peek on working → done / needs you. */
export function useAgents(enabled: boolean, onPeek?: (banner: Banner) => void): AgentSession[] {
  const [settings] = useSettings()
  const [logs, setLogs] = useState<AgentSession[]>([])
  const [hooks, setHooks] = useState<Record<string, HookEvent & { at: number }>>({})
  const prev = useRef<Record<string, AgentState>>({})
  const dirs = (tool: string) => settings.aiAccounts.filter((a) => a.tool === tool).map((a) => a.dir)
  const claudeDirs = dirs("claude")
  const codexDirs = dirs("codex")
  const antigravityDirs = dirs("antigravity")
  const key = JSON.stringify([claudeDirs, codexDirs, antigravityDirs])

  useEffect(() => {
    if (!enabled) return setLogs([])
    const poll = () =>
      invoke<AgentSession[]>("agent_sessions", { claudeDirs, codexDirs, antigravityDirs }).then(setLogs).catch(() => {})
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
      const banner = transitionBanner(prev.current[s.sessionId], s)
      if (banner && settings.aiNotify && onPeek) onPeek(banner)
      next[s.sessionId] = s.state
    }
    prev.current = next
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [signature])
  return sessions
}

/** Usage per account, rescanned every 30 s while AI features are on. Supports 9router toggle. */
export function useUsage(enabled: boolean): {
  usage: UsageReport[] | null
  toggleActive: (id: string, active: boolean) => Promise<void>
  refresh: () => Promise<void>
} {
  const [settings] = useSettings()
  const [usage, setUsage] = useState<UsageReport[] | null>(null)
  const key = JSON.stringify(settings.aiAccounts)

  const poll = () => {
    if (!enabled) return Promise.resolve()
    return invoke<UsageReport[]>("ai_usage", {
      accounts: settings.aiAccounts,
      tzOffsetMin: new Date().getTimezoneOffset(),
    })
      .then(setUsage)
      .catch(() => {})
  }

  useEffect(() => {
    if (!enabled) return setUsage(null)
    poll()
    const id = setInterval(poll, 30_000)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enabled, key])

  const toggleActive = async (id: string, active: boolean) => {
    // Optimistic local update
    setUsage((prev) =>
      prev?.map((r) => ((r.connectionId === id || r.id === id) ? { ...r, isActive: active } : r)) ?? null
    )
    try {
      await invoke("set_9router_connection_active", { id, active })
      setTimeout(poll, 500)
    } catch (e) {
      console.error("Failed to toggle connection in 9router:", e)
      poll()
    }
  }

  return { usage, toggleActive, refresh: poll }
}
