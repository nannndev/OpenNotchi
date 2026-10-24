import assert from "node:assert/strict"
import { test } from "node:test"
import { STRIP_FORMATS, STRIP_SHOT_CHOICES, STRIP_STYLES, stripCells, type StripFormat, type StripStyle } from "./photobox.ts"

const styles = Object.keys(STRIP_STYLES) as StripStyle[]
const formats = Object.keys(STRIP_FORMATS) as StripFormat[]

test("all 19 macOS styles in macOS order", () => {
  assert.equal(styles.length, 19)
  assert.deepEqual(styles.slice(0, 3), ["classic", "receipt", "social"])
  assert.equal(styles.at(-1), "album")
})

test("a strip grows with the number of photos, 1200 wide, 4:3 cells", () => {
  for (const style of styles) {
    // The grid style puts 2 photos side by side, so only same-parity counts compare there (as on macOS).
    const counts = style === "pastel" ? [2, 4, 6] : STRIP_SHOT_CHOICES
    const heights = counts.map((n) => stripCells(style, "strip", n).height)
    heights.slice(1).forEach((h, i) => assert.ok(h > heights[i], `${style}: ${heights}`))
    const L = stripCells(style, "strip", 4)
    assert.equal(L.width, 1200)
    for (const c of L.cells) assert.ok(Math.abs(c.w / c.h - 4 / 3) < 1e-9)
  }
  // Same numbers as macOS: classic, 4 shots = 65 + 70 + 4 × 795 + 3 × 34 + 440.
  assert.equal(stripCells("classic", "strip", 4).height, 3857)
})

test("fixed formats are width × ratio regardless of count", () => {
  for (const f of formats.filter((f) => f !== "strip")) {
    for (const n of STRIP_SHOT_CHOICES) {
      assert.equal(stripCells("classic", f, n).height, Math.round(1200 * STRIP_FORMATS[f].heightRatio!))
    }
  }
})

test("grid style uses 2 columns for even counts, 1 for odd", () => {
  const columns = (n: number) => new Set(stripCells("pastel", "strip", n).cells.map((c) => c.x)).size
  assert.equal(columns(4), 2)
  assert.equal(columns(6), 2)
  assert.equal(columns(3), 1)
  assert.equal(new Set(stripCells("classic", "strip", 4).cells.map((c) => c.x)).size, 1)
})

test("fixed formats pick the grid closest to 4:3", () => {
  // 4 photos on a square: 2×2 beats 1×4 and 4×1.
  assert.equal(new Set(stripCells("classic", "square", 4).cells.map((c) => c.x)).size, 2)
  // 6 photos on a tall story: 2 columns.
  assert.equal(new Set(stripCells("classic", "story", 6).cells.map((c) => c.x)).size, 2)
})

test("cells stay inside the canvas and above the footer", () => {
  for (const style of styles) for (const f of formats) for (const n of STRIP_SHOT_CHOICES) {
    const L = stripCells(style, f, n)
    assert.equal(L.cells.length, n)
    for (const c of L.cells) {
      assert.ok(c.w > 0 && c.h > 0, `${style}/${f}/${n}`)
      assert.ok(c.x >= 0 && c.y >= 0 && c.x + c.w <= L.width + 1e-6 && c.y + c.h <= L.footer.y + 1e-6, `${style}/${f}/${n}`)
    }
  }
})
