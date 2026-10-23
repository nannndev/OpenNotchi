import { Coffee, Pause, Play, Plus, RotateCcw, SkipForward, Timer } from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { nextPhase, PHASE_LABEL, PHASE_MINUTES, SESSIONS_PER_LONG_BREAK, type Phase } from "../pomodoro"

const PRESETS = [1, 5, 10, 15, 25, 50]

export function TimerTab() {
  const [totalSeconds, setTotalSeconds] = useState(25 * 60)
  const [remainingSeconds, setRemainingSeconds] = useState(25 * 60)
  const [isRunning, setIsRunning] = useState(false)
  const [didFinish, setDidFinish] = useState(false)
  const [pomodoro, setPomodoro] = useState(false)
  const [phase, setPhase] = useState<Phase>("focus")
  const [focusToday, setFocusToday] = useState(0)
  const audioContextRef = useRef<AudioContext | null>(null)
  // Read inside the interval callback, which only sees the state from when it was created.
  const pomoRef = useRef({ pomodoro, phase, focusToday })
  pomoRef.current = { pomodoro, phase, focusToday }

  const startPhase = (next: Phase) => {
    setPhase(next)
    setTotalSeconds(PHASE_MINUTES[next] * 60)
    setRemainingSeconds(PHASE_MINUTES[next] * 60)
    setDidFinish(false)
    setIsRunning(true)
  }

  const finishPhase = () => {
    const { pomodoro, phase, focusToday } = pomoRef.current
    playChime()
    if (!pomodoro) {
      setIsRunning(false)
      setDidFinish(true)
      return
    }
    const done = phase === "focus" ? focusToday + 1 : focusToday
    setFocusToday(done)
    startPhase(nextPhase(phase, done))
  }

  useEffect(() => {
    let interval: number | undefined
    if (isRunning && remainingSeconds > 0) {
      interval = window.setInterval(() => {
        setRemainingSeconds((prev) => {
          if (prev <= 1) {
            // Deferred so state updates don't run inside this updater.
            setTimeout(finishPhase)
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

  const togglePomodoro = () => {
    const on = !pomodoro
    const mins = on ? PHASE_MINUTES.focus : 25
    setPomodoro(on)
    setPhase("focus")
    setIsRunning(false)
    setDidFinish(false)
    setTotalSeconds(mins * 60)
    setRemainingSeconds(mins * 60)
  }

  const skip = () => startPhase(nextPhase(phase, focusToday, true))

  // Position inside the current 4-session round; the long break shows the full round.
  const roundDots = phase === "longBreak" ? SESSIONS_PER_LONG_BREAK : focusToday % SESSIONS_PER_LONG_BREAK
  const isBreak = pomodoro && phase !== "focus"

  const progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0
  const minutes = Math.floor(remainingSeconds / 60)
  const seconds = remainingSeconds % 60
  const formatted = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`

  const radius = 48
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - progress * circumference

  return (
    <div className="tab-timer">
      <div className="timer-side">
        <button className={`preset-btn pomo-toggle ${pomodoro ? "selected" : ""}`} onClick={togglePomodoro}>
          <Timer size={11} />
          Pomodoro
        </button>
        {pomodoro ? (
          <div className="pomo-info">
            {(["focus", "shortBreak", "longBreak"] as const).map((p) => (
              <div key={p} className={`pomo-phase ${phase === p ? "current" : ""}`}>
                <span>{PHASE_LABEL[p]}</span>
                <span className="muted">{PHASE_MINUTES[p]}m</span>
              </div>
            ))}
            <div className="pomo-round">
              {Array.from({ length: SESSIONS_PER_LONG_BREAK }, (_, i) => (
                <span key={i} className={`pomo-dot ${i < roundDots ? "filled" : ""}`} />
              ))}
              <span className="muted">{focusToday} today</span>
            </div>
          </div>
        ) : (
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
        )}
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
            className={`ring-progress ${didFinish || isBreak ? "finished" : ""}`}
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
            {isBreak && <Coffee size={9} />}{" "}
            {didFinish
              ? "Time's up"
              : pomodoro
                ? PHASE_LABEL[phase] + (!isRunning && remainingSeconds < totalSeconds ? " · Paused" : "")
                : isRunning ? "Running" : remainingSeconds < totalSeconds ? "Paused" : "Ready"}
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
        {pomodoro ? (
          <button className="timer-action-btn secondary" onClick={skip} title="Skip to next phase">
            <SkipForward size={13} />
            <span>Skip</span>
          </button>
        ) : (
          <button className="timer-action-btn secondary" onClick={addMinute} title="Add 1 minute">
            <Plus size={13} />
            <span>+1 min</span>
          </button>
        )}
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
