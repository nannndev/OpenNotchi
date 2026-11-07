import {
  CameraOff,
  FlipHorizontal2,
  Grid3x3,
  Lightbulb,
  LightbulbOff,
  Pin,
  PinOff,
  RotateCcw,
  SlidersHorizontal,
  Sparkles,
  SwitchCamera,
  Timer,
  X,
} from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import { positionAt, useNowPlaying } from "../media"
import {
  buildCameraFilter,
  captureFrame,
  composeStrip,
  DEFAULT_CAMERA_ADJUSTMENTS,
  EFFECTS,
  isCameraAdjusted,
  samplePhotos,
  savePng,
  STRIP_FORMATS,
  STRIP_SHOT_CHOICES,
  STRIP_STYLES,
  stripFontsReady,
  type CameraAdjustments,
  type MirrorEffect,
  type StripFormat,
  type StripStyle,
} from "../photobox"
import { MIRROR_MAX_HEIGHT, MIRROR_MIN_HEIGHT, useSettings, type AppSettings } from "../settings"

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

type AdjKey = "brightness" | "glow" | "contrast" | "saturation" | "warmth" | "vignette" | "zoom"

interface AdjDef {
  key: AdjKey
  settingKey: keyof AppSettings
  label: string
  min: number
  max: number
  step: number
  defaultVal: number
  format: (v: number) => string
}

const ADJ_DEFS: AdjDef[] = [
  { key: "brightness", settingKey: "mirrorBrightness", label: "Bright", min: -0.35, max: 0.35, step: 0.01, defaultVal: 0, format: (v) => `${v >= 0 ? "+" : ""}${Math.round(v * 100)}` },
  { key: "glow", settingKey: "mirrorGlow", label: "Glow", min: 0, max: 1, step: 0.02, defaultVal: 0, format: (v) => `${Math.round(v * 100)}%` },
  { key: "contrast", settingKey: "mirrorContrast", label: "Contrast", min: 0.65, max: 1.45, step: 0.01, defaultVal: 1, format: (v) => `${Math.round(v * 100)}%` },
  { key: "saturation", settingKey: "mirrorSaturation", label: "Color", min: 0, max: 1.8, step: 0.02, defaultVal: 1, format: (v) => `${Math.round(v * 100)}%` },
  { key: "warmth", settingKey: "mirrorWarmth", label: "Warmth", min: -0.5, max: 0.5, step: 0.02, defaultVal: 0, format: (v) => `${v >= 0 ? "+" : ""}${Math.round(v * 100)}` },
  { key: "vignette", settingKey: "mirrorVignette", label: "Vignette", min: 0, max: 1, step: 0.02, defaultVal: 0, format: (v) => `${Math.round(v * 100)}%` },
  { key: "zoom", settingKey: "mirrorZoom", label: "Zoom", min: 1, max: 2, step: 0.05, defaultVal: 1, format: (v) => `${v.toFixed(1)}x` },
]

/**
 * Same layout as the macOS mirror: the camera fills the tab, and controls only appear while the pointer
 * is over it (shutter + photobox + timer + zoom on the right, TikTok-style filter strip & adjustments along the bottom).
 */
