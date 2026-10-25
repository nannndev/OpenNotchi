import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import { Bot, ExternalLink, LayoutGrid, List, Rows3, Sparkles, Terminal } from "lucide-react"
import { useEffect, useRef, useState, type CSSProperties } from "react"
import {
  formatCost,
  formatTokens,
  getAccountQuota,
  mergeSessions,
  transitionPeek,
  resetsIn,
  STATE_LABELS,
  timeAgo,
  TOOL_NAMES,
  windowLabel,
  type AgentSession,
  type AgentState,
  type HookEvent,
  type RateWindow,
  type UsageReport,
} from "../ai"
import type { NowPlaying } from "../media"
import { useSettings } from "../settings"
import { ChatPanel } from "./ChatPanel"
export { askAi } from "./ChatPanel"
import { transitionBanner, type Banner } from "../banner"

type Section = "usage" | "analytics" | "agents" | "ask"
type UsageLayout = "cards" | "compact" | "list"

const SECTION_LABELS: Record<Section, string> = { usage: "Quota & Accounts", analytics: "Analytics", agents: "Agents", ask: "Ask" }

/** Per-viewer UI choice; storage can be unavailable, so fall back silently. */
function useStored<T extends string>(key: string, fallback: T): [T, (v: T) => void] {
  const [v, setV] = useState<T>(() => {
    try {
      return (localStorage.getItem(key) as T) || fallback
    } catch {
      return fallback
    }
  })
  return [
    v,
    (next: T) => {
      setV(next)
      try {
        localStorage.setItem(key, next)
      } catch {}
    },
  ]
}

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
  const [settings, setSettings] = useSettings()
  const [section, setSection] = useState<Section>(
    (usage && usage.length > 0) || settings.aiAccounts.length > 0
      ? "usage"
      : settings.aiAgents
      ? "agents"
      : "usage"
  )
  const layout: UsageLayout = settings.usageLayout
  const setLayout = (l: UsageLayout) => setSettings({ usageLayout: l })
  const now = Date.now()

  const totalTokensToday = usage?.reduce((sum, r) => sum + r.today.tokens, 0) ?? 0
  const totalCostToday = usage?.reduce((sum, r) => sum + r.today.cost, 0) ?? 0
  const activeCount = usage?.filter((r) => r.found && r.isActive !== false).length ?? 0

  return (
    <div className="tab-ai">
      <div className="segmented ai-segments">
        {(Object.keys(SECTION_LABELS) as Section[]).map((s) => (
          <button key={s} className={section === s ? "active" : ""} onClick={() => setSection(s)}>
            {SECTION_LABELS[s]}
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
                <div className="ai-layout-picker" role="group" aria-label="Layout">
                  {([["cards", LayoutGrid], ["compact", Rows3], ["list", List]] as const).map(([l, Icon]) => (
                    <button key={l} className={layout === l ? "active" : ""} onClick={() => setLayout(l)} title={`${l} layout`} aria-label={`${l} layout`}>
                      <Icon size={11} />
                    </button>
                  ))}
                </div>
              </div>
            )}

            {(!usage || usage.length === 0) && settings.aiAccounts.length === 0 ? (
              <div className="ai-empty">No AI accounts found. Connect 9router or add accounts in Settings › AI.</div>
            ) : !usage ? (
              <div className="ai-empty">Reading usage & quotas…</div>
            ) : (
              <div className={layout === "cards" ? "ai-usage" : layout === "compact" ? "ai-usage-compact" : "ai-usage-list"}>
                {usage.map((r, i) =>
                  layout === "cards" ? (
                    <UsageCard key={r.id || r.connectionId || i} r={r} now={now} onToggleActive={onToggleActive} />
                  ) : (
                    <UsageRow key={r.id || r.connectionId || i} r={r} now={now} compact={layout === "compact"} onToggleActive={onToggleActive} />
                  ),
                )}
              </div>
            )}
          </div>
        )}

        {section === "analytics" && <AnalyticsPanel />}

        {section === "agents" &&
          (!settings.aiAgents ? (
            <div className="ai-empty">Agent status is off in Settings › AI.</div>
          ) : (
            <AgentsPanel sessions={sessions} now={now} />
          ))}

        {section === "ask" && <ChatPanel lyricLine={lyricLine} np={np} usage={usage} />}
      </div>
    </div>
  )
}

