import { Camera, CameraOff, Images } from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { captureFrame, composeStrip, EFFECTS, savePng, STRIP_STYLES, type MirrorEffect, type StripStyle } from "../photobox"
import { useSettings } from "../settings"

const STRIP_SHOTS = 4

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

export function MirrorTab({ onBusy }: { onBusy: (busy: boolean) => void }) {
  const [settings, setSettings] = useSettings()
  const videoRef = useRef<HTMLVideoElement | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [countdown, setCountdown] = useState<number | null>(null)
  const [flash, setFlash] = useState(false)
  const [shotsTaken, setShotsTaken] = useState<number | null>(null)
  const [toast, setToast] = useState<string | null>(null)
  const busy = countdown !== null || shotsTaken !== null

  // The camera only runs while this tab is mounted, so the light goes off when the pill closes.
  useEffect(() => {
    let stream: MediaStream | null = null
    let cancelled = false
    navigator.mediaDevices
      ?.getUserMedia({ video: { width: 1280, height: 720 }, audio: false })
      .then((s) => {
        if (cancelled) return s.getTracks().forEach((t) => t.stop())
        stream = s
        if (videoRef.current) videoRef.current.srcObject = s
      })
      .catch((e: Error) => setError(e.name === "NotAllowedError" ? "denied" : "unavailable"))
    return () => {
      cancelled = true
      stream?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  // Keeps the pill open while counting down or shooting a strip.
  useEffect(() => onBusy(busy), [busy])
  useEffect(() => () => onBusy(false), [])

  const effect = settings.mirrorEffect
  const strip = settings.photoboxStyle

  const showToast = (text: string) => {
    setToast(text)
    setTimeout(() => setToast(null), 2200)
  }

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

  const takePhoto = async () => {
    if (busy || !videoRef.current?.videoWidth) return
    const shot = await shoot(3)
    await savePng(shot, `OpenNotchi Photo ${stamp()}`).catch(() => {})
    showToast("Photo saved to Downloads")
  }

  const takeStrip = async () => {
    if (busy || !videoRef.current?.videoWidth) return
    const shots: HTMLCanvasElement[] = []
    setShotsTaken(0)
    try {
      for (let i = 0; i < STRIP_SHOTS; i++) {
        shots.push(await shoot(i === 0 ? 3 : 2))
        setShotsTaken(i + 1)
        await sleep(350)
      }
      await savePng(composeStrip(shots, strip, "OpenNotchi"), `OpenNotchi Photobox ${stamp()}`)
      showToast("Photobox strip saved to Downloads")
    } catch {
      showToast("Couldn't save the strip")
    } finally {
      setShotsTaken(null)
    }
  }

  return (
    <div className="tab-mirror">
      <div className="mirror-view">
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
        {countdown !== null && <div className="mirror-countdown" key={countdown}>{countdown}</div>}
        {flash && <div className="mirror-flash" />}
        {shotsTaken !== null && (
          <div className="mirror-shots">
            {Array.from({ length: STRIP_SHOTS }, (_, i) => (
              <span key={i} className={i < shotsTaken ? "done" : ""} />
            ))}
          </div>
        )}
        {toast && <div className="mirror-toast">{toast}</div>}
      </div>

      <div className="mirror-side">
        <div className="mirror-chips">
          {(Object.keys(EFFECTS) as MirrorEffect[]).map((e) => (
            <button
              key={e}
              className={`deck-chip ${effect === e ? "active" : ""}`}
              onClick={() => setSettings({ mirrorEffect: e })}
              disabled={busy}
            >
              {EFFECTS[e].name}
            </button>
          ))}
        </div>
        <select
          className="mirror-select"
          value={strip}
          onChange={(e) => setSettings({ photoboxStyle: e.target.value as StripStyle })}
          disabled={busy}
          title="Photobox strip style"
        >
          {(Object.keys(STRIP_STYLES) as StripStyle[]).map((s) => (
            <option key={s} value={s}>
              {STRIP_STYLES[s].name} strip
            </option>
          ))}
        </select>
        <div className="mirror-actions">
          <button className="timer-action-btn primary" onClick={takePhoto} disabled={busy || !!error}>
            <Camera size={13} />
            <span>Photo</span>
          </button>
          <button className="timer-action-btn secondary" onClick={takeStrip} disabled={busy || !!error}>
            <Images size={13} />
            <span>Photobox</span>
          </button>
        </div>
      </div>
    </div>
  )
}

function stamp() {
  return new Date().toISOString().slice(0, 19).replace("T", " at ").replace(/:/g, ".")
}
