import type { AgentSession, AgentState } from "./ai"

export type BannerKind = "success" | "attention" | "reminder" | "info"

export interface Banner {
  id?: string
  kind: BannerKind
  icon: "checkmark" | "hand" | "bell" | "info" | "sparkles" | string
  tint: string
  badge: string
  title: string
  subtitle?: string
  actionTitle?: string
  onAction?: () => void
  duration?: number // in seconds
}

/** Standard durations per BannerKind from macOS OpenNotchi */
export function defaultBannerDuration(kind: BannerKind): number {
  switch (kind) {
    case "success":
      return 5
    case "attention":
      return 10
    case "reminder":
      return 12
    case "info":
      return 12
  }
}

const TOOL_NAMES: Record<string, string> = {
  claude: "Claude Code",
  codex: "Codex",
  antigravity: "Antigravity",
  commandcode: "Command Code",
}

/** Creates a Banner when an agent session transitions to done or needs_you. */
export function transitionBanner(prev: AgentState | undefined, next: AgentSession): Banner | null {
  const isDone = next.state === "done" && (prev === "working" || prev === "needs_you")
  const isNeeds = next.state === "needs_you" && prev !== "needs_you" && prev !== undefined

  if (!isDone && !isNeeds) return null

  const kind: BannerKind = isDone ? "success" : "attention"
  const toolName = TOOL_NAMES[next.tool] ?? "Agent"
  const title = `${toolName} ${isDone ? "finished" : "needs you"} · ${next.project}`

  return {
    kind,
    icon: isDone ? "checkmark" : "hand",
    tint: isDone ? "var(--green, #22c55e)" : "var(--orange, #f97316)",
    badge: isDone ? "Done" : "Needs you",
    title,
    subtitle: next.message ?? (isDone ? "All tasks completed" : "Waiting for your input"),
    duration: defaultBannerDuration(kind),
  }
}

/**
 * Calculates remaining progress fraction [0.0, 1.0] for the countdown bar.
 * If paused, remaining time freezes at pausedAt.
 */
export function bannerRemaining(
  shownAt: number,
  durationSec: number,
  now: number,
  pausedAt?: number | null,
  totalPausedMs: number = 0
): number {
  if (durationSec <= 0) return 0
  const effectiveNow = pausedAt != null ? pausedAt : now
  const elapsedMs = Math.max(0, effectiveNow - shownAt - totalPausedMs)
  const totalMs = durationSec * 1000
  return Math.max(0, Math.min(1, 1 - elapsedMs / totalMs))
}

let audioCtx: AudioContext | null = null

function getAudioContext(): AudioContext | null {
  if (typeof window === "undefined") return null
  const AudioCtx =
    window.AudioContext ||
    (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
  if (!AudioCtx) return null
  try {
    if (!audioCtx || audioCtx.state === "closed") {
      audioCtx = new AudioCtx()
    }
    if (audioCtx.state === "suspended") {
      audioCtx.resume().catch(() => {})
    }
    return audioCtx
  } catch {
    return null
  }
}

/**
 * Synthesize notification sounds using WebAudio (no external audio files).
 * - success: soft "glass" chime (two harmonized sine tones with soft decay)
 * - attention: brighter two-note "hero" chime (D5 -> A5 with bright envelope)
 * - reminder: single clear "ping" (high sine tone)
 * - info: silent
 */
export function playBannerSound(kind: BannerKind, enabled: boolean = true): void {
  if (!enabled || kind === "info") return

  try {
    const ctx = getAudioContext()
    if (!ctx) return

    const now = ctx.currentTime

    if (kind === "success") {
      // Soft "glass" chime: gentle, bell-like high harmonic pair
      const gain = ctx.createGain()
      gain.connect(ctx.destination)
      gain.gain.setValueAtTime(0.001, now)
      gain.gain.linearRampToValueAtTime(0.12, now + 0.015)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.6)

      const osc1 = ctx.createOscillator()
      osc1.type = "sine"
      osc1.frequency.setValueAtTime(1046.5, now) // C6
      osc1.connect(gain)

      const osc2 = ctx.createOscillator()
      osc2.type = "sine"
      osc2.frequency.setValueAtTime(2093.0, now) // C7 harmonic
      osc2.connect(gain)

      osc1.start(now)
      osc2.start(now)
      osc1.stop(now + 0.65)
      osc2.stop(now + 0.65)
    } else if (kind === "attention") {
      // Brighter two-note "hero" chime: note 1 (D5) then note 2 (A5)
      const gain1 = ctx.createGain()
      gain1.connect(ctx.destination)
      gain1.gain.setValueAtTime(0.001, now)
      gain1.gain.linearRampToValueAtTime(0.14, now + 0.015)
      gain1.gain.exponentialRampToValueAtTime(0.001, now + 0.15)

      const osc1 = ctx.createOscillator()
      osc1.type = "sine"
      osc1.frequency.setValueAtTime(587.33, now) // D5
      osc1.connect(gain1)
      osc1.start(now)
      osc1.stop(now + 0.16)

      const note2Time = now + 0.11
      const gain2 = ctx.createGain()
      gain2.connect(ctx.destination)
      gain2.gain.setValueAtTime(0.001, note2Time)
      gain2.gain.linearRampToValueAtTime(0.18, note2Time + 0.02)
      gain2.gain.exponentialRampToValueAtTime(0.0001, note2Time + 0.7)

      const osc2 = ctx.createOscillator()
      osc2.type = "triangle"
      osc2.frequency.setValueAtTime(880.0, note2Time) // A5 hero note
      osc2.connect(gain2)
      osc2.start(note2Time)
      osc2.stop(note2Time + 0.75)
    } else if (kind === "reminder") {
      // Single clear "ping": high pure tone with quick drop
      const gain = ctx.createGain()
      gain.connect(ctx.destination)
      gain.gain.setValueAtTime(0.001, now)
      gain.gain.linearRampToValueAtTime(0.15, now + 0.008)
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.45)

      const osc = ctx.createOscillator()
      osc.type = "sine"
      osc.frequency.setValueAtTime(1760.0, now) // A6
      osc.connect(gain)
      osc.start(now)
      osc.stop(now + 0.5)
    }
  } catch {
    // AudioContext blocked or not supported
  }
}
