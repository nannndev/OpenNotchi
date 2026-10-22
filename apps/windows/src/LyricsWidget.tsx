import { invoke } from "@tauri-apps/api/core"
import { getCurrentWindow } from "@tauri-apps/api/window"
import { Lock, Maximize2, Share2, X } from "lucide-react"
import { useState } from "react"
import { currentLine, useLyrics, useNowPlaying, useTick } from "./media"

const BACKGROUND_KEY = "lyricsBackground"

/** Floating desktop lyrics: the line being sung and the next one. Drag to move, corner grip to resize. */
export function LyricsWidget() {
  const np = useNowPlaying()
  const lyrics = useLyrics(np)
  const [hover, setHover] = useState(false)
  const [background, setBackground] = useState(() => Number(safeGet(BACKGROUND_KEY) ?? 0.45))
  useTick(200)

  const { index, text } = currentLine(np, lyrics)
  const next = index !== null && lyrics && lyrics !== "loading" ? lyrics.synced[index + 1]?.text : undefined
  const win = getCurrentWindow()

  const cycleBackground = () => {
    const value = background >= 0.99 ? 0 : Math.min(1, Math.floor(background / 0.25) * 0.25 + 0.25)
    setBackground(value)
    safeSet(BACKGROUND_KEY, String(value))
  }

  // Locked: clicks pass through to the apps underneath. Unlock from the tray icon's menu.
  const lock = () => win.setIgnoreCursorEvents(true)

  return (
    <div
      className="widget"
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      onMouseDown={(e) => e.button === 0 && !(e.target as HTMLElement).closest("button") && win.startDragging()}
      style={{ background: text || hover ? `rgba(0,0,0,${Math.max(background, hover ? 0.35 : 0)})` : "transparent" }}
    >
      {text ? (
        <>
          <div className="widget-line" key={index}>{text}</div>
          {next && <div className="widget-next">{next}</div>}
        </>
      ) : (
        hover && <div className="widget-next">{np ? "Waiting for lyrics…" : "Nothing playing"}</div>
      )}

      {hover && (
        <>
          <div className="widget-controls">
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
