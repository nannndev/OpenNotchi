import type { AgentState } from "./ai"

export const REST_HEIGHTS = [0.42, 0.68, 1.0, 0.68, 0.42]

export type NotchiMood =
  | "idle"
  | "sleepy"
  | "busy"
  | "happy"
  | "alert"
  | "vibing"
  | "tired"
  | "loved"

export interface NotchiContext {
  agentStates: (AgentState | "needsYou")[]
  musicPlaying: boolean
  batteryLow?: boolean
  idleFor: number // seconds
  hour: number
  petted: boolean
}


/**
 * Height of bar `i` (0...4) as a fraction of the full height.
 * Clamped within 0.12...1.0.
 */
function crest(x: number, center: number, width: number): number {
  return Math.exp(-Math.pow(x - center, 2) / width)
}

export function notchiLevel(i: number, mood: NotchiMood, t: number, gaze: number): number {
  const x = i
  const rest = REST_HEIGHTS[i] ?? 0.5
  let val = rest

  switch (mood) {
    case "idle": {
      // The tallest bar slides toward the pointer, and the whole wave breathes.
      const center = 2 + gaze * 1.6
      val = (0.32 + 0.66 * crest(x, center, 1.6)) * (1 + 0.07 * Math.sin(t * 2.2 + x * 0.6))
      break
    }
    case "sleepy": {
      // Low and flat, rising and falling slowly like breathing.
      val = rest * 0.32 + 0.06 * (1 + Math.sin(t * 1.3 + x * 0.35))
      break
    }
    case "busy": {
      // A crest sweeping back and forth, like a scanner.
      const center = 2 + 2.2 * Math.sin(t * 4)
      val = 0.26 + 0.74 * crest(x, center, 0.8)
      break
    }
    case "happy": {
      // A cascade of hops from left to right.
      val = rest * (0.72 + 0.4 * Math.abs(Math.sin(t * 6 - x * 0.65)))
      break
    }
    case "alert": {
      // All tall and jittery.
      val = 0.82 + 0.18 * Math.sin(t * 24 + x * 1.3)
      break
    }
    case "vibing": {
      // An equalizer: each bar on its own beat.
      const beat = Math.abs(Math.sin(t * (4.6 + x * 1.15) + x * 1.7)) * 0.6 + Math.abs(Math.sin(t * 2.3 + x)) * 0.4
      val = 0.22 + 0.78 * beat
      break
    }
    case "tired": {
      // Drooping, with the last bar flickering like a dying battery.
      const flicker = i === 4 ? (Math.sin(t * 9) > 0.55 ? 0.35 : 0.12) : rest * 0.5
      val = flicker + 0.04 * Math.sin(t * 1.6 + x)
      break
    }
    case "loved": {
      // A heartbeat: lub-dub, then rest.
      const p = t % 1.1
      const beat =
        p < 0.12
          ? Math.sin((p / 0.12) * Math.PI)
          : p > 0.22 && p < 0.34
          ? 0.7 * Math.sin(((p - 0.22) / 0.12) * Math.PI)
          : 0
      val = rest * (0.68 + 0.36 * beat)
      break
    }
  }

  return Math.max(0.12, Math.min(1.0, val))
}

/**
 * Determine Notchi's current mood based on system context.
 * Priority: alert > loved > busy > tired > vibing > happy > sleepy > idle.
 */
export function notchiMood(c: NotchiContext): NotchiMood {
  if (c.agentStates.includes("needs_you") || c.agentStates.includes("needsYou")) return "alert"
  if (c.petted) return "loved"
  if (c.agentStates.includes("working")) return "busy"
  if (c.batteryLow) return "tired"
  if (c.musicPlaying) return "vibing"
  if (c.agentStates.includes("done")) return "happy"
  if (c.idleFor > 10 * 60 || c.hour >= 23 || c.hour < 5) return "sleepy"
  return "idle"
}

/**
 * Filters recent agent states so a "done" older than doneFor seconds is treated as idle.
 */
export function filterRecentAgentStates(
  sessions: { state: AgentState | "needsYou"; updatedAt: number }[],
  now: number,
  doneForSeconds = 8
): AgentState[] {
  return sessions.map((s) => {
    const st: AgentState = s.state === "needsYou" ? "needs_you" : s.state
    if (st === "done" && (now - s.updatedAt) / 1000 > doneForSeconds) {
      return "idle"
    }
    return st
  })
}


/**
 * Synthesizes a soft pop sound with WebAudio when Notchi is petted.
 */
let audioCtx: AudioContext | null = null

export function playPetPopSound(): void {
  try {
    if (!audioCtx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext
      audioCtx = new AudioCtx()
    }
    if (audioCtx.state === "suspended") {
      audioCtx.resume().catch(() => {})
    }
    const t = audioCtx.currentTime
    const osc = audioCtx.createOscillator()
    const gain = audioCtx.createGain()

    osc.type = "sine"
    osc.frequency.setValueAtTime(440, t)
    osc.frequency.exponentialRampToValueAtTime(880, t + 0.08)

    gain.gain.setValueAtTime(0.25, t)
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.09)

    osc.connect(gain)
    gain.connect(audioCtx.destination)

    osc.start(t)
    osc.stop(t + 0.09)
  } catch {
    // AudioContext may be restricted before user gesture or unavailable
  }
}
