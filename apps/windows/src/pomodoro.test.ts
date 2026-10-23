import assert from "node:assert/strict"
import { test } from "node:test"
import { nextPhase } from "./pomodoro.ts"

test("nextPhase cycles focus/breaks with a long break every 4th focus", () => {
  assert.equal(nextPhase("focus", 1), "shortBreak")
  assert.equal(nextPhase("focus", 4), "longBreak")
  assert.equal(nextPhase("focus", 8), "longBreak")
  assert.equal(nextPhase("shortBreak", 1), "focus")
  assert.equal(nextPhase("longBreak", 4), "focus")
  assert.equal(nextPhase("focus", 0, true), "shortBreak")
})
