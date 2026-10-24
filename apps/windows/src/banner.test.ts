import assert from "node:assert/strict"
import { test } from "node:test"
import {
  bannerRemaining,
  defaultBannerDuration,
  playBannerSound,
  transitionBanner,
  type BannerKind,
} from "./banner.ts"
import type { AgentSession } from "./ai.ts"

const session = (over: Partial<AgentSession>): AgentSession => ({
  tool: "claude",
  sessionId: "s1",
  project: "OpenNotchi",
  state: "working",
  updatedAt: 10_000_000,
  ...over,
})

test("defaultBannerDuration returns proper durations according to macOS OpenNotchi spec", () => {
  assert.equal(defaultBannerDuration("success"), 5)
  assert.equal(defaultBannerDuration("attention"), 10)
  assert.equal(defaultBannerDuration("reminder"), 12)
  assert.equal(defaultBannerDuration("info"), 12)
})

test("transitionBanner triggers success banner on working → done", () => {
  const b = transitionBanner("working", session({ state: "done", project: "OpenNotchi" }))
  assert.ok(b)
  assert.equal(b.kind, "success")
  assert.equal(b.badge, "Done")
  assert.equal(b.icon, "checkmark")
  assert.equal(b.duration, 5)
  assert.ok(b.title.includes("Claude Code finished"))
  assert.ok(b.title.includes("OpenNotchi"))
})

test("transitionBanner triggers attention banner on working → needs_you", () => {
  const b = transitionBanner(
    "working",
    session({
      tool: "codex",
      state: "needs_you",
      project: "backend",
      message: "Needs approval for terminal command",
    })
  )
  assert.ok(b)
  assert.equal(b.kind, "attention")
  assert.equal(b.badge, "Needs you")
  assert.equal(b.icon, "hand")
  assert.equal(b.duration, 10)
  assert.equal(b.subtitle, "Needs approval for terminal command")
  assert.ok(b.title.includes("Codex needs you"))
})

test("transitionBanner handles Antigravity tool name correctly", () => {
  const b = transitionBanner("working", session({ tool: "antigravity", state: "done", project: "app" }))
  assert.ok(b)
  assert.equal(b.kind, "success")
  assert.ok(b.title.includes("Antigravity finished"))
})

test("transitionBanner returns null when state does not transition into done or needs_you", () => {
  assert.equal(transitionBanner(undefined, session({ state: "done" })), null)
  assert.equal(transitionBanner("done", session({ state: "done" })), null)
  assert.equal(transitionBanner("idle", session({ state: "working" })), null)
  assert.equal(transitionBanner("needs_you", session({ state: "needs_you" })), null)
})

test("bannerRemaining calculates countdown progress and handles pause correctly", () => {
  const start = 1000
  const duration = 10 // 10 seconds = 10,000 ms

  // At start
  assert.equal(bannerRemaining(start, duration, 1000), 1.0)

  // Halfway through
  assert.equal(bannerRemaining(start, duration, 6000), 0.5)

  // At expiration
  assert.equal(bannerRemaining(start, duration, 11000), 0.0)

  // Beyond expiration clamped to 0
  assert.equal(bannerRemaining(start, duration, 15000), 0.0)

  // Paused halfway through
  const pausedAt = 6000
  const nowLater = 9000
  assert.equal(bannerRemaining(start, duration, nowLater, pausedAt), 0.5)
})

test("playBannerSound executes safely in non-browser / node test environment", () => {
  // Should not throw even without AudioContext in node
  const kinds: BannerKind[] = ["success", "attention", "reminder", "info"]
  for (const k of kinds) {
    playBannerSound(k, true)
    playBannerSound(k, false)
  }
})
