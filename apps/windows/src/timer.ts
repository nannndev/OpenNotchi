// Shared countdown timer (Timer tab + closed pill), ported from the macOS TimerManager.
// It lives outside React so it keeps running when the Timer tab is not shown.

import { useSyncExternalStore } from "react"
import { nextPhase, PHASE_MINUTES, type Phase } from "./pomodoro.ts"

export type TimerState = {
  /** Length of the current countdown in seconds. */
  total: number
  /** Unix ms when it ends while running, else null. */
  endsAt: number | null
  /** Seconds left while paused part-way, else null. */
  pausedRemaining: number | null
  finished: boolean
  pomodoro: boolean
  phase: Phase
  focusToday: number
}

/** Seconds left at `now`. */
export function remaining(s: TimerState, now = Date.now()): number {
  if (s.endsAt !== null) return Math.max(0, Math.ceil((s.endsAt - now) / 1000))
  return s.pausedRemaining ?? s.total
}

/** Running or paused part-way: what the closed pill shows. */
export function isActive(s: TimerState): boolean {
  return s.endsAt !== null || s.pausedRemaining !== null
}

/** 0 at the start, 1 when time is up. */
export function progress(s: TimerState, now = Date.now()): number {
  return s.total > 0 ? 1 - remaining(s, now) / s.total : 0
}

export function formatCountdown(seconds: number): string {
  const m = Math.floor(seconds / 60)
  return `${String(m).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`
}

let state: TimerState = {
  total: 25 * 60,
  endsAt: null,
  pausedRemaining: null,
  finished: false,
  pomodoro: false,
  phase: "focus",
  focusToday: 0,
}
const listeners = new Set<() => void>()
let ticker: number | undefined

function set(patch: Partial<TimerState>) {
  state = { ...state, ...patch }
  listeners.forEach((l) => l())
  // One interval for the whole app, only while something is counting down.
  if (state.endsAt !== null && ticker === undefined) ticker = window.setInterval(tick, 250)
  if (state.endsAt === null && ticker !== undefined) ticker = (clearInterval(ticker), undefined)
}

function tick() {
  if (state.endsAt !== null && remaining(state) <= 0) finishPhase()
  // A fresh object, so useSyncExternalStore re-renders the countdown.
  else set({})
}

function startPhase(phase: Phase) {
  const total = PHASE_MINUTES[phase] * 60
  set({ phase, total, endsAt: Date.now() + total * 1000, pausedRemaining: null, finished: false })
}

function finishPhase() {
  playChime()
  if (!state.pomodoro) return set({ endsAt: null, pausedRemaining: null, finished: true })
  const done = state.phase === "focus" ? state.focusToday + 1 : state.focusToday
  set({ focusToday: done })
  startPhase(nextPhase(state.phase, done))
}

let audio: AudioContext | null = null
function playChime() {
  try {
    audio ??= new AudioContext()
    const osc = audio.createOscillator()
    const gain = audio.createGain()
    osc.type = "sine"
    osc.frequency.setValueAtTime(880, audio.currentTime) // A5
    osc.frequency.exponentialRampToValueAtTime(1760, audio.currentTime + 0.3)
    gain.gain.setValueAtTime(0.3, audio.currentTime)
    gain.gain.exponentialRampToValueAtTime(0.01, audio.currentTime + 0.6)
    osc.connect(gain)
    gain.connect(audio.destination)
    osc.start()
    osc.stop(audio.currentTime + 0.6)
  } catch {}
}

export const timer = {
  setPreset(minutes: number) {
    set({ total: minutes * 60, endsAt: null, pausedRemaining: null, finished: false })
  },
  toggleRun() {
    if (state.endsAt !== null) return set({ endsAt: null, pausedRemaining: remaining(state) })
    const left = state.finished ? state.total : remaining(state)
    set({ endsAt: Date.now() + left * 1000, pausedRemaining: null, finished: false })
  },
  addMinute() {
    if (state.endsAt !== null) set({ endsAt: state.endsAt + 60_000, total: state.total + 60 })
    else set({ pausedRemaining: remaining(state) + 60, total: state.total + 60 })
  },
  reset() {
    set({ endsAt: null, pausedRemaining: null, finished: false })
  },
  togglePomodoro() {
    const on = !state.pomodoro
    set({ pomodoro: on, phase: "focus", total: (on ? PHASE_MINUTES.focus : 25) * 60, endsAt: null, pausedRemaining: null, finished: false })
  },
  skip() {
    startPhase(nextPhase(state.phase, state.focusToday, true))
  },
}

const subscribe = (l: () => void) => (listeners.add(l), () => void listeners.delete(l))
/** The current state, outside React. */
export const snapshot = () => state

/** The shared timer; re-renders on every change and every tick while running. */
export function useTimer(): TimerState {
  return useSyncExternalStore(subscribe, snapshot)
}
