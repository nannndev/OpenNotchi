import { getCurrentWindow } from "@tauri-apps/api/window"
import {
  Check,
  Copy,
  Download,
  Image as ImageIcon,
  Music2,
  Sparkles,
  X,
} from "lucide-react"
import { useEffect, useMemo, useState } from "react"
import { useLyrics, useNowPlaying } from "./media"
import { useAccent } from "./palette"
import { resolveAccentColor, useSettings } from "./settings"
import {
  copyCardToClipboard,
  downloadCardImage,
  exportCardToBlob,
  type LyricCardStyle,
} from "./shareCardRenderer"

const STYLES: { id: LyricCardStyle; name: string; desc: string; icon: string }[] = [
  { id: "aura", name: "Aura", desc: "Blurred ambient glow", icon: "✨" },
  { id: "player", name: "Player", desc: "Now Playing card", icon: "🎵" },
  { id: "polaroid", name: "Polaroid", desc: "Vintage retro frame", icon: "📷" },
  { id: "solid", name: "Solid", desc: "Vibrant album color", icon: "🎨" },
  { id: "paper", name: "Paper", desc: "Editorial serif parchment", icon: "📜" },
]

export function LyricsShareWindow() {
  const np = useNowPlaying()
  const lyrics = useLyrics(np)
  const rawAccent = useAccent(np?.artwork)
  const [settings] = useSettings()

  const resolvedAccent = resolveAccentColor(
    settings.accentChoice,
    rawAccent,
    settings.customAccent,
  )

  const [style, setStyle] = useState<LyricCardStyle>("aura")
  const [selectedIndices, setSelectedIndices] = useState<number[]>([0, 1])
  const [toast, setToast] = useState<string | null>(null)
  const [isExporting, setIsExporting] = useState(false)

  // Extract clean lines
  const lines = useMemo(() => {
    if (lyrics && lyrics !== "loading" && lyrics.synced.length > 0) {
      return lyrics.synced.map((l) => l.text.trim()).filter(Boolean)
    }
    if (lyrics && lyrics !== "loading" && lyrics.plain) {
      return lyrics.plain.split("\n").map((l) => l.trim()).filter(Boolean)
    }
    // Fallback sample lines if nothing playing
    return [
      "Tell me why",
      "Ain't nothin' but a heartache",
      "Tell me why",
      "Ain't nothin' but a mistake",
      "I never wanna hear you say",
      "I want it that way",
    ]
  }, [lyrics])

  const times = useMemo(() => {
    if (lyrics && lyrics !== "loading" && lyrics.synced.length > 0) {
      return lyrics.synced.map((l) => l.time)
    }
    return [0, 4, 8, 12, 16, 20]
  }, [lyrics])

  // Select a line or expand selection (max 5 lines)
  const handleLineClick = (idx: number) => {
    if (selectedIndices.length === 0) {
      setSelectedIndices([idx])
      return
    }

    const first = selectedIndices[0]
    const last = selectedIndices[selectedIndices.length - 1]

    if (idx < first) {
      // New starting point
      setSelectedIndices([idx])
    } else if (idx === first && selectedIndices.length === 1) {
      // Toggle off or keep 1
      return
    } else {
      // Expand range from `first` to `idx`, up to 5 lines
      const end = Math.min(idx, first + 4)
      const range: number[] = []
      for (let i = first; i <= end; i++) {
        range.push(i)
      }
      setSelectedIndices(range)
    }
  }

  const selectedLines = useMemo(() => {
    return selectedIndices.map((i) => lines[i]).filter(Boolean)
  }, [selectedIndices, lines])

  const firstSelectedTime = times[selectedIndices[0]] ?? 0

  const showToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(null), 2500)
  }

  const handleCopy = async () => {
    if (selectedLines.length === 0) return
    setIsExporting(true)
    try {
      const blob = await exportCardToBlob({
        title: np?.title || "Shape of My Heart",
        artist: np?.artist || "Backstreet Boys",
        album: np?.album,
        artworkUrl: np?.artwork,
        accentColor: resolvedAccent,
        lines: selectedLines,
        time: firstSelectedTime,
        duration: np?.duration || 230,
        style,
      })
      await copyCardToClipboard(blob)
      showToast("Copied 1080×1350 PNG to clipboard!")
    } catch (e) {
      console.error(e)
      showToast("Failed to copy image")
    } finally {
      setIsExporting(false)
    }
  }

  const handleDownload = async () => {
    if (selectedLines.length === 0) return
    setIsExporting(true)
    try {
      const title = np?.title || "Song"
      const artist = np?.artist || "Artist"
      const blob = await exportCardToBlob({
        title,
        artist,
        album: np?.album,
        artworkUrl: np?.artwork,
        accentColor: resolvedAccent,
        lines: selectedLines,
        time: firstSelectedTime,
        duration: np?.duration || 230,
        style,
      })
      downloadCardImage(blob, `${artist} - ${title} (OpenNotchi).png`)
      showToast("Card image saved!")
    } catch (e) {
      console.error(e)
      showToast("Failed to save image")
    } finally {
      setIsExporting(false)
    }
  }

  const handleClose = () => {
    getCurrentWindow().hide()
  }

  // Keyboard shortcut ESC to close
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") handleClose()
    }
    window.addEventListener("keydown", onKey)
    return () => window.removeEventListener("keydown", onKey)
  }, [])

  return (
    <div className="share-window">
      {/* Top Titlebar */}
      <header className="share-header">
        <div className="share-title-meta">
          <Sparkles size={16} className="share-sparkle" />
          <span className="share-title-text">Share Lyric Card</span>
          <span className="share-aspect-tag">1080 × 1350</span>
        </div>
        <button
          className="share-close-btn"
          onClick={handleClose}
          aria-label="Close"
          title="Close (Esc)"
        >
          <X size={16} />
        </button>
      </header>

      {/* Main Container: Left Line Picker, Right Card Preview */}
      <div className="share-body">
        {/* Left Column: Song Info & Line Selector */}
        <div className="share-picker-panel">
          <div className="share-track-card">
            <div className="share-track-art">
              {np?.artwork ? (
                <img src={np.artwork} alt="" />
              ) : (
                <Music2 size={24} className="muted" />
              )}
            </div>
            <div className="share-track-info">
              <div className="share-track-title">{np?.title || "Shape of My Heart"}</div>
              <div className="share-track-artist">{np?.artist || "Backstreet Boys"}</div>
            </div>
          </div>

          <div className="share-picker-heading">
            <span>Select 1–5 consecutive lines</span>
            <span className="share-count-badge">
              {selectedLines.length} / 5
            </span>
          </div>

          <div className="share-lines-list">
            {lines.map((text, idx) => {
              const isSelected = selectedIndices.includes(idx)
              const isFirst = selectedIndices[0] === idx
              const isLast = selectedIndices[selectedIndices.length - 1] === idx

              return (
                <button
                  key={idx}
                  className={`share-line-item ${isSelected ? "selected" : ""} ${
                    isFirst ? "first" : ""
                  } ${isLast ? "last" : ""}`}
                  onClick={() => handleLineClick(idx)}
                >
                  <span className="line-check">
                    {isSelected ? <Check size={12} /> : idx + 1}
                  </span>
                  <span className="line-text">{text}</span>
                </button>
              )
            })}
          </div>
        </div>

        {/* Right Column: Style Selector, Live Card Preview, Actions */}
        <div className="share-preview-panel">
          {/* Style Selector Tabs */}
          <div className="share-style-tabs">
            {STYLES.map((s) => (
              <button
                key={s.id}
                className={`share-style-tab ${style === s.id ? "active" : ""}`}
                onClick={() => setStyle(s.id)}
              >
                <span className="style-icon">{s.icon}</span>
                <span className="style-name">{s.name}</span>
              </button>
            ))}
          </div>

          {/* Live Card Preview (Scaled 4:5 Card) */}
          <div className="share-card-wrapper">
            <LiveCardPreview
              style={style}
              title={np?.title || "Shape of My Heart"}
              artist={np?.artist || "Backstreet Boys"}
              artwork={np?.artwork ?? null}
              accent={resolvedAccent}
              lines={selectedLines}
              time={firstSelectedTime}
              duration={np?.duration || 230}
            />

            {toast && <div className="share-toast">{toast}</div>}
          </div>

          {/* Action Buttons */}
          <div className="share-actions-bar">
            <button
              className="share-btn primary"
              onClick={handleCopy}
              disabled={isExporting || selectedLines.length === 0}
            >
              <Copy size={15} />
              <span>{isExporting ? "Rendering..." : "Copy Image"}</span>
            </button>
            <button
              className="share-btn secondary"
              onClick={handleDownload}
              disabled={isExporting || selectedLines.length === 0}
            >
              <Download size={15} />
              <span>Save Image</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

/* ==========================================================================
   LIVE CARD PREVIEW COMPONENT
   ========================================================================== */

interface LiveCardProps {
  style: LyricCardStyle
  title: string
  artist: string
  artwork: string | null
  accent: string
  lines: string[]
  time: number
  duration: number
}

function LiveCardPreview({
  style,
  title,
  artist,
  artwork,
  accent,
  lines,
  time,
  duration,
}: LiveCardProps) {
  const progressPercent = duration > 0 ? (time / duration) * 100 : 35

  return (
    <div className={`live-card live-card-${style}`} style={{ ["--card-accent" as string]: accent }}>
      {/* Aura style background */}
      {style === "aura" && (
        <div className="live-aura-bg">
          {artwork && <div className="live-aura-art" style={{ backgroundImage: `url(${artwork})` }} />}
          <div className="live-aura-glow" style={{ background: `radial-gradient(circle at 50% 60%, ${accent}66 0%, transparent 75%)` }} />
        </div>
      )}

      {/* Player style background */}
      {style === "player" && (
        <div className="live-player-bg">
          {artwork && <div className="live-player-blur" style={{ backgroundImage: `url(${artwork})` }} />}
          <div className="live-player-glow" style={{ background: `radial-gradient(circle at 50% 35%, ${accent}33 0%, transparent 70%)` }} />
        </div>
      )}

      {/* Solid style background */}
      {style === "solid" && <div className="live-solid-bg" style={{ backgroundColor: accent }} />}

      {/* Content Layouts */}
      {style === "player" ? (
        <div className="live-player-layout">
          <div className="live-player-cover">
            {artwork ? <img src={artwork} alt="" /> : <Music2 size={36} />}
          </div>
          <div className="live-player-title">{title}</div>
          <div className="live-player-artist">{artist}</div>

          <div className="live-player-lyrics">
            {lines.map((l, i) => (
              <div key={i} className="live-player-line">{l}</div>
            ))}
          </div>

          <div className="live-player-controls">
            <div className="live-progress-bar">
              <div className="live-progress-fill" style={{ width: `${progressPercent}%` }} />
            </div>
            <div className="live-times">
              <span>{Math.floor(time / 60)}:{String(Math.floor(time % 60)).padStart(2, "0")}</span>
              <span>-{Math.floor(Math.max(0, duration - time) / 60)}:{String(Math.floor(Math.max(0, duration - time) % 60)).padStart(2, "0")}</span>
            </div>
          </div>
        </div>
      ) : style === "polaroid" ? (
        <div className="live-polaroid-frame">
          <div className="live-polaroid-photo">
            {artwork ? <img src={artwork} alt="" /> : <div className="photo-placeholder" />}
            <span className="live-photo-tag">{title.toUpperCase()}</span>
          </div>
          <div className="live-polaroid-lyrics">
            {lines.slice(0, 4).map((l, i) => (
              <div key={i} className="live-polaroid-line">{l}</div>
            ))}
            <div className="live-polaroid-artist">— {artist}</div>
          </div>
        </div>
      ) : (
        <div className="live-standard-layout">
          {/* Header */}
          <div className="live-card-header">
            <div className="live-header-art">
              {artwork ? <img src={artwork} alt="" /> : <Music2 size={16} />}
            </div>
            <div className="live-header-text">
              <div className="live-header-title">{title}</div>
              <div className="live-header-artist">{artist}</div>
            </div>
          </div>

          {/* Paper style giant quote */}
          {style === "paper" && <span className="live-paper-quote">“</span>}

          {/* Lyrics Block */}
          <div className="live-card-lyrics">
            {lines.map((l, i) => (
              <div key={i} className="live-card-line">{l}</div>
            ))}
          </div>

          {/* Footer Branding */}
          <div className="live-card-footer">
            <span>❝ OpenNotchi</span>
          </div>
        </div>
      )}
    </div>
  )
}
