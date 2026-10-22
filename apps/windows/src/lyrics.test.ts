// Run with: npm test (Node's built-in test runner, no extra dependency).
import assert from "node:assert/strict"
import { test } from "node:test"
import { cleanTitle, currentIndex, parseLRC } from "./lyrics.ts"

test("parseLRC handles stamps, repeats and junk lines", () => {
  const lines = parseLRC("[ar:Someone]\n[00:12.50] Hello\n[00:05.00][00:20.00]Chorus\nno stamp here")
  assert.deepEqual(lines, [
    { time: 5, text: "Chorus" },
    { time: 12.5, text: "Hello" },
    { time: 20, text: "Chorus" },
  ])
})

test("cleanTitle drops remaster suffixes and features only", () => {
  assert.equal(cleanTitle("Let It Be - Remastered 2009"), "Let It Be")
  assert.equal(cleanTitle("Song (feat. Other)"), "Song")
  assert.equal(cleanTitle("Love - Me"), "Love - Me")
})

test("currentIndex picks the last line already started", () => {
  const lines = [{ time: 5, text: "a" }, { time: 10, text: "b" }]
  assert.equal(currentIndex(lines, 1), null)
  assert.equal(currentIndex(lines, 9.8), 1) // 0.25s lead, like macOS
  assert.equal(currentIndex(lines, 30), 1)
})
