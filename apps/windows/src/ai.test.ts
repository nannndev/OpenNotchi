import assert from "node:assert/strict"
import { test } from "node:test"
import {
  closedMeter,
  formatCost,
  formatTokens,
  mergeSessions,
  quickPrompt,
  resetsIn,
  timeAgo,
  transitionPeek,
  userLanguage,
  windowLabel,
  type AgentSession,
  type UsageReport,
} from "./ai.ts"

const now = 10_000_000
const session = (over: Partial<AgentSession>): AgentSession => ({
  tool: "claude",
  sessionId: "s1",
  project: "notch",
  state: "working",
  updatedAt: now - 1000,
  ...over,
})

test("mergeSessions lays newer hook states over the logs and turns old done into idle", () => {
  const hook = { sessionId: "s1", project: "notch", state: "needs_you" as const, message: "Allow Bash?", at: now }
  assert.equal(mergeSessions([session({})], { s1: hook }, now)[0].state, "needs_you")
  // The log was written after the hook (permission granted), so the log wins.
  assert.equal(mergeSessions([session({ updatedAt: now + 5000 })], { s1: hook }, now + 6000)[0].state, "working")
  // Hook-only sessions show up.
  assert.equal(mergeSessions([], { s2: { ...hook, sessionId: "s2" } }, now)[0].project, "notch")
  assert.equal(mergeSessions([session({ state: "done", updatedAt: now - 6 * 60_000 })], {}, now)[0].state, "idle")
  const many = Array.from({ length: 8 }, (_, i) => session({ sessionId: `s${i}`, updatedAt: now - i }))
  const merged = mergeSessions(many, {}, now)
  assert.equal(merged.length, 5)
  assert.equal(merged[0].sessionId, "s0")
})

test("transitionPeek fires on working → done and on → needs you", () => {
  assert.equal(transitionPeek("working", session({ state: "done" })), "Claude Code finished · notch")
  assert.equal(transitionPeek("working", session({ state: "needs_you", tool: "codex" })), "Codex needs you · notch")
  assert.equal(transitionPeek(undefined, session({ state: "done" })), null)
  assert.equal(transitionPeek("done", session({ state: "done" })), null)
  assert.equal(transitionPeek("idle", session({ state: "working" })), null)
})

test("formatting", () => {
  assert.equal(formatTokens(950), "950")
  assert.equal(formatTokens(1234), "1.2K")
  assert.equal(formatTokens(93_176_220), "93M")
  assert.equal(formatTokens(4_000_000), "4M")
  assert.equal(formatCost(64.638), "$64.64")
  assert.equal(formatCost(123.4), "$123")
  assert.equal(windowLabel(300), "5h")
  assert.equal(windowLabel(10080), "weekly")
  assert.equal(resetsIn(now + 200 * 60_000, now), "resets in 3h 20m")
  assert.equal(resetsIn(now + 3 * 86_400_000, now), "resets in 3d")
  assert.equal(timeAgo(now - 30_000, now), "now")
  assert.equal(timeAgo(now - 7 * 60_000, now), "7m")
})

test("closedMeter prefers a hot Codex window over a Claude block", () => {
  const base: UsageReport = { name: "", tool: "claude", dir: "", found: true, today: { tokens: 0, cost: 0 }, block: null, days: [], limits: null }
  const block = { ...base, block: { start: now - 3_600_000, end: now + 4 * 3_600_000, tokens: 2500, cost: 1 } }
  const codex = { ...base, tool: "codex" as const, limits: { planType: "plus", primary: { usedPercent: 85, windowMinutes: 300, resetsAt: now / 1000 + 60 }, secondary: null } }
  assert.deepEqual(closedMeter([block, codex], now), { label: "5h 85%", percent: 85, hot: true })
  assert.deepEqual(closedMeter([block], now), { label: "2.5K", percent: 20, hot: false })
  assert.equal(closedMeter([base], now), null)
})

test("quick prompts", () => {
  assert.equal(userLanguage("id-ID"), "Indonesian")
  assert.match(quickPrompt("translate", "hola", "English"), /into English/)
  assert.match(quickPrompt("explain", "la la", "English", { title: "Song", artist: "Me" }), /"Song" by Me/)
})