export function MirrorTab({ onBusy }: { onBusy: (busy: boolean) => void }) {
  const [settings, setSettings] = useSettings()
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const [cameras, setCameras] = useState<MediaDeviceInfo[]>([])
  const [error, setError] = useState<string | null>(null)
  const [hovering, setHovering] = useState(false)
  const [choosingStrip, setChoosingStrip] = useState(false)
  const [showAdjust, setShowAdjust] = useState(false)
  const [selectedAdj, setSelectedAdj] = useState<AdjKey>("brightness")
  const [filterBanner, setFilterBanner] = useState<string | null>(null)
  const [countdown, setCountdown] = useState<number | null>(null)
  const [flash, setFlash] = useState(false)
  const [shotsTaken, setShotsTaken] = useState<number | null>(null)
  const [saved, setSaved] = useState<string | null>(null)
  const np = useNowPlaying()
  const busy = countdown !== null || shotsTaken !== null

  const effect = settings.mirrorEffect

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
  const hasCustomAdj = isCameraAdjusted(adj)

  // Show filter banner HUD when switching filters
  useEffect(() => {
    const info = EFFECTS[effect]
    if (!info) return
    setFilterBanner(`${info.name} · ${info.category}`)
    const t = setTimeout(() => setFilterBanner(null), 1300)
    return () => clearTimeout(t)
  }, [effect])

  // The camera only runs while this tab is mounted, so the light goes off when the pill closes.
  useEffect(() => {
    let stream: MediaStream | null = null
    let cancelled = false
    setError(null)
    const video = settings.mirrorCameraId
      ? { deviceId: { exact: settings.mirrorCameraId }, width: 1280, height: 720 }
      : { width: 1280, height: 720 }
    navigator.mediaDevices
      ?.getUserMedia({ video, audio: false })
      .then(async (s) => {
        if (cancelled) return s.getTracks().forEach((t) => t.stop())
        stream = s
        if (videoRef.current) videoRef.current.srcObject = s
        // Labels and ids are only filled in once access is granted.
        const all = await navigator.mediaDevices.enumerateDevices()
        setCameras(all.filter((d) => d.kind === "videoinput"))
      })
      .catch((e: Error) => {
        // A remembered camera that's gone falls back to the default one.
        if (settings.mirrorCameraId && e.name === "OverconstrainedError") setSettings({ mirrorCameraId: "" })
        else setError(e.name === "NotAllowedError" ? "denied" : "unavailable")
      })
    return () => {
      cancelled = true
      stream?.getTracks().forEach((t) => t.stop())
    }
  }, [settings.mirrorCameraId])

  // Keeps the pill open while counting down, shooting a strip or picking a strip style.
  useEffect(() => onBusy(busy || choosingStrip), [busy, choosingStrip])
  useEffect(() => () => onBusy(false), [])
  useEffect(() => () => { if (saved) URL.revokeObjectURL(saved) }, [saved])

  const shoot = async (from: number) => {
    for (let n = from; n > 0; n--) {
      setCountdown(n)
      await sleep(800)
    }
    setCountdown(null)
    setFlash(true)
    setTimeout(() => setFlash(false), 180)
    return captureFrame(videoRef.current!, effect, adj)
  }

  const keep = async (canvas: HTMLCanvasElement, name: string) => {
    await savePng(canvas, name)
    canvas.toBlob((b) => {
      if (!b) return
      setSaved(URL.createObjectURL(b))
      setTimeout(() => setSaved(null), 3500)
    }, "image/jpeg", 0.7)
  }

  const takePhoto = async () => {
    if (busy || !videoRef.current?.videoWidth) return
    const timerSec = settings.mirrorTimer ?? 3
    await keep(await shoot(timerSec), `OpenNotchi Photo ${stamp()}`).catch(() => {})
  }

  const startPhotobox = async () => {
    setChoosingStrip(false)
    if (busy || !videoRef.current?.videoWidth) return
    const shots: HTMLCanvasElement[] = []
    setShotsTaken(0)
    try {
      for (let i = 0; i < settings.stripShots; i++) {
        shots.push(await shoot(i === 0 ? 3 : 2))
        setShotsTaken(i + 1)
        await sleep(350)
      }
      const artwork = np?.artwork ? await loadImage(np.artwork).catch(() => null) : null
      await stripFontsReady
      const strip = composeStrip(shots, settings.photoboxStyle, settings.stripFormat, {
        caption: settings.stripCaption || undefined,
        songTitle: np?.title,
        artist: np?.artist,
        artwork,
        songPosition: np ? positionAt(np) : undefined,
        songDuration: np?.duration || undefined,
        isPlaying: np?.isPlaying,
      })
      await keep(strip, `OpenNotchi Photobox ${stamp()}`)
    } catch {
      // Nothing saved; the strip simply isn't kept.
    } finally {
      setShotsTaken(null)
    }
  }

  const nextCamera = () => {
    if (cameras.length < 2) return
    const i = cameras.findIndex((c) => c.deviceId === settings.mirrorCameraId)
    setSettings({ mirrorCameraId: cameras[(i + 1) % cameras.length].deviceId })
  }

  const cycleTimer = () => {
    const cur = settings.mirrorTimer ?? 3
    const next = cur === 0 ? 3 : cur === 3 ? 5 : 0
    setSettings({ mirrorTimer: next })
  }

  const cycleZoom = () => {
    const z = settings.mirrorZoom ?? 1
    const next = z < 1.2 ? 1.25 : z < 1.45 ? 1.5 : z < 1.9 ? 2.0 : 1.0
    setSettings({ mirrorZoom: next })
  }

  const resetAllAdj = () => {
    setSettings(DEFAULT_CAMERA_ADJUSTMENTS)
  }

  const showControls = hovering && !busy && !choosingStrip
  const activeAdjDef = ADJ_DEFS.find((d) => d.key === selectedAdj) ?? ADJ_DEFS[0]
  const activeAdjVal = Number(settings[activeAdjDef.settingKey] ?? activeAdjDef.defaultVal)

  return (
    <div className="tab-mirror">
      <div
        className={`mirror-view ${settings.mirrorRingLight ? "ring" : ""}`}
        onMouseEnter={() => setHovering(true)}
        onMouseLeave={() => setHovering(false)}
      >
        {error ? (
          <div className="mirror-error">
            <CameraOff size={22} />
            <span>
              {error === "denied"
                ? "Camera access is off. Allow it in Windows Settings › Privacy & security › Camera."
                : "No camera found."}
            </span>
          </div>
        ) : (
          <>
            <video
              ref={videoRef}
              autoPlay
              muted
              playsInline
              style={{
                filter: buildCameraFilter(effect, adj),
                transform: `scaleX(${adj.mirrorFlipped ? -1 : 1}) scale(${adj.mirrorZoom})`,
              }}
            />
            {EFFECTS[effect]?.tint && (
              <div className="mirror-tint-overlay" style={{ background: EFFECTS[effect].tint }} />
            )}
            {adj.mirrorVignette > 0.01 && (
              <div
                className="mirror-vignette-overlay"
                style={{
                  background: `radial-gradient(circle, transparent 42%, rgba(0,0,0,${(adj.mirrorVignette * 0.72).toFixed(2)}) 100%)`,
                }}
              />
            )}
          </>
        )}

        {settings.mirrorGrid && <div className="mirror-grid" />}

        {filterBanner && !busy && (
          <div className="mirror-filter-banner" key={filterBanner}>
            <Sparkles size={11} />
            <span>{filterBanner}</span>
          </div>
        )}

        {countdown !== null && <div className="mirror-countdown" key={countdown}>{countdown}</div>}
        {flash && <div className="mirror-flash" />}

        {shotsTaken !== null && (
          <div className="mirror-shots">
            {Array.from({ length: settings.stripShots }, (_, i) => (
              <span key={i} className={i < shotsTaken ? "done" : ""} />
            ))}
          </div>
        )}

        {saved && (
          <div className="mirror-saved">
            <img src={saved} alt="" />
            <div>
              <b>Saved</b>
              <span>Downloads</span>
            </div>
          </div>
        )}

        {!error && (
          <div className={`mirror-right ${showControls ? "show" : ""}`}>
            <button
              className="mirror-shutter"
              onClick={takePhoto}
              title={settings.mirrorTimer > 0 ? `Take photo (${settings.mirrorTimer}s timer)` : "Take a photo"}
              aria-label="Take a photo"
            />
            <button className="mirror-booth-btn" onClick={() => setChoosingStrip(true)} title="Photobox" aria-label="Photobox">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="7" width="18" height="14" rx="2" />
                <path d="M7 3h10M5 5h14" />
                <circle cx="9" cy="12" r="1.5" />
                <path d="m21 17-5-5-8 9" />
              </svg>
            </button>
            <button
              className={`mirror-rail-pill ${settings.mirrorTimer > 0 ? "active-yellow" : ""}`}
              onClick={cycleTimer}
              title="Self-timer (Off / 3s / 5s)"
            >
              <Timer size={11} />
              <span>{settings.mirrorTimer > 0 ? `${settings.mirrorTimer}s` : "0s"}</span>
            </button>
            <button
              className={`mirror-rail-pill ${adj.mirrorZoom > 1.01 ? "active-cyan" : ""}`}
              onClick={cycleZoom}
              title="Camera Zoom (1.0x / 1.25x / 1.5x / 2.0x)"
            >
              <span>{adj.mirrorZoom.toFixed(adj.mirrorZoom === 1.25 ? 2 : 1)}x</span>
            </button>
          </div>
        )}

        {showAdjust && showControls && (
          <div className="mirror-adj-drawer">
            <div className="mirror-adj-pills">
              {ADJ_DEFS.map((d) => {
                const val = Number(settings[d.settingKey] ?? d.defaultVal)
                const modified = Math.abs(val - d.defaultVal) > 0.01
                return (
                  <button
                    key={d.key}
                    className={`mirror-adj-pill ${selectedAdj === d.key ? "active" : ""}`}
                    onClick={() => setSelectedAdj(d.key)}
                  >
                    <span>{d.label}</span>
                    {modified && <i className="mirror-adj-dot" />}
                  </button>
                )
              })}
              {hasCustomAdj && (
                <button className="mirror-adj-reset" onClick={resetAllAdj} title="Reset all adjustments">
                  <RotateCcw size={10} />
                  <span>Reset</span>
                </button>
              )}
            </div>
            <div className="mirror-adj-slider-row">
              <span className="mirror-adj-label">{activeAdjDef.label}</span>
              <input
                type="range"
                min={activeAdjDef.min}
                max={activeAdjDef.max}
                step={activeAdjDef.step}
                value={activeAdjVal}
                onChange={(e) => setSettings({ [activeAdjDef.settingKey]: parseFloat(e.target.value) })}
              />
              <span className="mirror-adj-val">{activeAdjDef.format(activeAdjVal)}</span>
              {Math.abs(activeAdjVal - activeAdjDef.defaultVal) > 0.01 && (
                <button
                  className="mirror-adj-single-reset"
                  onClick={() => setSettings({ [activeAdjDef.settingKey]: activeAdjDef.defaultVal })}
                  title={`Reset ${activeAdjDef.label}`}
                >
                  <RotateCcw size={10} />
                </button>
              )}
            </div>
          </div>
        )}

        <div className={`mirror-capsule ${showControls ? "show" : ""}`}>
          <div className="mirror-filter-strip">
            {(Object.keys(EFFECTS) as MirrorEffect[]).map((e) => (
              <button
                key={e}
                className={`mirror-filter-pill ${effect === e ? "active" : ""}`}
                onClick={() => setSettings({ mirrorEffect: e })}
                title={`${EFFECTS[e].name} (${EFFECTS[e].category})`}
              >
                <span className="mirror-swatch" style={{ background: EFFECTS[e].swatch }} />
                <span className="mirror-filter-pill-name">{EFFECTS[e].name}</span>
              </button>
            ))}
          </div>
          <span className="mirror-divider" />
          <button
            className={`mirror-cap-btn ${showAdjust || hasCustomAdj ? "on-pink" : ""}`}
            onClick={() => setShowAdjust((v) => !v)}
            title="TikTok Camera Adjustments (Glow, Brightness, Contrast, Warmth, Zoom)"
          >
            <SlidersHorizontal size={13} />
          </button>
          <button
            className={`mirror-cap-btn ${settings.mirrorRingLight ? "on-yellow" : ""}`}
            onClick={() => setSettings({ mirrorRingLight: !settings.mirrorRingLight })}
            title="Ring light"
          >
            {settings.mirrorRingLight ? <Lightbulb size={13} /> : <LightbulbOff size={13} />}
          </button>
          <button
            className={`mirror-cap-btn ${settings.mirrorGrid ? "on-yellow" : ""}`}
            onClick={() => setSettings({ mirrorGrid: !settings.mirrorGrid })}
            title="3×3 Composition Grid"
          >
            <Grid3x3 size={13} />
          </button>
          <button
            className={`mirror-cap-btn ${!adj.mirrorFlipped ? "on-cyan" : ""}`}
            onClick={() => setSettings({ mirrorFlipped: !adj.mirrorFlipped })}
            title={adj.mirrorFlipped ? "Mirrored (click for true view)" : "True view (un-mirrored)"}
          >
            <FlipHorizontal2 size={13} />
          </button>
          {cameras.length > 1 && (
            <button className="mirror-cap-btn" onClick={nextCamera} title="Switch camera">
              <SwitchCamera size={13} />
            </button>
          )}
          <button
            className={`mirror-cap-btn ${settings.mirrorPinned ? "on-yellow" : ""}`}
            onClick={() => setSettings({ mirrorPinned: !settings.mirrorPinned })}
            title={settings.mirrorPinned ? "Unpin (close when the cursor leaves)" : "Keep the notch open"}
          >
            {settings.mirrorPinned ? <Pin size={13} /> : <PinOff size={13} />}
          </button>
        </div>

        {choosingStrip && <StripPicker onStart={startPhotobox} onClose={() => setChoosingStrip(false)} />}
      </div>

      <ResizeHandle />
    </div>
  )
}

