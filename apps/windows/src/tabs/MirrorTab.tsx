import { CameraOff, Grid3x3, Lightbulb, LightbulbOff, Pin, PinOff, SwitchCamera, X } from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import { positionAt, useNowPlaying } from "../media"
import {
  captureFrame,
  composeStrip,
  EFFECTS,
  samplePhotos,
  savePng,
  STRIP_FORMATS,
  STRIP_SHOT_CHOICES,
  STRIP_STYLES,
  stripFontsReady,
  type MirrorEffect,
  type StripFormat,
  type StripStyle,
} from "../photobox"
import { MIRROR_MAX_HEIGHT, MIRROR_MIN_HEIGHT, useSettings } from "../settings"

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

/**
 * Same layout as the macOS mirror: the camera fills the tab, and controls only appear while the pointer
 * is over it (shutter + photobox on the right, a capsule of looks and toggles along the bottom).
 */
export function MirrorTab({ onBusy }: { onBusy: (busy: boolean) => void }) {
  const [settings, setSettings] = useSettings()
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const [cameras, setCameras] = useState<MediaDeviceInfo[]>([])
  const [error, setError] = useState<string | null>(null)
  const [hovering, setHovering] = useState(false)
  const [choosingStrip, setChoosingStrip] = useState(false)
  const [countdown, setCountdown] = useState<number | null>(null)
  const [flash, setFlash] = useState(false)
  const [shotsTaken, setShotsTaken] = useState<number | null>(null)
  const [saved, setSaved] = useState<string | null>(null)
  const np = useNowPlaying()
  const busy = countdown !== null || shotsTaken !== null

  const effect = settings.mirrorEffect

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
    return captureFrame(videoRef.current!, effect)
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
    await keep(await shoot(3), `OpenNotchi Photo ${stamp()}`).catch(() => {})
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

  const showControls = hovering && !busy && !choosingStrip

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
          <video ref={videoRef} autoPlay muted playsInline style={{ filter: EFFECTS[effect].filter }} />
        )}

        {settings.mirrorGrid && <div className="mirror-grid" />}
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
            <button className="mirror-shutter" onClick={takePhoto} title="Take a photo" aria-label="Take a photo" />
            <button className="mirror-booth-btn" onClick={() => setChoosingStrip(true)} title="Photobox" aria-label="Photobox">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="3" y="7" width="18" height="14" rx="2" />
                <path d="M7 3h10M5 5h14" />
                <circle cx="9" cy="12" r="1.5" />
                <path d="m21 17-5-5-8 9" />
              </svg>
            </button>
          </div>
        )}

        <div className={`mirror-capsule ${showControls ? "show" : ""}`}>
          {(Object.keys(EFFECTS) as MirrorEffect[]).map((e) => (
            <button
              key={e}
              className={`mirror-swatch ${effect === e ? "active" : ""}`}
              style={{ background: EFFECTS[e].swatch }}
              onClick={() => setSettings({ mirrorEffect: e })}
              title={EFFECTS[e].name}
            />
          ))}
          <span className="mirror-effect-name">{EFFECTS[effect].name}</span>
          <span className="mirror-divider" />
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
            title="Grid"
          >
            <Grid3x3 size={13} />
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
