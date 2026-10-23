export type Phase = "focus" | "shortBreak" | "longBreak"

export const PHASE_MINUTES: Record<Phase, number> = { focus: 25, shortBreak: 5, longBreak: 15 }
export const PHASE_LABEL: Record<Phase, string> = { focus: "Focus", shortBreak: "Break", longBreak: "Long Break" }
/** Every 4th finished focus earns a long break. */
export const SESSIONS_PER_LONG_BREAK = 4

/** `focusDone` already includes the focus that just finished; a skipped focus never earns the long break. */
export function nextPhase(phase: Phase, focusDone: number, skipped = false): Phase {
  if (phase !== "focus") return "focus"
  if (skipped) return "shortBreak"
  return focusDone % SESSIONS_PER_LONG_BREAK === 0 ? "longBreak" : "shortBreak"
}
