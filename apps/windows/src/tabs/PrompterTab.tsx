import { FlipHorizontal, Minus, Pause, Pencil, Play, Plus, RotateCcw } from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { useSettings } from "../settings"

/** Reading speed shown next to the scroll speed; 28 px/s at 18px text reads at roughly 135 words a minute. */
const wpm = (speed: number) => Math.round(Math.max(50, Math.min(350, (speed / 28) * 135)))

export function PrompterTab() {
  const [settings, setSettings] = useSettings()
  const [editing, setEditing] = useState(false)
  const [playing, setPlaying] = useState(false)
  const viewportRef = useRef<HTMLDivElement | null>(null)
  // Fractional scroll position; scrollTop on its own rounds away slow speeds.
  const offset = useRef(0)

  const words = settings.prompterScript.split(/\s+/).filter(Boolean).length
  const minutes = words / wpm(settings.prompterSpeed)

  useEffect(() => {
    if (!playing) return
    let last = performance.now()
    let frame = requestAnimationFrame(function tick(now) {
      const el = viewportRef.current
      if (el) {
        offset.current += (Math.min(100, now - last) / 1000) * settings.prompterSpeed
        el.scrollTop = offset.current
        if (el.scrollTop + el.clientHeight >= el.scrollHeight - 1) setPlaying(false)
      }
      last = now
      frame = requestAnimationFrame(tick)
    })
    return () => cancelAnimationFrame(frame)
  }, [playing, settings.prompterSpeed])

  const restart = () => {
    offset.current = 0
    if (viewportRef.current) viewportRef.current.scrollTop = 0
  }

  const togglePlay = () => {
    const el = viewportRef.current
    if (el && el.scrollTop + el.clientHeight >= el.scrollHeight - 1) restart()
    if (el) offset.current = el.scrollTop
    setPlaying(!playing)
  }

  const nudgeSpeed = (d: number) => setSettings({ prompterSpeed: Math.max(8, Math.min(80, settings.prompterSpeed + d)) })

  if (editing) {
    return (
      <div className="tab-prompter">
        <textarea
          className="prompter-editor"
          autoFocus
          value={settings.prompterScript}
          onChange={(e) => setSettings({ prompterScript: e.target.value })}
          placeholder="Paste or type your script…"
        />
        <div className="prompter-bar">
          <span className="muted">{words} words</span>
          <button className="prompter-btn primary" onClick={() => { setEditing(false); restart() }}>
            Done
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="tab-prompter">
      <div className="prompter-eyeline">EYE-CONTACT LEVEL · keep reading here</div>
      <div
        ref={viewportRef}
        className="prompter-viewport"
        // Manual scrolling pauses auto-scroll and moves the start point.
        onWheel={() => setPlaying(false)}
        style={{ fontSize: settings.prompterFontSize, transform: settings.prompterMirror ? "scaleX(-1)" : undefined }}
      >
        {settings.prompterScript.split(/\n{2,}/).map((para, i) => (
          <p key={i}>{para}</p>
        ))}
        <p className="prompter-end">End of script</p>
      </div>
      <div className="prompter-bar">
        <button className="prompter-btn primary" onClick={togglePlay}>
          {playing ? <Pause size={12} fill="currentColor" /> : <Play size={12} fill="currentColor" />}
          {playing ? "Pause" : "Play"}
        </button>
        <button className="prompter-btn" onClick={restart} title="Back to top">
          <RotateCcw size={12} />
        </button>
        <button className="prompter-btn" onClick={() => nudgeSpeed(-4)} title="Slower">
          <Minus size={12} />
        </button>
        <span className="prompter-speed">{wpm(settings.prompterSpeed)} wpm</span>
        <button className="prompter-btn" onClick={() => nudgeSpeed(4)} title="Faster">
          <Plus size={12} />
        </button>
        <input
          type="range"
          min={12}
          max={30}
          value={settings.prompterFontSize}
          onChange={(e) => setSettings({ prompterFontSize: parseInt(e.target.value, 10) })}
          title="Text size"
        />
        <button
          className={`prompter-btn ${settings.prompterMirror ? "on" : ""}`}
          onClick={() => setSettings({ prompterMirror: !settings.prompterMirror })}
          title="Mirror text for a beam-splitter rig"
        >
          <FlipHorizontal size={12} />
        </button>
        <span className="muted">
          {words} words · ~{Math.max(1, Math.round(minutes))} min
        </span>
        <button className="prompter-btn" onClick={() => { setPlaying(false); setEditing(true) }} title="Edit script">
          <Pencil size={12} />
        </button>
      </div>
    </div>
  )
}
