import { invoke } from "@tauri-apps/api/core"
import { Captions, Languages, Pause, Play, SkipBack, SkipForward, X } from "lucide-react"
import { useEffect, useRef, useState, type CSSProperties } from "react"
import { chatAi } from "./tabs/ChatPanel"
import { currentIndex } from "./lyrics"
import { control, formatTime, positionAt, useLyrics, useNowPlaying, useTick } from "./media"
import { useAccent } from "./palette"
import { NOW_PLAYING_BACKGROUNDS, useSettings, type AppSettings } from "./settings"

const translationCache = new Map<string, Record<string, string>>()

/** Translates the lyric lines with the Ask AI provider (Windows has no on-device translator). Cached per song. */
function useTranslations(key: string, lines: string[], settings: AppSettings): Record<string, string> {
  const [map, setMap] = useState<Record<string, string>>({})
  const target = settings.lyricsTranslateTarget
  useEffect(() => {
    if (!target || !lines.length) return setMap({})
    const cacheKey = `${key}\u0000${target}`
    if (translationCache.has(cacheKey)) return setMap(translationCache.get(cacheKey)!)
    let alive = true
    const unique = [...new Set(lines.filter((l) => l.trim()))]
    const prompt = `Translate each song lyric line into the language with code "${target}". Reply with JSON only: an array of strings, same order and count.\n\n${JSON.stringify(unique)}`
    chatAi(settings, [{ role: "user", content: prompt }], "You translate song lyrics. Output JSON only.")
      .then((reply) => {
        const json = reply.slice(reply.indexOf("["), reply.lastIndexOf("]") + 1)
        const out: string[] = JSON.parse(json)
        const next = Object.fromEntries(unique.map((l, i) => [l, out[i] ?? ""]))
        translationCache.set(cacheKey, next)
        if (alive) setMap(next)
      })
      .catch(() => alive && setMap({}))
    return () => {
      alive = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, target, lines.length])
  return map
}

/** Full-screen player in its own window: blurred artwork or album-color backdrop, big cover, synced lyrics. */
export function NowPlayingScreen() {
  const [settings, setSettings] = useSettings()
  const np = useNowPlaying()
  const lyrics = useLyrics(np)
  const accent = useAccent(np?.artwork)
  const [controlsVisible, setControlsVisible] = useState(true)
  const hideTimer = useRef<number | undefined>(undefined)
  const scroller = useRef<HTMLDivElement>(null)
  useTick(250)

  const close = () => invoke("close_now_playing").catch(() => {})
  const synced = lyrics && lyrics !== "loading" ? lyrics.synced : []
  const translations = useTranslations(np ? `${np.title}\u0000${np.artist}` : "", synced.map((l) => l.text), settings)
  const pos = np ? positionAt(np) : 0
  const current = np && synced.length ? (currentIndex(synced, pos) ?? -1) : -1
  const nextBackground = () => {
    const i = NOW_PLAYING_BACKGROUNDS.findIndex((b) => b.id === settings.nowPlayingBackground)
    setSettings({ nowPlayingBackground: NOW_PLAYING_BACKGROUNDS[(i + 1) % NOW_PLAYING_BACKGROUNDS.length].id })
  }
  const toggleTranslate = () => setSettings({ lyricsTranslateTarget: settings.lyricsTranslateTarget ? "" : navigator.language.split("-")[0] || "en" })

  const poke = () => {
    setControlsVisible(true)
    window.clearTimeout(hideTimer.current)
    hideTimer.current = window.setTimeout(() => setControlsVisible(false), 3000)
  }
  useEffect(() => {
    poke()
    const onKey = (e: KeyboardEvent) => {
      if (e.key === " ") control("toggle")
      else if (e.key === "ArrowRight") control("next")
      else if (e.key === "ArrowLeft") control("previous")
      else if (e.key.toLowerCase() === "t") toggleTranslate()
      else if (e.key.toLowerCase() === "l") setSettings({ nowPlayingLyrics: !settings.nowPlayingLyrics })
      else if (e.key.toLowerCase() === "b") nextBackground()
      else close()
      e.preventDefault()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settings])

  // Keep the current line about a third of the way down.
  useEffect(() => {
    const el = scroller.current?.querySelector<HTMLElement>(`[data-line="${current}"]`)
    if (el && scroller.current) scroller.current.scrollTo({ top: el.offsetTop - scroller.current.clientHeight * 0.35, behavior: "smooth" })
  }, [current])

  const bg = settings.nowPlayingBackground
  const showLyrics = settings.nowPlayingLyrics
  return (
    <div className={`np-screen bg-${bg} ${showLyrics ? "" : "no-lyrics"}`} style={{ "--np-accent": accent, "--np-scale": settings.nowPlayingTextScale } as CSSProperties} onMouseMove={poke}>
      <div className="np-backdrop">
        {bg === "blur" && np?.artwork && <img className="np-backdrop-img" src={np.artwork} alt="" key={np.title} />}
        {bg === "vinyl" && (
          <div className={`np-vinyl ${np?.isPlaying ? "spin" : ""}`}>
            {np?.artwork && <img src={np.artwork} alt="" />}
          </div>
        )}
        {bg !== "black" && bg !== "vinyl" && <div className="np-glow" />}
        <div className="np-shade" />
      </div>

      {np ? (
        <div className="np-layout">
          <div className="np-player">
            <div className={`np-cover ${np.isPlaying ? "" : "paused"}`}>
              {np.artwork ? <img src={np.artwork} alt="" key={np.title} /> : <div className="np-cover-empty">♪</div>}
            </div>
            <div className="np-title">{np.title}</div>
            <div className="np-artist">{np.artist}</div>
            <div className="np-progress">
              <div className="np-bar">
                <i style={{ width: np.duration ? `${(pos / np.duration) * 100}%` : 0 }} />
              </div>
              <div className="np-times">
                <span>{formatTime(pos)}</span>
                <span>{formatTime(np.duration)}</span>
              </div>
            </div>
            <div className="np-transport">
              <button onClick={() => control("previous")} aria-label="Previous" title="Previous (←)"><SkipBack size={26} fill="currentColor" /></button>
              <button className="np-play" onClick={() => control("toggle")} aria-label={np.isPlaying ? "Pause" : "Play"} title="Play / pause (Space)">
                {np.isPlaying ? <Pause size={38} fill="currentColor" /> : <Play size={38} fill="currentColor" />}
              </button>
              <button onClick={() => control("next")} aria-label="Next" title="Next (→)"><SkipForward size={26} fill="currentColor" /></button>
            </div>
            <div className={`np-extras ${controlsVisible ? "" : "faded"}`}>
              <button className={showLyrics ? "on" : ""} onClick={() => setSettings({ nowPlayingLyrics: !showLyrics })} title="Lyrics (L)" aria-label="Lyrics"><Captions size={16} /></button>
              <button className={settings.lyricsTranslateTarget ? "on" : ""} onClick={toggleTranslate} title="Translate lyrics (T)" aria-label="Translate lyrics"><Languages size={16} /></button>
              <button onClick={nextBackground} title={`Background: ${NOW_PLAYING_BACKGROUNDS.find((b) => b.id === bg)?.name} (B)`} aria-label="Switch background">
                {bg === "blur" ? "🖼" : bg === "aurora" ? "✨" : bg === "gradient" ? "◐" : bg === "vinyl" ? "💿" : "🌙"}
              </button>
              <button onClick={close} title="Close (Esc)" aria-label="Close"><X size={16} /></button>
            </div>
          </div>

          {showLyrics && (
            <div className="np-lyrics" ref={scroller}>
              {lyrics === "loading" ? (
                <div className="np-lyrics-note">Loading lyrics…</div>
              ) : synced.length ? (
                <>
                  <div className="np-spacer" />
                  {synced.map((l, i) => {
                    const d = i - current
                    const t = settings.lyricsTranslateTarget ? translations[l.text] : ""
                    return (
                      <div
                        key={i}
                        data-line={i}
                        className={`np-line ${d === 0 ? "now" : d < 0 ? "past" : ""}`}
                        style={{ "--d": Math.min(5, Math.abs(d)) } as CSSProperties}
                        onClick={() => control("seek", l.time)}
                      >
                        <div>{l.text || "♪"}</div>
                        {t && l.text && <div className="np-translation">{t}</div>}
                      </div>
                    )
                  })}
                  <div className="np-spacer" />
                </>
              ) : lyrics?.plain ? (
                <div className="np-plain">{lyrics.plain}</div>
              ) : (
                <div className="np-lyrics-note">No lyrics for this song</div>
              )}
            </div>
          )}
        </div>
      ) : (
        <div className="np-nothing">Nothing playing</div>
      )}

      {settings.nowPlayingClock && <Clock />}
    </div>
  )
}

function Clock() {
  useTick(1000)
  const now = new Date()
  return (
    <div className="np-clock">
      <div>{now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</div>
      <span>{now.toLocaleDateString([], { weekday: "long", day: "numeric", month: "long" })}</span>
    </div>
  )
}

/** Opens the full-screen player after the PC sits idle while music plays; mounted in the pill window. */
export function useIdleNowPlaying(isPlaying: boolean) {
  const [settings] = useSettings()
  const shown = useRef(false)
  useEffect(() => {
    if (!settings.nowPlayingEnabled) return
    const id = setInterval(async () => {
      const idle = await invoke<number>("idle_seconds").catch(() => 0)
      // Reset once the user is back, so the next idle stretch can open it again.
      if (idle < 5) shown.current = false
      if (!shown.current && isPlaying && idle >= settings.nowPlayingIdleMinutes * 60) {
        shown.current = true
        invoke("open_now_playing").catch(() => {})
      }
    }, 5000)
    return () => clearInterval(id)
  }, [settings.nowPlayingEnabled, settings.nowPlayingIdleMinutes, isPlaying])
}
