import { invoke } from "@tauri-apps/api/core"
import { Check, Copy, Wrench } from "lucide-react"
import { useEffect, useState } from "react"

const GATEWAY_BASE = "http://127.0.0.1:20129"
const GATEWAY_V1 = `${GATEWAY_BASE}/v1`

export function GatewayClientConfig({ activeModel }: { activeModel?: string }) {
  const [routed, setRouted] = useState(false)
  const [busy, setBusy] = useState(false)
  const [status, setStatus] = useState<{ ok: boolean; text: string } | null>(null)
  const [copiedId, setCopiedId] = useState<string | null>(null)

  const model = activeModel?.trim() || "auto"

  useEffect(() => {
    invoke<boolean>("claude_gateway_routed", { dir: "~/.claude" })
      .then(setRouted)
      .catch(() => {})
  }, [])

  const toggleClaude = async () => {
    setBusy(true)
    setStatus(null)
    try {
      const next = await invoke<boolean>("claude_gateway_route", { dir: "~/.claude", enable: !routed })
      setRouted(next)
      setStatus({
        ok: true,
        text: next ? "Saved! Restart Claude Code to use Notchi Gateway." : "Restored direct Claude Code connection.",
      })
    } catch (e) {
      setStatus({ ok: false, text: String(e) })
    } finally {
      setBusy(false)
    }
  }

  const copyText = (id: string, text: string) => {
    navigator.clipboard?.writeText(text)
    setCopiedId(id)
    setTimeout(() => setCopiedId((cur) => (cur === id ? null : cur)), 1500)
  }

  const snippets: { id: string; title: string; display?: string; code: string; copyLabel?: string }[] = [
    {
      id: "ps",
      title: "PowerShell",
      code: `$env:OPENAI_BASE_URL="${GATEWAY_V1}"; $env:OPENAI_API_KEY="eay-gateway"`,
    },
    {
      id: "bash",
      title: "Bash / WSL",
      code: `export OPENAI_BASE_URL="${GATEWAY_V1}" OPENAI_API_KEY="eay-gateway"`,
    },
    {
      id: "ide",
      title: "Cursor / Continue / Cline",
      display: `Base URL: ${GATEWAY_V1}\nAPI Key: eay-gateway · Model: ${model}`,
      code: GATEWAY_V1,
      copyLabel: "Copy URL",
    },
    {
      id: "curl",
      title: "cURL Quick Test",
      code: `curl ${GATEWAY_V1}/chat/completions -H "Content-Type: application/json" -d "{\\"model\\":\\"${model}\\",\\"messages\\":[{\\"role\\":\\"user\\",\\"content\\":\\"ping\\"}]}"`,
    },
  ]

  return (
    <div className="gw-config-box">
      <div className="gw-config-head">
        <Wrench size={12} />
        <div>
          <strong>Connect Your Tools</strong>
          <span className="gw-mono">{GATEWAY_V1}</span>
        </div>
      </div>

      <div className="gw-config-claude">
        <div className="gw-config-claude-row">
          <div className="gw-config-claude-label">
            <span className={`gw-dot ${routed ? "on" : ""}`} />
            <div>
              <strong>Claude Code</strong>
              <span>~/.claude/settings.json</span>
            </div>
          </div>
          <button
            type="button"
            className="ai-settings-btn"
            disabled={busy}
            onClick={toggleClaude}
          >
            {routed ? "Restore Direct Connection" : "Route Claude Code via Gateway"}
          </button>
        </div>
        <p className="gw-config-desc">
          {routed
            ? `Requests go through ${GATEWAY_BASE} with automatic multi-account fallback.`
            : `Merges ANTHROPIC_BASE_URL=${GATEWAY_BASE} into settings.json (keeps settings.json.gateway.bak).`}
        </p>
        {status && <div className={`gw-msg ${status.ok ? "ai-ok" : "ai-error"}`}>{status.text}</div>}
      </div>

      <div className="gw-snippets">
        {snippets.map((s) => (
          <div key={s.id} className="gw-snippet">
            <div className="gw-snippet-head">
              <span>{s.title}</span>
              <button
                type="button"
                className="ai-settings-btn"
                onClick={() => copyText(s.id, s.code)}
              >
                {copiedId === s.id ? <Check size={11} /> : <Copy size={11} />}
                {copiedId === s.id ? "Copied" : (s.copyLabel ?? "Copy")}
              </button>
            </div>
            <pre className="gw-snippet-code">{s.display ?? s.code}</pre>
          </div>
        ))}
      </div>
    </div>
  )
}
