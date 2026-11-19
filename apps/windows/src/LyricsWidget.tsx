import { invoke } from "@tauri-apps/api/core"
import { getCurrentWindow } from "@tauri-apps/api/window"
import { Code2, ListEnd, Lock, Maximize2, Share2, Sparkles, X } from "lucide-react"
import { useState } from "react"
import { DesktopCodeLyrics } from "./CodeLyrics"
import { cursorVisible, typingSplit } from "./codeLyricsEngine"
import { currentLine, positionAt, useLyrics, useNowPlaying, useTick } from "./media"
import { LYRICS_ANIMATION_OPTIONS, useSettings } from "./settings"

const BACKGROUND_KEY = "lyricsBackground"

/** Floating desktop lyrics: standard or live source-code typing mode with selectable animations. */
export function LyricsWidget() {
  const [settings, setSettings] = useSettings()
  const np = useNowPlaying()
  const lyrics = useLyrics(np)
  const [hover, setHover] = useState(false)
  const [background, setBackground] = useState(() => Number(safeGet(BACKGROUND_KEY) ?? 0.45))
  const anim = settings.lyricsAnimation ?? "smooth"
  useTick(settings.lyricsCodeMode || anim === "typewriter" ? 42 : 200)

  const { index, text } = currentLine(np, lyrics)
  const synced = lyrics && lyrics !== "loading" ? lyrics.synced : []
  const curLine = index !== null ? synced[index] : undefined
  const nextLine = index !== null ? synced[index + 1] : undefined
  const next = nextLine?.text
  const win = getCurrentWindow()

  const cycleBackground = () => {
    const value = background >= 0.99 ? 0 : Math.min(1, Math.floor(background / 0.25) * 0.25 + 0.25)
    setBackground(value)
    safeSet(BACKGROUND_KEY, String(value))
  }

  const cycleAnimation = () => {
    const i = LYRICS_ANIMATION_OPTIONS.findIndex((a) => a.id === anim)
    const nextAnim = LYRICS_ANIMATION_OPTIONS[(i + 1) % LYRICS_ANIMATION_OPTIONS.length].id
    setSettings({ lyricsAnimation: nextAnim })
  }

  // Locked: clicks pass through to the apps underneath. Unlock from the tray icon's menu.
  const lock = () => win.setIgnoreCursorEvents(true)

  const pos = np ? positionAt(np) : 0
  const split =
    !settings.lyricsCodeMode && anim === "typewriter" && text && curLine
      ? typingSplit(text, curLine.time, nextLine?.time ?? null, pos)
      : null
  const cursorOn = cursorVisible(Date.now(), Boolean(np?.isPlaying))

  return (
    <div
      className={`widget ${settings.lyricsCodeMode ? "widget-code" : ""} ly-anim-${anim}`}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onMouseDown={(e) => e.button === 0 && !(e.target as HTMLElement).closest("button") && win.startDragging()}
      style={{ background: text || hover ? `rgba(0,0,0,${Math.max(background, hover ? 0.35 : 0)})` : "transparent" }}
    >
      {settings.lyricsCodeMode ? (
        <DesktopCodeLyrics
          index={index}
          lines={synced}
          np={np}
          showNextLine={settings.lyricsOverlayNextLine}
          hover={hover}
        />
      ) : text ? (
        <>
          <div className={`widget-line ly-anim-${anim}`} key={index}>
            {split ? (
              <>
                <span>{split.typed}</span>
                <span className={`cl-cursor ${cursorOn ? "on" : "off"}`}>▋</span>
                <span className="cl-ghost">{split.ghost}</span>
              </>
            ) : (
              text
            )}
          </div>
          {settings.lyricsOverlayNextLine && next && <div className="widget-next">{next}</div>}
        </>
      ) : (
        hover && <div className="widget-next">{np ? "Waiting for lyrics…" : "Nothing playing"}</div>
      )}

      {hover && (
        <>
          <div className="widget-controls">
            <button
              className={settings.lyricsCodeMode ? "on" : ""}
              onClick={() => setSettings({ lyricsCodeMode: !settings.lyricsCodeMode })}
              title={settings.lyricsCodeMode ? "Standard lyrics style" : "Source code live-typing style"}
              aria-label="Toggle source code lyrics"
            >
              <Code2 size={12} />
            </button>
            <button
              className={anim !== "smooth" ? "on" : ""}
              onClick={cycleAnimation}
              title={`Lyrics animation: ${LYRICS_ANIMATION_OPTIONS.find((a) => a.id === anim)?.name ?? anim}`}
              aria-label="Cycle lyrics animation"
            >
              <Sparkles size={12} />
            </button>
            <button
              className={settings.lyricsOverlayNextLine ? "on" : ""}
              onClick={() => setSettings({ lyricsOverlayNextLine: !settings.lyricsOverlayNextLine })}
              title={settings.lyricsOverlayNextLine ? "Hide next line" : "Show next line"}
              aria-label="Toggle next line"
            >
              <ListEnd size={12} />
            </button>
            <button onClick={() => invoke("open_share_lyrics").catch(() => {})} title="Share lyrics card" aria-label="Share lyrics card"><Share2 size={12} /></button>
            <button onClick={cycleBackground} title={`Background ${Math.round(background * 100)}%`} aria-label="Background opacity">◐</button>
            <button onClick={lock} title="Lock (clicks pass through)" aria-label="Lock"><Lock size={12} /></button>
            <button onClick={() => invoke("hide_lyrics").catch(() => win.hide())} title="Hide" aria-label="Hide"><X size={12} /></button>
          </div>
          <button className="widget-grip" onMouseDown={() => win.startResizeDragging("SouthEast")} title="Drag to resize" aria-label="Resize">
            <Maximize2 size={11} />
          </button>
        </>
      )}
    </div>
  )
}

// localStorage can throw in locked-down profiles; the widget works without it.
function safeGet(key: string) {
  try { return localStorage.getItem(key) } catch { return null }
}
function safeSet(key: string, value: string) {
  try { localStorage.setItem(key, value) } catch { /* not persisted */ }
}
