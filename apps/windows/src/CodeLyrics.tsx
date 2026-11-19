import {
  Activity,
  Camera,
  Code2,
  FileCode2,
  FileText,
  FolderOpen,
  GitBranch,
  Image as ImageIcon,
  Languages,
  Maximize2,
  Pause,
  Play,
  Search,
  SkipBack,
  SkipForward,
  X,
} from "lucide-react"
import { useEffect, useRef, type CSSProperties } from "react"
import {
  cursorVisible,
  fileSlug,
  templateForLine,
  typingSplit,
  type CodeLineTemplate,
  type CodeToken,
} from "./codeLyricsEngine"
import type { LyricLine } from "./lyrics"
import { control, formatTime, positionAt, type NowPlaying } from "./media"
import type { AppSettings } from "./settings"

export { cursorVisible, fileSlug, templateForLine, typingSplit }

function TokenSpan({ tokens }: { tokens: CodeToken[] }) {
  return (
    <>
      {tokens.map((tok, i) => (
        <span key={i} className={`cl-tok cl-tok-${tok.role}`}>
          {tok.text}
        </span>
      ))}
    </>
  )
}

function ActiveCodeLine({
  template,
  typed,
  ghost,
  cursorOn,
}: {
  template: CodeLineTemplate
  typed: string
  ghost: string
  cursorOn: boolean
}) {
  return (
    <span className="cl-code-active">
      <TokenSpan tokens={template.prefix} />
      <span className="cl-typed">{typed}</span>
      <span className={`cl-cursor ${cursorOn ? "on" : "off"}`}>▋</span>
      {ghost && <span className="cl-ghost">{ghost}</span>}
      <TokenSpan tokens={template.suffix} />
    </span>
  )
}

function IdleCodeLine({
  template,
  text,
  isPast,
}: {
  template: CodeLineTemplate
  text: string
  isPast: boolean
}) {
  return (
    <span className={`cl-code-idle ${isPast ? "past" : "future"}`}>
      <TokenSpan tokens={template.prefix} />
      <span className="cl-str">{text}</span>
      <TokenSpan tokens={template.suffix} />
    </span>
  )
}

// MARK: - 1. Floating Desktop Code Lyrics (No Heavy Box)

export function DesktopCodeLyrics({
  index,
  lines,
  np,
  showNextLine,
  hover,
}: {
  index: number | null
  lines: LyricLine[]
  np: NowPlaying | null
  showNextLine: boolean
  hover: boolean
}) {
  const pos = np ? positionAt(np) : 0
  const curLine = index !== null ? lines[index] : undefined
  const nextLine = index !== null ? lines[index + 1] : undefined
  const cursorOn = cursorVisible(Date.now(), Boolean(np?.isPlaying))

  if (!curLine) {
    return hover ? (
      <div className="cl-desktop-empty">
        {np ? "// syncing lyrics stream…" : "// awaiting playback…"}
      </div>
    ) : null
  }

  const displayText = curLine.text || "♪"
  const split = typingSplit(displayText, curLine.time, nextLine?.time ?? null, pos)
  const tmpl = templateForLine(index ?? 0, displayText, false)

  return (
    <div className="cl-desktop">
      <div className="cl-desktop-row">
        <span className="cl-ln active">{String((index ?? 0) + 1).padStart(2, "0")}</span>
        <ActiveCodeLine template={tmpl} typed={split.typed} ghost={split.ghost} cursorOn={cursorOn} />
      </div>
      {showNextLine && nextLine?.text && (
        <div className="cl-desktop-next">
          <span className="cl-ln">{String((index ?? 0) + 2).padStart(2, "0")}</span>
          <span className="cl-comment">// next: "{nextLine.text}"</span>
        </div>
      )}
    </div>
  )
}

// MARK: - 2. Compact Open-Pill Code Lyrics (No Box Background)

