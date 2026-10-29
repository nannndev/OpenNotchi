import { invoke } from "@tauri-apps/api/core"
import { CheckCircle2, CircleDashed, Cpu, ExternalLink, Network, Plus, RefreshCw, Square, Trash2, XCircle } from "lucide-react"
import { useEffect, useState } from "react"
import { formatBytes, formatRate, isLocalWebPort } from "../devtools"

type Port = { port: number; pid: number; process: string; address: string }
type Stats = { cpuPercent: number; memUsedBytes: number; memTotalBytes: number; netDownBps: number; netUpBps: number }
type Run = {
  id: number
  workflow: string
  title: string
  branch: string
  status: string
  conclusion: string | null
  url: string
  updatedAt: string
}
type Section = "ports" | "system" | "ci"

const REPOS_KEY = "opennotchi_ci_repos_v1"
const DEFAULT_REPO = "nannndev/OpenNotchi"

const loadRepos = (): string[] => {
  try {
    const saved = JSON.parse(localStorage.getItem(REPOS_KEY) ?? "[]")
    return Array.isArray(saved) && saved.length ? saved : [DEFAULT_REPO]
  } catch {
    return [DEFAULT_REPO]
  }
}

const openUrl = (url: string) => invoke("open_external_url", { url }).catch(() => {})

