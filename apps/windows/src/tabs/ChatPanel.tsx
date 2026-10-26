import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import { ArrowUp, Check, Clipboard, Copy, Image as ImageIcon, Music2, Paperclip, PenSquare, RotateCcw, Square, Trash2, Undo2, X } from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { formatTokens, type UsageReport } from "../ai"
import type { NowPlaying } from "../media"
import { settingsChanges, splitReply, systemPrompt, type Change, type Options } from "../notchiBrain"
import {
  ACCENT_PRESETS,
  ANIMATION_OPTIONS,
  BORDER_OPTIONS,
  NOW_PLAYING_BACKGROUNDS,
  THEME_OPTIONS,
  useSettings,
  type AppSettings,
} from "../settings"

const OPTIONS: Options = { themes: THEME_OPTIONS, accents: ACCENT_PRESETS, borders: BORDER_OPTIONS, animations: ANIMATION_OPTIONS, backgrounds: NOW_PLAYING_BACKGROUNDS }

type Message = { role: "user" | "assistant"; content: string; context?: string; attachments?: string[]; images?: string[]; changes?: Change[] }
type Session = { id: string; title: string; updatedAt: number; messages: Message[] }

const STORE_KEY = "opennotchi_chats_v1"
const MAX_SESSIONS = 50

function loadSessions(): Session[] {
  try {
    return JSON.parse(localStorage.getItem(STORE_KEY) || "[]")
  } catch {
    return []
  }
}

function saveSessions(sessions: Session[]) {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify(sessions.slice(0, MAX_SESSIONS)))
  } catch {
    // Storage full (big images): keep the chat in memory for this session.
  }
}

function providerFields(s: AppSettings) {
  if (s.aiProvider === "ninerouter") return { provider: "ninerouter", baseUrl: "", model: s.aiNineRouterModel }
  if (s.aiProvider === "anthropic") return { provider: "anthropic", baseUrl: "", model: s.aiAnthropicModel }
  if (s.aiProvider === "openai") return { provider: "openai", baseUrl: s.aiOpenaiUrl, model: s.aiOpenaiModel }
  return { provider: "ollama", baseUrl: s.aiOllamaUrl, model: s.aiOllamaModel }
}

let streamSeq = 0

/** Sends a conversation to the provider from Settings; `onDelta` gets each chunk as it streams in. */
export async function chatAi(
  settings: AppSettings,
  messages: Message[],
  system: string,
  onDelta: (text: string) => void = () => {},
): Promise<string> {
  const streamEvent = `ai-chat-${Date.now()}-${streamSeq++}`
  const unlisten = await listen<string>(streamEvent, ({ payload }) => onDelta(payload))
  try {
    return await invoke<string>("ai_chat", {
      req: {
        ...providerFields(settings),
        system,
        streamEvent,
        messages: messages.map((m) => ({ role: m.role, content: m.content, context: m.context ?? null, images: m.images ?? [] })),
      },
    })
  } finally {
    unlisten()
  }
}

/** One-shot prompt; used by the Settings "Test" button. */
export function askAi(settings: AppSettings, prompt: string): Promise<string> {
  return chatAi(settings, [{ role: "user", content: prompt }], "Be concise.")
}

/** Downscales an image file or data URL to a JPEG data URL so chats stay small. */
function shrinkImage(src: string, maxSide = 1280): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => {
      const scale = Math.min(1, maxSide / Math.max(img.width, img.height))
      const canvas = document.createElement("canvas")
      canvas.width = Math.round(img.width * scale)
      canvas.height = Math.round(img.height * scale)
      const ctx = canvas.getContext("2d")
      if (!ctx) return reject(new Error("no canvas"))
      ctx.fillStyle = "#fff"
      ctx.fillRect(0, 0, canvas.width, canvas.height)
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
      resolve(canvas.toDataURL("image/jpeg", 0.75))
    }
    img.onerror = reject
    img.src = src
  })
}

const readAsDataURL = (f: File) =>
  new Promise<string>((res, rej) => {
    const r = new FileReader()
    r.onload = () => res(String(r.result))
    r.onerror = rej
    r.readAsDataURL(f)
  })