export function PillCodeLyrics({
  np,
  lines,
}: {
  np: NowPlaying
  lines: LyricLine[]
}) {
  const scrollerRef = useRef<HTMLDivElement>(null)
  const pos = positionAt(np)
  const activeIdx = findCurrentIndex(lines, pos)
  const curLine = activeIdx !== null ? lines[activeIdx] : undefined
  const nextLine = activeIdx !== null ? lines[activeIdx + 1] : undefined
  const split = typingSplit(curLine?.text || "♪", curLine?.time ?? pos, nextLine?.time ?? null, pos)
  const cursorOn = cursorVisible(Date.now(), np.isPlaying)

  useEffect(() => {
    const el = scrollerRef.current?.querySelector<HTMLElement>(`[data-cl="${activeIdx ?? 0}"]`)
    el?.scrollIntoView({ block: "center", behavior: "smooth" })
  }, [activeIdx])

  return (
    <div className="cl-pill-scroller" ref={scrollerRef}>
      <div className="cl-pill-pad" />
      {lines.map((l, i) => {
        const isCurrent = i === activeIdx
        const isPast = activeIdx !== null && i < activeIdx
        const displayText = l.text || "♪"
        const tmpl = templateForLine(i, displayText, true)
        return (
          <div
            key={i}
            data-cl={i}
            className={`cl-pill-row ${isCurrent ? "active" : ""}`}
            onClick={() => control("seek", l.time)}
          >
            <span className={`cl-ln ${isCurrent ? "active" : ""}`}>
              {String(i + 1).padStart(2, "0")}
            </span>
            {isCurrent ? (
              <ActiveCodeLine template={tmpl} typed={split.typed} ghost={split.ghost} cursorOn={cursorOn} />
            ) : (
              <IdleCodeLine template={tmpl} text={displayText} isPast={isPast} />
            )}
          </div>
        )
      })}
      <div className="cl-pill-pad" />
    </div>
  )
}

// MARK: - 3. Full-Screen Floating Code Lyrics (No Box Background)

export function FullScreenCodeLyrics({
  np,
  lines,
  translations,
  translateOn,
}: {
  np: NowPlaying
  lines: LyricLine[]
  translations: Record<string, string>
  translateOn: boolean
}) {
  const scrollerRef = useRef<HTMLDivElement>(null)
  const pos = positionAt(np)
  const activeIdx = findCurrentIndex(lines, pos)
  const curLine = activeIdx !== null ? lines[activeIdx] : undefined
  const nextLine = activeIdx !== null ? lines[activeIdx + 1] : undefined
  const split = typingSplit(curLine?.text || "♪", curLine?.time ?? pos, nextLine?.time ?? null, pos)
  const cursorOn = cursorVisible(Date.now(), np.isPlaying)

  useEffect(() => {
    const el = scrollerRef.current?.querySelector<HTMLElement>(`[data-fcl="${activeIdx ?? 0}"]`)
    el?.scrollIntoView({ block: "center", behavior: "smooth" })
  }, [activeIdx])

  return (
    <div className="cl-fs-scroller" ref={scrollerRef}>
      <div className="np-spacer" />
      {lines.map((l, i) => {
        const isCurrent = i === activeIdx
        const isPast = activeIdx !== null && i < activeIdx
        const displayText = l.text || "♪"
        const tmpl = templateForLine(i, displayText, false)
        const trans = translateOn ? translations[l.text] : undefined

        return (
          <div
            key={i}
            data-fcl={i}
            className={`cl-fs-row ${isCurrent ? "active" : isPast ? "past" : "future"}`}
            onClick={() => control("seek", l.time)}
          >
            <div className="cl-fs-line">
              <span className={`cl-ln ${isCurrent ? "active" : ""}`}>
                {String(i + 1).padStart(2, "0")}
              </span>
              {isCurrent ? (
                <ActiveCodeLine template={tmpl} typed={split.typed} ghost={split.ghost} cursorOn={cursorOn} />
              ) : (
                <IdleCodeLine template={tmpl} text={displayText} isPast={isPast} />
              )}
            </div>
            {trans && l.text && (
              <div className="cl-fs-trans">// ↳ {trans}</div>
            )}
          </div>
        )
      })}
      <div className="np-spacer" />
    </div>
  )
}

// MARK: - 4. Dedicated Full-Screen IDE Workspace CodeLyric Mode

