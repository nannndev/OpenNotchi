import { invoke } from "@tauri-apps/api/core"
import { Plus, Trash2 } from "lucide-react"
import { useEffect, useState } from "react"
import { ANTHROPIC_MODELS, PROVIDERS, type AiAccount, type AiProvider } from "./ai"
import { useSettings } from "./settings"
import { askAi } from "./tabs/AITab"

/** Settings › AI: master toggle, Agents, Usage accounts and the Ask AI provider. */
export function AISettings() {
  const [settings, setSettings] = useSettings()
  const firstClaudeDir = settings.aiAccounts.find((a) => a.tool === "claude")?.dir ?? "~/.claude"
  const [hooks, setHooks] = useState(false)
  const [hookMsg, setHookMsg] = useState<string | null>(null)

  useEffect(() => {
    invoke<boolean>("claude_hooks_installed", { dir: firstClaudeDir }).then(setHooks).catch(() => {})
  }, [firstClaudeDir])

  const enable = async (on: boolean) => {
    // First enable: add the default accounts whose folders exist.
    const accounts = on && !settings.aiAccounts.length ? await invoke<AiAccount[]>("ai_default_accounts").catch(() => []) : settings.aiAccounts
    setSettings({ aiEnabled: on, aiAccounts: accounts })
  }

  const setHooksInstalled = (install: boolean) =>
    invoke<boolean>("claude_hooks", { dir: firstClaudeDir, install })
      .then((now) => {
        setHooks(now)
        setHookMsg(install ? `Added to ${firstClaudeDir}/settings.json (backup in settings.json.bak). New Claude Code sessions use them.` : "Removed.")
      })
      .catch((e) => setHookMsg(String(e)))

  const setAccount = (i: number, patch: Partial<AiAccount>) =>
    setSettings({ aiAccounts: settings.aiAccounts.map((a, j) => (i === j ? { ...a, ...patch } : a)) })

  const on = settings.aiEnabled

  return (
    <div className="settings-section">
      <h2 className="section-title">AI</h2>
      <div className="toggle-list">
        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Enable AI features</div>
            <div className="toggle-desc">
              Agent status and usage are read from files on this computer. Ask AI sends your text only to the provider you choose.
            </div>
          </div>
          <input type="checkbox" className="switch" checked={on} onChange={(e) => enable(e.target.checked)} />
        </div>
      </div>

      <fieldset className="ai-settings-body" disabled={!on}>
        <h2 className="section-title" style={{ marginTop: 24 }}>Agents</h2>
        <div className="toggle-list">
          <div className="toggle-row">
            <div className="toggle-info">
              <div className="toggle-title">Show Claude Code and Codex sessions</div>
              <div className="toggle-desc">Working, needs you and done, read from their session logs every 2 seconds.</div>
            </div>
            <input type="checkbox" className="switch" checked={settings.aiAgents} onChange={(e) => setSettings({ aiAgents: e.target.checked })} />
          </div>
          <div className="toggle-row">
            <div className="toggle-info">
              <div className="toggle-title">Claude Code hooks</div>
              <div className="toggle-desc">
                Optional. Instant updates and "needs you" when Claude Code waits for permission. Adds a curl call to 127.0.0.1:47823 in{" "}
                {firstClaudeDir}/settings.json.
              </div>
            </div>
            {hooks ? (
              <button className="ai-settings-btn" onClick={() => setHooksInstalled(false)}>
                Remove
              </button>
            ) : (
              <button className="ai-settings-btn primary" onClick={() => setHooksInstalled(true)}>
                Install Claude Code hooks
              </button>
            )}
          </div>
          {hookMsg && <div className="ai-settings-note">{hookMsg}</div>}
          <div className="toggle-row">
            <div className="toggle-info">
              <div className="toggle-title">Notify when an agent finishes</div>
            </div>
            <input type="checkbox" className="switch" checked={settings.aiNotify} onChange={(e) => setSettings({ aiNotify: e.target.checked })} />
          </div>
        </div>

        <h2 className="section-title" style={{ marginTop: 24 }}>Quota & Accounts</h2>
        <p className="section-desc">Accounts to track. Monitor tokens, quotas, and sessions for Claude Code, Codex, and Antigravity.</p>
        <div className="toggle-list">
          {settings.aiAccounts.map((a, i) => (
            <div className="toggle-row ai-account-row" key={i}>
              <input className="settings-input" value={a.name} onChange={(e) => setAccount(i, { name: e.target.value })} aria-label="Account name" />
              <select className="settings-select" value={a.tool} onChange={(e) => setAccount(i, { tool: e.target.value as AiAccount["tool"] })} aria-label="Tool">
                <option value="claude">Claude Code</option>
                <option value="codex">Codex</option>
                <option value="antigravity">Antigravity</option>
              </select>
              <input className="settings-input ai-account-dir" value={a.dir} onChange={(e) => setAccount(i, { dir: e.target.value })} aria-label="Folder" />
              <button
                className="ai-icon-btn"
                title="Remove account"
                aria-label="Remove account"
                onClick={() => setSettings({ aiAccounts: settings.aiAccounts.filter((_, j) => j !== i) })}
              >
                <Trash2 size={13} />
              </button>
            </div>
          ))}
          <div className="toggle-row" style={{ gap: 8 }}>
            <button
              className="ai-settings-btn"
              onClick={() => setSettings({ aiAccounts: [...settings.aiAccounts, { name: "Claude Code", tool: "claude", dir: "~/.claude" }] })}
            >
              <Plus size={12} /> Add Claude
            </button>
            <button
              className="ai-settings-btn"
              onClick={() => setSettings({ aiAccounts: [...settings.aiAccounts, { name: "Antigravity", tool: "antigravity", dir: "~/.gemini/antigravity-ide" }] })}
            >
              <Plus size={12} /> Add Antigravity
            </button>
            <button
              className="ai-settings-btn"
              onClick={() => setSettings({ aiAccounts: [...settings.aiAccounts, { name: "Codex", tool: "codex", dir: "~/.codex" }] })}
            >
              <Plus size={12} /> Add Codex
            </button>
          </div>
          <div className="toggle-row">
            <div className="toggle-info">
              <div className="toggle-title">Show usage in the closed notch</div>
              <div className="toggle-desc">A small meter while a Claude block is active or a Codex limit is 80% used.</div>
            </div>
            <input
              type="checkbox"
              className="switch"
              checked={settings.aiClosedMeter}
              onChange={(e) => setSettings({ aiClosedMeter: e.target.checked })}
            />
          </div>
        </div>

        <h2 className="section-title" style={{ marginTop: 24 }}>Ask AI</h2>
        <ProviderSettings />
      </fieldset>
    </div>
  )
}