type ContextKind = "clipboard" | "song" | "usage"
const CONTEXTS: { id: ContextKind; label: string; icon: typeof Clipboard }[] = [
  { id: "clipboard", label: "Clipboard", icon: Clipboard },
  { id: "song", label: "Now playing", icon: Music2 },
  { id: "usage", label: "My AI usage", icon: ImageIcon },
]

export function ChatPanel({
  np,
  lyricLine,
  usage,
  onOpenTab,
}: {
  np: NowPlaying | null
  lyricLine: string | null
  usage: UsageReport[] | null
  onOpenTab?: (tab: string) => void
}) {
  const [settings, setSettings] = useSettings()
  const [sessions, setSessions] = useState<Session[]>(loadSessions)
  const [currentId, setCurrentId] = useState<string | null>(() => loadSessions()[0]?.id ?? null)
  const [input, setInput] = useState("")
  const [busy, setBusy] = useState(false)
  const [streaming, setStreaming] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [attached, setAttached] = useState<Set<ContextKind>>(new Set())
  const [images, setImages] = useState<string[]>([])
  const [files, setFiles] = useState<{ name: string; body: string }[]>([])
  const [models, setModels] = useState<string[]>([])
  const [historyOpen, setHistoryOpen] = useState(false)
  const [dragging, setDragging] = useState(false)
  const [copied, setCopied] = useState<number | null>(null)
  const [undone, setUndone] = useState<Set<string>>(new Set())
  const cancelled = useRef(false)
  const scroller = useRef<HTMLDivElement>(null)
  const fileInput = useRef<HTMLInputElement>(null)

  const current = sessions.find((s) => s.id === currentId) ?? null
  const messages = current?.messages ?? []

  useEffect(() => saveSessions(sessions), [sessions])
  // Scroll only the chat list: scrollIntoView also scrolls every overflow:hidden ancestor,
  // which shifted the whole pill up out of the window and left the aura glow behind.
  useEffect(() => {
    const el = scroller.current
    if (el) el.scrollTop = el.scrollHeight
  }, [messages.length, messages[messages.length - 1]?.content, busy, error])
  useEffect(() => {
    if (settings.aiProvider === "ninerouter") invoke<string[]>("ninerouter_models").then(setModels).catch(() => {})
  }, [settings.aiProvider])

  const updateCurrent = (fn: (m: Message[]) => Message[], id = currentId) =>
    setSessions((all) => {
      const i = all.findIndex((s) => s.id === id)
      if (i < 0) return all
      const s = { ...all[i], messages: fn(all[i].messages), updatedAt: Date.now() }
      return [s, ...all.slice(0, i), ...all.slice(i + 1)]
    })

  const contextBlock = async (ctx: Set<ContextKind>) => {
    const parts: string[] = []
    if (ctx.has("clipboard")) {
      const clip = await navigator.clipboard?.readText().catch(() => "")
      if (clip) parts.push(`Clipboard:\n${clip.slice(0, 6000)}`)
    }
    if (ctx.has("song") && np) parts.push(`Now playing: "${np.title}" by ${np.artist}${lyricLine ? `. Current lyric: "${lyricLine}"` : ""}`)
    if (ctx.has("usage") && usage?.length) {
      const lines = usage.map((r) => {
        const q = (r.quotas ?? []).map((x) => `${x.name} ${x.unlimited ? "unlimited" : `${Math.round(x.remainingPercentage)}% left`}`).join(", ")
        return `- ${r.name} (${r.tool}, ${r.isActive === false ? "off" : "on"}): ${formatTokens(r.today.tokens)} tokens today${q ? `; ${q}` : ""}`
      })
      parts.push(`My AI accounts in 9router:\n${lines.join("\n")}`)
    }
    return parts
  }

  const run = async (history: Message[], sessionId: string) => {
    setBusy(true)
    setError(null)
    cancelled.current = false
    let answer = ""
    let started = false
    try {
      await chatAi(settings, history, systemPrompt(settings, OPTIONS), (delta) => {
        if (cancelled.current) return
        answer += delta
        if (!started) {
          started = true
          setStreaming(true)
          updateCurrent((m) => [...m, { role: "assistant", content: "" }], sessionId)
        }
        updateCurrent((m) => [...m.slice(0, -1), { ...m[m.length - 1], content: splitReply(answer).text }], sessionId)
      })
      if (cancelled.current) return
      const { text, actions } = splitReply(answer)
      let changes: Change[] = []
      if (actions) {
        const { patch, changes: c } = settingsChanges(actions, settings, OPTIONS)
        changes = c
        if (Object.keys(patch).length) setSettings(patch)
        if (actions.tab && onOpenTab) {
          onOpenTab(actions.tab)
          changes.push({ key: "tab", label: `Opened ${actions.tab}` })
        }
        if (actions.settings) {
          invoke("open_settings").catch(() => {})
          changes.push({ key: "settings", label: "Opened Settings" })
        }
        if (actions.nowPlaying) {
          invoke("open_now_playing").catch(() => {})
          changes.push({ key: "nowPlaying", label: "Opened the full-screen player" })
        }
      }
      updateCurrent(
        (m) => [...(started ? m.slice(0, -1) : m), { role: "assistant", content: text || "Done.", changes: changes.length ? changes : undefined }],
        sessionId,
      )
    } catch (e) {
      if (!cancelled.current) {
        if (started && !answer) updateCurrent((m) => m.slice(0, -1), sessionId)
        setError(String(e))
      }
    } finally {
      setBusy(false)
      setStreaming(false)
    }
  }

  const send = async (text: string, ctxOverride?: Set<ContextKind>) => {
    let prompt = text.trim()
    if (busy || (!prompt && !images.length && !files.length)) return
    if (!prompt) prompt = images.length ? "What's in this image?" : "What's in this file?"
    const ctx = ctxOverride ?? attached
    const parts = [...(await contextBlock(ctx)), ...files.map((f) => `File ${f.name}:\n${f.body}`)]
    const labels = [...CONTEXTS.filter((c) => ctx.has(c.id)).map((c) => c.label), ...files.map((f) => f.name)]
    const msg: Message = {
      role: "user",
      content: prompt,
      context: parts.length ? parts.join("\n\n") : undefined,
      attachments: labels.length ? labels : undefined,
      images: images.length ? images : undefined,
    }
    setInput("")
    setAttached(new Set())
    setImages([])
    setFiles([])

    let id = currentId
    let history: Message[]
    if (current) {
      history = [...current.messages, msg]
      updateCurrent((m) => [...m, msg])
    } else {
      id = crypto.randomUUID()
      history = [msg]
      setSessions((all) => [{ id: id!, title: prompt.split("\n")[0].slice(0, 48), updatedAt: Date.now(), messages: [msg] }, ...all])
      setCurrentId(id)
    }
    run(history, id!)
  }

  const regenerate = () => {
    if (busy || !current) return
    const history = messages[messages.length - 1]?.role === "assistant" ? messages.slice(0, -1) : messages
    if (history[history.length - 1]?.role !== "user") return
    updateCurrent(() => history)
    run(history, current.id)
  }

  const stop = () => {
    cancelled.current = true
    setBusy(false)
    setStreaming(false)
  }

  const newChat = () => {
    stop()
    setCurrentId(null)
    setError(null)
    setHistoryOpen(false)
  }

  const addFiles = async (list: FileList | File[]) => {
    for (const f of Array.from(list)) {
      if (f.type.startsWith("image/")) {
        const url = await shrinkImage(await readAsDataURL(f)).catch(() => null)
        if (url) setImages((x) => [...x, url])
      } else if (f.size < 2_000_000) {
        const body = await f.text().catch(() => "")
        if (body) setFiles((x) => [...x, { name: f.name, body: body.slice(0, 20_000) }])
        else setError(`Can't read ${f.name}. Images and text files work.`)
      } else {
        setError(`${f.name} is too big.`)
      }
    }
  }

  const onPaste = async (e: React.ClipboardEvent) => {
    const imgs = Array.from(e.clipboardData.files).filter((f) => f.type.startsWith("image/"))
    if (imgs.length) {
      e.preventDefault()
      addFiles(imgs)
    }
  }

  const undo = (c: Change) => {
    if (!c.undo) return
    setSettings(c.undo)
    setUndone((u) => new Set(u).add(`${currentId}:${c.key}:${c.label}`))
  }

  const providerLabel =
    settings.aiProvider === "ninerouter"
      ? `9router · ${settings.aiNineRouterModel || "auto"}`
      : settings.aiProvider === "anthropic"
      ? `Anthropic · ${settings.aiAnthropicModel}`
      : settings.aiProvider === "openai"
      ? settings.aiOpenaiModel
      : `Ollama · ${settings.aiOllamaModel}`

  return (
    <div
      className={`chat ${dragging ? "dragging" : ""}`}
      onDragOver={(e) => {
        e.preventDefault()
        setDragging(true)
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault()
        setDragging(false)
        addFiles(e.dataTransfer.files)
      }}
      onKeyDown={(e) => e.key === "Escape" && busy && stop()}
    >
      <div className="chat-head">
        <select
          className="chat-model"
          value={settings.aiProvider === "ninerouter" ? `9r:${settings.aiNineRouterModel}` : settings.aiProvider}
          onChange={(e) => {
            const v = e.target.value
            if (v.startsWith("9r:")) setSettings({ aiProvider: "ninerouter", aiNineRouterModel: v.slice(3) })
            else setSettings({ aiProvider: v as AppSettings["aiProvider"] })
          }}
          title="Where your prompts go"
        >
          <option value="9r:">9router · auto</option>
          {models.map((m) => (
            <option key={m} value={`9r:${m}`}>
              9router · {m}
            </option>
          ))}
          <option value="anthropic">Anthropic API</option>
          <option value="openai">OpenAI-compatible</option>
          <option value="ollama">Ollama (local)</option>
        </select>
        <span className="chat-provider muted">{providerLabel}</span>
        <div className="chat-head-actions">
          <button className="chat-icon" onClick={() => setHistoryOpen(!historyOpen)} title="Chat history" aria-label="Chat history">
            <RotateCcw size={12} />
            <span className="chat-title">{current?.title ?? "New chat"}</span>
          </button>
          <button className="chat-icon" onClick={newChat} title="New chat" aria-label="New chat">
            <PenSquare size={12} />
          </button>
        </div>
        {historyOpen && (
          <div className="chat-history">
            {sessions.length === 0 && <div className="muted">No chats yet.</div>}
            {sessions.slice(0, 15).map((s) => (
              <div key={s.id} className={`chat-history-row ${s.id === currentId ? "on" : ""}`}>
                <button
                  onClick={() => {
                    stop()
                    setCurrentId(s.id)
                    setHistoryOpen(false)
                  }}
                >
                  {s.title}
                </button>
                <button
                  className="chat-icon"
                  aria-label="Delete chat"
                  onClick={() => {
                    setSessions((all) => all.filter((x) => x.id !== s.id))
                    if (currentId === s.id) setCurrentId(null)
                  }}
                >
                  <Trash2 size={11} />
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="chat-scroll" ref={scroller}>
        {messages.length === 0 && !error && (
          <div className="chat-empty">
            <b>What can I help with?</b>
            <div className="chat-suggest">
              <button onClick={() => send("Summarize this.", new Set(["clipboard"]))}>Summarize clipboard</button>
              <button onClick={() => send("Make my notch look nicer. Pick a theme, accent and animation that go well together.")}>Make my notch look nicer</button>
              <button onClick={() => send("What can OpenNotchi do? Give me a quick tour.")}>What can Notchi do?</button>
              {!!usage?.length && <button onClick={() => send("How is my AI usage looking? Anything close to its limit?", new Set(["usage"]))}>How's my AI usage?</button>}
            </div>
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} className={`chat-msg ${m.role}`}>
            {m.attachments && (
              <div className="chat-attach-labels">
                {m.attachments.map((a) => (
                  <span key={a}>
                    <Paperclip size={9} /> {a}
                  </span>
                ))}
              </div>
            )}
            {m.images && (
              <div className="chat-images">
                {m.images.map((src, j) => (
                  <img key={j} src={src} alt="" />
                ))}
              </div>
            )}
            <div className="chat-bubble">
              {m.content}
              {streaming && i === messages.length - 1 && <span className="chat-caret">▍</span>}
            </div>
            {m.changes && (
              <div className="chat-changes">
                {m.changes.map((c) => {
                  const isUndone = undone.has(`${currentId}:${c.key}:${c.label}`)
                  return (
                    <div key={c.key + c.label} className={isUndone ? "undone" : ""}>
                      {isUndone ? <Undo2 size={11} /> : <Check size={11} />}
                      <span>{c.label}</span>
                      {c.undo && !isUndone && <button onClick={() => undo(c)}>Undo</button>}
                    </div>
                  )
                })}
              </div>
            )}
            {m.role === "assistant" && !(streaming && i === messages.length - 1) && (
              <div className="chat-msg-actions">
                <button
                  onClick={() =>
                    navigator.clipboard.writeText(m.content).then(() => {
                      setCopied(i)
                      setTimeout(() => setCopied(null), 1200)
                    })
                  }
                >
                  {copied === i ? <Check size={10} /> : <Copy size={10} />} {copied === i ? "Copied" : "Copy"}
                </button>
                {i === messages.length - 1 && !busy && (
                  <button onClick={regenerate}>
                    <RotateCcw size={10} /> Regenerate
                  </button>
                )}
              </div>
            )}
          </div>
        ))}
        {busy && !streaming && (
          <div className="chat-msg assistant">
            <div className="chat-bubble chat-typing" aria-label="Thinking">
              <i />
              <i />
              <i />
            </div>
          </div>
        )}
        {error && (
          <div className="chat-error">
            <span>{error}</span>
            <button onClick={regenerate}>Retry</button>
          </div>
        )}
      </div>

      <div className="chat-composer">
        <div className="chat-contexts">
          {CONTEXTS.map((c) => {
            const on = attached.has(c.id)
            const disabled = (c.id === "song" && !np) || (c.id === "usage" && !usage?.length)
            return (
              <button
                key={c.id}
                className={on ? "on" : ""}
                disabled={disabled}
                onClick={() => {
                  const next = new Set(attached)
                  on ? next.delete(c.id) : next.add(c.id)
                  setAttached(next)
                }}
                title={`Attach ${c.label.toLowerCase()} to your next message`}
              >
                {on ? <Check size={10} /> : <c.icon size={10} />} {c.label}
              </button>
            )
          })}
          <span className="spacer" />
          <button onClick={() => fileInput.current?.click()} title="Attach images or files (or drop / paste them)" aria-label="Attach files">
            <Paperclip size={11} />
          </button>
          <input
            ref={fileInput}
            type="file"
            multiple
            hidden
            onChange={(e) => {
              if (e.target.files) addFiles(e.target.files)
              e.target.value = ""
            }}
          />
        </div>
        {(images.length > 0 || files.length > 0) && (
          <div className="chat-pending">
            {images.map((src, i) => (
              <div key={i} className="chat-thumb">
                <img src={src} alt="" />
                <button aria-label="Remove image" onClick={() => setImages((x) => x.filter((_, j) => j !== i))}>
                  <X size={9} />
                </button>
              </div>
            ))}
            {files.map((f, i) => (
              <div key={f.name + i} className="chat-file">
                {f.name}
                <button aria-label="Remove file" onClick={() => setFiles((x) => x.filter((_, j) => j !== i))}>
                  <X size={9} />
                </button>
              </div>
            ))}
          </div>
        )}
        <div className="chat-input-row">
          <textarea
            className="chat-input"
            rows={1}
            placeholder={messages.length ? "Reply…" : "Ask anything…"}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onPaste={onPaste}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                send(input)
              }
            }}
          />
          <button
            className="chat-send"
            onClick={() => (busy ? stop() : send(input))}
            disabled={!busy && !input.trim() && !images.length && !files.length}
            aria-label={busy ? "Stop" : "Send"}
            title={busy ? "Stop (Esc)" : "Send (Enter)"}
          >
            {busy ? <Square size={12} /> : <ArrowUp size={14} />}
          </button>
        </div>
      </div>
      {dragging && <div className="chat-drop">Drop to attach</div>}
    </div>
  )
}
