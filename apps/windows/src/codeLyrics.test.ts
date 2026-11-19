import assert from "node:assert/strict"
import test from "node:test"
import { fileSlug, templateForLine, typingSplit } from "./codeLyricsEngine.ts"

test("fileSlug formats artist and title into a clean pseudo path", () => {
  assert.equal(fileSlug("everything u are", "Hindia"), "hindia/everything_u_are.swift")
  assert.equal(fileSlug("", ""), "track/lyrics.swift")
})

test("typingSplit splits active line into typed text and ghost completion", () => {
  const start = typingSplit("Hello World", 10, 14, 10)
  assert.equal(start.typed, "")
  assert.equal(start.ghost, "Hello World")
  assert.equal(start.column, 1)
  assert.equal(start.isComplete, false)

  const mid = typingSplit("Hello World", 10, 14, 11.56)
  assert.ok(mid.typed.length > 0 && mid.ghost.length > 0)
  assert.equal(mid.typed + mid.ghost, "Hello World")

  const end = typingSplit("Hello World", 10, 14, 13.8)
  assert.equal(end.typed, "Hello World")
  assert.equal(end.ghost, "")
  assert.equal(end.isComplete, true)
})

test("templateForLine produces varied syntax constructs across lines", () => {
  const prefixes = [0, 1, 2, 3, 4].map((i) =>
    templateForLine(i, `Sample line ${i}`, false)
      .prefix.map((t) => t.text)
      .join("")
  )
  assert.ok(new Set(prefixes).size >= 4)
})
