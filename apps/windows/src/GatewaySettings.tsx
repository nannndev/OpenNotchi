import { invoke } from "@tauri-apps/api/core"
import { ArrowDown, ArrowUp, Copy, LogIn, RefreshCw, Trash2 } from "lucide-react"
import { useCallback, useEffect, useState } from "react"
import { openExternalUrl } from "./updater"

/** Settings › Gateway: the bundled Notchi Gateway's providers, accounts and routing. */

interface Provider {
  id: string
  alias: string
  name: string
  family: string
  needs_key: boolean
  enabled: boolean
  connected: boolean
  base_url: string | null
  default_base_url: string
  custom_models: string[]
  seed_models: string[]
  synced_count?: number
  models_synced_at?: number | null
  cooling?: boolean
  extra_keys?: { id: string; label: string | null; enabled: boolean; last_error: string | null; cooling_until: number | null }[]
}

interface Account {
  id: string
  provider: string
  label: string | null
  email: string | null
  enabled: boolean
  plan: string | null
  last_error: string | null
  cooling_until: number | null
}

interface OAuthMeta {
  id: string
  alias: string
  name: string
  flow: string
}

interface Routing {
  settings: {
    routing_strategy: string
    fallback_order: string
    provider_priority: string[]
    auto_models_per_provider: number
    cooldown_secs: number
  }
  auto_order: string[]
}

interface Stats {
  requests: number
  input_tokens: number
  output_tokens: number
  errors: number
  connected_providers: number
}

type Tab = "overview" | "providers" | "accounts" | "routing"

/** Providers whose own login can be imported from disk. */
const IMPORTABLE: Record<string, string> = { commandcode: "Command Code CLI", "xiaomi-mimo": "MiMo Desktop", kiro: "Kiro IDE", codex: "Codex CLI" }
/** Subscription providers that expose a model list. */
const SYNCABLE_OAUTH = ["copilot", "kimi", "kilocode", "nous", "cline", "grok-cli"]

const admin = <T,>(method: string, path: string, body?: unknown) => invoke<T>("gateway_admin", { method, path, body: body ?? null })
const fmt = (n: number) => (n >= 1e6 ? `${(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${(n / 1e3).toFixed(1)}K` : String(n))

