import assert from "node:assert/strict"
import { test } from "node:test"
import { accentFromPixels, withAlpha } from "./palette.ts"

const pixels = (...runs: [number, [number, number, number]][]) =>
  runs.flatMap(([count, rgb]) => Array.from({ length: count }, () => [...rgb, 255]).flat())

test("a saturated color beats a bigger area of white and black", () => {
  const accent = accentFromPixels(pixels([300, [250, 250, 250]], [300, [5, 5, 5]], [120, [200, 30, 40]]))
  const [r, g, b] = accent!.match(/\d+/g)!.map(Number)
  assert.ok(r > 200 && g < 100 && b < 100, accent!)
})

test("dark colors are brightened so they read on black", () => {
  const [r, g, b] = accentFromPixels(pixels([100, [20, 30, 90]]))!.match(/\d+/g)!.map(Number)
  assert.ok(Math.max(r, g, b) >= 200, `${r},${g},${b}`)
})

test("grey artwork falls back to white, empty input to null", () => {
  assert.equal(accentFromPixels(pixels([100, [128, 128, 128]])), "#ffffff")
  assert.equal(accentFromPixels([]), null)
})

test("withAlpha works for both hex and rgb accents", () => {
  // Artwork accents are rgb(); appending a hex alpha to one made canvas reject the color.
  assert.equal(withAlpha("rgb(20, 204, 114)", 0.4), "rgba(20, 204, 114, 0.4)")
  assert.equal(withAlpha("#3b82f6", 0.4), "rgba(59, 130, 246, 0.4)")
  assert.equal(withAlpha("#fff", 0.5), "rgba(255, 255, 255, 0.5)")
})