/** Repeats `fn` every `ms` while mounted; the Dev tab only polls while it's the visible tab. */
function usePoll(fn: () => void, ms: number, deps: unknown[] = []) {
  useEffect(() => {
    fn()
    const id = setInterval(fn, ms)
    return () => clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps)
}

export function DevTab() {
  const [section, setSection] = useState<Section>("ports")
  return (
    <div className="dev">
      <div className="dev-sections">
        {(
          [
            ["ports", "Ports", Network],
            ["system", "System", Cpu],
            ["ci", "CI / Builds", CheckCircle2],
          ] as const
        ).map(([id, label, Icon]) => (
          <button key={id} className={section === id ? "on" : ""} onClick={() => setSection(id)}>
            <Icon size={11} /> {label}
          </button>
        ))}
      </div>
      {section === "ports" && <Ports />}
      {section === "system" && <System />}
      {section === "ci" && <Ci />}
    </div>
  )
}

function Ports() {
  const [ports, setPorts] = useState<Port[] | null>(null)
  const [confirm, setConfirm] = useState<number | null>(null)
  const [error, setError] = useState<string | null>(null)
  const load = () => invoke<Port[]>("listening_ports").then(setPorts).catch(() => setPorts([]))
  usePoll(load, 4000)

  const kill = (p: Port) => {
    if (confirm !== p.pid) return setConfirm(p.pid)
    setConfirm(null)
    invoke("kill_process", { pid: p.pid })
      .then(() => {
        setError(null)
        load()
      })
      .catch((e) => setError(String(e)))
  }

  if (ports === null) return <div className="dev-empty muted">Scanning ports…</div>
  return (
    <div className="dev-list">
      {error && <div className="dev-error">{error}</div>}
      {ports.length === 0 && <div className="dev-empty muted">Nothing is listening on a TCP port.</div>}
      {ports.map((p) => (
        <div key={p.port} className="dev-row">
          <span className="dev-port">:{p.port}</span>
          <span className="dev-proc" title={`${p.process} · PID ${p.pid} · ${p.address}`}>
            {p.process}
          </span>
          <span className="dev-dim">PID {p.pid}</span>
          {isLocalWebPort(p.port) && (
            <button title="Open in browser" onClick={() => openUrl(`http://localhost:${p.port}`)}>
              <ExternalLink size={11} />
            </button>
          )}
          <button
            className={confirm === p.pid ? "danger" : ""}
            title={confirm === p.pid ? "Click again to stop it" : `Stop ${p.process}`}
            onClick={() => kill(p)}
            onMouseLeave={() => confirm === p.pid && setConfirm(null)}
          >
            {confirm === p.pid ? "Stop?" : <Square size={10} />}
          </button>
        </div>
      ))}
    </div>
  )
}

function System() {
  const [s, setS] = useState<Stats | null>(null)
  usePoll(() => {
    invoke<Stats>("system_stats").then(setS).catch(() => {})
  }, 2000)
  const mem = s && s.memTotalBytes ? s.memUsedBytes / s.memTotalBytes : 0
  return (
    <div className="dev-stats">
      <Meter label="CPU" value={s ? `${Math.round(s.cpuPercent)}%` : "…"} fraction={(s?.cpuPercent ?? 0) / 100} />
      <Meter
        label="RAM"
        value={s ? `${formatBytes(s.memUsedBytes)} / ${formatBytes(s.memTotalBytes)}` : "…"}
        fraction={mem}
      />
      <div className="dev-net">
        <div>
          <span className="dev-dim">Down</span>
          <b>{s ? formatRate(s.netDownBps) : "…"}</b>
        </div>
        <div>
          <span className="dev-dim">Up</span>
          <b>{s ? formatRate(s.netUpBps) : "…"}</b>
        </div>
      </div>
    </div>
  )
}

function Meter({ label, value, fraction }: { label: string; value: string; fraction: number }) {
  const f = Math.min(1, Math.max(0, fraction))
  return (
    <div className="dev-meter">
      <div>
        <span className="dev-dim">{label}</span>
        <b>{value}</b>
      </div>
      <div className="dev-bar">
        <i style={{ width: `${f * 100}%`, background: f > 0.85 ? "var(--orange)" : "var(--accent)" }} />
      </div>
    </div>
  )
}

function Ci() {
  const [repos, setRepos] = useState<string[]>(loadRepos)
  const [repo, setRepo] = useState(repos[0])
  const [runs, setRuns] = useState<Run[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [adding, setAdding] = useState("")

  useEffect(() => {
    try {
      localStorage.setItem(REPOS_KEY, JSON.stringify(repos))
    } catch {}
  }, [repos])

  // Unauthenticated GitHub allows 60 requests an hour, so once a minute while this view is open.
  const load = () =>
    invoke<Run[]>("ci_runs", { repo })
      .then((r) => {
        setRuns(r)
        setError(null)
      })
      .catch((e) => setError(String(e)))
  usePoll(load, 60_000, [repo])

  const add = () => {
    const slug = adding.trim().replace(/^https?:\/\/github\.com\//, "").replace(/\.git$/, "").replace(/\/$/, "")
    if (!/^[\w.-]+\/[\w.-]+$/.test(slug)) return setError("Use owner/repo, e.g. nannndev/OpenNotchi")
    setRepos((all) => [slug, ...all.filter((r) => r !== slug)])
    setRepo(slug)
    setRuns(null)
    setAdding("")
  }

  const remove = () => {
    const rest = repos.filter((r) => r !== repo)
    const next = rest.length ? rest : [DEFAULT_REPO]
    setRepos(next)
    setRepo(next[0])
    setRuns(null)
  }

  return (
    <div className="dev-ci">
      <div className="dev-ci-head">
        <select value={repo} onChange={(e) => (setRepo(e.target.value), setRuns(null))}>
          {repos.map((r) => (
            <option key={r}>{r}</option>
          ))}
        </select>
        <button title="Refresh" onClick={load}>
          <RefreshCw size={11} />
        </button>
        <button title={`Remove ${repo}`} onClick={remove}>
          <Trash2 size={11} />
        </button>
        <input
          placeholder="Add owner/repo"
          value={adding}
          onChange={(e) => setAdding(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && add()}
        />
        <button title="Add repository" onClick={add}>
          <Plus size={11} />
        </button>
      </div>
      {error && <div className="dev-error">{error}</div>}
      <div className="dev-list">
        {runs === null && !error && <div className="dev-empty muted">Loading runs…</div>}
        {runs?.length === 0 && <div className="dev-empty muted">No workflow runs yet.</div>}
        {runs?.map((r) => (
          <button key={r.id} className="dev-row dev-run" onClick={() => openUrl(r.url)} title="Open on GitHub">
            <RunIcon run={r} />
            <span className="dev-proc">{r.title}</span>
            <span className="dev-dim">
              {r.workflow} · {r.branch}
            </span>
          </button>
        ))}
      </div>
    </div>
  )
}

function RunIcon({ run }: { run: Run }) {
  if (run.status !== "completed") return <CircleDashed size={12} className="dev-spin" color="var(--orange)" />
  if (run.conclusion === "success") return <CheckCircle2 size={12} color="var(--green)" />
  return <XCircle size={12} color={run.conclusion === "cancelled" ? "var(--muted)" : "#ff5f57"} />
}
