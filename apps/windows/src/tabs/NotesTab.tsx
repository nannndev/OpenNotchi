import { invoke } from "@tauri-apps/api/core"
import { Coffee } from "lucide-react"
import { useEffect, useState } from "react"
import { useSettings } from "../settings"

export function NotesTab({ awake, onToggleAwake }: { awake: boolean; onToggleAwake: (val: boolean) => void }) {
  const [settings, setSettings] = useSettings()
  const [duration, setDuration] = useState<string>("off")

  useEffect(() => {
    if (!awake) setDuration("off")
  }, [awake])

  const setKeepAwakeDuration = async (minutes: number | null) => {
    try {
      if (minutes === null) {
        // Toggle or set infinite
        await invoke("set_keep_awake", { on: true })
        onToggleAwake(true)
        setDuration("infinite")
      } else {
        await invoke("set_keep_awake", { on: true })
        onToggleAwake(true)
        setDuration(`${minutes}m`)
        setTimeout(() => {
          invoke("set_keep_awake", { on: false })
          onToggleAwake(false)
          setDuration("off")
        }, minutes * 60 * 1000)
      }
    } catch (e) {
      console.error(e)
    }
  }

  const turnOffAwake = async () => {
    await invoke("set_keep_awake", { on: false }).catch(() => {})
    onToggleAwake(false)
    setDuration("off")
  }

  return (
    <div className="tab-notes">
      <div className="notes-editor-wrap">
        <textarea
          className="notes-editor"
          placeholder="Quick scratchpad notes… (auto-saved)"
          value={settings.notesText}
          onChange={(e) => setSettings({ notesText: e.target.value })}
        />
        <div className="notes-footer">
          <span>{settings.notesText.length} characters</span>
        </div>
      </div>

      <div className="notes-sidebar">
        <div className="sidebar-group">
          <div className="sidebar-title">
            <Coffee size={13} />
            <span>Keep Awake</span>
          </div>

          <div className="awake-buttons">
            <button
              className={`awake-btn ${awake && duration === "15m" ? "active" : ""}`}
              onClick={() => setKeepAwakeDuration(15)}
            >
              15 min
            </button>
            <button
              className={`awake-btn ${awake && duration === "60m" ? "active" : ""}`}
              onClick={() => setKeepAwakeDuration(60)}
            >
              1 hour
            </button>
            <button
              className={`awake-btn ${awake && duration === "120m" ? "active" : ""}`}
              onClick={() => setKeepAwakeDuration(120)}
            >
              2 hours
            </button>
            <button
              className={`awake-btn ${awake && duration === "infinite" ? "active" : ""}`}
              onClick={() => setKeepAwakeDuration(null)}
            >
              Indefinite
            </button>
            {awake && (
              <button className="awake-btn turn-off" onClick={turnOffAwake}>
                Turn Off
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
