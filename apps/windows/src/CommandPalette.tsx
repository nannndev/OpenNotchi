import { invoke } from "@tauri-apps/api/core"
import {
  Activity,
  AppWindow,
  ArrowDownToLine,
  ArrowLeftRight,
  BarChart3,
  Calculator,
  Camera,
  Captions,
  ChartBar,
  ClipboardList,
  Code2,
  Coffee,
  Copy,
  Disc3,
  Maximize2,
  Music2,
  Paintbrush,
  Pause,
  Play,
  RefreshCw,
  ScrollText,
  Search,
  Share2,
  SkipBack,
  SkipForward,
  Sparkles,
  Terminal,
  Timer,
  TrendingUp,
  Video,
  XOctagon,
  type LucideIcon,
} from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import { isLocalWebPort } from "./devtools"
import { control, type NowPlaying } from "./media"
import { THEME_OPTIONS, useSettings } from "./settings"

type Port = { port: number; pid: number; process: string; address: string }

export interface PaletteTabInfo {
  key: string
  label: string
  enabled: boolean
  shortcut?: string
}

interface CommandItem {
  id: string
  category: string
  title: string
  subtitle?: string
  icon: LucideIcon
  tint: string
  badge?: string
  keywords: string[]
  run: () => void
}

const TAB_ICONS: Record<string, LucideIcon> = {
  music: Music2,
  clipboard: ClipboardList,
  timer: Timer,
  notes: Coffee,
  calc: Calculator,
  markets: TrendingUp,
  prompter: ScrollText,
  mirror: Video,
  dev: Terminal,
  ai: Sparkles,
}