const LOGOS = ["claude", "codex", "antigravity", "commandcode"]

/** The provider's real logo (public/providers, from 9router), falling back to a generic icon. */
function AgentToolIcon({ tool, size = 16 }: { tool: string; size?: number }) {
  const t = tool.toLowerCase()
  if (LOGOS.includes(t)) return <img src={`/providers/${t}.png`} width={size} height={size} className="ai-logo" alt={TOOL_NAMES[t] || t} />
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
          <span className="ai-card-email">{TOOL_NAMES[r.tool] || r.tool}</span>
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

/** The quota closest to running out decides whether an account is usable. */
function tightestQuota(r: UsageReport) {
  return (r.quotas ?? []).filter((q) => !q.unlimited).sort((a, b) => a.remainingPercentage - b.remainingPercentage)[0]
}

const quotaLevel = (remaining: number) => (remaining <= 10 ? "hot" : remaining <= 30 ? "warn" : "ok")

/** Compact tile (ring + tightest quota) or a one-line list row with every quota. */
function UsageRow({
  r,
  now,
  compact,
  onToggleActive,
}: {
  r: UsageReport
  now: number
  compact: boolean
  onToggleActive?: (id: string, active: boolean) => void
}) {
  const isActive = r.isActive !== false
  const tight = tightestQuota(r)
  const remaining = tight?.remainingPercentage ?? 100
  const toggle = r.isFrom9Router && (
    <button
      type="button"
      className={`ai-switch ${isActive ? "on" : ""}`}
      onClick={() => onToggleActive?.(r.connectionId || r.id || "", !isActive)}
      title={isActive ? "Active in 9router. Click to turn off." : "Inactive. Click to turn on."}
      aria-label={`${r.name} ${isActive ? "on" : "off"}`}
    />
  )

  if (compact) {
    return (
      <div className={`ai-tile ${isActive ? "" : "ai-card-inactive"}`} title={tight?.resetAt ? resetsIn(tight.resetAt, now) : undefined}>
        <div className={`ai-ring ${tight ? quotaLevel(remaining) : ""}`} style={{ "--p": `${Math.max(0, Math.min(100, remaining))}%` } as CSSProperties}>
          <AgentToolIcon tool={r.tool} size={18} />
        </div>
        <div className="ai-tile-text">
          <strong>{r.name}</strong>
          <span className={tight ? `ai-q-${quotaLevel(remaining)}` : "muted"}>
            {tight ? `${Math.round(remaining)}% · ${tight.name}` : r.quotas?.length ? "Unlimited" : TOOL_NAMES[r.tool] || r.tool}
          </span>
          <span className="muted">
            {TOOL_NAMES[r.tool] || r.tool} · {formatTokens(r.today.tokens)} today
          </span>
        </div>
        {toggle}
      </div>
    )
  }

  return (
    <div className={`ai-list-row ${isActive ? "" : "ai-card-inactive"}`}>
      <AgentToolIcon tool={r.tool} size={20} />
      <div className="ai-list-name">
        <strong>{r.name}</strong>
        <span className="muted">{TOOL_NAMES[r.tool] || r.tool}</span>
      </div>
      <div className="ai-list-quotas">
        {(r.quotas ?? []).slice(0, 4).map((q) => (
          <div key={q.name} title={q.resetAt ? resetsIn(q.resetAt, now) : q.name}>
            <span>{q.unlimited ? `${q.name} ∞` : `${q.name} ${Math.round(q.remainingPercentage)}%`}</span>
            <i className={`ai-q-bar ai-q-${q.unlimited ? "ok" : quotaLevel(q.remainingPercentage)}`} style={{ "--p": `${q.unlimited ? 100 : Math.max(0, Math.min(100, q.remainingPercentage))}%` } as CSSProperties} />
          </div>
        ))}
      </div>
      <b className="ai-list-tokens">{formatTokens(r.today.tokens)}</b>
      {toggle}
    </div>
  )
}

const STATE_ORDER: Record<string, number> = { needs_you: 0, working: 1, done: 2, idle: 3 }

function AgentsPanel({ sessions, now }: { sessions: AgentSession[]; now: number }) {
  const count = (st: AgentState) => sessions.filter((s) => s.state === st).length
  const sorted = [...sessions].sort((a, b) => (STATE_ORDER[a.state] ?? 9) - (STATE_ORDER[b.state] ?? 9) || b.updatedAt - a.updatedAt)

  return (
    <div className="ai-agents">
      <div className="ai-agent-stats">
        {(["needs_you", "working", "done"] as const).map((st) => (
          <span key={st} className={`ai-stat-pill ${st} ${count(st) ? "has" : ""}`}>
            <b>{count(st)}</b> {STATE_LABELS[st]}
          </span>
        ))}
      </div>
      {sessions.length === 0 ? (
        <div className="ai-empty">
          <div className="ai-empty-logos">
            {LOGOS.map((t) => (
              <AgentToolIcon key={t} tool={t} size={30} />
            ))}
          </div>
          <b>No agents running</b>
          <span>Start Claude Code, Codex, Antigravity or Command Code. Progress and approval prompts show up here.</span>
        </div>
      ) : (
        <div className="ai-agent-grid">
          {sorted.map((s) => (
            <div key={s.sessionId} className={`ai-agent-card ${s.state}`} title={s.message ?? undefined}>
              <AgentToolIcon tool={s.tool} size={26} />
              <div className="ai-agent-text">
                <div className="ai-agent-top">
                  <strong>{s.project || TOOL_NAMES[s.tool] || s.tool}</strong>
                  <span className="ai-agent-time">{timeAgo(s.updatedAt, now)}</span>
                </div>
                <div className="ai-agent-state">
                  <i className="ai-dot" />
                  <b>{STATE_LABELS[s.state]}</b>
                  <span className="muted">· {TOOL_NAMES[s.tool] || s.tool}</span>
                </div>
                {s.message && <div className="ai-agent-msg">{s.message}</div>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

interface DayStat {
  date: string
  requests: number
  input: number
  cached: number
  output: number
  cost: number
}
interface Analytics {
  days: DayStat[]
  recent: { id: number; timestamp: string; model: string; provider: string; input: number; output: number; ok: boolean }[]
  topModels: { model: string; tokens: number; cost: number }[]
}

const RANGES = { Today: 1, "7D": 7, "30D": 30, All: null } as const
type Range = keyof typeof RANGES
type Metric = "Tokens" | "Requests" | "Cost"

/** 9router usage history: totals, a chart, recent requests and today's top models. */
function AnalyticsPanel() {
  const [range, setRange] = useStored<Range>("analyticsRange", "7D")
  const [metric, setMetric] = useState<Metric>("Tokens")
  const [data, setData] = useState<Analytics | null>(null)
  const now = Date.now()

  useEffect(() => {
    const load = () => invoke<Analytics>("ninerouter_analytics", { days: RANGES[range] }).then(setData).catch(() => setData(null))
    load()
    const id = setInterval(load, 10_000)
    return () => clearInterval(id)
  }, [range])

  if (!data) return <div className="ai-empty">Reading 9router…</div>
  if (data.days.length === 0 && data.recent.length === 0) return <div className="ai-empty">Install 9router to see request history and analytics.</div>

  const total = data.days.reduce(
    (t, d) => ({ requests: t.requests + d.requests, input: t.input + d.input, cached: t.cached + d.cached, output: t.output + d.output, cost: t.cost + d.cost }),
    { requests: 0, input: 0, cached: 0, output: 0, cost: 0 },
  )
  const value = (d: DayStat) => (metric === "Tokens" ? d.input + d.output : metric === "Requests" ? d.requests : d.cost)
  const values = data.days.map(value)
  const peak = Math.max(1, ...values)
  const pts = values.map((v, i) => `${values.length === 1 ? 50 : (i / (values.length - 1)) * 100},${100 - (v / peak) * 92}`)

  return (
    <div className="ai-analytics">
      <div className="ai-an-stats">
        <div><span>Requests</span><b>{total.requests.toLocaleString()}</b></div>
        <div><span>Input</span><b className="ai-c-orange">{formatTokens(total.input)}</b></div>
        <div><span>Cached</span><b className="ai-c-cyan">{formatTokens(total.cached)}</b></div>
        <div><span>Output</span><b className="ai-c-green">{formatTokens(total.output)}</b></div>
        <div><span>Est. cost</span><b className="ai-c-yellow">{formatCost(total.cost)}</b></div>
      </div>
      <div className="ai-an-body">
        <div className="ai-an-chart">
          <div className="ai-an-controls">
            <div className="segmented">
              {(["Tokens", "Requests", "Cost"] as const).map((m) => (
                <button key={m} className={metric === m ? "active" : ""} onClick={() => setMetric(m)}>{m}</button>
              ))}
            </div>
            <div className="segmented">
              {(Object.keys(RANGES) as Range[]).map((r) => (
                <button key={r} className={range === r ? "active" : ""} onClick={() => setRange(r)}>{r}</button>
              ))}
            </div>
          </div>
          <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="ai-an-svg" role="img" aria-label={`${metric} per day`}>
            <defs>
              <linearGradient id="an-fill" x1="0" x2="0" y1="0" y2="1">
                <stop offset="0" stopColor="var(--accent)" stopOpacity="0.35" />
                <stop offset="1" stopColor="var(--accent)" stopOpacity="0" />
              </linearGradient>
            </defs>
            {pts.length > 1 && <polygon points={`0,100 ${pts.join(" ")} 100,100`} fill="url(#an-fill)" />}
            {pts.length > 1 && <polyline points={pts.join(" ")} fill="none" stroke="var(--accent)" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />}
            {pts.length === 1 && <circle cx="50" cy={pts[0].split(",")[1]} r="1.5" fill="var(--accent)" />}
          </svg>
          <div className="ai-an-axis">
            <span>{data.days[0]?.date.slice(5)}</span>
            <span>peak {metric === "Cost" ? formatCost(peak) : formatTokens(peak)}</span>
            <span>{data.days[data.days.length - 1]?.date.slice(5)}</span>
          </div>
        </div>
        <div className="ai-an-recent">
          <span className="ai-an-title">Recent requests</span>
          {data.recent.map((r) => (
            <div key={r.id} className={`ai-an-req ${r.ok ? "" : "fail"}`}>
              <AgentToolIcon tool={r.provider} size={12} />
              <span className="ai-an-model">{r.model}</span>
              <span className="muted">{formatTokens(r.input)}↑ {formatTokens(r.output)}↓</span>
              <span className="ai-agent-time">{timeAgo(Date.parse(r.timestamp), now)}</span>
            </div>
          ))}
          {data.topModels.length > 0 && <span className="ai-an-title">Top models today</span>}
          {data.topModels.map((m) => (
            <div key={m.model} className="ai-an-req">
              <span className="ai-an-model">{m.model}</span>
              <b>{formatTokens(m.tokens)}</b>
            </div>
          ))}
          <button className="ai-an-open" onClick={() => invoke("open_external_url", { url: "http://127.0.0.1:20128" }).catch(() => {})}>
            <ExternalLink size={10} /> Open 9router
          </button>
        </div>
      </div>
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
