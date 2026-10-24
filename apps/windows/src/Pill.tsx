import { invoke } from "@tauri-apps/api/core"
import { listen } from "@tauri-apps/api/event"
import {
  Camera,
  ClipboardList,
  Coffee,
  Mic,
  ScrollText,
  Video,
  Music2,
  Pause,
  PictureInPicture2,
  Play,
  Quote,
  Settings as SettingsIcon,
  Share2,
  SkipBack,
  SkipForward,
  Sparkles,
  Timer,
} from "lucide-react"
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react"
import { currentIndex } from "./lyrics"
import { control, currentLine, formatTime, positionAt, useLyrics, useNowPlaying, useTick, type NowPlaying } from "./media"
import { closedMeter } from "./ai"
import { NotchiMascot } from "./NotchiMascot"
import { NotchiStatus } from "./NotchiStatus"
import { filterRecentAgentStates, notchiMood, playPetPopSound, type NotchiMood } from "./notchi"
import { useAccent } from "./palette"
import { resolveAccentColor, useSettings } from "./settings"
import { AITab, useAgents, useUsage } from "./tabs/AITab"
import { ClipboardTab } from "./tabs/ClipboardTab"
import { MirrorTab } from "./tabs/MirrorTab"
import { NotesTab } from "./tabs/NotesTab"
import { PrompterTab } from "./tabs/PrompterTab"
import { TimerTab } from "./tabs/TimerTab"
import { useUpdateChecker } from "./updater"
import { BannerView } from "./BannerView"
import { playBannerSound, type Banner } from "./banner"

// Pill sizes in logical pixels. The window is a fixed 640×280 transparent canvas; the pill animates inside it.
const CLOSED = { width: 340, height: 38 }
const PEEKING = { width: 380, height: 38 }
const BANNER_SIZE = { width: 420, height: 96 }
const OPEN = { width: 600, height: 210 }
/** Gap above the floating pill. */
const FLOAT_GAP = 10
/** Height of the invisible top-edge strip that reveals an auto-hidden pill. */
const REVEAL_STRIP = 4
const PEEK_MS = 3000

type Privacy = { camera: boolean; mic: boolean }
type TabKey = "music" | "clipboard" | "timer" | "notes" | "prompter" | "mirror" | "ai"

