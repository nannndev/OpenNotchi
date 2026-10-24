import { useEffect, useMemo, useState } from "react"
import {
  composeStrip,
  stripFontsReady,
  EFFECTS,
  samplePhotos,
  STRIP_FORMATS,
  STRIP_SHOT_CHOICES,
  STRIP_STYLES,
  type MirrorEffect,
  type StripFormat,
  type StripStyle,
} from "./photobox"
import { useSettings } from "./settings"

/** Settings › Mirror & Photobox, laid out like the macOS Mirror pane: strip previews first, then the mirror options. */
export function MirrorSettings() {
  const [settings, setSettings] = useSettings()
  const [cameras, setCameras] = useState<MediaDeviceInfo[]>([])
  const previews = useStripPreviews(settings.stripShots, settings.stripFormat, settings.stripCaption)

  useEffect(() => {
    // Labels are empty until camera access has been granted once (in the Mirror tab).
    navigator.mediaDevices
      ?.enumerateDevices()
      .then((all) => setCameras(all.filter((d) => d.kind === "videoinput")))
      .catch(() => {})
  }, [])

  const chosen = previews[settings.photoboxStyle]

  return (
    <div className="settings-section">
      <h2 className="section-title">Photobox</h2>
      <p className="section-desc">Pick the frame for photobox strips. Previews use sample photos.</p>

      <div className="strip-gallery">
        {(Object.keys(STRIP_STYLES) as StripStyle[]).map((s) => (
          <button
            key={s}
            className={`strip-gallery-item ${settings.photoboxStyle === s ? "active" : ""}`}
            onClick={() => setSettings({ photoboxStyle: s })}
          >
            {previews[s] ? (
              <img src={previews[s]} alt="" />
            ) : (
              <span className="strip-gallery-swatch" style={{ background: `linear-gradient(${STRIP_STYLES[s].swatch.join(", ")})` }} />
            )}
            <span>{STRIP_STYLES[s].name}</span>
          </button>
        ))}
      </div>

      {chosen && (
        <div className="strip-closeup">
          <img className="strip-closeup-full" src={chosen} alt="" />
          <div className="strip-closeup-side">
            <div className="toggle-title">{STRIP_STYLES[settings.photoboxStyle].name}</div>
            {/* The bottom of the strip, large enough to read the text. */}
            <div className="strip-closeup-footer" style={{ backgroundImage: `url(${chosen})` }} />
            <div className="toggle-desc">
              Pictures are 1200 px wide; Story, Post and Square are sized for Instagram.
            </div>
          </div>
        </div>
      )}

      <div className="toggle-list" style={{ marginTop: 16 }}>
        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Format</div>
          </div>
          <select
            className="settings-select"
            value={settings.stripFormat}
            onChange={(e) => setSettings({ stripFormat: e.target.value as StripFormat })}
          >
            {(Object.keys(STRIP_FORMATS) as StripFormat[]).map((f) => (
              <option key={f} value={f}>
                {STRIP_FORMATS[f].name}
              </option>
            ))}
          </select>
        </div>

        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Photos</div>
          </div>
          <div className="segmented">
            {STRIP_SHOT_CHOICES.map((n) => (
              <button key={n} className={settings.stripShots === n ? "active" : ""} onClick={() => setSettings({ stripShots: n })}>
                {n}
              </button>
            ))}
          </div>
        </div>

        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Text on the strip</div>
          </div>
          <input
            className="settings-input"
            placeholder="Style's own title"
            maxLength={40}
            value={settings.stripCaption}
            onChange={(e) => setSettings({ stripCaption: e.target.value })}
          />
        </div>
      </div>
      <p className="section-desc" style={{ marginTop: 8 }}>
        Take a strip from the Mirror tab with the photobox button. Strips are saved to your Downloads folder.
      </p>

      <h2 className="section-title" style={{ marginTop: 28 }}>Mirror</h2>
      <div className="toggle-list">
        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Camera Device</div>
          </div>
          <select
            className="settings-select"
            value={settings.mirrorCameraId}
            onChange={(e) => setSettings({ mirrorCameraId: e.target.value })}
          >
            <option value="">Automatic (Default)</option>
            {cameras.map((c, i) => (
              <option key={c.deviceId || i} value={c.deviceId}>
                {c.label || `Camera ${i + 1}`}
              </option>
            ))}
          </select>
        </div>

        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Look</div>
          </div>
          <select
            className="settings-select"
            value={settings.mirrorEffect}
            onChange={(e) => setSettings({ mirrorEffect: e.target.value as MirrorEffect })}
          >
            {(Object.keys(EFFECTS) as MirrorEffect[]).map((e) => (
              <option key={e} value={e}>
                {EFFECTS[e].name}
              </option>
            ))}
          </select>
        </div>

        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Keep the notch open while using the Mirror</div>
          </div>
          <input
            type="checkbox"
            className="switch"
            checked={settings.mirrorPinned}
            onChange={(e) => setSettings({ mirrorPinned: e.target.checked })}
          />
        </div>

        <div className="toggle-row">
          <div className="toggle-info">
            <div className="toggle-title">Ring light</div>
          </div>
          <input
            type="checkbox"
            className="switch"
            checked={settings.mirrorRingLight}
            onChange={(e) => setSettings({ mirrorRingLight: e.target.checked })}
          />
        </div>
      </div>
      <p className="section-desc" style={{ marginTop: 8 }}>
        Nothing leaves your PC, and the camera only runs while the Mirror tab is open.
      </p>
    </div>
  )
}

/** Renders every style once with sample photos; re-renders when the shot count, format or caption change. */
function useStripPreviews(shots: number, format: StripFormat, caption: string): Partial<Record<StripStyle, string>> {
  const [urls, setUrls] = useState<Partial<Record<StripStyle, string>>>({})
  const photos = useMemo(() => samplePhotos(), [])

  useEffect(() => {
    let cancelled = false
    const next: Partial<Record<StripStyle, string>> = {}
    const styles = Object.keys(STRIP_STYLES) as StripStyle[]
    // One style per frame so the settings window stays responsive while 19 strips render.
    const step = (i: number) => {
      if (cancelled || i >= styles.length) return
      const picks = Array.from({ length: shots }, (_, k) => photos[k % photos.length])
      const canvas = composeStrip(picks, styles[i], format, {
        caption: caption || undefined,
        songTitle: "Midnight Drive",
        artist: "The Placeholders",
      })
      const url = canvas.toDataURL("image/jpeg", 0.8)
      next[styles[i]] = url
      setUrls({ ...next })
      requestAnimationFrame(() => step(i + 1))
    }
    stripFontsReady.then(() => step(0))
    return () => {
      cancelled = true
    }
  }, [shots, format, caption, photos])

  return urls
}