/** Pick a strip style, format, number of photos and caption right in the mirror, then start the photobox. */
function StripPicker({ onStart, onClose }: { onStart: () => void; onClose: () => void }) {
  const [settings, setSettings] = useSettings()
  const previews = useMiniPreviews(settings.stripShots, settings.stripFormat)
  return (
    <div className="strip-picker">
      <div className="strip-picker-top">
        <select
          className="strip-format"
          value={settings.stripFormat}
          onChange={(e) => setSettings({ stripFormat: e.target.value as StripFormat })}
          title="Size of the picture: a classic strip, or ready for a story or post"
        >
          {(Object.keys(STRIP_FORMATS) as StripFormat[]).map((f) => (
            <option key={f} value={f}>
              {STRIP_FORMATS[f].name}
            </option>
          ))}
        </select>
        <div className="strip-shots" title="Number of photos">
          {STRIP_SHOT_CHOICES.map((n) => (
            <button key={n} className={settings.stripShots === n ? "active" : ""} onClick={() => setSettings({ stripShots: n })}>
              {n}
            </button>
          ))}
        </div>
        <input
          className="strip-caption"
          placeholder="Your text"
          maxLength={40}
          value={settings.stripCaption}
          onChange={(e) => setSettings({ stripCaption: e.target.value })}
          onKeyDown={(e) => e.key === "Enter" && onStart()}
        />
        <span className="mirror-spacer" />
        <button className="mirror-cap-btn" onClick={onClose} title="Close">
          <X size={13} />
        </button>
      </div>
      <div className="strip-picker-row">
        <div className="strip-styles">
          {(Object.keys(STRIP_STYLES) as StripStyle[]).map((s) => (
            <button key={s} className={settings.photoboxStyle === s ? "active" : ""} onClick={() => setSettings({ photoboxStyle: s })}>
              {previews[s] ? (
                <img className="strip-thumb-img" src={previews[s]} alt="" />
              ) : (
                <span className="strip-thumb" style={{ background: `linear-gradient(${STRIP_STYLES[s].swatch.join(", ")})` }} />
              )}
              {STRIP_STYLES[s].name}
            </button>
          ))}
        </div>
        <button className="strip-start" onClick={onStart}>
          Start
        </button>
      </div>
    </div>
  )
}

