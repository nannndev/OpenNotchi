import assert from "node:assert/strict"
import test from "node:test"
import {
  filterRecentAgentStates,
  notchiLevel,
  notchiMood,
  REST_HEIGHTS,
  type NotchiContext,
  type NotchiMood,
} from "./notchi.ts"

test("REST_HEIGHTS matches the 5-bar brand waveform", () => {
  assert.equal(REST_HEIGHTS.length, 5)
  assert.equal(REST_HEIGHTS[2], 1.0)
  assert.equal(REST_HEIGHTS[0], REST_HEIGHTS[4])
  assert.equal(REST_HEIGHTS[1], REST_HEIGHTS[3])
})

test("notchiLevel clamps between 0.12 and 1.0 for every mood and bar", () => {
  const moods: NotchiMood[] = ["idle", "sleepy", "busy", "happy", "alert", "vibing", "tired", "loved"]
  const times = [0, 0.5, 1.0, 1.5, 2.7, 5.0, 10.3]
  const gazes = [-1.0, -0.5, 0, 0.5, 1.0]

  for (const mood of moods) {
    for (let i = 0; i < 5; i++) {
      for (const t of times) {
        for (const gaze of gazes) {
          const lvl = notchiLevel(i, mood, t, gaze)
          assert.ok(lvl >= 0.12, `level ${lvl} < 0.12 for mood ${mood}, bar ${i}, t ${t}`)
          assert.ok(lvl <= 1.0, `level ${lvl} > 1.0 for mood ${mood}, bar ${i}, t ${t}`)
        }
      }
    }
  }
})

test("idle crest moves toward the gaze", () => {
  const t = 1.0
  // When looking far left (gaze = -1), left bar (i = 0) is taller than right bar (i = 4)
  const leftGazeBar0 = notchiLevel(0, "idle", t, -1)
  const leftGazeBar4 = notchiLevel(4, "idle", t, -1)
  assert.ok(leftGazeBar0 > leftGazeBar4, `expected left bar (${leftGazeBar0}) > right bar (${leftGazeBar4}) when gazing left`)

  // When looking far right (gaze = 1), right bar (i = 4) is taller than left bar (i = 0)
  const rightGazeBar0 = notchiLevel(0, "idle", t, 1)
  const rightGazeBar4 = notchiLevel(4, "idle", t, 1)
  assert.ok(rightGazeBar4 > rightGazeBar0, `expected right bar (${rightGazeBar4}) > left bar (${rightGazeBar0}) when gazing right`)
})

test("mood priority: alert > loved > busy > tired > vibing > happy > sleepy > idle", () => {
  const base: NotchiContext = {
    agentStates: [],
    musicPlaying: false,
    idleFor: 0,
    hour: 12,
    petted: false,
  }

  // 1. Alert beats everything
  assert.equal(
    notchiMood({ ...base, agentStates: ["needsYou", "working"], petted: true, musicPlaying: true }),
    "alert"
  )

  // 2. Loved beats working
  assert.equal(
    notchiMood({ ...base, agentStates: ["working"], petted: true, musicPlaying: true }),
    "loved"
  )

  // 3. Busy beats tired and music
  assert.equal(
    notchiMood({ ...base, agentStates: ["working"], batteryLow: true, musicPlaying: true }),
    "busy"
  )

  // 4. Tired beats music
  assert.equal(
    notchiMood({ ...base, batteryLow: true, musicPlaying: true }),
    "tired"
  )

  // 5. Music playing is vibing
  assert.equal(
    notchiMood({ ...base, musicPlaying: true, agentStates: ["done"] }),
    "vibing"
  )

  // 6. Agent finished is happy
  assert.equal(
    notchiMood({ ...base, agentStates: ["done"] }),
    "happy"
  )

  // 7. Long idle or night is sleepy
  assert.equal(
    notchiMood({ ...base, idleFor: 15 * 60 }),
    "sleepy"
  )
  assert.equal(
    notchiMood({ ...base, hour: 23 }),
    "sleepy"
  )
  assert.equal(
    notchiMood({ ...base, hour: 3 }),
    "sleepy"
  )

  // 8. Normal day is idle
  assert.equal(
    notchiMood({ ...base, hour: 14 }),
    "idle"
  )
})

test("filterRecentAgentStates expires done state after 8 seconds", () => {
  const now = 100000
  const sessions = [
    { state: "done" as const, updatedAt: now - 3000 }, // 3s ago -> still done
    { state: "done" as const, updatedAt: now - 12000 }, // 12s ago -> expires to idle
    { state: "working" as const, updatedAt: now - 30000 }, // working stays working
  ]
  const filtered = filterRecentAgentStates(sessions, now, 8)
  assert.deepEqual(filtered, ["done", "idle", "working"])
})
