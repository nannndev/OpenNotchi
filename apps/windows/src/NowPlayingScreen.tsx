import { invoke } from "@tauri-apps/api/core"
import { Camera, Captions, Languages, Pause, Play, SkipBack, SkipForward, Sparkles, Video, X } from "lucide-react"
import { useEffect, useMemo, useRef, useState, type CSSProperties } from "react"
import { chatAi } from "./tabs/ChatPanel"
import { currentIndex } from "./lyrics"
import { control, formatTime, positionAt, useLyrics, useNowPlaying, useTick } from "./media"
import { useAccent } from "./palette"
import { buildCameraFilter, EFFECTS, savePng, type CameraAdjustments, type MirrorEffect } from "./photobox"
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

  const bg = settings.nowPlayingBackground
  const showLyrics = settings.nowPlayingLyrics
  const isMirrorActive = settings.nowPlayingCoverMirror || bg === "mirror"
  const [stream, setStream] = useState<MediaStream | null>(null)
  const coverVideoRef = useRef<HTMLVideoElement | null>(null)
  const bgVideoRef = useRef<HTMLVideoElement | null>(null)
  const [flash, setFlash] = useState(false)
  const [toast, setToast] = useState<string | null>(null)
  const [showMirrorBar, setShowMirrorBar] = useState(false)

  const adj: CameraAdjustments = useMemo(
    () => ({
      mirrorBrightness: settings.mirrorBrightness ?? 0,
      mirrorContrast: settings.mirrorContrast ?? 1,
      mirrorSaturation: settings.mirrorSaturation ?? 1,
      mirrorWarmth: settings.mirrorWarmth ?? 0,
      mirrorGlow: settings.mirrorGlow ?? 0,
      mirrorVignette: settings.mirrorVignette ?? 0,
      mirrorZoom: settings.mirrorZoom ?? 1,
      mirrorFlipped: settings.mirrorFlipped ?? true,
    }),
    [
      settings.mirrorBrightness,
      settings.mirrorContrast,
      settings.mirrorSaturation,
      settings.mirrorWarmth,
      settings.mirrorGlow,
      settings.mirrorVignette,
      settings.mirrorZoom,
      settings.mirrorFlipped,
    ]
  )
  const cameraCssFilter = useMemo(() => buildCameraFilter(settings.mirrorEffect, adj), [settings.mirrorEffect, adj])

  // Camera stream lifecycle
  useEffect(() => {
    if (!isMirrorActive) {
      if (stream) {
        stream.getTracks().forEach((t) => t.stop())
        setStream(null)
      }
      return
    }
    let cancelled = false
    const videoConstraint = settings.mirrorCameraId
      ? { deviceId: { exact: settings.mirrorCameraId }, width: 1280, height: 720 }
      : { width: 1280, height: 720 }
    navigator.mediaDevices?.getUserMedia({ video: videoConstraint, audio: false })
      .then((s) => {
        if (cancelled) {
          s.getTracks().forEach((t) => t.stop())
          return
        }
        setStream(s)
      })
      .catch(() => {})

    return () => {
      cancelled = true
    }
  }, [isMirrorActive, settings.mirrorCameraId])

  useEffect(() => {
    if (coverVideoRef.current && stream) {
      coverVideoRef.current.srcObject = stream
      coverVideoRef.current.play().catch(() => {})
    }
  }, [stream, settings.nowPlayingCoverMirror])

  useEffect(() => {
    if (bgVideoRef.current && stream) {
      bgVideoRef.current.srcObject = stream
      bgVideoRef.current.play().catch(() => {})
    }
  }, [stream, bg])

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

  const toggleMirrorMode = () => {
    if (!settings.nowPlayingCoverMirror && bg !== "mirror") {
      setSettings({ nowPlayingCoverMirror: true })
    } else if (settings.nowPlayingCoverMirror) {
      setSettings({ nowPlayingCoverMirror: false, nowPlayingBackground: "mirror" })
    } else {
      setSettings({ nowPlayingCoverMirror: false, nowPlayingBackground: "blur" })
    }
  }

  const capturePhoto = async () => {
    setFlash(true)
    setTimeout(() => setFlash(false), 200)

    try {
      const audioCtx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)()
      const osc = audioCtx.createOscillator()
      const gain = audioCtx.createGain()
      osc.type = "sine"
      osc.frequency.setValueAtTime(800, audioCtx.currentTime)
      osc.frequency.exponentialRampToValueAtTime(300, audioCtx.currentTime + 0.08)
      gain.gain.setValueAtTime(0.25, audioCtx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.08)
      osc.connect(gain)
      gain.connect(audioCtx.destination)
      osc.start()
      osc.stop(audioCtx.currentTime + 0.09)
    } catch {}

    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    const video = (settings.nowPlayingCoverMirror ? coverVideoRef.current : bgVideoRef.current) || coverVideoRef.current || bgVideoRef.current

    if (settings.nowPlayingCoverMirror && bg !== "mirror") {
      canvas.width = 1080
      canvas.height = 1080
      const grad = ctx.createLinearGradient(0, 0, 1080, 1080)
      grad.addColorStop(0, "#18181b")
      grad.addColorStop(1, "#09090b")
      ctx.fillStyle = grad
      ctx.fillRect(0, 0, 1080, 1080)

      if (video && video.videoWidth) {
        ctx.save()
        const cx = 140, cy = 120, cw = 800, ch = 800
        ctx.beginPath()
        ctx.roundRect(cx, cy, cw, ch, 48)
        ctx.clip()
        ctx.filter = cameraCssFilter
        if (adj.mirrorFlipped) {
          ctx.translate(cx + cw, cy)
          ctx.scale(-1, 1)
          ctx.drawImage(video, 0, 0, cw, ch)
        } else {
          ctx.drawImage(video, cx, cy, cw, ch)
        }
        ctx.filter = "none"
        if (EFFECTS[settings.mirrorEffect]?.tint) {
          ctx.fillStyle = EFFECTS[settings.mirrorEffect].tint!
          ctx.fillRect(cx, cy, cw, ch)
        }
        ctx.restore()

        ctx.save()
        ctx.strokeStyle = "rgba(255, 255, 255, 0.2)"
        ctx.lineWidth = 3
        ctx.beginPath()
        ctx.roundRect(cx, cy, cw, ch, 48)
        ctx.stroke()
        ctx.restore()
      }

      ctx.fillStyle = "#ffffff"
      ctx.font = "bold 44px 'Segoe UI', system-ui, sans-serif"
      ctx.fillText(np ? np.title : "Music", 140, 980)

      ctx.fillStyle = "rgba(255, 255, 255, 0.7)"
      ctx.font = "500 28px 'Segoe UI', system-ui, sans-serif"
      ctx.fillText(np ? np.artist : "", 140, 1024)

      ctx.fillStyle = "rgba(255, 255, 255, 0.4)"
      ctx.font = "600 22px 'Segoe UI', system-ui, sans-serif"
      ctx.textAlign = "right"
      ctx.fillText("OpenNotchi", 940, 1024)
    } else {
      canvas.width = 1920
      canvas.height = 1080
      ctx.fillStyle = "#000000"
      ctx.fillRect(0, 0, 1920, 1080)

      if (video && video.videoWidth) {
        ctx.save()
        const blurPart = settings.nowPlayingMirrorBlur > 0 ? ` blur(${settings.nowPlayingMirrorBlur * 1.5}px)` : ""
        ctx.filter = `${cameraCssFilter}${blurPart}`
        if (adj.mirrorFlipped) {
          ctx.translate(1920, 0)
          ctx.scale(-1, 1)
        }
        ctx.drawImage(video, 0, 0, 1920, 1080)
        ctx.restore()
        ctx.filter = "none"
        if (EFFECTS[settings.mirrorEffect]?.tint) {
          ctx.fillStyle = EFFECTS[settings.mirrorEffect].tint!
          ctx.fillRect(0, 0, 1920, 1080)
        }
      }

      const shade = ctx.createLinearGradient(0, 0, 0, 1080)
      shade.addColorStop(0, "rgba(0, 0, 0, 0.35)")
      shade.addColorStop(0.7, "rgba(0, 0, 0, 0.65)")
      shade.addColorStop(1, "rgba(0, 0, 0, 0.85)")
      ctx.fillStyle = shade
      ctx.fillRect(0, 0, 1920, 1080)

      if (settings.nowPlayingCoverSilhouette && np?.artwork) {
        try {
          const img = new Image()
          img.crossOrigin = "anonymous"
          img.src = np.artwork
          await new Promise((res) => { img.onload = res; img.onerror = res })
          if (img.width) {
            ctx.save()
            ctx.globalAlpha = 0.22
            ctx.filter = "blur(20px)"
            ctx.drawImage(img, 120, 180, 720, 720)
            ctx.restore()
            ctx.filter = "none"
          }
        } catch {}
      }

      ctx.fillStyle = "#ffffff"
      ctx.font = "bold 56px 'Segoe UI', system-ui, sans-serif"
      ctx.fillText(np ? np.title : "", 160, 480)

      ctx.fillStyle = "rgba(255, 255, 255, 0.75)"
      ctx.font = "500 36px 'Segoe UI', system-ui, sans-serif"
      ctx.fillText(np ? np.artist : "", 160, 545)

      if (synced.length && current >= 0 && synced[current]) {
        ctx.fillStyle = "#ffffff"
        ctx.font = "bold 64px 'Segoe UI', system-ui, sans-serif"
        const lineText = synced[current].text
        ctx.fillText(lineText, 980, 520)

        const trans = settings.lyricsTranslateTarget ? translations[lineText] : ""
        if (trans) {
          ctx.fillStyle = accent || "#38bdf8"
          ctx.font = "600 38px 'Segoe UI', system-ui, sans-serif"
          ctx.fillText(trans, 980, 580)
        }
      }

      ctx.fillStyle = "rgba(255, 255, 255, 0.5)"
      ctx.font = "600 24px 'Segoe UI', system-ui, sans-serif"
      ctx.fillText("OpenNotchi", 160, 960)
    }

    const title = np ? np.title.replace(/[\\/:*?"<>|]/g, "") : "Music"
    await savePng(canvas, `NowPlaying - ${title}`)
    try {
      canvas.toBlob((blob) => {
        if (blob) navigator.clipboard.write([new ClipboardItem({ "image/png": blob })])
      }, "image/png")
    } catch {}

    setToast("📸 Photo saved & copied to clipboard!")
    setTimeout(() => setToast(null), 3000)
  }

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
      else if (e.key.toLowerCase() === "m") toggleMirrorMode()
      else if (e.key.toLowerCase() === "c") capturePhoto()
      else close()
      e.preventDefault()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [settings, current, synced, translations, bg, np])

  // Keep the current line about a third of the way down.
  useEffect(() => {
    const el = scroller.current?.querySelector<HTMLElement>(`[data-line="${current}"]`)
    if (el && scroller.current) scroller.current.scrollTo({ top: el.offsetTop - scroller.current.clientHeight * 0.35, behavior: "smooth" })
  }, [current])

  return (
    <div className={`np-screen bg-${bg} ${showLyrics ? "" : "no-lyrics"}`} style={{ "--np-accent": accent, "--np-scale": settings.nowPlayingTextScale } as CSSProperties} onMouseMove={poke}>
      <div className="np-backdrop">
        {bg === "blur" && np?.artwork && <img className="np-backdrop-img" src={np.artwork} alt="" key={np.title} />}
        {bg === "vinyl" && (
          <div className={`np-vinyl ${np?.isPlaying ? "spin" : ""}`}>
            {np?.artwork && <img src={np.artwork} alt="" />}
          </div>
        )}
        {bg === "mirror" && (
          <div className="np-backdrop-mirror">
            <video
              ref={(el) => {
                bgVideoRef.current = el
                if (el && stream && el.srcObject !== stream) {
                  el.srcObject = stream
                  el.play().catch(() => {})
                }
              }}
              autoPlay
              playsInline
              muted
              className="np-backdrop-video"
              style={{
                filter: `${cameraCssFilter} blur(${settings.nowPlayingMirrorBlur}px)`,
                transform: `scaleX(${adj.mirrorFlipped ? -1 : 1}) scale(${Math.max(1.06, adj.mirrorZoom)})`,
              }}
            />
            {settings.nowPlayingCoverSilhouette && np?.artwork && (
              <div className="np-silhouette">
                <img src={np.artwork} alt="" className="np-silhouette-img" />
              </div>
            )}
          </div>
        )}
        {bg !== "black" && bg !== "vinyl" && <div className="np-glow" />}
        <div className="np-shade" />
      </div>

      {np ? (
        <div className="np-layout">
          <div className="np-player">
            <div className={`np-cover ${settings.nowPlayingCoverMirror ? "np-cover-mirror" : ""} ${np.isPlaying ? "" : "paused"}`}>
              {settings.nowPlayingCoverMirror ? (
                <>
                  <video
                    ref={(el) => {
                      coverVideoRef.current = el
                      if (el && stream && el.srcObject !== stream) {
                        el.srcObject = stream
                        el.play().catch(() => {})
                      }
                    }}
                    autoPlay
                    playsInline
                    muted
                    className="np-cover-video"
                    style={{
                      filter: cameraCssFilter,
                      transform: `scaleX(${adj.mirrorFlipped ? -1 : 1}) scale(${adj.mirrorZoom})`,
                    }}
                  />
                  {EFFECTS[settings.mirrorEffect]?.tint && (
                    <div className="mirror-tint-overlay" style={{ background: EFFECTS[settings.mirrorEffect].tint, borderRadius: 22 }} />
                  )}
                  {np.artwork && (
                    <div className="np-cover-badge" title={np.title}>
                      <img src={np.artwork} alt="" />
                    </div>
                  )}
                </>
              ) : np.artwork ? (
                <img src={np.artwork} alt="" key={np.title} />
              ) : (
                <div className="np-cover-empty">♪</div>
              )}
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
                {bg === "blur" ? "🖼" : bg === "aurora" ? "✨" : bg === "gradient" ? "◐" : bg === "vinyl" ? "💿" : bg === "mirror" ? "📹" : "🌙"}
              </button>
              <button
                className={settings.nowPlayingCoverMirror || bg === "mirror" ? "on" : ""}
                onClick={() => setShowMirrorBar((v) => !v)}
                title="Mirror mode options: Cover & Background (M)"
                aria-label="Mirror mode"
              >
                <Video size={16} />
              </button>
              <button onClick={capturePhoto} title="Capture photo (C)" aria-label="Capture photo">
                <Camera size={16} />
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

      {(showMirrorBar || (controlsVisible && (settings.nowPlayingCoverMirror || bg === "mirror"))) && (
        <div className="np-mirror-bar">
          <div className="np-mirror-chips">
            <button
              className={`np-mirror-chip ${!settings.nowPlayingCoverMirror && bg !== "mirror" ? "active" : ""}`}
              onClick={() => setSettings({ nowPlayingCoverMirror: false, nowPlayingBackground: bg === "mirror" ? "blur" : bg })}
            >
              Off
            </button>
            <button
              className={`np-mirror-chip ${settings.nowPlayingCoverMirror ? "active" : ""}`}
              onClick={() => setSettings({ nowPlayingCoverMirror: !settings.nowPlayingCoverMirror, nowPlayingBackground: bg === "mirror" ? "blur" : bg })}
            >
              Cover Mirror
            </button>
            <button
              className={`np-mirror-chip ${bg === "mirror" ? "active" : ""}`}
              onClick={() => setSettings({ nowPlayingCoverMirror: false, nowPlayingBackground: bg === "mirror" ? "blur" : "mirror" })}
            >
              Background Mirror
            </button>
          </div>

          {bg === "mirror" && (
            <>
              <div className="np-mirror-divider" />
              <div className="np-blur-chips">
                <span>Blur:</span>
                {[0, 15, 30, 60].map((b) => (
                  <button
                    key={b}
                    className={`np-blur-chip ${settings.nowPlayingMirrorBlur === b ? "active" : ""}`}
                    onClick={() => setSettings({ nowPlayingMirrorBlur: b })}
                  >
                    {b}px
                  </button>
                ))}
              </div>
              <div className="np-mirror-divider" />
              <button
                className={`np-silhouette-toggle ${settings.nowPlayingCoverSilhouette ? "active" : ""}`}
                onClick={() => setSettings({ nowPlayingCoverSilhouette: !settings.nowPlayingCoverSilhouette })}
              >
                Siluet Cover {settings.nowPlayingCoverSilhouette ? "✓" : ""}
              </button>
            </>
          )}

          <div className="np-mirror-divider" />
          <div className="np-filter-strip">
            {(Object.keys(EFFECTS) as MirrorEffect[]).map((e) => (
              <button
                key={e}
                className={`np-filter-pill ${settings.mirrorEffect === e ? "active" : ""}`}
                onClick={() => setSettings({ mirrorEffect: e })}
                title={`${EFFECTS[e].name} (${EFFECTS[e].category})`}
              >
                <span className="mirror-swatch" style={{ background: EFFECTS[e].swatch }} />
                <span>{EFFECTS[e].name}</span>
              </button>
            ))}
          </div>

          <button
            className={`np-silhouette-toggle ${(settings.mirrorGlow ?? 0) > 0.05 ? "active" : ""}`}
            onClick={() => setSettings({ mirrorGlow: (settings.mirrorGlow ?? 0) > 0.05 ? 0 : 0.45 })}
            title="Beauty Glow"
          >
            <Sparkles size={11} style={{ display: "inline", marginRight: 3, verticalAlign: "-1px" }} />
            Glow
          </button>

          <div className="np-mirror-divider" />
          <button className="np-capture-btn" onClick={capturePhoto}>
            <Camera size={13} />
            <span>Capture (C)</span>
          </button>
        </div>
      )}

      {flash && <div className="np-flash" />}
      {toast && (
        <div className="np-toast">
          <Camera size={15} />
          <span>{toast}</span>
        </div>
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