/** Small previews of every style, rendered one per frame so opening the picker never stalls the camera. */
function useMiniPreviews(shots: number, format: StripFormat): Partial<Record<StripStyle, string>> {
  const [urls, setUrls] = useState<Partial<Record<StripStyle, string>>>({})
  const photos = useMemo(() => samplePhotos(), [])
  useEffect(() => {
    let cancelled = false
    const next: Partial<Record<StripStyle, string>> = {}
    const styles = Object.keys(STRIP_STYLES) as StripStyle[]
    const step = (i: number) => {
      if (cancelled || i >= styles.length) return
      const picks = Array.from({ length: shots }, (_, k) => photos[k % photos.length])
      const full = composeStrip(picks, styles[i], format, { songTitle: "Midnight Drive", artist: "The Placeholders" })
      // Downscale before encoding; full strips are 1200px wide.
      const small = document.createElement("canvas")
      small.width = 120
      small.height = Math.round((full.height / full.width) * 120)
      small.getContext("2d")!.drawImage(full, 0, 0, small.width, small.height)
      next[styles[i]] = small.toDataURL("image/jpeg", 0.8)
      setUrls({ ...next })
      requestAnimationFrame(() => step(i + 1))
    }
    stripFontsReady.then(() => step(0))
    return () => {
      cancelled = true
    }
  }, [shots, format, photos])
  return urls
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = "anonymous"
    img.onload = () => resolve(img)
    img.onerror = reject
    img.src = src
  })
}