export function CommandPalette({
  tabs,
  np,
  awake,
  widgetOn,
  onClose,
  onSelectTab,
  onOpenAiSection,
  onRefreshUsage,
  onToggleWidget,
  onToggleAwake,
  onStartPomodoro,
}: {
  tabs: PaletteTabInfo[]
  np: NowPlaying | null
  awake: boolean
  widgetOn: boolean
  onClose: () => void
  onSelectTab: (key: string) => void
  onOpenAiSection: (section: "usage" | "analytics" | "agents" | "ask") => void
  onRefreshUsage: () => void
  onToggleWidget: () => void
  onToggleAwake: () => void
  onStartPomodoro: () => void
}) {
  const [settings, setSettings] = useSettings()
  const [query, setQuery] = useState("")
  const [selectedIndex, setSelectedIndex] = useState(0)
  const [ports, setPorts] = useState<Port[]>([])
  const inputRef = useRef<HTMLInputElement>(null)
  const listRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    inputRef.current?.focus()
    invoke<Port[]>("listening_ports")
      .then((res) => setPorts(res.filter((p) => isLocalWebPort(p.port)).slice(0, 5)))
      .catch(() => {})
  }, [])

  const items = useMemo<CommandItem[]>(() => {
    const out: CommandItem[] = []

    // 1. Tabs
    for (const t of tabs) {
      out.push({
        id: `tab.${t.key}`,
        category: "Tabs",
        title: t.label,
        subtitle: t.enabled ? `Switch to ${t.label}` : `Enable & open ${t.label}`,
        icon: TAB_ICONS[t.key] ?? Sparkles,
        tint: "var(--accent)",
        badge: t.shortcut ?? (t.enabled ? undefined : "Enable"),
        keywords: ["tab", "open", "switch", t.label.toLowerCase(), t.key],
        run: () => onSelectTab(t.key),
      })
    }

    // 2. AI & Gateway
    out.push(
      {
        id: "ai.ask",
        category: "AI & Gateway",
        title: "Ask AI…",
        subtitle: "Open Notchi assistant chat",
        icon: Sparkles,
        tint: "#38bdf8",
        keywords: ["ai", "ask", "chat", "prompt", "notchi"],
        run: () => onOpenAiSection("ask"),
      },
      {
        id: "ai.usage",
        category: "AI & Gateway",
        title: "AI Quota & Accounts",
        subtitle: "Inspect connected accounts & live quotas",
        icon: ChartBar,
        tint: "#34d399",
        keywords: ["ai", "quota", "accounts", "usage", "limits"],
        run: () => onOpenAiSection("usage"),
      },
      {
        id: "ai.analytics",
        category: "AI & Gateway",
        title: "AI Analytics & Cost",
        subtitle: "Token breakdown, cache hits & recent requests",
        icon: BarChart3,
        tint: "#a78bfa",
        keywords: ["ai", "analytics", "cost", "tokens", "cached", "history"],
        run: () => onOpenAiSection("analytics"),
      },
      {
        id: "gw.refresh",
        category: "AI & Gateway",
        title: "Refresh Gateway Quotas",
        subtitle: "Sync live usage & account cooldowns",
        icon: RefreshCw,
        tint: "#34d399",
        keywords: ["gateway", "refresh", "quota", "sync"],
        run: () => onRefreshUsage(),
      },
      {
        id: "gw.round_robin",
        category: "AI & Gateway",
        title: "Gateway Routing: Round-Robin",
        subtitle: "Distribute requests evenly across active accounts",
        icon: ArrowLeftRight,
        tint: "#60a5fa",
        keywords: ["gateway", "routing", "round robin", "strategy"],
        run: () => {
          invoke("gateway_admin", { method: "POST", path: "/gateway/admin/settings", body: { routing_strategy: "round_robin" } }).catch(() => {})
        },
      },
      {
        id: "gw.fill_first",
        category: "AI & Gateway",
        title: "Gateway Routing: Fill-First",
        subtitle: "Drain primary account in priority order before falling back",
        icon: ArrowDownToLine,
        tint: "#fb923c",
        keywords: ["gateway", "routing", "fill first", "priority", "strategy"],
        run: () => {
          invoke("gateway_admin", { method: "POST", path: "/gateway/admin/settings", body: { routing_strategy: "fill_first" } }).catch(() => {})
        },
      },
      {
        id: "gw.copy_url",
        category: "AI & Gateway",
        title: "Copy Gateway Endpoint URL",
        subtitle: "http://127.0.0.1:20129/v1",
        icon: Copy,
        tint: "#9ca3af",
        badge: "v1",
        keywords: ["gateway", "copy", "endpoint", "url", "openai", "20129"],
        run: () => {
          invoke<string>("gateway_endpoint")
            .catch(() => "http://127.0.0.1:20129/v1")
            .then((url) => navigator.clipboard?.writeText(url))
        },
      },
    )

    // 3. Media & Lyrics
    out.push(
      {
        id: "media.toggle",
        category: "Media & Lyrics",
        title: np?.isPlaying ? "Pause Music" : "Play Music",
        subtitle: np ? `${np.title} · ${np.artist}` : "Toggle media playback",
        icon: np?.isPlaying ? Pause : Play,
        tint: "#f472b6",
        keywords: ["music", "play", "pause", "spotify", "media"],
        run: () => control("toggle"),
      },
      {
        id: "media.next",
        category: "Media & Lyrics",
        title: "Next Track",
        icon: SkipForward,
        tint: "#f472b6",
        keywords: ["music", "next", "skip", "track"],
        run: () => control("next"),
      },
      {
        id: "media.previous",
        category: "Media & Lyrics",
        title: "Previous Track",
        icon: SkipBack,
        tint: "#f472b6",
        keywords: ["music", "previous", "back", "track"],
        run: () => control("previous"),
      },
      {
        id: "media.widget",
        category: "Media & Lyrics",
        title: "Toggle Desktop Lyrics",
        subtitle: widgetOn ? "Currently On" : "Currently Off",
        icon: Captions,
        tint: "#22d3ee",
        badge: widgetOn ? "On" : "Off",
        keywords: ["lyrics", "desktop", "widget", "karaoke"],
        run: () => onToggleWidget(),
      },
      {
        id: "media.code_lyrics",
        category: "Media & Lyrics",
        title: "Toggle Source Code Lyrics Mode",
        subtitle: settings.lyricsCodeMode ? "Live-typing code lyrics active" : "Switch lyrics to live-typing source code style",
        icon: Code2,
        tint: "#c084fc",
        badge: settings.lyricsCodeMode ? "Code" : "Standard",
        keywords: ["lyrics", "code", "source", "typing", "ide", "monospaced"],
        run: () => setSettings({ lyricsCodeMode: !settings.lyricsCodeMode }),
      },
      {
        id: "media.workspace_lyrics",
        category: "Media & Lyrics",
        title: "Full-Screen IDE Workspace CodeLyric",
        subtitle: "Open full-screen player in dedicated IDE Workspace layout",
        icon: AppWindow,
        tint: "#818cf8",
        badge: settings.lyricsCodeWorkspace ? "Active" : "IDE",
        keywords: ["lyrics", "workspace", "ide", "vscode", "fullscreen", "code", "editor"],
        run: () => {
          setSettings({ nowPlayingLyrics: true, lyricsCodeMode: true, lyricsCodeWorkspace: true })
          invoke("open_now_playing").catch(() => {})
        },
      },
      {
        id: "media.artwork_style",
        category: "Media & Lyrics",
        title: `Switch Artwork Style (${settings.artworkStyle === "vinyl" ? "Cover Art" : "Spinning Vinyl"})`,
        subtitle: "Toggle between album cover and spinning vinyl in the pill",
        icon: Disc3,
        tint: "#38bdf8",
        badge: settings.artworkStyle === "vinyl" ? "Vinyl" : "Cover",
        keywords: ["artwork", "vinyl", "cover", "album", "style"],
        run: () => setSettings({ artworkStyle: settings.artworkStyle === "vinyl" ? "cover" : "vinyl" }),
      },
      {
        id: "media.fullscreen",
        category: "Media & Lyrics",
        title: "Open Full-Screen Player",
        icon: Maximize2,
        tint: "#22d3ee",
        keywords: ["now playing", "fullscreen", "player"],
        run: () => {
          invoke("open_now_playing").catch(() => {})
        },
      },
      {
        id: "media.share",
        category: "Media & Lyrics",
        title: "Share Lyric Card",
        icon: Share2,
        tint: "#22d3ee",
        keywords: ["share", "lyric", "card", "image"],
        run: () => {
          invoke("open_share_lyrics").catch(() => {})
        },
      },
    )

    // 4. Developer & Tools
    out.push(
      {
        id: "dev.pomodoro",
        category: "Developer & Tools",
        title: "Start 25m Pomodoro Timer",
        subtitle: "Start a 25-minute focus countdown",
        icon: Timer,
        tint: "#fb923c",
        badge: "25m",
        keywords: ["timer", "pomodoro", "focus", "25"],
        run: () => onStartPomodoro(),
      },
      {
        id: "dev.awake",
        category: "Developer & Tools",
        title: awake ? "Stop Keeping Awake" : "Keep Awake (Prevent Sleep)",
        icon: Coffee,
        tint: "#fbbf24",
        badge: awake ? "On" : undefined,
        keywords: ["awake", "coffee", "sleep", "caffeine"],
        run: () => onToggleAwake(),
      },
      {
        id: "dev.mirror",
        category: "Developer & Tools",
        title: "Open Camera Mirror & Photobox",
        icon: Camera,
        tint: "#60a5fa",
        keywords: ["camera", "mirror", "photobox"],
        run: () => onSelectTab("mirror"),
      },
      {
        id: "dev.ports",
        category: "Developer & Tools",
        title: "Inspect Ports & System Stats",
        icon: Activity,
        tint: "#34d399",
        keywords: ["dev", "ports", "cpu", "ram", "ci", "system"],
        run: () => onSelectTab("dev"),
      },
    )

    for (const p of ports) {
      out.push({
        id: `dev.kill.${p.pid}.${p.port}`,
        category: "Developer & Tools",
        title: `Kill Port :${p.port} (${p.process})`,
        subtitle: `Stop PID ${p.pid} at ${p.address}`,
        icon: XOctagon,
        tint: "#f87171",
        badge: `:${p.port}`,
        keywords: ["kill", "stop", "port", String(p.port), p.process.toLowerCase()],
        run: () => {
          invoke("kill_process", { pid: p.pid }).catch(() => {})
        },
      })
    }

    // 5. Appearance
    for (const theme of THEME_OPTIONS) {
      out.push({
        id: `theme.${theme.id}`,
        category: "Appearance",
        title: `Theme: ${theme.name}`,
        subtitle: theme.desc,
        icon: Paintbrush,
        tint: "#c084fc",
        badge: settings.theme === theme.id ? "Active" : undefined,
        keywords: ["theme", "appearance", "look", theme.name.toLowerCase()],
        run: () => setSettings({ theme: theme.id }),
      })
    }

    return out
  }, [tabs, np, widgetOn, awake, ports, settings.theme, onSelectTab, onOpenAiSection, onRefreshUsage, onToggleWidget, onToggleAwake, onStartPomodoro, setSettings])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return items
    return items.filter(
      (i) =>
        i.title.toLowerCase().includes(q) ||
        i.category.toLowerCase().includes(q) ||
        (i.subtitle?.toLowerCase().includes(q) ?? false) ||
        i.keywords.some((k) => k.includes(q)),
    )
  }, [items, query])

  useEffect(() => {
    setSelectedIndex(0)
  }, [query])

  useEffect(() => {
    const el = listRef.current?.querySelector<HTMLElement>(`[data-idx="${selectedIndex}"]`)
    el?.scrollIntoView({ block: "nearest" })
  }, [selectedIndex])

  const execute = (item: CommandItem) => {
    onClose()
    item.run()
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "ArrowDown") {
      e.preventDefault()
      if (filtered.length > 0) setSelectedIndex((i) => (i + 1) % filtered.length)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      if (filtered.length > 0) setSelectedIndex((i) => (i - 1 + filtered.length) % filtered.length)
    } else if (e.key === "Enter") {
      e.preventDefault()
      const picked = filtered[Math.min(selectedIndex, Math.max(0, filtered.length - 1))]
      if (picked) execute(picked)
    } else if (e.key === "Escape") {
      e.preventDefault()
      e.stopPropagation()
      onClose()
    }
  }

  return (
    <div className="cmd-backdrop" onClick={onClose} onKeyDown={handleKeyDown}>
      <div className="cmd-modal" onClick={(e) => e.stopPropagation()} role="dialog" aria-label="Command Palette">
        <div className="cmd-search">
          <Search size={13} className="cmd-search-icon" />
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Type a command, tab, theme, or port…"
            aria-label="Search commands"
          />
          {query && (
            <button type="button" className="cmd-clear" onClick={() => setQuery("")} aria-label="Clear">
              ×
            </button>
          )}
          <button type="button" className="cmd-esc" onClick={onClose}>
            ESC
          </button>
        </div>

        <div className="cmd-list" ref={listRef}>
          {filtered.length === 0 ? (
            <div className="cmd-empty">No matching commands</div>
          ) : (
            filtered.map((item, idx) => {
              const Icon = item.icon
              const showCat = idx === 0 || filtered[idx - 1].category !== item.category
              const active = idx === Math.min(selectedIndex, filtered.length - 1)
              return (
                <div key={item.id}>
                  {showCat && <div className="cmd-cat">{item.category}</div>}
                  <button
                    type="button"
                    data-idx={idx}
                    className={`cmd-item ${active ? "selected" : ""}`}
                    onMouseEnter={() => setSelectedIndex(idx)}
                    onClick={() => execute(item)}
                  >
                    <span className="cmd-item-icon" style={{ color: item.tint }}>
                      <Icon size={13} />
                    </span>
                    <span className="cmd-item-text">
                      <strong>{item.title}</strong>
                      {item.subtitle && <small>{item.subtitle}</small>}
                    </span>
                    {item.badge && (
                      <span className={`cmd-badge ${item.badge === "Active" ? "ok" : ""}`}>{item.badge}</span>
                    )}
                  </button>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}