export function Pill() {
  const np = useNowPlaying()
  const lyrics = useLyrics(np)
  const rawAccent = useAccent(np?.artwork)
  const [settings] = useSettings()

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
  const { usage, toggleActive } = useUsage(settings.aiEnabled)
  const meter = settings.aiEnabled && settings.aiClosedMeter && usage ? closedMeter(usage, Date.now()) : null

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

  // A countdown or photobox in progress keeps the pill open even if the cursor drifts away.
  const [mirrorBusy, setMirrorBusy] = useState(false)
  const mirrorBusyRef = useRef(false)
  // A pinned Mirror stays open until unpinned or another tab is chosen.
  mirrorBusyRef.current = mirrorBusy || (activeTab === "mirror" && settings.mirrorPinned)
  const { updateInfo } = useUpdateChecker()
  useTick(250)

  const onMirror = activeTab === "mirror" && settings.tabMirror
  const openSize = onMirror ? { width: 620, height: settings.mirrorHeight } : OPEN
  const isMascotIdle = settings.showMascot && !peek && !activeBanner && !np && !meter
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
    invoke("set_pill_size", hover).catch(() => {})
  }, [hover.width, hover.height])

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
    let closeTimer: number | undefined
    const unlistenHover = listen<boolean>("pill-hover", ({ payload: inside }) => {
      clearTimeout(closeTimer)
      if (activeBannerRef.current) {
        setBannerHovered(inside)
        return
      }
      if (inside) setOpen(true)
      else closeTimer = window.setTimeout(() => !mirrorBusyRef.current && setOpen(false), settings.closeDelayMs ?? 300)
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

  // Fallback active tab if current tab is disabled in settings
  const enabledTabs: Record<TabKey, boolean> = {
    music: settings.tabMusic,
    clipboard: settings.tabClipboard,
    timer: settings.tabTimer,
    notes: settings.tabNotes,
    prompter: settings.tabPrompter,
    mirror: settings.tabMirror,
    ai: settings.aiEnabled,
  }
  const currentTabSafe: TabKey = enabledTabs[activeTab]
    ? activeTab
    : (Object.keys(enabledTabs) as TabKey[]).find((k) => enabledTabs[k]) ?? "music"

  return (
    <div
      className={`stage mode-${mode}`}
      style={{ ["--accent" as string]: resolvedAccent, ["--float-gap" as string]: `${FLOAT_GAP}px` } as CSSProperties}
    >
      <div
        className={`pill ${open ? "open" : ""} ${hidden ? "hidden" : ""} theme-${settings.theme} border-${settings.borderStyle} anim-${settings.openAnimation}`}
        style={{ width: size.width, height: size.height }}
      >
        {/* Album Art theme background */}
        {settings.theme === "albumArt" && np?.artwork && (
          <div className="theme-album-bg" style={{ backgroundImage: `url(${np.artwork})` }} />
        )}

        {/* Dynamic aura blur behind open pill */}
        {open && settings.auraGlow !== "off" && (
          <div
            className={`aura ${settings.auraGlow}`}
            style={{
              backgroundImage: np?.artwork ? `url(${np.artwork})` : undefined,
              backgroundColor: !np?.artwork ? resolvedAccent : undefined,
            }}
          />
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
          ) : np ? (
            <>
              <Vinyl src={np.artwork} size={24} playing={np.isPlaying} />
              <span className="closed-text" key={line.text ?? np.title}>
                {line.text ?? np.title}
              </span>
              {meter ? (
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
          ) : meter ? (
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
        </div>


        {/* Open Pill State with Header & Tabs */}
        <div className="pill-open" aria-hidden={!open}>
          {/* Header Bar */}
          <div className="pill-header">
            <div className="pill-tabs-nav">
              {settings.tabMusic && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "music" ? "active" : ""}`}
                  title="Music"
                  onClick={() => setActiveTab("music")}
                >
                  <Music2 size={12} />
                  <span>Music</span>
                </button>
              )}
              {settings.tabClipboard && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "clipboard" ? "active" : ""}`}
                  title="Clipboard"
                  onClick={() => setActiveTab("clipboard")}
                >
                  <ClipboardList size={12} />
                  <span>Clipboard</span>
                </button>
              )}
              {settings.tabTimer && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "timer" ? "active" : ""}`}
                  title="Timer"
                  onClick={() => setActiveTab("timer")}
                >
                  <Timer size={12} />
                  <span>Timer</span>
                </button>
              )}
              {settings.tabNotes && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "notes" ? "active" : ""}`}
                  title="Notes"
                  onClick={() => setActiveTab("notes")}
                >
                  <Coffee size={12} />
                  <span>Notes</span>
                </button>
              )}
              {settings.tabPrompter && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "prompter" ? "active" : ""}`}
                  onClick={() => setActiveTab("prompter")}
                  title="Teleprompter"
                >
                  <ScrollText size={12} />
                  <span>Prompter</span>
                </button>
              )}
              {settings.tabMirror && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "mirror" ? "active" : ""}`}
                  onClick={() => setActiveTab("mirror")}
                  title="Mirror & photobox"
                >
                  <Video size={12} />
                  <span>Mirror</span>
                </button>
              )}
              {settings.aiEnabled && (
                <button
                  className={`tab-nav-btn ${currentTabSafe === "ai" ? "active" : ""}`}
                  onClick={() => setActiveTab("ai")}
                  title="AI agents, usage and Ask AI"
                >
                  <Sparkles size={12} />
                  <span>AI</span>
                </button>
              )}
            </div>

            <div className="pill-header-actions">
              <button
                className={`header-action-btn ${awake ? "on" : ""}`}
                onClick={toggleAwake}
                title={awake ? "Stop keeping awake" : "Keep awake"}
              >
                <Coffee size={12} />
              </button>
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

          {/* Active Tab View */}
          <div className="pill-tab-content">
            {currentTabSafe === "music" && (
              <div className="music-content">
                <div className="deck">
                  <Vinyl src={np?.artwork ?? null} size={118} playing={!!np?.isPlaying} tonearm />
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
                        className="lyrics-share-toggle"
                        onClick={openShare}
                        aria-label="Share lyric card"
                        title="Share lyric card"
                      >
                        <Share2 size={11} />
                      </button>
                    </div>
                  )}
                </div>

                {showLyrics && np ? (
                  <>
                    <LyricsScroller np={np} lines={synced} />
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

            {currentTabSafe === "prompter" && <PrompterTab />}

            {/* Mounted only while open so the camera light goes off when the pill closes. */}
            {currentTabSafe === "mirror" && open && <MirrorTab onBusy={setMirrorBusy} />}

            {currentTabSafe === "ai" && (
              <AITab
                sessions={agents}
                usage={usage}
                onToggleActive={toggleActive}
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
