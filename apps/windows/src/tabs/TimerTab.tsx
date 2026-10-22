import { Pause, Play, Plus, RotateCcw } from "lucide-react"
import { useEffect, useRef, useState } from "react"

const PRESETS = [1, 5, 10, 15, 25, 50]

export function TimerTab() {
  const [totalSeconds, setTotalSeconds] = useState(25 * 60)
  const [remainingSeconds, setRemainingSeconds] = useState(25 * 60)
  const [isRunning, setIsRunning] = useState(false)
  const [didFinish, setDidFinish] = useState(false)
  const audioContextRef = useRef<AudioContext | null>(null)

  useEffect(() => {
    let interval: number | undefined
    if (isRunning && remainingSeconds > 0) {
      interval = window.setInterval(() => {
        setRemainingSeconds((prev) => {
          if (prev <= 1) {
            setIsRunning(false)
            setDidFinish(true)
            playChime()
            return 0
          }
          return prev - 1
        })
      }, 1000)
    }
    return () => clearInterval(interval)
  }, [isRunning, remainingSeconds])

  const playChime = () => {
    try {
      const ctx = audioContextRef.current || new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)()
      audioContextRef.current = ctx
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = "sine"
      osc.frequency.setValueAtTime(880, ctx.currentTime) // A5
      osc.frequency.exponentialRampToValueAtTime(1760, ctx.currentTime + 0.3)
      gain.gain.setValueAtTime(0.3, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.6)
      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.start()
      osc.stop(ctx.currentTime + 0.6)
    } catch {}
  }

  const setPreset = (mins: number) => {
    setIsRunning(false)
    setDidFinish(false)
    setTotalSeconds(mins * 60)
    setRemainingSeconds(mins * 60)
  }

  const toggleRun = () => {
    if (didFinish) {
      setRemainingSeconds(totalSeconds)
      setDidFinish(false)
      setIsRunning(true)
      return
    }
    setIsRunning(!isRunning)
  }

  const addMinute = () => {
    setRemainingSeconds((r) => r + 60)
    setTotalSeconds((t) => t + 60)
  }

  const reset = () => {
    setIsRunning(false)
    setDidFinish(false)
    setRemainingSeconds(totalSeconds)
  }

  const progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0
  const minutes = Math.floor(remainingSeconds / 60)
  const seconds = remainingSeconds % 60
  const formatted = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`

  const radius = 48
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - progress * circumference

  return (
    <div className="tab-timer">
      <div className="timer-presets">
        {PRESETS.map((p) => {
          const isSelected = totalSeconds === p * 60 && !isRunning
          return (
            <button
              key={p}
              className={`preset-btn ${isSelected ? "selected" : ""}`}
              onClick={() => setPreset(p)}
              disabled={isRunning}
            >
              {p}m
            </button>
          )
        })}
      </div>

      <div className="timer-ring-container">
        <svg className="timer-ring" width="124" height="124" viewBox="0 0 124 124">
          <circle
            className="ring-bg"
            cx="62"
            cy="62"
            r={radius}
            strokeWidth="7"
          />
          <circle
            className={`ring-progress ${didFinish ? "finished" : ""}`}
            cx="62"
            cy="62"
            r={radius}
            strokeWidth="7"
            strokeDasharray={circumference}
            strokeDashoffset={strokeDashoffset}
            strokeLinecap="round"
          />
        </svg>

        <div className="timer-center-text">
          <span className={`timer-digits ${didFinish ? "pulse" : ""}`}>
            {didFinish ? "Done!" : formatted}
          </span>
          <span className="timer-status">
            {didFinish ? "Time's up" : isRunning ? "Running" : remainingSeconds < totalSeconds ? "Paused" : "Ready"}
          </span>
        </div>
      </div>

      <div className="timer-actions">
        <button
          className={`timer-action-btn primary ${isRunning ? "running" : ""}`}
          onClick={toggleRun}
          title={isRunning ? "Pause" : "Start"}
        >
          {isRunning ? <Pause size={14} fill="currentColor" /> : <Play size={14} fill="currentColor" />}
          <span>{isRunning ? "Pause" : remainingSeconds < totalSeconds && !didFinish ? "Resume" : "Start"}</span>
        </button>
        <button className="timer-action-btn secondary" onClick={addMinute} title="Add 1 minute">
          <Plus size={13} />
          <span>+1 min</span>
        </button>
        <button
          className="timer-action-btn secondary"
          onClick={reset}
          disabled={!isRunning && remainingSeconds === totalSeconds && !didFinish}
          title="Reset"
        >
          <RotateCcw size={13} />
          <span>Reset</span>
        </button>
      </div>
    </div>
  )
}
