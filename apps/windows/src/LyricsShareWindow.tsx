import { getCurrentWindow } from "@tauri-apps/api/window"
import {
  Camera,
  Check,
  Copy,
  Disc,
  Download,
  FileText,
  Film,
  Image as ImageIcon,
  Layers,
  Music2,
  Pause,
  Play,
  PlayCircle,
  Radio,
  Receipt,
  RotateCcw,
  Share2,
  Sliders,
  ZoomIn,
  Sparkles,
  Square,
  Upload,
  Video,
  X,
} from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import { currentIndex, getNextLyricSelection, makeRange } from "./lyrics"
import { positionAt, useLyrics, useNowPlaying } from "./media"
import { useAccent } from "./palette"
import { resolveAccentColor, useSettings } from "./settings"
import {
  copyCardToClipboard,
  downloadCardImage,
  downloadVideo,
  exportCardToBlob,
  exportVideo,
  LYRIC_FONTS,
  type LyricAlign,
  type LyricFont,
  formatTime,
  formatTimecode,
  getCanvasDimensions,
  isLightColor,
  type CardAspectRatio,
  type LyricCardStyle,
} from "./shareCardRenderer"

interface StyleMeta {
  id: LyricCardStyle
  name: string
  desc: string
  icon: typeof Sparkles
}

const STYLES: StyleMeta[] = [
  { id: "aura", name: "Aura", desc: "Blurred ambient glow", icon: Sparkles },
  { id: "player", name: "Player", desc: "Now Playing card", icon: PlayCircle },
  { id: "vhs", name: "VHS 90s", desc: "Camcorder retro vibes", icon: Video },
  { id: "cassette", name: "Cassette", desc: "Vintage cassette tape", icon: Radio },
  { id: "vinyl", name: "Vinyl", desc: "Spinning record album", icon: Disc },
  { id: "glass", name: "Glass", desc: "Frosted glassmorphism", icon: Layers },
  { id: "polaroid", name: "Polaroid", desc: "Vintage retro frame", icon: Camera },
  { id: "paper", name: "Paper", desc: "Editorial serif parchment", icon: FileText },
  { id: "receipt", name: "Receipt", desc: "Archive printed receipt", icon: Receipt },
  { id: "solid", name: "Solid", desc: "Vibrant album color", icon: Square },
]