export function GatewaySettings() {
  const [tab, setTab] = useState<Tab>("overview")
  const [providers, setProviders] = useState<Provider[]>([])
  const [accounts, setAccounts] = useState<Account[]>([])
  const [oauth, setOauth] = useState<OAuthMeta[]>([])
  const [routing, setRouting] = useState<Routing | null>(null)
  const [combos, setCombos] = useState<Record<string, string[]>>({})
  const [stats, setStats] = useState<Stats | null>(null)
  const [endpoint, setEndpoint] = useState("")
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)

  const reload = useCallback(async () => {
    try {
      const [p, a, r, c, s] = await Promise.all([
        admin<{ providers: Provider[] }>("GET", "/gateway/admin/providers"),
        admin<{ accounts: Account[]; providers: OAuthMeta[] }>("GET", "/gateway/admin/accounts"),
        admin<Routing>("GET", "/gateway/admin/settings"),
        admin<{ combos: Record<string, string[]> }>("GET", "/gateway/admin/combos"),
        admin<Stats>("GET", "/gateway/admin/stats"),
      ])
      setProviders(p.providers)
      setAccounts(a.accounts)
      setOauth(a.providers ?? [])
      setRouting(r)
      setCombos(c.combos)
      setStats(s)
    } catch (e) {
      setMsg({ ok: false, text: String(e) })
    }
  }, [])

  useEffect(() => {
    invoke<string>("gateway_endpoint").then(setEndpoint).catch(() => {})
    reload()
  }, [reload])

  /** Runs an action, shows its result and reloads. */
  const act = async (fn: () => Promise<unknown>, ok?: string) => {
    setBusy(true)
    setMsg(null)
    try {
      await fn()
      if (ok) setMsg({ ok: true, text: ok })
      await reload()
    } catch (e) {
      setMsg({ ok: false, text: String(e) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="settings-section">
      <h2 className="section-title">Notchi Gateway</h2>
      <p className="toggle-desc gw-intro">
        One local endpoint for all your AI accounts and API keys. Ask AI uses it, and so can Claude Code, Codex, Cursor or any OpenAI-compatible tool.
      </p>

      <div className="gw-tabs" role="tablist">
        {(["overview", "providers", "accounts", "routing"] as const).map((t) => (
          <button key={t} role="tab" aria-selected={tab === t} className={`gw-tab ${tab === t ? "active" : ""}`} onClick={() => setTab(t)}>
            {t[0].toUpperCase() + t.slice(1)}
          </button>
        ))}
      </div>

      {tab === "overview" && <Overview endpoint={endpoint} stats={stats} />}
      {tab === "providers" && <Providers providers={providers} busy={busy} act={act} />}
      {tab === "accounts" && <Accounts accounts={accounts} oauth={oauth} busy={busy} act={act} setMsg={setMsg} reload={reload} />}
      {tab === "routing" && routing && <RoutingTab routing={routing} combos={combos} providers={providers} oauth={oauth} act={act} />}

      {msg && <div className={`gw-msg ${msg.ok ? "ai-ok" : "ai-error"}`}>{msg.text}</div>}
    </div>
  )
}

function Overview({ endpoint, stats }: { endpoint: string; stats: Stats | null }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="toggle-list">
      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">OpenAI-compatible endpoint</div>
          <div className="toggle-desc gw-mono">{endpoint}</div>
        </div>
        <button
          className="ai-settings-btn"
          onClick={() => {
            navigator.clipboard?.writeText(endpoint)
            setCopied(true)
            setTimeout(() => setCopied(false), 1500)
          }}
        >
          <Copy size={12} /> {copied ? "Copied" : "Copy"}
        </button>
      </div>
      {stats && (
        <div className="gw-stats">
          <div><span>Connected</span><b>{stats.connected_providers}</b></div>
          <div><span>Requests</span><b>{stats.requests.toLocaleString()}</b></div>
          <div><span>Tokens</span><b>{fmt(stats.input_tokens + stats.output_tokens)}</b></div>
          <div><span>Errors</span><b>{stats.errors}</b></div>
        </div>
      )}
    </div>
  )
}

function Providers({ providers, busy, act }: { providers: Provider[]; busy: boolean; act: (fn: () => Promise<unknown>, ok?: string) => Promise<void> }) {
  const [selected, setSelected] = useState("")
  const [filter, setFilter] = useState("")
  const [key, setKey] = useState("")
  const [baseUrl, setBaseUrl] = useState("")
  const [newModel, setNewModel] = useState("")
  const [extraKey, setExtraKey] = useState("")
  const p = providers.find((x) => x.id === selected) ?? providers[0]

  useEffect(() => {
    setKey("")
    setBaseUrl(p?.base_url ?? "")
  }, [p?.id, p?.base_url])

  if (!p) return <div className="ai-empty">Starting Notchi Gateway…</div>
  const shown = providers.filter((x) => `${x.name} ${x.id}`.toLowerCase().includes(filter.toLowerCase()))
  const synced = p.synced_count && p.models_synced_at
    ? `${p.synced_count} from provider · synced ${new Date(p.models_synced_at * 1000).toLocaleString()}`
    : `${p.seed_models.length} built-in`

  return (
    <div className="toggle-list">
      <div className="toggle-row">
        <input className="settings-input" placeholder="Search providers…" value={filter} onChange={(e) => setFilter(e.target.value)} />
        <select className="settings-select" value={p.id} onChange={(e) => setSelected(e.target.value)}>
          {shown.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name} {!x.enabled ? "· off" : x.connected ? "· connected" : ""}
            </option>
          ))}
        </select>
      </div>

      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">{p.name}</div>
          <div className="toggle-desc">
            {p.family} · alias <span className="gw-mono">{p.alias}/</span> {p.cooling ? "· cooling down" : ""}
          </div>
        </div>
        <label className="gw-switch" title={p.enabled ? "Disable" : "Enable"}>
          <input
            type="checkbox"
            checked={p.enabled}
            onChange={(e) => act(() => admin("PATCH", `/gateway/admin/providers/${p.id}/toggle`, { enabled: e.target.checked }))}
          />
        </label>
      </div>

      {p.needs_key && (
        <div className="toggle-row">
          <input
            className="settings-input ai-wide"
            type="password"
            placeholder={p.connected ? "•••••••• (paste a new key)" : "Paste API key…"}
            value={key}
            onChange={(e) => setKey(e.target.value)}
          />
          <button
            className="ai-settings-btn"
            disabled={busy || !key.trim()}
            onClick={() => act(() => admin("POST", `/gateway/admin/providers/${p.id}/connect`, { api_key: key.trim(), base_url: baseUrl.trim() || null }), `Connected ${p.name}.`)}
          >
            Connect
          </button>
          {p.connected && (
            <button className="ai-icon-btn" title="Disconnect" aria-label="Disconnect" onClick={() => act(() => admin("POST", `/gateway/admin/providers/${p.id}/disconnect`), `Disconnected ${p.name}.`)}>
              <Trash2 size={13} />
            </button>
          )}
        </div>
      )}
      {p.needs_key && (
        <div className="toggle-row">
          <input
            className="settings-input ai-wide"
            placeholder={p.default_base_url ? `Base URL (default ${p.default_base_url})` : "Base URL (required)"}
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
          />
          {IMPORTABLE[p.id] && (
            <button className="ai-settings-btn" disabled={busy} onClick={() => act(() => admin("POST", `/gateway/admin/providers/${p.id}/import`), `Imported key from ${IMPORTABLE[p.id]}.`)}>
              Import from {IMPORTABLE[p.id]}
            </button>
          )}
        </div>
      )}

      {p.needs_key && p.connected && (
        <>
          <div className="toggle-row">
            <div className="toggle-info">
              <div className="toggle-title">More keys</div>
              <div className="toggle-desc">{(p.extra_keys?.length ?? 0) + 1} total · they rotate per Routing</div>
            </div>
          </div>
          {(p.extra_keys ?? []).map((k, i, list) => (
            <div key={k.id} className={`toggle-row gw-account ${k.enabled ? "" : "ai-card-inactive"}`}>
              <label className="gw-switch" title={k.enabled ? "Pause" : "Use again"}>
                <input
                  type="checkbox"
                  checked={k.enabled}
                  onChange={(e) => act(() => admin("PATCH", `/gateway/admin/accounts/${p.id}/${encodeURIComponent(k.id)}/toggle`, { enabled: e.target.checked }))}
                />
              </label>
              <div className="toggle-info">
                <div className="toggle-title gw-mono">{k.label ?? k.id}</div>
                {k.last_error && <div className="toggle-desc ai-error">{k.last_error.slice(0, 80)}</div>}
              </div>
              {list.length > 1 && (
                <MoveButtons
                  index={i}
                  count={list.length}
                  onSwap={(from, to) => {
                    const ids = list.map((x) => x.id)
                    ;[ids[from], ids[to]] = [ids[to], ids[from]]
                    act(() => admin("POST", `/gateway/admin/accounts/${p.id}/reorder`, { account_ids: ids }))
                  }}
                />
              )}
              <button className="ai-icon-btn" title="Remove this key" aria-label="Remove this key"
                onClick={() => act(() => admin("DELETE", `/gateway/admin/accounts/${p.id}/${encodeURIComponent(k.id)}`))}>
                <Trash2 size={13} />
              </button>
            </div>
          ))}
          <div className="toggle-row">
            <input className="settings-input ai-wide" type="password" placeholder="Paste another API key…" value={extraKey} onChange={(e) => setExtraKey(e.target.value)} />
            <button
              className="ai-settings-btn"
              disabled={busy || !extraKey.trim()}
              onClick={() => act(() => admin("POST", `/gateway/admin/providers/${p.id}/keys`, { api_key: extraKey.trim() }).then(() => setExtraKey("")), `Added another ${p.name} key.`)}
            >
              Add key
            </button>
          </div>
        </>
      )}

      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Models</div>
          <div className="toggle-desc">{synced} · {p.custom_models.length} custom</div>
        </div>
        {p.connected && (
          <button className="ai-icon-btn" title="Refresh models from the provider" aria-label="Refresh models" disabled={busy}
            onClick={() => act(() => admin("POST", `/gateway/admin/providers/${p.id}/models/sync`), `Fetched models from ${p.name}.`)}>
            <RefreshCw size={13} />
          </button>
        )}
      </div>
      <div className="toggle-row">
        <input
          className="settings-input ai-wide"
          placeholder="Add custom model (e.g. gpt-5-mini)"
          value={newModel}
          onChange={(e) => setNewModel(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && newModel.trim()) act(() => admin("POST", `/gateway/admin/providers/${p.id}/models`, { model: newModel.trim() }).then(() => setNewModel("")))
          }}
        />
        <button className="ai-settings-btn" disabled={!newModel.trim()}
          onClick={() => act(() => admin("POST", `/gateway/admin/providers/${p.id}/models`, { model: newModel.trim() }).then(() => setNewModel("")))}>
          Add
        </button>
      </div>
      {p.custom_models.length > 0 && (
        <div className="gw-chips">
          {p.custom_models.map((m) => (
            <button key={m} className="gw-chip" title="Remove" onClick={() => act(() => admin("DELETE", `/gateway/admin/providers/${p.id}/models`, { model: m }))}>
              {m} ×
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

interface OAuthStart {
  session_id: string
  kind: string
  auth_url?: string
  verification_uri?: string
  user_code?: string
  interval?: number
}

function Accounts({
  accounts,
  oauth,
  busy,
  act,
  setMsg,
  reload,
}: {
  accounts: Account[]
  oauth: OAuthMeta[]
  busy: boolean
  act: (fn: () => Promise<unknown>, ok?: string) => Promise<void>
  setMsg: (m: { ok: boolean; text: string } | null) => void
  reload: () => Promise<void>
}) {
  const [provider, setProvider] = useState("claude")
  const [flow, setFlow] = useState<(OAuthStart & { provider: string }) | null>(null)
  const [callback, setCallback] = useState("")

  // Device logins: poll until the user approves in the browser.
  useEffect(() => {
    if (!flow || flow.kind !== "device") return
    let stopped = false
    const tick = async () => {
      if (stopped) return
      try {
        const r = await admin<{ status: string; error?: string }>("POST", `/gateway/admin/accounts/${flow.provider}/poll`, { session_id: flow.session_id })
        if (r.status === "done") {
          setFlow(null)
          setMsg({ ok: true, text: "Account connected." })
          return reload()
        }
        if (r.status === "expired") {
          setFlow(null)
          return setMsg({ ok: false, text: r.error ?? "Login timed out." })
        }
      } catch (e) {
        setFlow(null)
        return setMsg({ ok: false, text: String(e) })
      }
      setTimeout(tick, Math.max(2, flow.interval ?? 5) * 1000)
    }
    const id = setTimeout(tick, Math.max(2, flow.interval ?? 5) * 1000)
    return () => {
      stopped = true
      clearTimeout(id)
    }
  }, [flow, reload, setMsg])

  // Browser logins finish on the gateway's localhost callback: watch for the new account.
  useEffect(() => {
    if (!flow || flow.kind === "device") return
    const before = new Set(accounts.map((a) => a.id))
    const id = setInterval(async () => {
      const a = await admin<{ accounts: Account[] }>("GET", "/gateway/admin/accounts").catch(() => null)
      if (a?.accounts.some((x) => x.provider === flow.provider && !before.has(x.id))) {
        setFlow(null)
        setMsg({ ok: true, text: "Account connected." })
        reload()
      }
    }, 1500)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [flow])

  const start = async (prov: string) => {
    setMsg(null)
    try {
      const f = await admin<OAuthStart>("POST", `/gateway/admin/accounts/${prov}/start`, {})
      setFlow({ ...f, provider: prov })
      const url = f.auth_url ?? f.verification_uri
      if (url) openExternalUrl(url)
    } catch (e) {
      setMsg({ ok: false, text: String(e) })
    }
  }

  const grouped = accounts.reduce<Record<string, Account[]>>((g, a) => ((g[a.provider] ??= []).push(a), g), {})
  const nameOf = (id: string) => oauth.find((o) => o.id === id)?.name ?? id
  const now = Date.now() / 1000

  return (
    <div className="toggle-list">
      <div className="toggle-row">
        <select className="settings-select" value={provider} onChange={(e) => setProvider(e.target.value)}>
          {oauth.map((o) => (
            <option key={o.id} value={o.id}>
              {o.name}
            </option>
          ))}
        </select>
        <button className="ai-settings-btn" disabled={busy || !!flow} onClick={() => start(provider)}>
          <LogIn size={12} /> {flow ? "Waiting…" : "Connect"}
        </button>
        {IMPORTABLE[provider] && (
          <button className="ai-settings-btn" disabled={busy} onClick={() => act(() => admin("POST", `/gateway/admin/providers/${provider}/import`), `Imported login from ${IMPORTABLE[provider]}.`)}>
            Import from {IMPORTABLE[provider]}
          </button>
        )}
      </div>

      {flow && (
        <div className="gw-flow">
          {flow.user_code ? (
            <div className="toggle-row">
              <div className="toggle-info">
                <div className="toggle-title">Enter this code in the browser</div>
                <div className="gw-code">{flow.user_code}</div>
              </div>
              <button className="ai-settings-btn" onClick={() => navigator.clipboard?.writeText(flow.user_code ?? "")}>
                <Copy size={12} /> Copy
              </button>
            </div>
          ) : (
            <div className="toggle-row">
              <input
                className="settings-input ai-wide"
                placeholder="Or paste the callback URL / code here…"
                value={callback}
                onChange={(e) => setCallback(e.target.value)}
              />
              <button
                className="ai-settings-btn"
                disabled={!callback.trim()}
                onClick={() =>
                  act(
                    () => admin("POST", `/gateway/admin/accounts/${flow.provider}/complete`, { session_id: flow.session_id, callback: callback.trim() }).then(() => {
                      setFlow(null)
                      setCallback("")
                    }),
                    "Account connected.",
                  )
                }
              >
                Complete
              </button>
            </div>
          )}
          <button className="ai-settings-btn" onClick={() => setFlow(null)}>
            Cancel
          </button>
        </div>
      )}

      {accounts.length === 0 && <div className="ai-empty">No subscription accounts connected yet.</div>}

      {Object.entries(grouped).map(([prov, list]) => (
        <div key={prov} className="gw-group">
          <div className="toggle-row">
            <div className="toggle-info">
              <div className="toggle-title">
                {nameOf(prov)} <span className="muted">{list.length}</span>
              </div>
            </div>
            {SYNCABLE_OAUTH.includes(prov) && (
              <button className="ai-icon-btn" title="Refresh models" aria-label="Refresh models" disabled={busy}
                onClick={() => act(() => admin("POST", `/gateway/admin/providers/${prov}/models/sync`), `Fetched ${nameOf(prov)} models.`)}>
                <RefreshCw size={13} />
              </button>
            )}
          </div>
          {list.map((a, i) => (
            <div key={a.id} className={`toggle-row gw-account ${a.enabled ? "" : "ai-card-inactive"}`}>
              <label className="gw-switch" title={a.enabled ? "Pause" : "Use again"}>
                <input
                  type="checkbox"
                  checked={a.enabled}
                  onChange={(e) => act(() => admin("PATCH", `/gateway/admin/accounts/${prov}/${encodeURIComponent(a.id)}/toggle`, { enabled: e.target.checked }))}
                />
              </label>
              <div className="toggle-info">
                <div className="toggle-title">{a.label || a.email || a.id}</div>
                <div className="toggle-desc">
                  {[a.plan, a.cooling_until && a.cooling_until > now ? `cooling ${Math.round(a.cooling_until - now)}s` : null, a.last_error ? `error: ${a.last_error.slice(0, 80)}` : null]
                    .filter(Boolean)
                    .join(" · ")}
                </div>
              </div>
              {list.length > 1 && (
                <>
                  <span className="muted">#{i + 1}</span>
                  <MoveButtons
                    index={i}
                    count={list.length}
                    onSwap={(from, to) => {
                      const ids = list.map((x) => x.id)
                      ;[ids[from], ids[to]] = [ids[to], ids[from]]
                      act(() => admin("POST", `/gateway/admin/accounts/${prov}/reorder`, { account_ids: ids }))
                    }}
                  />
                </>
              )}
              <button className="ai-icon-btn" title="Remove account" aria-label="Remove account"
                onClick={() => act(() => admin("DELETE", `/gateway/admin/accounts/${prov}/${encodeURIComponent(a.id)}`))}>
                <Trash2 size={13} />
              </button>
            </div>
          ))}
        </div>
      ))}
    </div>
  )
}

function MoveButtons({ index, count, onSwap }: { index: number; count: number; onSwap: (from: number, to: number) => void }) {
  return (
    <span className="gw-move">
      <button className="ai-icon-btn" disabled={index === 0} title="Move up" aria-label="Move up" onClick={() => onSwap(index, index - 1)}>
        <ArrowUp size={12} />
      </button>
      <button className="ai-icon-btn" disabled={index >= count - 1} title="Move down" aria-label="Move down" onClick={() => onSwap(index, index + 1)}>
        <ArrowDown size={12} />
      </button>
    </span>
  )
}

const STRATEGY_HINT: Record<string, string> = {
  priority: "Always starts with your first account and falls back in order.",
  round_robin: "Spreads requests across a provider's accounts in turn.",
  fill_first: "Keeps using the account that last worked until it fails or hits a limit.",
}

function RoutingTab({
  routing,
  combos,
  providers,
  oauth,
  act,
}: {
  routing: Routing
  combos: Record<string, string[]>
  providers: Provider[]
  oauth: OAuthMeta[]
  act: (fn: () => Promise<unknown>, ok?: string) => Promise<void>
}) {
  const st = routing.settings
  const [comboName, setComboName] = useState("")
  const [comboTargets, setComboTargets] = useState("")
  const save = (fields: Record<string, unknown>) => act(() => admin("POST", "/gateway/admin/settings", fields))
  const label = (id: string) => oauth.find((o) => o.id === id) ?? providers.find((p) => p.id === id)

  return (
    <div className="toggle-list">
      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Strategy</div>
          <div className="toggle-desc">{STRATEGY_HINT[st.routing_strategy]}</div>
        </div>
        <select className="settings-select" value={st.routing_strategy} onChange={(e) => save({ routing_strategy: e.target.value })}>
          <option value="priority">Priority</option>
          <option value="round_robin">Round robin</option>
          <option value="fill_first">Fill first</option>
        </select>
      </div>
      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Fallback order</div>
          <div className="toggle-desc">
            {st.fallback_order === "account_first"
              ? "Tries every model on one account before the next account."
              : "Tries the best model on every account before a smaller model."}
          </div>
        </div>
        <select className="settings-select" value={st.fallback_order} onChange={(e) => save({ fallback_order: e.target.value })}>
          <option value="model_first">Model first</option>
          <option value="account_first">Account first</option>
        </select>
      </div>
      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Models per API-key provider</div>
          <div className="toggle-desc">How many of a provider's models `auto` tries before moving on.</div>
        </div>
        <input className="settings-input gw-num" type="number" min={1} max={10} value={st.auto_models_per_provider}
          onChange={(e) => save({ auto_models_per_provider: Number(e.target.value) })} />
      </div>
      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Cooldown after a rate limit (seconds)</div>
          <div className="toggle-desc">0 turns it off unless the provider says when to retry.</div>
        </div>
        <input className="settings-input gw-num" type="number" min={0} max={3600} step={30} value={st.cooldown_secs}
          onChange={(e) => save({ cooldown_secs: Number(e.target.value) })} />
      </div>

      <h3 className="gw-subtitle">
        Provider priority for <span className="gw-mono">auto</span>
        {st.provider_priority.length > 0 && (
          <button className="ai-settings-btn gw-inline" onClick={() => save({ provider_priority: [] })}>
            Reset
          </button>
        )}
      </h3>
      {routing.auto_order.length === 0 && <div className="ai-empty">Connect an account or API key first.</div>}
      {routing.auto_order.map((id, i) => (
        <div key={id} className="toggle-row">
          <span className="muted">{i + 1}</span>
          <div className="toggle-info">
            <div className="toggle-title">{label(id)?.name ?? id}</div>
            <div className="toggle-desc gw-mono">{label(id)?.alias ?? id}/auto</div>
          </div>
          <MoveButtons
            index={i}
            count={routing.auto_order.length}
            onSwap={(from, to) => {
              const order = [...routing.auto_order]
              ;[order[from], order[to]] = [order[to], order[from]]
              save({ provider_priority: order })
            }}
          />
        </div>
      ))}

      <h3 className="gw-subtitle">Combos (auto mix)</h3>
      {Object.keys(combos)
        .sort()
        .map((name) => (
          <div key={name} className="toggle-row">
            <div className="toggle-info" onClick={() => (setComboName(name), setComboTargets(combos[name].join(", ")))}>
              <div className="toggle-title gw-mono">auto/{name}</div>
              <div className="toggle-desc gw-mono">{combos[name].join(" → ")}</div>
            </div>
            <button className="ai-icon-btn" title="Delete combo" aria-label="Delete combo" onClick={() => act(() => admin("DELETE", `/gateway/admin/combos/${encodeURIComponent(name)}`))}>
              <Trash2 size={13} />
            </button>
          </div>
        ))}
      <div className="toggle-row">
        <input className="settings-input gw-combo-name" placeholder="name" value={comboName} onChange={(e) => setComboName(e.target.value)} />
        <input className="settings-input ai-wide" placeholder="cx/gpt-5.5, cc/auto, ds/deepseek-chat" value={comboTargets} onChange={(e) => setComboTargets(e.target.value)} />
        <button
          className="ai-settings-btn"
          disabled={!comboName.trim() || !comboTargets.trim()}
          onClick={() =>
            act(
              () =>
                admin("POST", "/gateway/admin/combos", {
                  name: comboName.trim(),
                  targets: comboTargets.split(",").map((t) => t.trim()).filter(Boolean),
                }).then(() => (setComboName(""), setComboTargets(""))),
              `Saved combo auto/${comboName.trim()}.`,
            )
          }
        >
          Save
        </button>
      </div>
      <div className="toggle-desc">
        Model ids: <span className="gw-mono">auto</span> (all providers by priority) · <span className="gw-mono">&lt;alias&gt;/auto</span> (one provider) ·{" "}
        <span className="gw-mono">auto/&lt;combo&gt;</span> (your mix). Click a combo to edit it.
      </div>
    </div>
  )
}
