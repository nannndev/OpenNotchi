import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import {
  Activity,
  Calculator,
  Camera,
  ClipboardList,
  Code2,
  Coffee,
  Disc3,
  LayoutGrid,
  Mic,
  ScrollText,
  Search,
  Terminal,
  TrendingUp,
  Video,
  Music2,
  Pause,
  PictureInPicture2,
  Play,
  Quote,
  Settings as SettingsIcon,
  Share2, Maximize2,
  SkipBack,
  SkipForward,
  Sparkles,
  Timer,
} from "lucide-react"
import { useEffect, useRef, useState, type CSSProperties } from "react"
import { PillCodeLyrics } from "./CodeLyrics"
import { currentIndex } from "./lyrics"
import { control, currentLine, formatTime, positionAt, useLyrics, useNowPlaying, useTick, type NowPlaying } from "./media"
import { closedMeter, formatTokens, type UsageReport } from "./ai"
import { CommandPalette, type PaletteTabInfo } from "./CommandPalette"
import { formatBytes, formatRate } from "./devtools"
import { NotchiMascot } from "./NotchiMascot"
import { NotchiStatus } from "./NotchiStatus"
import { filterRecentAgentStates, notchiMood, playPetPopSound, type NotchiMood } from "./notchi"
import { useAccent } from "./palette"
import { resolveAccentColor, useSettings, type AppSettings } from "./settings"
import { AITab, useAgents, useUsage, type AiSection } from "./tabs/AITab"
import { CalcTab } from "./tabs/CalcTab"
import { DevTab } from "./tabs/DevTab"
import { MarketsTab } from "./tabs/MarketsTab"
import { useIdleNowPlaying } from "./NowPlayingScreen"
import { ClipboardTab } from "./tabs/ClipboardTab"
import { MirrorTab } from "./tabs/MirrorTab"
import { NotesTab } from "./tabs/NotesTab"
import { PrompterTab } from "./tabs/PrompterTab"
import { TimerTab } from "./tabs/TimerTab"
import { ClosedTimer } from "./ClosedTimer"
import { formatCountdown, isActive as isTimerActive, remaining as timerRemaining, timer as timerControl, useTimer, type TimerState } from "./timer"
import { useUpdateChecker } from "./updater"
import { BannerView } from "./BannerView"
import { playBannerSound, type Banner } from "./banner"

// Pill sizes in logical pixels. The window is a fixed 640×280 transparent canvas; the pill animates inside it.
const CLOSED = { width: 340, height: 38 }
const PEEKING = { width: 380, height: 38 }
const BANNER_SIZE = { width: 420, height: 96 }
const OPEN = { width: 620, height: 232 }
/** The AI tab needs room for chat messages above the composer (macOS uses 340 too). */
const OPEN_AI = { width: 620, height: 344 }
/** How long the cursor must rest on the closed pill before it opens, so passing by doesn't open it. */
const OPEN_DELAY_MS = 150
/** Gap above the floating pill. */
const FLOAT_GAP = 10
/** Height of the invisible top-edge strip that reveals an auto-hidden pill. */
const REVEAL_STRIP = 4
const PEEK_MS = 3000

type Privacy = { camera: boolean; mic: boolean }
type TabKey = "music" | "clipboard" | "timer" | "notes" | "calc" | "markets" | "prompter" | "mirror" | "dev" | "ai"
type ClosedSlot = "timer" | "music" | "aiMeter"
type SystemStats = { cpuPercent: number; memUsedBytes: number; memTotalBytes: number; netDownBps: number; netUpBps: number }

const TAB_DEFS: {
  key: TabKey
  label: string
  settingKey: keyof AppSettings
  title: string
  Icon: typeof Music2
}[] = [
  { key: "music", label: "Music", settingKey: "tabMusic", title: "Music", Icon: Music2 },
  { key: "ai", label: "AI", settingKey: "aiEnabled", title: "AI agents, usage and Ask AI", Icon: Sparkles },
  { key: "calc", label: "Calc", settingKey: "tabCalc", title: "Calculator & unit converter", Icon: Calculator },
  { key: "timer", label: "Timer", settingKey: "tabTimer", title: "Timer", Icon: Timer },
  { key: "notes", label: "Notes", settingKey: "tabNotes", title: "Notes", Icon: Coffee },
  { key: "clipboard", label: "Clipboard", settingKey: "tabClipboard", title: "Clipboard", Icon: ClipboardList },
  { key: "markets", label: "Markets", settingKey: "tabMarkets", title: "Live crypto markets", Icon: TrendingUp },
  { key: "dev", label: "Dev", settingKey: "tabDev", title: "Ports, system stats and CI builds", Icon: Terminal },
  { key: "prompter", label: "Prompter", settingKey: "tabPrompter", title: "Teleprompter", Icon: ScrollText },
  { key: "mirror", label: "Mirror", settingKey: "tabMirror", title: "Mirror & photobox", Icon: Video },
]

