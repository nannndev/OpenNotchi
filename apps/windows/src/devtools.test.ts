import assert from "node:assert/strict"
import { test } from "node:test"
import { formatBytes, formatRate, isLocalWebPort } from "./devtools.ts"

test("bytes format with one decimal above a kilobyte", () => {
  assert.equal(formatBytes(512), "512 B")
  assert.equal(formatBytes(1536), "1.5 KB")
  assert.equal(formatBytes(8 * 1024 ** 3), "8.0 GB")
})

test("rates never go negative", () => {
  assert.equal(formatRate(-5), "0 B/s")
  assert.equal(formatRate(2 * 1024 * 1024), "2.0 MB/s")
})

test("dev server ports get an open button, Windows service ports don't", () => {
  assert.ok(isLocalWebPort(5173) && isLocalWebPort(3000) && isLocalWebPort(8080))
  assert.ok(!isLocalWebPort(135) && !isLocalWebPort(445) && !isLocalWebPort(5040) && !isLocalWebPort(49664))
})
