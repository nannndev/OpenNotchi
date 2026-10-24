import assert from "node:assert/strict"
import { test } from "node:test"
import { stripLayout } from "./photobox.ts"

test("stripLayout stacks 4:3 photos with even padding and a caption band", () => {
  const L = stripLayout(4, 600)
  assert.equal(L.photoH, 450)
  assert.equal(L.pad, 36)
  assert.equal(L.width, 672)
  assert.equal(L.slotY(0), 36)
  assert.equal(L.slotY(1), 36 + 450 + 36)
  // Caption starts right after the last photo's bottom padding and fits inside the strip.
  assert.equal(L.captionY, L.slotY(3) + 450 + 36)
  assert.ok(L.captionY < L.height)
})
