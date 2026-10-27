import { Brain, Coffee, Pause, Timer } from "lucide-react"
import { SESSIONS_PER_LONG_BREAK } from "./pomodoro"
import { formatCountdown, progress, remaining, type TimerState } from "./timer"

/**
 * The running timer in the closed pill, like macOS ClosedTimerView: a ring that empties as time
 * runs out (colored by Pomodoro phase) on the left, the countdown with session dots on the right.
 * The last minute turns orange and pulses; a paused timer dims.
 */
export function ClosedTimer({ t }: { t: TimerState }) {
  const running = t.endsAt !== null
  const left = remaining(t)
  const urgent = running && left <= 60
  const onBreak = t.pomodoro && t.phase !== "focus"
  // Breaks are green so they read as "rest"; focus uses the accent.
  const tint = urgent ? "var(--orange)" : onBreak ? "var(--green)" : "var(--accent)"
  const Icon = !running ? Pause : t.pomodoro ? (onBreak ? Coffee : Brain) : Timer

  const r = 9
  const circumference = 2 * Math.PI * r
  const done = t.focusToday % SESSIONS_PER_LONG_BREAK
  const [mm, ss] = formatCountdown(left).split(":")

  return (
    <div className={`closed-timer ${running ? "" : "paused"} ${urgent ? "urgent" : ""}`} style={{ color: tint }}>
      <span className="closed-timer-ring">
        <svg width="24" height="24" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r={r} className="track" />
          <circle
            cx="12"
            cy="12"
            r={r}
            className="fill"
            strokeDasharray={circumference}
            strokeDashoffset={circumference * progress(t)}
          />
        </svg>
        <Icon size={10} strokeWidth={2.6} />
      </span>
      <span className="closed-timer-label">{t.pomodoro ? (onBreak ? "Break" : "Focus") : running ? "Timer" : "Paused"}</span>
      <span className="closed-timer-right">
        <span className="closed-timer-time">
          {mm}
          <span className="colon">:</span>
          {ss}
        </span>
        {t.pomodoro && (
          <span className="closed-timer-dots">
            {Array.from({ length: SESSIONS_PER_LONG_BREAK }, (_, i) => (
              <i key={i} className={i < done ? "on" : ""} />
            ))}
          </span>
        )}
      </span>
    </div>
  )
}
