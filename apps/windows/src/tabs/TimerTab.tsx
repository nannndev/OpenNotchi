import { Coffee, Pause, Play, Plus, RotateCcw, SkipForward, Timer } from "lucide-react"
import { PHASE_LABEL, PHASE_MINUTES, SESSIONS_PER_LONG_BREAK } from "../pomodoro"
import { formatCountdown, remaining, timer, useTimer } from "../timer"

const PRESETS = [1, 5, 10, 15, 25, 50]

export function TimerTab() {
  const t = useTimer()
  const { pomodoro, phase, focusToday, finished: didFinish } = t
  const isRunning = t.endsAt !== null
  const totalSeconds = t.total
  const remainingSeconds = remaining(t)
  const { setPreset, toggleRun, addMinute, reset, togglePomodoro, skip } = timer

  // Position inside the current 4-session round; the long break shows the full round.
  const roundDots = phase === "longBreak" ? SESSIONS_PER_LONG_BREAK : focusToday % SESSIONS_PER_LONG_BREAK
  const isBreak = pomodoro && phase !== "focus"

  const progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0
  const formatted = formatCountdown(remainingSeconds)

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
