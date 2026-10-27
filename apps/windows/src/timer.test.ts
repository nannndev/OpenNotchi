import assert from "node:assert/strict"
import { test } from "node:test"

// The store schedules its tick on `window`; node has none, so lend it the global timers.
;(globalThis as { window?: unknown }).window = globalThis

const { formatCountdown, isActive, progress, remaining, snapshot, timer } = await import("./timer.ts")

test("countdown text is mm:ss", () => {
  assert.equal(formatCountdown(0), "00:00")
  assert.equal(formatCountdown(65), "01:05")
  assert.equal(formatCountdown(25 * 60), "25:00")
})

test("remaining and progress follow endsAt while running and pausedRemaining while paused", () => {
  const base = { total: 600, finished: false, pomodoro: false, phase: "focus" as const, focusToday: 0 }
  const now = 1_000_000
  const running = { ...base, endsAt: now + 300_000, pausedRemaining: null }
  assert.equal(remaining(running, now), 300)
  assert.equal(progress(running, now), 0.5)
  assert.ok(isActive(running))

  const paused = { ...base, endsAt: null, pausedRemaining: 120 }
  assert.equal(remaining(paused, now), 120)
  assert.ok(isActive(paused))

  const idle = { ...base, endsAt: null, pausedRemaining: null }
  assert.equal(remaining(idle, now), 600)
  assert.ok(!isActive(idle), "an untouched timer is not shown in the closed pill")
})

test("pausing keeps the time left, and the closed pill keeps showing it", () => {
  timer.setPreset(5)
  timer.toggleRun()
  assert.notEqual(snapshot().endsAt, null)
  timer.toggleRun()
  const s = snapshot()
  assert.equal(s.endsAt, null)
  assert.equal(s.pausedRemaining, 300)
  assert.ok(isActive(s))

  timer.addMinute()
  assert.equal(remaining(snapshot()), 360)

  timer.reset()
  assert.ok(!isActive(snapshot()))
})

test("skipping a pomodoro focus starts a running short break", () => {
  timer.togglePomodoro()
  timer.skip()
  const s = snapshot()
  assert.equal(s.phase, "shortBreak")
  assert.equal(s.total, 5 * 60)
  assert.notEqual(s.endsAt, null)
  timer.reset()
  timer.togglePomodoro()
})