const ASPECT_RATIOS: { id: CardAspectRatio; label: string; dims: string }[] = [
  { id: "portrait", label: "4:5 Post", dims: "1080 × 1350" },
  { id: "story", label: "9:16 Story", dims: "1080 × 1920" },
  { id: "square", label: "1:1 Square", dims: "1080 × 1080" },
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

  // Studio Mode & Aspect Ratio
  const [mode, setMode] = useState<"photo" | "video">("photo")
  const [aspectRatio, setAspectRatio] = useState<CardAspectRatio>("portrait")
  const [style, setStyle] = useState<LyricCardStyle>("aura")
  const [selectedIndices, setSelectedIndices] = useState<number[]>([0, 1])

  // Custom Cover & Backgrounds
  const [customCover, setCustomCover] = useState<string | null>(null)
  const [customBackdrop, setCustomBackdrop] = useState<string | null>(null)
  const [backdropBlur, setBackdropBlur] = useState<number>(14)
  const [backdropZoom, setBackdropZoom] = useState(1)
  const [customVideo, setCustomVideo] = useState<string | null>(null)
  const [musicUrl, setMusicUrl] = useState<string | null>(null)
  const [lyricFont, setLyricFont] = useState<LyricFont>("auto")
  const [fontScale, setFontScale] = useState(1)
  const [textAlign, setTextAlign] = useState<LyricAlign>("auto")
  const textOpts = { backdropZoom, lyricFont, fontScale, textAlign }
  const [showTranslation, setShowTranslation] = useState(false)

  // Video Mode Playback & Timeline
  const [isPlaying, setIsPlaying] = useState(true)
  const [previewElapsed, setPreviewElapsed] = useState(0)
  const [duration, setDuration] = useState(15)

  // Export State
  const [toast, setToast] = useState<string | null>(null)
  const [isExporting, setIsExporting] = useState(false)
  const [renderProgress, setRenderProgress] = useState(0)

  const listRef = useRef<HTMLDivElement | null>(null)
  const coverInputRef = useRef<HTMLInputElement | null>(null)
  const backdropInputRef = useRef<HTMLInputElement | null>(null)
  const videoInputRef = useRef<HTMLInputElement | null>(null)
  const musicInputRef = useRef<HTMLInputElement | null>(null)

  // Effective artwork: custom cover overrides track artwork
  const activeArtwork = customCover || np?.artwork || null

  // Extract clean lines
  const lines = useMemo(() => {
    if (lyrics && lyrics !== "loading" && lyrics.synced.length > 0) {
      return lyrics.synced.map((l) => l.text.trim()).filter(Boolean)
    }
    if (lyrics && lyrics !== "loading" && lyrics.plain) {
      return lyrics.plain.split("\n").map((l) => l.trim()).filter(Boolean)
    }
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

  // Pre-select current playing lyric on initial load
  const [hasInitializedLyrics, setHasInitializedLyrics] = useState(false)
  useEffect(() => {
    if (lyrics && lyrics !== "loading" && np && !hasInitializedLyrics) {
      if (lyrics.synced.length > 0) {
        const idx = currentIndex(lyrics.synced, positionAt(np))
        if (idx !== null && idx >= 0 && idx < lyrics.synced.length) {
          const end = Math.min(lyrics.synced.length - 1, idx + 1)
          setSelectedIndices(makeRange(idx, end))
          setHasInitializedLyrics(true)
          return
        }
      }
      setHasInitializedLyrics(true)
    }
  }, [lyrics, np, hasInitializedLyrics])

  // Auto duration calculation based on selected lines
  const autoDuration = useMemo(() => {
    if (selectedIndices.length === 0) return 15
    const startIdx = selectedIndices[0]
    const endIdx = selectedIndices[selectedIndices.length - 1]
    const startTime = times[startIdx]
    const endTime = times[endIdx]
    if (typeof startTime === "number" && typeof endTime === "number" && endTime >= startTime) {
      return Math.max(5, Math.min(30, Math.round(endTime - startTime + 3.5)))
    }
    return 15
  }, [selectedIndices, times])

  // Select line with smart consecutive selection (up to 8 lines like macOS)
  const handleLineClick = (idx: number) => {
    const next = getNextLyricSelection(selectedIndices, idx, 8)
    setSelectedIndices(next)
    if (next.length > 0) {
      const startIdx = next[0]
      const endIdx = next[next.length - 1]
      const startTime = times[startIdx]
      const endTime = times[endIdx]
      if (typeof startTime === "number" && typeof endTime === "number" && endTime >= startTime) {
        const autoD = Math.max(5, Math.min(30, Math.round(endTime - startTime + 3.5)))
        setDuration(autoD)
        if (previewElapsed > autoD) setPreviewElapsed(0)
      }
    }
  }

  // Auto-scroll list when jumping or selecting
  useEffect(() => {
    if (selectedIndices.length > 0 && listRef.current) {
      const firstIdx = selectedIndices[0]
      const el = listRef.current.querySelector<HTMLElement>(`[data-line-idx="${firstIdx}"]`)
      if (el) {
        el.scrollIntoView({ block: "nearest", behavior: "smooth" })
      }
    }
  }, [selectedIndices[0]])

  const selectedLines = useMemo(() => {
    return selectedIndices.map((i) => lines[i]).filter(Boolean)
  }, [selectedIndices, lines])

  const selectedTimes = useMemo(() => {
    return selectedIndices.map((i) => times[i] ?? 0)
  }, [selectedIndices, times])

  const firstSelectedTime = selectedTimes[0] ?? 0

  // 30fps animation loop for Video mode
  useEffect(() => {
    if (mode !== "video" || !isPlaying || isExporting) return
    const interval = setInterval(() => {
      setPreviewElapsed((prev) => {
        const next = prev + 1 / 30
        return next >= duration ? 0 : next
      })
    }, 1000 / 30)
    return () => clearInterval(interval)
  }, [mode, isPlaying, duration, isExporting])

  // Calculate current active karaoke line index in Video mode
  const activeLineIndex = useMemo(() => {
    if (mode !== "video") return null
    if (selectedIndices.length === 0) return null
    const startTime = selectedTimes[0] ?? 0
    const currentSongTime = startTime + previewElapsed
    let best = 0
    let foundAny = false
    for (let i = 0; i < selectedTimes.length; i++) {
      if (typeof selectedTimes[i] === "number") {
        foundAny = true
        if (selectedTimes[i] <= currentSongTime) {
          best = i
        }
      }
    }
    if (!foundAny && duration > 0) {
      const progress = Math.min(Math.max(previewElapsed / duration, 0), 0.999)
      best = Math.floor(progress * selectedIndices.length)
    }
    return best
  }, [mode, selectedIndices, selectedTimes, previewElapsed, duration])

  const showToast = (msg: string) => {
    setToast(msg)
    setTimeout(() => setToast(null), 2500)
  }

  // Image Upload Handlers
  const handleCoverUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = () => {
        setCustomCover(reader.result as string)
        showToast("Custom cover attached!")
      }
      reader.readAsDataURL(file)
    }
  }

  const handleBackdropUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      const reader = new FileReader()
      reader.onload = () => {
        setCustomBackdrop(reader.result as string)
        showToast("Custom background attached!")
      }
      reader.readAsDataURL(file)
    }
  }

  const handleVideoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (customVideo) URL.revokeObjectURL(customVideo)
      setCustomVideo(URL.createObjectURL(file))
      showToast("Video background attached!")
    }
  }

  const handleMusicUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (musicUrl) URL.revokeObjectURL(musicUrl)
      setMusicUrl(URL.createObjectURL(file))
      showToast("Music attached!")
    }
  }

  // Export Actions
  const handleCopy = async () => {
    if (selectedLines.length === 0) return
    setIsExporting(true)
    try {
      const blob = await exportCardToBlob({
        title: np?.title || "Shape of My Heart",
        artist: np?.artist || "Backstreet Boys",
        album: np?.album,
        artworkUrl: activeArtwork,
        accentColor: resolvedAccent,
        lines: selectedLines,
        times: selectedTimes,
        time: firstSelectedTime,
        duration: np?.duration || 230,
        style,
        aspectRatio,
        backdropUrl: customBackdrop,
        backdropBlur,
        ...textOpts,
        showTranslation,
      })
      await copyCardToClipboard(blob)
      showToast("Copied high-res image to clipboard!")
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
        artworkUrl: activeArtwork,
        accentColor: resolvedAccent,
        lines: selectedLines,
        times: selectedTimes,
        time: firstSelectedTime,
        duration: np?.duration || 230,
        style,
        aspectRatio,
        backdropUrl: customBackdrop,
        backdropBlur,
        ...textOpts,
        showTranslation,
      })
      downloadCardImage(blob, `${artist} - ${title} (${aspectRatio}).png`)
      showToast("Card image saved!")
    } catch (e) {
      console.error(e)
      showToast("Failed to save image")
    } finally {
      setIsExporting(false)
    }
  }

  const handleShare = async () => {
    if (selectedLines.length === 0) return
    setIsExporting(true)
    try {
      const title = np?.title || "Song"
      const artist = np?.artist || "Artist"
      const blob = await exportCardToBlob({
        title,
        artist,
        album: np?.album,
        artworkUrl: activeArtwork,
        accentColor: resolvedAccent,
        lines: selectedLines,
        times: selectedTimes,
        time: firstSelectedTime,
        duration: np?.duration || 230,
        style,
        aspectRatio,
        backdropUrl: customBackdrop,
        backdropBlur,
        ...textOpts,
        showTranslation,
      })

      const file = new File([blob], `${artist} - ${title}.png`, { type: "image/png" })
      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: `${title} - ${artist}`,
          text: `Lyrics from ${title} by ${artist}`,
        })
      } else {
        await copyCardToClipboard(blob)
        showToast("Sharing not supported; copied to clipboard!")
      }
    } catch (e) {
      console.error(e)
      showToast("Share cancelled or failed")
    } finally {
      setIsExporting(false)
    }
  }

  const handleExportVideo = async () => {
    if (selectedLines.length === 0) return
    setIsExporting(true)
    setRenderProgress(0)
    try {
      const title = np?.title || "Song"
      const artist = np?.artist || "Artist"
      const blob = await exportVideo(
        {
          title,
          artist,
          album: np?.album,
          artworkUrl: activeArtwork,
          accentColor: resolvedAccent,
          lines: selectedLines,
          times: selectedTimes,
          time: firstSelectedTime,
          duration: np?.duration || 230,
          style,
          aspectRatio,
          backdropUrl: customBackdrop,
          backdropBlur,
          ...textOpts,
          showTranslation,
        },
        duration,
        30,
        (progress) => setRenderProgress(progress),
        { videoUrl: customVideo, musicUrl, musicStart: firstSelectedTime },
      )
      downloadVideo(blob, `${artist} - ${title} (Lyric Video)`)
      showToast("Video exported and saved!")
    } catch (e) {
      console.error(e)
      showToast("Video export failed")
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

  const currentDims = getCanvasDimensions(aspectRatio)

  return (
    <div className="share-window">
      {/* Top Titlebar */}
      <header className="share-header">
        <div className="share-title-meta">
          <Sparkles size={16} className="share-sparkle" />
          <span className="share-title-text">Share Lyric Card</span>
          <span className="share-aspect-tag">{currentDims.width} × {currentDims.height}</span>
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

      {/* Main Container: Left Line Picker, Right Studio Studio */}
      <div className="share-body">
        {/* Left Column: Song Info & Line Selector */}
        <div className="share-picker-panel">
          <div className="share-track-card">
            <div className="share-track-art">
              {activeArtwork ? (
                <img src={activeArtwork} alt="" />
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
            <span>Select 1–8 consecutive lines</span>
            <span className="share-count-badge">
              {selectedLines.length} / 8
            </span>
          </div>

          <div className="share-lines-list" ref={listRef}>
            {lines.map((text, idx) => {
              const isSelected = selectedIndices.includes(idx)
              const isFirst = selectedIndices[0] === idx
              const isLast = selectedIndices[selectedIndices.length - 1] === idx

              return (
                <button
                  key={idx}
                  data-line-idx={idx}
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

        {/* Right Column: Studio Deck, Live Preview & Actions */}
        <div className="share-preview-panel">
          {/* Top Studio Toolbar: Mode Switcher & Aspect Ratio Switcher */}
          <div className="share-top-toolbar">
            {/* Mode Switcher */}
            <div className="share-pill-group">
              <button
                className={`share-mode-pill ${mode === "photo" ? "active" : ""}`}
                onClick={() => setMode("photo")}
              >
                <ImageIcon size={13} />
                <span>Photo</span>
              </button>
              <button
                className={`share-mode-pill ${mode === "video" ? "active" : ""}`}
                onClick={() => setMode("video")}
              >
                <Film size={13} />
                <span>Video</span>
              </button>
            </div>

            {/* Aspect Ratio Switcher */}
            <div className="share-pill-group">
              {ASPECT_RATIOS.map((r) => (
                <button
                  key={r.id}
                  className={`share-ratio-pill ${aspectRatio === r.id ? "active" : ""}`}
                  onClick={() => setAspectRatio(r.id)}
                >
                  <span>{r.label}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Live Card Preview (with aspect ratio frame) */}
          <div className="share-card-wrapper">
            <LiveCardPreview
              style={style}
              aspectRatio={aspectRatio}
              title={np?.title || "Shape of My Heart"}
              artist={np?.artist || "Backstreet Boys"}
              artwork={activeArtwork}
              accent={resolvedAccent}
              lines={selectedLines}
              time={firstSelectedTime}
              duration={np?.duration || 230}
              elapsed={previewElapsed}
              activeLineIndex={activeLineIndex}
              backdropUrl={customBackdrop}
              backdropBlur={backdropBlur}
              videoUrl={mode === "video" ? customVideo : null}
              isPlaying={isPlaying}
              {...textOpts}
            />

            {/* Video Export Overlay */}
            {isExporting && mode === "video" && (
              <div className="share-render-overlay">
                <div className="share-render-box">
                  <div className="share-render-progress-bar">
                    <div
                      className="share-render-progress-fill"
                      style={{ width: `${Math.round(renderProgress * 100)}%` }}
                    />
                  </div>
                  <div className="share-render-text">
                    Rendering Video: {Math.round(renderProgress * 100)}%
                  </div>
                </div>
              </div>
            )}

            {toast && <div className="share-toast">{toast}</div>}
          </div>

          {/* Video Playback Scrubber & Transport in Video Mode */}
          {mode === "video" && (
            <div className="share-video-transport">
              <button
                className="transport-play-btn"
                onClick={() => setIsPlaying((p) => !p)}
                title={isPlaying ? "Pause" : "Play"}
              >
                {isPlaying ? <Pause size={12} /> : <Play size={12} />}
              </button>

              <span className="transport-time">{formatTime(previewElapsed)}</span>

              <input
                type="range"
                className="transport-scrubber"
                min={0}
                max={duration}
                step={0.1}
                value={previewElapsed}
                onChange={(e) => setPreviewElapsed(parseFloat(e.target.value))}
              />

              <span className="transport-time">{formatTime(duration)}</span>
            </div>
          )}

          {/* Bottom Controls Deck */}
          <div className="share-controls-deck">
            {/* Style Selector Carousel */}
            <div className="share-style-carousel">
              {STYLES.map((s) => {
                const IconComponent = s.icon
                return (
                  <button
                    key={s.id}
                    className={`share-style-chip ${style === s.id ? "active" : ""}`}
                    onClick={() => setStyle(s.id)}
                  >
                    <IconComponent size={14} className="chip-icon" />
                    <span className="chip-name">{s.name}</span>
                  </button>
                )
              })}
            </div>

            <div className="share-context-row">
              <div className="deck-media-group">
                <span className="deck-label">Font</span>
                <select className="deck-select" value={lyricFont} onChange={(e) => setLyricFont(e.target.value as LyricFont)}>
                  <option value="auto">Auto</option>
                  <option value="sans">Sans</option>
                  <option value="system">System</option>
                  <option value="serif">Serif</option>
                  <option value="mono">Mono</option>
                  <option value="hand">Handwritten</option>
                </select>
                <span className="deck-label">Align</span>
                {(["auto", "left", "center", "right"] as const).map((a) => (
                  <button
                    key={a}
                    className={`deck-pill-btn ${textAlign === a ? "active" : ""}`}
                    onClick={() => setTextAlign(a)}
                  >
                    {a[0].toUpperCase() + a.slice(1)}
                  </button>
                ))}
                <div className="deck-slider-wrap" title="Lyric size">
                  <span className="muted">Aa</span>
                  <input
                    type="range"
                    min={0.6}
                    max={1.6}
                    step={0.05}
                    value={fontScale}
                    onChange={(e) => setFontScale(parseFloat(e.target.value))}
                  />
                </div>
              </div>
            </div>

            <div className="share-deck-divider" />

            {/* Dynamic Context Controls */}
            <div className="share-context-row">
              {mode === "video" ? (
                <>
                  {/* Duration Selector */}
                  <div className="deck-duration-group">
                    <span className="deck-label">Duration:</span>
                    <button
                      className={`deck-pill-btn ${Math.abs(duration - autoDuration) < 0.5 ? "active" : ""}`}
                      onClick={() => setDuration(autoDuration)}
                    >
                      Auto ({autoDuration}s)
                    </button>
                    {[10, 15, 30].map((d) => (
                      <button
                        key={d}
                        className={`deck-pill-btn ${duration === d ? "active" : ""}`}
                        onClick={() => setDuration(d)}
                      >
                        {d}s
                      </button>
                    ))}
                  </div>

                  {/* Video Media Source */}
                  <div className="deck-media-group">
                    <button
                      className={`deck-pill-btn ${customVideo ? "highlight" : ""}`}
                      onClick={() => videoInputRef.current?.click()}
                    >
                      <Film size={12} />
                      <span>{customVideo ? "Video Attached" : "Video Bg"}</span>
                    </button>
                    {customVideo && (
                      <button className="deck-icon-btn" onClick={() => setCustomVideo(null)} title="Remove video">
                        <X size={12} />
                      </button>
                    )}
                    <button
                      className={`deck-pill-btn ${customBackdrop ? "highlight" : ""}`}
                      onClick={() => backdropInputRef.current?.click()}
                    >
                      <ImageIcon size={12} />
                      <span>Photo</span>
                    </button>
                    {customBackdrop && (
                      <button className="deck-icon-btn" onClick={() => setCustomBackdrop(null)} title="Remove photo">
                        <X size={12} />
                      </button>
                    )}
                    <button
                      className={`deck-pill-btn ${customCover ? "highlight" : ""}`}
                      onClick={() => coverInputRef.current?.click()}
                    >
                      <Disc size={12} />
                      <span>Cover</span>
                    </button>
                    <button
                      className={`deck-pill-btn ${musicUrl ? "highlight" : ""}`}
                      onClick={() => musicInputRef.current?.click()}
                      title="Audio file of the song; the part matching the chosen lines is added to the video"
                    >
                      <Music2 size={12} />
                      <span>{musicUrl ? "Music Attached" : "Music"}</span>
                    </button>
                    {musicUrl && (
                      <button className="deck-icon-btn" onClick={() => setMusicUrl(null)} title="Remove music">
                        <X size={12} />
                      </button>
                    )}

                    {(customVideo || customBackdrop) && (
                      <>
                        <div className="deck-slider-wrap" title="Background blur">
                          <Sliders size={12} className="muted" />
                          <input
                            type="range"
                            min={0}
                            max={40}
                            value={backdropBlur}
                            onChange={(e) => setBackdropBlur(parseInt(e.target.value, 10))}
                          />
                        </div>
                        <div className="deck-slider-wrap" title="Background zoom">
                          <ZoomIn size={12} className="muted" />
                          <input
                            type="range"
                            min={1}
                            max={3}
                            step={0.05}
                            value={backdropZoom}
                            onChange={(e) => setBackdropZoom(parseFloat(e.target.value))}
                          />
                        </div>
                      </>
                    )}
                  </div>
                </>
              ) : (
                <>
                  {/* Photo Mode Cover & Backdrop controls */}
                  <div className="deck-media-group">
                    <button
                      className={`deck-pill-btn ${customCover ? "highlight" : ""}`}
                      onClick={() => coverInputRef.current?.click()}
                    >
                      <Music2 size={12} />
                      <span>{customCover ? "Custom Cover" : "Cover Art"}</span>
                    </button>

                    {customCover && (
                      <button
                        className="deck-icon-btn"
                        onClick={() => setCustomCover(null)}
                        title="Reset cover to song artwork"
                      >
                        <RotateCcw size={12} />
                      </button>
                    )}

                    <button
                      className={`deck-pill-btn ${customBackdrop ? "highlight" : ""}`}
                      onClick={() => backdropInputRef.current?.click()}
                    >
                      <ImageIcon size={12} />
                      <span>{customBackdrop ? "Custom Bg" : "Background"}</span>
                    </button>

                    {customBackdrop && (
                      <>
                        <div className="deck-slider-wrap" title="Background blur">
                          <Sliders size={12} className="muted" />
                          <input
                            type="range"
                            min={0}
                            max={40}
                            value={backdropBlur}
                            onChange={(e) => setBackdropBlur(parseInt(e.target.value, 10))}
                          />
                        </div>
                        <button
                          className="deck-icon-btn"
                          onClick={() => setCustomBackdrop(null)}
                          title="Remove custom background"
                        >
                          <RotateCcw size={12} />
                        </button>
                      </>
                    )}
                  </div>
                </>
              )}

              {/* Hidden File Inputs */}
              <input
                ref={coverInputRef}
                type="file"
                accept="image/*"
                style={{ display: "none" }}
                onChange={handleCoverUpload}
              />
              <input
                ref={backdropInputRef}
                type="file"
                accept="image/*"
                style={{ display: "none" }}
                onChange={handleBackdropUpload}
              />
              <input
                ref={videoInputRef}
                type="file"
                accept="video/*"
                style={{ display: "none" }}
                onChange={handleVideoUpload}
              />
              <input
                ref={musicInputRef}
                type="file"
                accept="audio/*,video/*"
                style={{ display: "none" }}
                onChange={handleMusicUpload}
              />
            </div>

            {/* Action Buttons */}
            <div className="share-actions-bar">
              {mode === "photo" ? (
                <>
                  <button
                    className="share-btn secondary"
                    onClick={handleCopy}
                    disabled={isExporting || selectedLines.length === 0}
                  >
                    <Copy size={15} />
                    <span>Copy Image</span>
                  </button>
                  <button
                    className="share-btn secondary"
                    onClick={handleDownload}
                    disabled={isExporting || selectedLines.length === 0}
                  >
                    <Download size={15} />
                    <span>Save Image</span>
                  </button>
                  <button
                    className="share-btn primary"
                    onClick={handleShare}
                    disabled={isExporting || selectedLines.length === 0}
                  >
                    <Share2 size={15} />
                    <span>Share…</span>
                  </button>
                </>
              ) : (
                <button
                  className="share-btn primary full"
                  onClick={handleExportVideo}
                  disabled={isExporting || selectedLines.length === 0}
                >
                  <Film size={15} />
                  <span>{isExporting ? "Rendering Video…" : "Export Video (MP4)"}</span>
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

/* ==========================================================================
   LIVE CARD PREVIEW COMPONENT (Supports all 10 styles and 3 aspect ratios)
   ========================================================================== */

interface LiveCardProps {
  style: LyricCardStyle
  aspectRatio: CardAspectRatio
  title: string
  artist: string
  artwork: string | null
  accent: string
  lines: string[]
  time: number
  duration: number
  elapsed: number
  activeLineIndex: number | null
  backdropUrl: string | null
  backdropBlur: number
  videoUrl: string | null
  isPlaying: boolean
  backdropZoom: number
  lyricFont: LyricFont
  fontScale: number
  textAlign: LyricAlign
}

function LiveCardPreview({
  style,
  aspectRatio,
  title,
  artist,
  artwork,
  accent,
  lines,
  time,
  duration,
  elapsed,
  activeLineIndex,
  backdropUrl,
  backdropBlur,
  videoUrl,
  isPlaying,
  backdropZoom,
  lyricFont,
  fontScale,
  textAlign,
}: LiveCardProps) {
  const videoRef = useRef<HTMLVideoElement | null>(null)
  useEffect(() => {
    const v = videoRef.current
    if (v) isPlaying ? v.play().catch(() => {}) : v.pause()
  }, [isPlaying, videoUrl])
  const currentTotalTime = (time || 0) + (elapsed || 0)
  const progressPercent = duration > 0 ? (currentTotalTime / duration) * 100 : 35
  const isBlink = Math.floor(elapsed * 2) % 2 === 0
  const isLight = isLightColor(accent)

  return (
    <div
      className={`live-card live-card-${style} aspect-${aspectRatio}`}
      data-font={lyricFont === "auto" ? undefined : lyricFont}
      data-align={textAlign === "auto" ? undefined : textAlign}
      style={{
        ["--card-accent" as string]: accent,
        ["--card-ink" as string]: isLight ? "#111" : "#fff",
        ["--lyric-font" as string]: lyricFont === "auto" ? undefined : LYRIC_FONTS[lyricFont],
        ["--lyric-align" as string]: textAlign,
        ["--lyric-scale" as string]: fontScale,
      }}
    >
      {/* Custom Backdrop or Style Background */}
      {videoUrl || backdropUrl ? (
        <div className="live-custom-backdrop">
          {videoUrl ? (
            // shortcut: preview video loops on its own clock, not locked to the scrubber; export is in sync.
            <video
              ref={videoRef}
              className="live-backdrop-img"
              src={videoUrl}
              autoPlay
              loop
              muted
              playsInline
              style={{ objectFit: "cover", width: "130%", height: "130%", filter: `blur(${backdropBlur}px)`, transform: `scale(${backdropZoom})` }}
            />
          ) : (
            <div
              className="live-backdrop-img"
              style={{
                backgroundImage: `url(${backdropUrl})`,
                filter: `blur(${backdropBlur}px)`,
                transform: `scale(${backdropZoom})`,
              }}
            />
          )}
          <div className="live-backdrop-overlay" />
        </div>
      ) : (
        <>
          {style === "aura" && (
            <div className="live-aura-bg">
              {artwork && <div className="live-aura-art" style={{ backgroundImage: `url(${artwork})` }} />}
              <div
                className="live-aura-glow"
                style={{
                  background: `radial-gradient(circle at 50% 60%, ${accent}66 0%, transparent 75%)`,
                }}
              />
            </div>
          )}

          {style === "player" && (
            <div className="live-player-bg">
              {artwork && <div className="live-player-blur" style={{ backgroundImage: `url(${artwork})` }} />}
              <div
                className="live-player-glow"
                style={{
                  background: `radial-gradient(circle at 50% 35%, ${accent}33 0%, transparent 70%)`,
                }}
              />
            </div>
          )}

          {style === "glass" && (
            <div className="live-glass-bg">
              {artwork && <div className="live-glass-art" style={{ backgroundImage: `url(${artwork})` }} />}
              <div
                className="live-glass-glow"
                style={{
                  background: `radial-gradient(circle at 30% 30%, ${accent}55 0%, transparent 60%), radial-gradient(circle at 70% 70%, #8b5cf644 0%, transparent 60%)`,
                }}
              />
            </div>
          )}

          {style === "solid" && (
            <div
              className="live-solid-bg"
              style={{
                backgroundColor: accent,
                background: `linear-gradient(135deg, ${accent} 0%, ${accent}ee 100%)`,
              }}
            />
          )}

          {style === "vhs" && (
            <div className="live-vhs-scanlines" />
          )}
        </>
      )}

      {/* Content Layouts by Style */}
      {style === "player" ? (
        <div className="live-player-layout">
          <div className="live-player-cover">
            {artwork ? <img src={artwork} alt="" /> : <Music2 size={36} />}
          </div>
          <div className="live-player-title">{title}</div>
          <div className="live-player-artist">{artist}</div>

          <div className="live-player-lyrics">
            {lines.length === 0 ? (
              <div className="live-player-line dimmed">Select lines on the left…</div>
            ) : (
              lines.map((l, i) => {
                const isCurrent = activeLineIndex === null || activeLineIndex === i
                return (
                  <div
                    key={i}
                    className={`live-player-line ${isCurrent ? "current" : "inactive"}`}
                  >
                    {l}
                  </div>
                )
              })
            )}
          </div>

          <div className="live-player-controls">
            <div className="live-progress-bar">
              <div className="live-progress-fill" style={{ width: `${progressPercent}%` }} />
            </div>
            <div className="live-times">
              <span>{formatTime(currentTotalTime)}</span>
              <span>-{formatTime(Math.max(0, duration - currentTotalTime))}</span>
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
            {lines.length === 0 ? (
              <div className="live-polaroid-line dimmed">Select lines on the left…</div>
            ) : (
              lines.slice(0, 5).map((l, i) => {
                const isCurrent = activeLineIndex === null || activeLineIndex === i
                return (
                  <div
                    key={i}
                    className={`live-polaroid-line ${isCurrent ? "current" : "inactive"}`}
                  >
                    {l}
                  </div>
                )
              })
            )}
            <div className="live-polaroid-artist">— {artist}</div>
          </div>
        </div>
      ) : style === "vhs" ? (
        <div className="live-vhs-layout">
          {/* Top Status */}
          <div className="live-vhs-top">
            <div className="vhs-rec-wrap">
              <span className={`vhs-rec-dot ${isBlink ? "on" : "off"}`} />
              <span className="vhs-rec-text">REC</span>
              <span className="vhs-sp-tag">SP</span>
            </div>
            <div className="vhs-auto-wrap">AUTO [■■□]</div>
          </div>

          {/* Glowing Green Timecode */}
          <div className="live-vhs-timecode">{formatTimecode(elapsed)}</div>

          {/* Lyrics in Neon Cyan Uppercase */}
          <div className="live-vhs-lyrics">
            {lines.length === 0 ? (
              <div className="live-vhs-line dimmed">SELECT LINES ON THE LEFT…</div>
            ) : (
              lines.map((l, i) => {
                const isCurrent = activeLineIndex === null || activeLineIndex === i
                return (
                  <div
                    key={i}
                    className={`live-vhs-line ${isCurrent ? "current" : "inactive"}`}
                  >
                    {l.toUpperCase()}
                  </div>
                )
              })
            )}
          </div>

          {/* Bottom Track Meta & PLAY */}
          <div className="live-vhs-bottom">
            <div className="vhs-meta">
              <div className="vhs-title">{title.toUpperCase()}</div>
              <div className="vhs-artist">{artist.toUpperCase()}</div>
            </div>
            <div className="vhs-play">PLAY ▶</div>
          </div>
        </div>
      ) : style === "cassette" ? (
        <div className="live-cassette-layout">
          {/* Mini Header */}
          <div className="live-card-header">
            <div className="live-header-art">
              {artwork ? <img src={artwork} alt="" /> : <Music2 size={16} />}
            </div>
            <div className="live-header-text">
              <div className="live-header-title">{title}</div>
              <div className="live-header-artist">{artist}</div>
            </div>
          </div>

          {/* Cassette Graphic */}
          <div className="live-cassette-shell">
            <div className="live-cassette-label">
              <div className="cassette-label-top">
                <span className="cassette-side-a">SIDE A</span>
                <span className="cassette-handwritten-title">{title}</span>
                <span className="cassette-type">C-60</span>
              </div>
              <div className="cassette-window">
                <div
                  className="cassette-spool"
                  style={{ transform: `rotate(${elapsed * 180}deg)` }}
                />
                <div className="cassette-tape-strip" />
                <div
                  className="cassette-spool"
                  style={{ transform: `rotate(${elapsed * 180}deg)` }}
                />
              </div>
            </div>
          </div>

          {/* Lyrics Block */}
          <div className="live-card-lyrics">
            {lines.length === 0 ? (
              <div className="live-card-line dimmed">Select lines on the left…</div>
            ) : (
              lines.map((l, i) => {
                const isCurrent = activeLineIndex === null || activeLineIndex === i
                return (
                  <div
                    key={i}
                    className={`live-card-line ${isCurrent ? "current" : "inactive"}`}
                  >
                    {l}
                  </div>
                )
              })
            )}
          </div>

          <div className="live-card-footer">❝ OpenNotchi</div>
        </div>
      ) : style === "vinyl" ? (
        <div className="live-vinyl-layout">
          <div className="live-card-header">
            <div className="live-header-art">
              {artwork ? <img src={artwork} alt="" /> : <Music2 size={16} />}
            </div>
            <div className="live-header-text">
              <div className="live-header-title">{title}</div>
              <div className="live-header-artist">{artist}</div>
            </div>
          </div>

          {/* Vinyl Disc & Sleeve Composition */}
          <div className="live-vinyl-comp">
            <div className="vinyl-sleeve">
              {artwork ? <img src={artwork} alt="" /> : <div className="sleeve-placeholder" />}
            </div>
            <div
              className="vinyl-disc"
              style={{ transform: `rotate(${elapsed * 90}deg)` }}
            >
              <div className="vinyl-groove" />
              <div className="vinyl-center-label">
                {artwork ? <img src={artwork} alt="" /> : <div className="label-fill" />}
                <div className="vinyl-spindle-hole" />
              </div>
            </div>
          </div>

          <div className="live-card-lyrics">
            {lines.length === 0 ? (
              <div className="live-card-line dimmed">Select lines on the left…</div>
            ) : (
              lines.map((l, i) => {
                const isCurrent = activeLineIndex === null || activeLineIndex === i
                return (
                  <div
                    key={i}
                    className={`live-card-line ${isCurrent ? "current" : "inactive"}`}
                  >
                    {l}
                  </div>
                )
              })
            )}
          </div>

          <div className="live-card-footer">❝ OpenNotchi</div>
        </div>
      ) : style === "glass" ? (
        <div className="live-glass-layout">
          {/* Frosted Capsule Header */}
          <div className="live-glass-pill-header">
            <div className="glass-pill-art">
              {artwork ? <img src={artwork} alt="" /> : <Music2 size={12} />}
            </div>
            <div className="glass-pill-meta">
              <div className="glass-pill-title">{title}</div>
              <div className="glass-pill-artist">{artist}</div>
            </div>
            <div className="glass-pill-eq">
              {[0, 1, 2, 3].map((i) => (
                <span
                  key={i}
                  className="glass-eq-bar"
                  style={{
                    height: `${6 + Math.sin(elapsed * 6 + i * 1.5) * 5}px`,
                  }}
                />
              ))}
            </div>
          </div>

          {/* Glass Card Lyrics Box */}
          <div className="live-glass-card-inner">
            <div className="live-card-lyrics">
              {lines.length === 0 ? (
                <div className="live-card-line dimmed">Select lines on the left…</div>
              ) : (
                lines.map((l, i) => {
                  const isCurrent = activeLineIndex === null || activeLineIndex === i
                  return (
                    <div
                      key={i}
                      className={`live-card-line ${isCurrent ? "current glow" : "inactive"}`}
                    >
                      {l}
                    </div>
                  )
                })
              )}
            </div>
          </div>

          <div className="live-card-footer">❝ OpenNotchi</div>
        </div>
      ) : style === "receipt" ? (
        <div className="live-receipt-layout">
          <div className="receipt-perforation top" />
          <div className="receipt-paper">
            <div className="receipt-header">
              <div className="receipt-title-archive">*** OPENNOTCHI ARCHIVE ***</div>
              <div className="receipt-sub-row">
                <span>AUDIO #1024</span>
                <span>{activeLineIndex !== null ? `TIME: ${formatTime(elapsed)}` : "TRACK CASSETTE"}</span>
              </div>
              <div className="receipt-divider">------------------------------</div>
              <div className="receipt-song-row">
                <span className="receipt-song-title">{title.toUpperCase()}</span>
                <span className="receipt-song-artist">{artist.toUpperCase()}</span>
              </div>
              <div className="receipt-divider">------------------------------</div>
            </div>

            <div className="receipt-lyrics">
              {lines.length === 0 ? (
                <div className="receipt-line dimmed">SELECT LINES ON THE LEFT…</div>
              ) : (
                lines.map((l, i) => {
                  const isCurrent = activeLineIndex === null || activeLineIndex === i
                  return (
                    <div
                      key={i}
                      className={`receipt-line ${isCurrent ? "current" : "inactive"}`}
                    >
                      <span className="receipt-num">{isCurrent && activeLineIndex !== null ? "►" : String(i + 1).padStart(2, "0")}</span>
                      <span className="receipt-text">{l}</span>
                    </div>
                  )
                })
              )}
            </div>

            <div className="receipt-footer">
              <div className="receipt-divider">------------------------------</div>
              <div className="receipt-barcode">
                {Array.from({ length: 28 }).map((_, b) => (
                  <span
                    key={b}
                    className={`barcode-bar ${b % 3 === 0 ? "thick" : b % 5 === 0 ? "bold" : ""}`}
                  />
                ))}
              </div>
              <div className="receipt-thank-you">THANK YOU FOR LISTENING</div>
            </div>
          </div>
          <div className="receipt-perforation bottom" />
        </div>
      ) : (
        /* Default / Aura / Paper / Solid */
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
            {lines.length === 0 ? (
              <div className="live-card-line dimmed">Select lines on the left…</div>
            ) : (
              lines.map((l, i) => {
                const isCurrent = activeLineIndex === null || activeLineIndex === i
                return (
                  <div
                    key={i}
                    className={`live-card-line ${isCurrent ? "current" : "inactive"} ${
                      style === "paper" && isCurrent && activeLineIndex !== null ? "highlight-paper" : ""
                    }`}
                  >
                    {l}
                  </div>
                )
              })
            )}
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