export function FullWorkspaceCodeLyrics({
  np,
  lines,
  plainText,
  loading,
  translations,
  settings,
  onToggleTranslate,
  onExitWorkspace,
  onCycleMode,
  onCapturePhoto,
  onClose,
}: {
  np: NowPlaying
  lines: LyricLine[]
  plainText?: string | null
  loading: boolean
  translations: Record<string, string>
  settings: AppSettings
  onToggleTranslate: () => void
  onExitWorkspace: () => void
  onCycleMode: () => void
  onCapturePhoto: () => void
  onClose: () => void
}) {
  const scrollerRef = useRef<HTMLDivElement>(null)
  const pos = positionAt(np)
  const activeIdx = findCurrentIndex(lines, pos)
  const curLine = activeIdx !== null ? lines[activeIdx] : undefined
  const nextLine = activeIdx !== null ? lines[activeIdx + 1] : undefined
  const split = typingSplit(curLine?.text || "♪", curLine?.time ?? pos, nextLine?.time ?? null, pos)
  const cursorOn = cursorVisible(Date.now(), np.isPlaying)
  const slug = fileSlug(np.title, np.artist)
  const fileName = slug.split("/").pop() || "lyrics.swift"

  useEffect(() => {
    const el = scrollerRef.current?.querySelector<HTMLElement>(`[data-wcl="${activeIdx ?? 0}"]`)
    el?.scrollIntoView({ block: "center", behavior: "smooth" })
  }, [activeIdx])

  const now = new Date()
  const clockStr = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })

  return (
    <div className="cl-ws" style={{ "--text-scale": settings.nowPlayingTextScale } as CSSProperties}>
      {/* 1. IDE Top Title Bar */}
      <div className="cl-ws-titlebar">
        <div className="cl-ws-lights">
          <button type="button" className="dot red" onClick={onClose} title="Close (Esc)" aria-label="Close" />
          <span className="dot yellow" />
          <span className="dot green" />
        </div>

        <div className="cl-ws-cmdbar">
          <Search size={11} />
          <span>OpenNotchi — {slug}</span>
        </div>

        <div className="cl-ws-titlebar-right">
          {settings.nowPlayingClock && <span className="cl-ws-clock">{clockStr}</span>}
          <button type="button" className="cl-ws-exit-btn" onClick={onExitWorkspace} title="Exit Workspace to Floating Code (K)">
            <Maximize2 size={11} />
            <span>Exit Workspace</span>
          </button>
        </div>
      </div>

      {/* 2. Split Body: Explorer Sidebar + Main Editor + Output */}
      <div className="cl-ws-body">
        <aside className="cl-ws-sidebar">
          <div className="cl-ws-side-hdr">
            <span>EXPLORER</span>
            <span className={`cl-ws-live ${np.isPlaying ? "playing" : "paused"}`}>
              {np.isPlaying ? "LIVE" : "PAUSED"}
            </span>
          </div>

          <div className="cl-ws-tree">
            <div className="cl-ws-tree-item folder"><FolderOpen size={12} /> <span>NOW-PLAYING</span></div>
            <div className="cl-ws-tree-item file active"><FileCode2 size={12} /> <span>{fileName}</span></div>
            <div className="cl-ws-tree-item file"><FileText size={12} /> <span>synced.lrc</span></div>
            <div className="cl-ws-tree-item file"><Activity size={12} /> <span>AudioStream.rs</span></div>
            <div className="cl-ws-tree-item file"><ImageIcon size={12} /> <span>cover_art.png</span></div>
          </div>

          <div className="cl-ws-divider" />

          <div className="cl-ws-inspector">
            <div className="cl-ws-side-hdr compact"><span>INSPECTOR · TRACK</span></div>
            <div className="cl-ws-art">
              {np.artwork ? <img src={np.artwork} alt="" /> : <div className="cl-ws-art-empty">♪</div>}
            </div>
            <div className="cl-ws-meta">
              <div className="cl-ws-track">{np.title || "Unknown Track"}</div>
              <div className="cl-ws-artist">// {np.artist || "Unknown Artist"}</div>
            </div>

            <div className="cl-ws-scrubber">
              <div
                className="cl-ws-bar"
                onClick={(e) => {
                  if (!np.duration) return
                  const rect = e.currentTarget.getBoundingClientRect()
                  const pct = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width))
                  control("seek", pct * np.duration)
                }}
              >
                <i style={{ width: np.duration ? `${Math.min(100, (pos / np.duration) * 100)}%` : "0%" }} />
              </div>
              <div className="cl-ws-times">
                <span>{formatTime(pos)}</span>
                <span>{formatTime(np.duration)}</span>
              </div>
            </div>

            <div className="cl-ws-transport">
              <button type="button" onClick={() => control("previous")} title="Previous (←)"><SkipBack size={16} fill="currentColor" /></button>
              <button type="button" className="play" onClick={() => control("toggle")} title="Play / Pause (Space)">
                {np.isPlaying ? <Pause size={18} fill="currentColor" /> : <Play size={18} fill="currentColor" />}
              </button>
              <button type="button" onClick={() => control("next")} title="Next (→)"><SkipForward size={16} fill="currentColor" /></button>
            </div>

            <div className="cl-ws-chips">
              <button type="button" className={settings.lyricsTranslateTarget ? "on" : ""} onClick={onToggleTranslate} title="Translate (T)">
                <Languages size={11} /> <span>T</span>
              </button>
              <button type="button" onClick={onCapturePhoto} title="Capture Photo (C)">
                <Camera size={11} /> <span>C</span>
              </button>
              <button type="button" className="on" onClick={onCycleMode} title="Cycle Lyrics Mode (K)">
                <Code2 size={11} /> <span>K</span>
              </button>
              <button type="button" onClick={onClose} title="Close (Esc)">
                <X size={11} />
              </button>
            </div>
          </div>

          <div className="cl-ws-side-foot">
            <div>lines: {lines.length} · synced</div>
            <div>cursor: line {(activeIdx ?? 0) + 1}</div>
          </div>
        </aside>

        <main className="cl-ws-main">
          {/* File Tabs */}
          <div className="cl-ws-tabs">
            <div className="cl-ws-tab active">
              <FileCode2 size={12} />
              <span>{fileName}</span>
              <i className="cl-ws-dirty" />
            </div>
            <div className="cl-ws-tab">
              <FileText size={12} />
              <span>synced.lrc</span>
            </div>
          </div>

          {/* Breadcrumb */}
          <div className="cl-ws-crumb">
            opennotchi › now_playing › <span>{slug}</span>
          </div>

          {/* Editor Buffer */}
          <div className="cl-ws-editor" ref={scrollerRef}>
            <div className="cl-ws-doc">
              <div>{"/**"}</div>
              <div> * @track   {np.title || "Unknown"}</div>
              <div> * @artist  {np.artist || "Unknown"}</div>
              <div> * @lines   {lines.length} synced statements</div>
              <div>{" */"}</div>
            </div>

            {lines.length > 0 ? (
              lines.map((l, i) => {
                const isCurrent = i === activeIdx
                const isPast = activeIdx !== null && i < activeIdx
                const displayText = l.text || "♪"
                const tmpl = templateForLine(i, displayText, false)
                const trans = settings.lyricsTranslateTarget ? translations[l.text] : undefined

                return (
                  <div
                    key={i}
                    data-wcl={i}
                    className={`cl-ws-row ${isCurrent ? "active" : isPast ? "past" : "future"}`}
                    onClick={() => control("seek", l.time)}
                  >
                    <div className="cl-ws-row-main">
                      <span className="cl-ws-gutter">
                        <span className="cl-ws-caret">{isCurrent ? "▸" : " "}</span>
                        <span className={`cl-ln ${isCurrent ? "active" : ""}`}>
                          {String(i + 1).padStart(2, "0")}
                        </span>
                      </span>
                      <span className="cl-ws-code">
                        {isCurrent ? (
                          <ActiveCodeLine template={tmpl} typed={split.typed} ghost={split.ghost} cursorOn={cursorOn} />
                        ) : (
                          <IdleCodeLine template={tmpl} text={displayText} isPast={isPast} />
                        )}
                      </span>
                      <span className="cl-ws-ts">// {formatTime(l.time)}</span>
                    </div>
                    {trans && l.text && (
                      <div className="cl-ws-trans">// ↳ {trans}</div>
                    )}
                  </div>
                )
              })
            ) : plainText ? (
              <pre className="cl-ws-plain">{plainText}</pre>
            ) : (
              <div className="cl-ws-doc">
                // {loading ? "fetching synced lyrics…" : "instrumental or no synced lyrics"}
              </div>
            )}

            <div className="cl-ws-eof">// ── EOF ({formatTime(np.duration)}) ──</div>
          </div>

          {/* Output Terminal Panel */}
          <div className="cl-ws-output">
            <div className="cl-ws-out-tabs">
              <span className="active">OUTPUT</span>
              <span>AUDIO STREAM</span>
              <span className="cl-ws-out-hint">Space play · ←/→ skip · T translate · K cycle mode · Esc close</span>
            </div>
            <div className="cl-ws-out-line">
              <span className="ts">[{formatTime(pos)} / {formatTime(np.duration)}]</span>
              <span className={np.isPlaying ? "ok" : "warn"}>{np.isPlaying ? "▶" : "⏸"}</span>
              <span className="msg">{curLine?.text ? `"${curLine.text}"` : `${np.title} — ${np.artist}`}</span>
            </div>
          </div>
        </main>
      </div>

      {/* 3. Bottom IDE Status Bar */}
      <div className="cl-ws-statusbar">
        <div className="cl-ws-sb-left">
          <span className="cl-ws-mode-badge">{np.isPlaying ? "INSERT" : "PAUSED"}</span>
          <span className="cl-ws-branch"><GitBranch size={11} /> main*</span>
        </div>
        <div className="cl-ws-sb-right">
          <span>Ln {(activeIdx ?? 0) + 1}/{Math.max(1, lines.length)}, Col {split.column}</span>
          <span className="dim">Spaces: 4</span>
          <span className="dim">UTF-8</span>
          <span className="accent">IDE Workspace (K)</span>
        </div>
      </div>
    </div>
  )
}

function findCurrentIndex(lines: LyricLine[], pos: number): number | null {
  if (!lines.length) return null
  let found: number | null = null
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].time <= pos) found = i
    else break
  }
  return found
}