function ProviderSettings() {
  const [settings, setSettings] = useSettings()
  const p = settings.aiProvider
  const keyed = p === "anthropic" || p === "openai"
  const [hasKey, setHasKey] = useState(false)
  const [key, setKey] = useState("")
  const [test, setTest] = useState<{ ok: boolean; text: string } | null>(null)
  const [testing, setTesting] = useState(false)
  const [routerModels, setRouterModels] = useState<string[]>([])

  useEffect(() => {
    if (p === "ninerouter") invoke<string[]>("ninerouter_models").then(setRouterModels).catch(() => {})
  }, [p])

  useEffect(() => {
    setKey("")
    setTest(null)
    if (keyed) invoke<boolean>("ai_key_exists", { provider: p }).then(setHasKey).catch(() => setHasKey(false))
  }, [p, keyed])

  const saveKey = (value: string) =>
    invoke("ai_key_set", { provider: p, key: value })
      .then(() => {
        setHasKey(!!value.trim())
        setKey("")
      })
      .catch((e) => setTest({ ok: false, text: String(e) }))

  const runTest = async () => {
    setTesting(true)
    setTest(null)
    try {
      setTest({ ok: true, text: await askAi(settings, "Reply with the single word: ready") })
    } catch (e) {
      setTest({ ok: false, text: String(e) })
    } finally {
      setTesting(false)
    }
  }

  return (
    <div className="toggle-list">
      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Provider</div>
        </div>
        <select className="settings-select" value={p} onChange={(e) => setSettings({ aiProvider: e.target.value as AiProvider })}>
          {PROVIDERS.map((x) => (
            <option key={x.id} value={x.id}>
              {x.name}
            </option>
          ))}
        </select>
      </div>

      {p !== "anthropic" && p !== "ninerouter" && (
        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Base URL</div>
          </div>
          <input
            className="settings-input ai-wide"
            value={p === "ollama" ? settings.aiOllamaUrl : settings.aiOpenaiUrl}
            onChange={(e) => setSettings(p === "ollama" ? { aiOllamaUrl: e.target.value } : { aiOpenaiUrl: e.target.value })}
          />
        </div>
      )}

      <div className="toggle-row">
        <div className="toggle-info">
          <div className="toggle-title">Model</div>
        </div>
        {p === "ninerouter" ? (
          <select className="settings-select" value={settings.aiNineRouterModel} onChange={(e) => setSettings({ aiNineRouterModel: e.target.value })}>
            <option value="">Automatic (Haiku or Sonnet)</option>
            {routerModels.map((m) => (
              <option key={m}>{m}</option>
            ))}
          </select>
        ) : p === "anthropic" ? (
          <select className="settings-select" value={settings.aiAnthropicModel} onChange={(e) => setSettings({ aiAnthropicModel: e.target.value })}>
            {ANTHROPIC_MODELS.map((m) => (
              <option key={m}>{m}</option>
            ))}
          </select>
        ) : (
          <input
            className="settings-input ai-wide"
            value={p === "ollama" ? settings.aiOllamaModel : settings.aiOpenaiModel}
            onChange={(e) => setSettings(p === "ollama" ? { aiOllamaModel: e.target.value } : { aiOpenaiModel: e.target.value })}
          />
        )}
      </div>

      {keyed && (
        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">API key</div>
            <div className="toggle-desc">Stored in Windows Credential Manager, never in OpenNotchi's settings.</div>
          </div>
          <input
            className="settings-input"
            type="password"
            placeholder={hasKey ? "•••••••• saved" : "Paste your key"}
            value={key}
            onChange={(e) => setKey(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && key.trim() && saveKey(key)}
          />
          <button className="ai-settings-btn" disabled={!key.trim()} onClick={() => saveKey(key)}>
            Save
          </button>
          {hasKey && (
            <button className="ai-icon-btn" title="Delete key" aria-label="Delete key" onClick={() => saveKey("")}>
              <Trash2 size={13} />
            </button>
          )}
        </div>
      )}

      <div className="toggle-row">
        <div className="toggle-info">
          <div className={`toggle-desc ${test ? (test.ok ? "ai-ok" : "ai-error") : ""}`}>
            {testing ? "Testing…" : test ? (test.ok ? `Works: "${test.text.slice(0, 60)}"` : test.text) : "Sends a one-word test prompt."}
          </div>
        </div>
        <button className="ai-settings-btn" disabled={testing} onClick={runTest}>
          Test
        </button>
      </div>
    </div>
  )
}