/** Drag the bar under the mirror to make the notch taller; double-click toggles compact/tall. */
function ResizeHandle() {
  const [settings, setSettings] = useSettings()
  const onPointerDown = (e: React.PointerEvent) => {
    const startY = e.screenY
    const startH = settings.mirrorHeight
    const el = e.currentTarget as HTMLElement
    el.setPointerCapture(e.pointerId)
    const move = (ev: PointerEvent) => setSettings({ mirrorHeight: clampHeight(startH + ev.screenY - startY) })
    const up = () => {
      el.removeEventListener("pointermove", move)
      el.removeEventListener("pointerup", up)
    }
    el.addEventListener("pointermove", move)
    el.addEventListener("pointerup", up)
  }
  const toggle = () =>
    setSettings({
      mirrorHeight: settings.mirrorHeight > (MIRROR_MIN_HEIGHT + MIRROR_MAX_HEIGHT) / 2 ? MIRROR_MIN_HEIGHT : MIRROR_MAX_HEIGHT,
    })
  return (
    <div className="mirror-resize" onPointerDown={onPointerDown} onDoubleClick={toggle} title="Drag to resize · double-click to toggle">
      <span />
    </div>
  )
}

export const clampHeight = (h: number) => Math.round(Math.min(MIRROR_MAX_HEIGHT, Math.max(MIRROR_MIN_HEIGHT, h)))

function stamp() {
  return new Date().toISOString().slice(0, 19).replace("T", " at ").replace(/:/g, ".")
}