export function Pill() {
  const np = useNowPlaying()
  useIdleNowPlaying(np?.isPlaying ?? false)
  const lyrics = useLyrics(np)
  const rawAccent = useAccent(np?.artwork)
  const [settings, setSettings] = useSettings()

  const resolvedAccent = resolveAccentColor(settings.accentChoice, rawAccent, settings.customAccent)

  const searchParams = typeof window !== "undefined" ? new URLSearchParams(window.location.search) : null
  const defaultOpen = searchParams?.get("open") === "1"
  const defaultTab = (searchParams?.get("tab") as TabKey) || "music"
  const defaultBanner: Banner | null = searchParams?.get("banner") === "1" ? {
    id: "demo",
    kind: "success",
    icon: "checkmark",
    tint: "var(--accent, #10b981)",
    badge: "Done",
    title: "Claude Code: Task completed",
    subtitle: "47/47 tests passed · OpenNotchi",
    actionTitle: "Open Terminal",
    duration: 12,
  } : null

  const [open, setOpen] = useState(defaultOpen)
  const [activeTab, setActiveTab] = useState<TabKey>(defaultTab)
  const [lyricsMode, setLyricsMode] = useState(false)
  const [awake, setAwake] = useState(false)
  const [widgetOn, setWidgetOn] = useState(false)
  const [peek, setPeek] = useState<Privacy | null>(null)
  const [paletteOpen, setPaletteOpen] = useState(false)
  const [overflowOpen, setOverflowOpen] = useState(false)
  const [statusOpen, setStatusOpen] = useState(false)
  const [closedSlotIdx, setClosedSlotIdx] = useState(0)
  const [aiSectionReq, setAiSectionReq] = useState<{ section: AiSection; seq: number } | null>(null)
  
  // Notification banners (macOS parity with kinds: success, attention, reminder, info)
  const [activeBanner, setActiveBanner] = useState<Banner | null>(defaultBanner)
  const activeBannerRef = useRef<Banner | null>(null)
  activeBannerRef.current = activeBanner
  const [bannerHovered, setBannerHovered] = useState(false)

  const showBanner = (b: Banner) => {
    setActiveBanner(b)
    playBannerSound(b.kind, settings.notificationSounds)
  }

  const agents = useAgents(settings.aiEnabled && settings.aiAgents, showBanner)
  const { usage, toggleActive, refresh: refreshUsage } = useUsage(settings.aiEnabled)
  const meter = settings.aiEnabled && settings.aiClosedMeter && usage ? closedMeter(usage, Date.now()) : null
  const timerState = useTimer()
  const timerActive = isTimerActive(timerState)

  const closedSlots: ClosedSlot[] = []
  if (timerActive) closedSlots.push("timer")
  if (np) closedSlots.push("music")
  if (meter) closedSlots.push("aiMeter")
  const activeClosedSlot: ClosedSlot | null = closedSlots.length > 0 ? closedSlots[closedSlotIdx % closedSlots.length] : null

  // Notchi Mascot state
  const [pettedAt, setPettedAt] = useState<number | null>(null)
  const [pets, setPets] = useState(0)
  const [mascotHovered, setMascotHovered] = useState(false)
  const [gaze, setGaze] = useState(0)
  const [quietSince, setQuietSince] = useState(Date.now())

  const handlePet = () => {
    const now = Date.now()
    if (pettedAt && now - pettedAt > 6000) {
      setPets(0)
    }
    setPets((p) => p + 1)
    setPettedAt(now)
    setQuietSince(now)
    playPetPopSound()
  }

  const isPetted = (pettedAt != null && Date.now() - pettedAt < 4000) || mascotHovered

  // Agent states with 8-second expiry for done
  const recentAgents = filterRecentAgentStates(
    agents.map((a) => ({ state: a.state, updatedAt: a.updatedAt })),
    Date.now(),
    8
  )

  const mascotMood: NotchiMood = notchiMood({
    agentStates: recentAgents,
    musicPlaying: Boolean(np?.isPlaying),
    idleFor: (Date.now() - quietSince) / 1000,
    hour: new Date().getHours(),
    petted: isPetted,
  })

  // Follow pointer for gaze when closed
  useEffect(() => {
    if (open) return
    const onMouseMove = (e: MouseEvent) => {
      const target = Math.max(-1, Math.min(1, (e.clientX - window.innerWidth / 2) / 400))
      setGaze(target)
    }
    window.addEventListener("mousemove", onMouseMove)
    return () => window.removeEventListener("mousemove", onMouseMove)
  }, [open])

  // Mascot bounding box reporting to Rust backend
  const handleMascotRectChange = (rect: { x: number; y: number; width: number; height: number } | null) => {
    if (open || !rect) {
      invoke("set_mascot_rect", { x: null, y: null, width: null, height: null }).catch(() => {})
    } else {
      invoke("set_mascot_rect", { x: rect.x, y: rect.y, width: rect.width, height: rect.height }).catch(() => {})
    }
  }

  useEffect(() => {
    if (open) {
      invoke("set_mascot_rect", { x: null, y: null, width: null, height: null }).catch(() => {})
    }
  }, [open])

  // A countdown or photobox in progress (or open overlay/popover) keeps the pill open even if the cursor drifts away.
  const [mirrorBusy, setMirrorBusy] = useState(false)
  const mirrorBusyRef = useRef(false)
  // A pinned Mirror stays open until unpinned or another tab is chosen.
  mirrorBusyRef.current = mirrorBusy || paletteOpen || overflowOpen || statusOpen || (activeTab === "mirror" && settings.mirrorPinned)
  // Hover comes only from Rust: WebView2 fires a stray mouseleave whenever the window resizes
  // (Mirror, Ask), so DOM mouse events closed the pill under a still cursor.
  const closeTimerRef = useRef<number | undefined>(undefined)
  const openTimerRef = useRef<number | undefined>(undefined)
  const { updateInfo } = useUpdateChecker()
  const [headerStats, setHeaderStats] = useState<SystemStats | null>(null)
  useTick(open && activeTab === "music" && lyricsMode && settings.lyricsCodeMode ? 42 : 250)

  useEffect(() => {
    if (!open || !settings.showStatsInHeader) return
    const load = () => invoke<SystemStats>("system_stats").then(setHeaderStats).catch(() => {})
    load()
    const id = window.setInterval(load, 3000)
    return () => window.clearInterval(id)
  }, [open, settings.showStatsInHeader])

  const onMirror = activeTab === "mirror" && settings.tabMirror
  const onAi = activeTab === "ai" && settings.aiEnabled
  const baseOpenSize = onMirror ? { width: 620, height: settings.mirrorHeight } : onAi ? OPEN_AI : OPEN
  const openSize = paletteOpen || overflowOpen || statusOpen
    ? { width: baseOpenSize.width, height: Math.max(baseOpenSize.height, 290) }
    : baseOpenSize
  const isMascotIdle = settings.showMascot && !peek && !activeBanner && closedSlots.length === 0
  const closedWidth = isMascotIdle ? 220 : CLOSED.width
  const closedSize = { width: closedWidth, height: CLOSED.height }
  const size = open ? openSize : activeBanner ? BANNER_SIZE : peek ? PEEKING : closedSize
  const mode = settings.notchMode ?? "pinned"
  const hidden = mode === "autoHide" && !open && !peek && !activeBanner
  // The hover zone Rust checks starts at the window's top edge, so it covers the floating gap too.
  const hover = hidden
    ? { width: size.width, height: REVEAL_STRIP }
    : { width: size.width, height: size.height + (mode === "floating" ? FLOAT_GAP : 0) }
  useEffect(() => {
    invoke("set_pill_size", { ...hover, open }).catch(() => {})
  }, [hover.width, hover.height, open])

  // The pill window is sized for the normal open pill; grow it for a taller Mirror.
  const windowHeight = Math.max(280, (open ? size.height : 0) + 70)
  useEffect(() => {
    invoke("set_pill_window_height", { height: windowHeight }).catch(() => {})
  }, [windowHeight])

  // Unpinning or leaving the Mirror while the cursor is already outside closes the pill.
  useEffect(() => {
    if (open && !mirrorBusyRef.current) invoke<boolean>("cursor_over_pill").then((inside) => !inside && setOpen(false)).catch(() => {})
  }, [settings.mirrorPinned, mirrorBusy])

  // Sync initial lyrics widget visibility and listen for changes (including tray clicks)
  useEffect(() => {
    invoke<boolean>("is_lyrics_visible").then(setWidgetOn).catch(() => {})

    const unlisten = listen<boolean>("lyrics-visibility-changed", ({ payload: visible }) => {
      setWidgetOn(visible)
    })
    return () => {
      unlisten.then((f) => f())
    }
  }, [])

  // Hover comes from Rust polling the cursor, so the pill reacts without first being clicked.
  useEffect(() => {
    const unlistenHover = listen<boolean>("pill-hover", ({ payload: inside }) => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current)
        closeTimerRef.current = undefined
      }
      clearTimeout(openTimerRef.current)
      if (activeBannerRef.current) {
        setBannerHovered(inside)
        return
      }
      if (inside) {
        openTimerRef.current = window.setTimeout(() => setOpen(true), OPEN_DELAY_MS)
      } else {
        closeTimerRef.current = window.setTimeout(() => {
          if (!mirrorBusyRef.current) setOpen(false)
        }, settings.closeDelayMs ?? 300)
      }
    })
    const unlistenMascot = listen<boolean>("pill-hover-mascot", ({ payload: inside }) => {
      setMascotHovered(inside)
      if (inside) {
        setQuietSince(Date.now())
      }
    })
    const unlistenBanner = listen<Banner>("show-banner", ({ payload }) => {
      showBanner(payload)
    })
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current)
        closeTimerRef.current = undefined
      }
      clearTimeout(openTimerRef.current)
      unlistenHover.then((f) => f())
      unlistenMascot.then((f) => f())
      unlistenBanner.then((f) => f())
    }
  }, [settings.closeDelayMs, settings.notificationSounds])


  // A pill for a few seconds whenever any app starts using the camera or mic.
  useEffect(() => {
    let last: Privacy = { camera: false, mic: false }
    let hide: number | undefined
    const id = setInterval(async () => {
      const now = await invoke<Privacy>("privacy_state").catch(() => last)
      if ((now.camera && !last.camera) || (now.mic && !last.mic)) {
        setPeek(now)
        clearTimeout(hide)
        hide = window.setTimeout(() => setPeek(null), PEEK_MS)
      }
      last = now
    }, 2000)
    return () => clearInterval(id)
  }, [])

  const toggleAwake = () =>
    invoke("set_keep_awake", { on: !awake })
      .then(() => setAwake(!awake))
      .catch(() => {})

  const toggleWidget = () =>
    invoke<boolean>("toggle_lyrics")
      .then((visible) => setWidgetOn(visible))
      .catch(() => {})

  const openSettings = () => invoke("open_settings").catch(() => {})
  const openShare = () => invoke("open_share_lyrics").catch(() => {})

  const line = currentLine(np, lyrics)
  const synced = lyrics && lyrics !== "loading" ? lyrics.synced : []
  const hasSynced = synced.length > 0
  const showLyrics = lyricsMode && hasSynced

  // Enabled tabs, pinned overflow list, and safe active fallback
  const visibleTabsList = TAB_DEFS.filter((t) => Boolean(settings[t.settingKey]))
  const hiddenTabsList = TAB_DEFS.filter((t) => !settings[t.settingKey])
  const currentTabSafe: TabKey = visibleTabsList.some((t) => t.key === activeTab)
    ? activeTab
    : visibleTabsList[0]?.key ?? "music"
  const overflowCount = Math.max(0, visibleTabsList.length - 5)
  const displayedTabs =
    visibleTabsList.length <= 5
      ? visibleTabsList
      : [
          ...visibleTabsList.slice(0, 4),
          visibleTabsList.find((t, idx) => idx >= 4 && t.key === currentTabSafe) ?? visibleTabsList[4],
        ]

  const selectOrEnableTab = (key: TabKey) => {
    const def = TAB_DEFS.find((t) => t.key === key)
    if (def && !settings[def.settingKey]) {
      setSettings({ [def.settingKey]: true } as Partial<AppSettings>)
    }
    setActiveTab(key)
    setOverflowOpen(false)
    setStatusOpen(false)
    setPaletteOpen(false)
  }

  useEffect(() => {
    if (!open) {
      setPaletteOpen(false)
      setOverflowOpen(false)
      setStatusOpen(false)
    }
  }, [open])

  useEffect(() => {
    if (!open) return
    const onKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && !e.altKey) {
        const key = e.key.toLowerCase()
        if (key === "k") {
          e.preventDefault()
          setOverflowOpen(false)
          setStatusOpen(false)
          setPaletteOpen((v) => !v)
          return
        }
        const n = Number(key)
        if (n >= 1 && n <= 8 && !e.shiftKey) {
          const target = visibleTabsList[n - 1]
          if (target) {
            e.preventDefault()
            selectOrEnableTab(target.key)
          }
          return
        }
      }
      if (e.key === "Escape" && (paletteOpen || overflowOpen || statusOpen)) {
        e.preventDefault()
        setPaletteOpen(false)
        setOverflowOpen(false)
        setStatusOpen(false)
      }
    }
    window.addEventListener("keydown", onKeyDown)
    return () => window.removeEventListener("keydown", onKeyDown)
  }, [open, paletteOpen, overflowOpen, statusOpen, visibleTabsList])

  const paletteTabs: PaletteTabInfo[] = TAB_DEFS.map((t) => {
    const vIdx = visibleTabsList.findIndex((v) => v.key === t.key)
    return {
      key: t.key,
      label: t.label,
      enabled: vIdx >= 0,
      shortcut: vIdx >= 0 && vIdx < 8 ? `Ctrl+${vIdx + 1}` : undefined,
    }
  })

  return (
    <div
      className={`stage mode-${mode}`}
      style={{
        ["--accent" as string]: resolvedAccent,
        ["--float-gap" as string]: `${FLOAT_GAP}px`,
        ["--custom-theme-top" as string]: settings.customThemeTop || "#1A0B2E",
        ["--custom-theme-bottom" as string]: settings.customThemeBottom || "#7A1E5A",
      } as CSSProperties}
    >
      {/* Dynamic ambient aura blur behind open pill when music is playing (or non-white accent) */}
      {open && settings.auraGlow !== "off" && (np?.artwork || (settings.accentChoice !== "artwork" && settings.accentChoice !== "white" && resolvedAccent !== "#ffffff")) && (
        <div
          className={`aura-backdrop ${settings.auraGlow}`}
          style={{
            width: Math.min(size.width, 580),
            height: size.height,
            backgroundImage: np?.artwork ? `url(${np.artwork})` : undefined,
            backgroundColor: !np?.artwork ? resolvedAccent : undefined,
          }}
        />
      )}

      <div
        className={`pill ${open ? "open" : ""} ${hidden ? "hidden" : ""} theme-${settings.theme} border-${settings.borderStyle} anim-${settings.openAnimation}`}
        style={{ width: size.width, height: size.height, zIndex: 1 }}
      >
        {/* Album Art theme background */}
        {settings.theme === "albumArt" && np?.artwork && (
          <div className="theme-album-bg" style={{ backgroundImage: `url(${np.artwork})` }} />
        )}

        {/* Closed Pill State */}
        <div className={`pill-closed ${activeBanner ? "is-banner" : ""}`} aria-hidden={open}>
          {activeBanner ? (
            <BannerView
              banner={activeBanner}
              onDismiss={() => setActiveBanner(null)}
              isHovered={bannerHovered}
            />
          ) : peek ? (
            <>
              <span className="peek-icons">
                {peek.camera && <Camera size={15} color="var(--green)" />}
                {peek.mic && <Mic size={15} color="var(--orange)" />}
              </span>
              <span className="peek-label" style={{ color: peek.camera ? "var(--green)" : "var(--orange)" }}>
                IN USE
              </span>
            </>
          ) : (
            <>
              {activeClosedSlot === "timer" ? (
                <ClosedTimer t={timerState} />
              ) : activeClosedSlot === "music" && np ? (
                <>
                  <Vinyl src={np.artwork} size={24} playing={np.isPlaying} />
                  <span className="closed-text" key={line.text ?? np.title}>
                    {line.text ?? np.title}
                  </span>
                  {meter && closedSlots.length <= 1 ? (
                    <UsageMeter {...meter} />
                  ) : settings.showMascot ? (
                    <NotchiMascot
                      mood="vibing"
                      size={24}
                      accent={resolvedAccent}
                      gaze={gaze}
                      pettedAt={pettedAt}
                      hovered={mascotHovered}
                      onClick={handlePet}
                      onHoverChange={setMascotHovered}
                    />
                  ) : (
                    <Bars playing={np.isPlaying} />
                  )}
                </>
              ) : activeClosedSlot === "aiMeter" && meter ? (
                <>
                  {settings.showMascot && (
                    <NotchiMascot
                      mood={mascotMood}
                      size={24}
                      accent={resolvedAccent}
                      gaze={gaze}
                      pettedAt={pettedAt}
                      hovered={mascotHovered}
                      onClick={handlePet}
                      onHoverChange={setMascotHovered}
                      onRectChange={handleMascotRectChange}
                    />
                  )}
                  <UsageMeter {...meter} />
                </>
              ) : settings.showMascot ? (
                <div className="notchi-idle-row">
                  <NotchiMascot
                    mood={mascotMood}
                    size={28}
                    accent={resolvedAccent}
                    gaze={gaze}
                    pettedAt={pettedAt}
                    hovered={mascotHovered}
                    onClick={handlePet}
                    onHoverChange={setMascotHovered}
                    onRectChange={handleMascotRectChange}
                  />
                  <div style={{ flex: 1 }} />
                  <NotchiStatus
                    mood={mascotMood}
                    size={28}
                    accent={resolvedAccent}
                    pets={pets}
                  />
                </div>
              ) : (
                <span className="closed-text muted">
                  {awake
                    ? "☕ Keeping awake"
                    : updateInfo?.available
                    ? `✨ v${updateInfo.latestVersion} update available`
                    : "OpenNotchi"}
                </span>
              )}

              {closedSlots.length > 1 && (
                <button
                  type="button"
                  className="closed-slot-dots"
                  title={`Switch Live Activity (${(closedSlotIdx % closedSlots.length) + 1}/${closedSlots.length})`}
                  aria-label="Switch Live Activity"
                  onClick={(e) => {
                    e.stopPropagation()
                    setClosedSlotIdx((i) => (i + 1) % closedSlots.length)
                  }}
                >
                  {closedSlots.map((slot, idx) => (
                    <i key={slot} className={idx === closedSlotIdx % closedSlots.length ? "active" : ""} />
                  ))}
                </button>
              )}
            </>
          )}
        </div>


        {/* Open Pill State with Header & Tabs */}
        <div className="pill-open" aria-hidden={!open} style={{ position: "relative" }}>
          {/* Header Bar */}
          <div className="pill-header">
            <div className="pill-tabs-nav">
              {displayedTabs.map(({ key, label, title, Icon }) => (
                <button
                  key={key}
                  className={`tab-nav-btn ${currentTabSafe === key ? "active" : ""}`}
                  title={title}
                  onClick={() => selectOrEnableTab(key)}
                >
                  <Icon size={12} />
                  <span>{label}</span>
                </button>
              ))}

              {(overflowCount > 0 || hiddenTabsList.length > 0) && (
                <button
                  type="button"
                  className={`tab-overflow-btn ${overflowOpen ? "open" : ""}`}
                  title="All tabs & quick launcher"
                  onClick={() => {
                    setStatusOpen(false)
                    setPaletteOpen(false)
                    setOverflowOpen((v) => !v)
                  }}
                >
                  <LayoutGrid size={11} />
                  {overflowCount > 0 && <span>+{overflowCount}</span>}
                </button>
              )}
            </div>

            <div className="pill-header-actions">
              {settings.showStatsInHeader && headerStats && (
                <button
                  type="button"
                  className="header-stats-pill"
                  onClick={() => {
                    setOverflowOpen(false)
                    setPaletteOpen(false)
                    setStatusOpen((v) => !v)
                  }}
                  title={`CPU ${Math.round(headerStats.cpuPercent)}% · RAM ${formatBytes(headerStats.memUsedBytes)}`}
                >
                  <span>{Math.round(headerStats.cpuPercent)}%</span>
                  <i>·</i>
                  <span>{Math.round((headerStats.memUsedBytes / Math.max(1, headerStats.memTotalBytes)) * 100)}%</span>
                </button>
              )}
              <button
                type="button"
                className={`header-action-btn ${paletteOpen ? "on" : ""}`}
                onClick={() => {
                  setOverflowOpen(false)
                  setStatusOpen(false)
                  setPaletteOpen((v) => !v)
                }}
                title="Command Palette (Ctrl+K)"
                aria-label="Command Palette"
              >
                <Search size={11} />
              </button>

              <button
                type="button"
                className={`header-action-btn ${statusOpen ? "on" : ""}`}
                onClick={() => {
                  setOverflowOpen(false)
                  setPaletteOpen(false)
                  setStatusOpen((v) => !v)
                }}
                title="System & Activity Quick Look"
                aria-label="System Quick Look"
              >
                <Activity size={11} />
              </button>

              {/* Keep awake belongs to Notes; elsewhere it shows only while on, so it can be turned off. */}
              {(currentTabSafe === "notes" || awake) && (
                <button
                  className={`header-action-btn ${awake ? "on" : ""}`}
                  onClick={toggleAwake}
                  title={awake ? "Stop keeping awake" : "Keep awake"}
                >
                  <Coffee size={12} />
                </button>
              )}
              {currentTabSafe === "music" && (
                <>
                  <button
                    className={`header-action-btn ${widgetOn ? "on" : ""}`}
                    onClick={toggleWidget}
                    title={widgetOn ? "Hide desktop lyrics" : "Show desktop lyrics"}
                  >
                    <PictureInPicture2 size={12} />
                  </button>
                  <button
                    className="header-action-btn"
                    onClick={openShare}
                    title="Share lyric card"
                  >
                    <Share2 size={12} />
                  </button>
                  <button
                    className="header-action-btn"
                    onClick={() => invoke("open_now_playing").catch(() => {})}
                    title="Full-screen player"
                    aria-label="Full-screen player"
                  >
                    <Maximize2 size={12} />
                  </button>
                </>
              )}
              <button
                className="header-action-btn"
                onClick={openSettings}
                title="Open Settings"
              >
                <SettingsIcon size={12} />
              </button>
              {updateInfo?.available && (
                <button
                  className="header-action-btn update-badge-btn"
                  onClick={openSettings}
                  title={`OpenNotchi v${updateInfo.latestVersion} available! Click to open Settings`}
                >
                  <Sparkles size={12} color="#38bdf8" />
                  <span className="update-dot" />
                </button>
              )}
            </div>
          </div>

          {overflowOpen && (
            <div className="pill-popover pill-popover-left">
              <button
                type="button"
                className="pill-pop-cmd"
                onClick={() => {
                  setOverflowOpen(false)
                  setPaletteOpen(true)
                }}
              >
                <Search size={11} />
                <span>Command Palette…</span>
                <kbd>Ctrl+K</kbd>
              </button>
              <div className="pill-pop-grid">
                {visibleTabsList.map((t, idx) => {
                  const Icon = t.Icon
                  const active = currentTabSafe === t.key
                  return (
                    <button
                      key={t.key}
                      type="button"
                      className={`pill-pop-tile ${active ? "active" : ""}`}
                      onClick={() => selectOrEnableTab(t.key)}
                    >
                      <Icon size={13} />
                      <span>{t.label}</span>
                      {idx < 8 && <kbd>Ctrl+{idx + 1}</kbd>}
                    </button>
                  )
                })}
              </div>
              {hiddenTabsList.length > 0 && (
                <div className="pill-pop-hidden">
                  <small>Hidden Tabs (click to enable)</small>
                  <div className="pill-pop-grid">
                    {hiddenTabsList.map((t) => {
                      const Icon = t.Icon
                      return (
                        <button
                          key={t.key}
                          type="button"
                          className="pill-pop-tile dim"
                          onClick={() => selectOrEnableTab(t.key)}
                        >
                          <Icon size={12} />
                          <span>{t.label}</span>
                        </button>
                      )
                    })}
                  </div>
                </div>
              )}
            </div>
          )}

          {statusOpen && (
            <StatusQuickLook
              timerState={timerState}
              timerActive={timerActive}
              aiEnabled={settings.aiEnabled}
              usage={usage}
              onOpenTab={(k) => selectOrEnableTab(k)}
              onClose={() => setStatusOpen(false)}
            />
          )}

          {paletteOpen && (
            <CommandPalette
              tabs={paletteTabs}
              np={np}
              awake={awake}
              widgetOn={widgetOn}
              onClose={() => setPaletteOpen(false)}
              onSelectTab={(k) => selectOrEnableTab(k as TabKey)}
              onOpenAiSection={(sec) => {
                setSettings({ aiEnabled: true })
                setActiveTab("ai")
                setAiSectionReq((prev) => ({ section: sec, seq: (prev?.seq ?? 0) + 1 }))
              }}
              onRefreshUsage={() => {
                refreshUsage().catch(() => {})
              }}
              onToggleWidget={toggleWidget}
              onToggleAwake={toggleAwake}
              onStartPomodoro={() => {
                setSettings({ tabTimer: true })
                timerControl.setPreset(25)
                timerControl.toggleRun()
                setActiveTab("timer")
              }}
            />
          )}

          {/* Active Tab View */}
          <div className="pill-tab-content">
            {currentTabSafe === "music" && (
              <div className="music-content">
                <div className="deck">
                  {settings.artworkStyle === "vinyl" ? (
                    <div
                      className="artwork-switch-wrap"
                      onClick={() => setSettings({ artworkStyle: "cover" })}
                      title="Click to switch to Cover Art"
                    >
                      <Vinyl src={np?.artwork ?? null} size={118} playing={!!np?.isPlaying} tonearm />
                    </div>
                  ) : (
                    <div
                      className={`cover-art-box ${np?.isPlaying ? "playing" : "paused"}`}
                      onClick={() => setSettings({ artworkStyle: "vinyl" })}
                      title="Click to switch to Spinning Vinyl"
                    >
                      {np?.artwork ? <img src={np.artwork} alt="" /> : <div className="cover-art-empty"><Disc3 size={34} /></div>}
                    </div>
                  )}
                  {hasSynced && (
                    <div className="deck-controls-stack">
                      <button
                        className={`lyrics-toggle ${lyricsMode ? "on" : ""}`}
                        onClick={() => setLyricsMode(!lyricsMode)}
                        aria-label={lyricsMode ? "Show player" : "Show lyrics"}
                        aria-pressed={lyricsMode}
                        title={lyricsMode ? "Show player" : "Show lyrics"}
                      >
                        <Quote size={11} fill="currentColor" />
                      </button>
                      <button
                        className={`lyrics-share-toggle ${settings.lyricsCodeMode ? "on" : ""}`}
                        onClick={() => {
                          if (!lyricsMode) setLyricsMode(true)
                          setSettings({ lyricsCodeMode: !settings.lyricsCodeMode })
                        }}
                        aria-label="Toggle source code lyrics"
                        title={settings.lyricsCodeMode ? "Standard lyrics style" : "Source code live-typing lyrics"}
                      >
                        <Code2 size={11} />
                      </button>
                    </div>
                  )}
                </div>

                {showLyrics && np ? (
                  <>
                    {settings.lyricsCodeMode ? (
                      <PillCodeLyrics np={np} lines={synced} />
                    ) : (
                      <LyricsScroller np={np} lines={synced} />
                    )}
                    <MiniPlayer np={np} />
                  </>
                ) : (
                  <PlayerView np={np} lyricLine={line.text} />
                )}
              </div>
            )}

            {currentTabSafe === "clipboard" && <ClipboardTab />}

            {currentTabSafe === "timer" && <TimerTab />}

            {currentTabSafe === "notes" && <NotesTab awake={awake} onToggleAwake={setAwake} />}

            {currentTabSafe === "calc" && <CalcTab />}

            {currentTabSafe === "markets" && <MarketsTab />}

            {currentTabSafe === "prompter" && <PrompterTab />}

            {/* Mounted only while open so the camera light goes off when the pill closes. */}
            {currentTabSafe === "mirror" && open && <MirrorTab onBusy={setMirrorBusy} />}

            {currentTabSafe === "dev" && <DevTab />}
            {currentTabSafe === "ai" && (
              <AITab
                sessions={agents}
                usage={usage}
                onToggleActive={toggleActive}
                onRefresh={refreshUsage}
                sectionRequest={aiSectionReq}
                lyricLine={line.text}
                np={np}
              />
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

function PlayerView({ np, lyricLine }: { np: NowPlaying | null; lyricLine: string | null }) {
  const position = np ? positionAt(np) : 0
  return (
    <div className="player">
      <div className="title">{np?.title || "Nothing playing"}</div>
      <div className={`subtitle ${lyricLine ? "lyric" : ""}`} key={lyricLine ?? np?.artist}>
        {lyricLine ?? np?.artist ?? "Play something in Spotify or your browser"}
      </div>
      {np && np.duration > 0 && <Progress np={np} position={position} />}
      <div className="transport">
        <button className="icon" onClick={() => control("previous")} aria-label="Previous" disabled={!np}>
          <SkipBack size={17} fill="currentColor" />
        </button>
        <button
          className="icon play"
          onClick={() => control("toggle")}
          aria-label={np?.isPlaying ? "Pause" : "Play"}
          disabled={!np}
        >
          {np?.isPlaying ? <Pause size={18} fill="currentColor" /> : <Play size={18} fill="currentColor" />}
        </button>
        <button className="icon" onClick={() => control("next")} aria-label="Next" disabled={!np}>
          <SkipForward size={17} fill="currentColor" />
        </button>
      </div>
    </div>
  )
}

function Progress({ np, position }: { np: NowPlaying; position: number }) {
  return (
    <div className="progress">
      <span>{formatTime(position)}</span>
      <input
        type="range"
        min={0}
        max={np.duration}
        step={0.5}
        value={position}
        onChange={(e) => control("seek", Number(e.target.value))}
        aria-label="Seek"
        style={{ ["--fill" as string]: `${(position / np.duration) * 100}%` } as CSSProperties}
      />
      <span>{formatTime(np.duration)}</span>
    </div>
  )
}

/** Synced lyrics that keep the current line centered; click a line to jump there. */
function LyricsScroller({ np, lines }: { np: NowPlaying; lines: { time: number; text: string }[] }) {
  const current = currentIndex(lines, positionAt(np))
  const box = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const scroller = box.current
    const el = scroller?.querySelector<HTMLElement>(`[data-i="${current ?? 0}"]`)
    // Scroll only the lyrics list: scrollIntoView also scrolls every overflow:hidden ancestor,
    // which shifted the whole pill (tabs and all) up out of the window.
    if (scroller && el) scroller.scrollTo({ top: el.offsetTop - scroller.clientHeight / 2 + el.offsetHeight / 2, behavior: "smooth" })
  }, [current])

  return (
    <div className="lyrics-scroll" ref={box}>
      {lines.map((line, i) => {
        const distance = current === null ? 3 : Math.abs(i - current)
        return (
          <button
            key={i}
            data-i={i}
            className={`lyric-line d${Math.min(distance, 3)}`}
            onClick={() => control("seek", line.time)}
          >
            {line.text || "♪"}
          </button>
        )
      })}
    </div>
  )
}

function MiniPlayer({ np }: { np: NowPlaying }) {
  const position = positionAt(np)
  return (
    <div className="mini">
      <div className="mini-transport">
        <button className="icon small" onClick={() => control("previous")} aria-label="Previous">
          <SkipBack size={13} fill="currentColor" />
        </button>
        <button
          className="icon play small"
          onClick={() => control("toggle")}
          aria-label={np.isPlaying ? "Pause" : "Play"}
        >
          {np.isPlaying ? <Pause size={14} fill="currentColor" /> : <Play size={14} fill="currentColor" />}
        </button>
        <button className="icon small" onClick={() => control("next")} aria-label="Next">
          <SkipForward size={13} fill="currentColor" />
        </button>
      </div>
      {np.duration > 0 && (
        <>
          <div className="mini-bar">
            <i style={{ width: `${(position / np.duration) * 100}%` }} />
          </div>
          <div className="mini-times">
            <span>{formatTime(position)}</span>
            <span>{formatTime(np.duration)}</span>
          </div>
        </>
      )}
    </div>
  )
}

/** Record with the cover as its label; the tonearm drops onto it while playing, like the macOS turntable. */
function Vinyl({
  src,
  size,
  playing,
  tonearm = false,
}: {
  src: string | null
  size: number
  playing: boolean
  tonearm?: boolean
}) {
  return (
    <div className="vinyl-wrap" style={{ width: size, height: size }}>
      <div className={`vinyl ${playing ? "spinning" : ""}`}>
        <div className="label">{src ? <img src={src} alt="" /> : <Music2 size={size * 0.16} />}</div>
      </div>
      {tonearm && (
        <div className={`tonearm ${playing ? "down" : ""}`} aria-hidden>
          <i className="pivot" />
          <i className="arm" />
        </div>
      )}
    </div>
  )
}

/** Compact usage meter in the closed pill: a ring filled to the share used. */
function UsageMeter({ label, percent, hot }: { label: string; percent: number; hot: boolean }) {
  return (
    <span className={`usage-meter ${hot ? "hot" : ""}`} title="AI usage" style={{ ["--p" as string]: `${Math.min(100, percent)}%` } as CSSProperties}>
      <i />
      {label}
    </span>
  )
}

function Bars({ playing }: { playing: boolean }) {
  return (
    <span className={`bars ${playing ? "playing" : ""}`} aria-hidden>
      <i />
      <i />
      <i />
      <i />
    </span>
  )
}

function StatusQuickLook({
  timerState,
  timerActive,
  aiEnabled,
  usage,
  onOpenTab,
  onClose,
}: {
  timerState: TimerState
  timerActive: boolean
  aiEnabled: boolean
  usage: UsageReport[] | null
  onOpenTab: (key: TabKey) => void
  onClose: () => void
}) {
  const [stats, setStats] = useState<SystemStats | null>(null)

  useEffect(() => {
    let active = true
    const poll = () => {
      invoke<SystemStats>("system_stats")
        .then((s) => {
          if (active) setStats(s)
        })
        .catch(() => {})
    }
    poll()
    const id = window.setInterval(poll, 2000)
    return () => {
      active = false
      clearInterval(id)
    }
  }, [])

  const memPct = stats && stats.memTotalBytes > 0 ? Math.round((stats.memUsedBytes / stats.memTotalBytes) * 100) : 0
  const activeAccounts = usage?.filter((r) => r.found && r.isActive !== false).length ?? 0
  const todayTokens = usage?.reduce((s, r) => s + r.today.tokens, 0) ?? 0

  return (
    <div className="pill-popover pill-popover-right">
      <div className="status-pop-head">
        <strong>System & Activity Quick Look</strong>
        <button type="button" className="ai-settings-btn" onClick={onClose}>
          Close
        </button>
      </div>

      <div className="status-pop-section">
        <div className="status-pop-row">
          <span>CPU</span>
          <b>{stats ? `${Math.round(stats.cpuPercent)}%` : "…"}</b>
        </div>
        <div className="status-pop-bar">
          <i style={{ width: `${Math.min(100, stats?.cpuPercent ?? 0)}%` }} />
        </div>
        <div className="status-pop-row">
          <span>Memory</span>
          <b>
            {stats
              ? `${formatBytes(stats.memUsedBytes)} / ${formatBytes(stats.memTotalBytes)} (${memPct}%)`
              : "…"}
          </b>
        </div>
        <div className="status-pop-bar">
          <i style={{ width: `${Math.min(100, memPct)}%` }} />
        </div>
        <div className="status-pop-net">
          <span>↓ {stats ? formatRate(stats.netDownBps) : "…"}</span>
          <span>↑ {stats ? formatRate(stats.netUpBps) : "…"}</span>
          <button type="button" className="status-link" onClick={() => onOpenTab("dev")}>
            Open Dev →
          </button>
        </div>
      </div>

      {timerActive && (
        <div className="status-pop-section">
          <div className="status-pop-row">
            <span>Timer ({timerState.pomodoro ? timerState.phase : "Countdown"})</span>
            <b className="gw-mono">{formatCountdown(timerRemaining(timerState))}</b>
          </div>
          <div className="status-pop-net">
            <button type="button" className="ai-settings-btn" onClick={() => timerControl.toggleRun()}>
              {timerState.endsAt !== null ? "Pause" : "Resume"}
            </button>
            <button type="button" className="status-link" onClick={() => onOpenTab("timer")}>
              Open Timer →
            </button>
          </div>
        </div>
      )}

      {aiEnabled && usage && usage.length > 0 && (
        <div className="status-pop-section">
          <div className="status-pop-row">
            <span>AI Quota ({activeAccounts} active)</span>
            <b>{formatTokens(todayTokens)} tokens</b>
          </div>
          <div className="status-pop-net">
            <span />
            <button type="button" className="status-link" onClick={() => onOpenTab("ai")}>
              Open AI →
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
