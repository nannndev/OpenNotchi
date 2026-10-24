import assert from "node:assert/strict"
import { test } from "node:test"
import pkg from "../package.json" with { type: "json" }
import { compareSemver, CURRENT_VERSION } from "./updater.ts"

test("compareSemver detects newer patch versions", () => {
  assert.equal(compareSemver("0.1.0", "v0.1.1"), true)
  assert.equal(compareSemver("0.1.0", "0.1.2"), true)
  assert.equal(compareSemver("0.1.1", "v0.1.0"), false)
  assert.equal(compareSemver("0.1.0", "0.1.0"), false)
})

test("compareSemver detects newer minor versions", () => {
  assert.equal(compareSemver("0.1.0", "v0.2.0"), true)
  assert.equal(compareSemver("0.2.5", "v0.3.0"), true)
  assert.equal(compareSemver("0.3.0", "v0.2.9"), false)
})

test("compareSemver detects newer major versions", () => {
  assert.equal(compareSemver("0.9.9", "v1.0.0"), true)
  assert.equal(compareSemver("1.0.0", "v2.0.0"), true)
  assert.equal(compareSemver("2.0.0", "v1.9.9"), false)
})

test("compareSemver handles prefix variations and suffixes", () => {
  assert.equal(compareSemver("0.1.0", "V0.1.1-beta"), true)
  assert.equal(compareSemver("0.1.0-alpha", "0.1.1"), true)
  assert.equal(compareSemver("0.1.0", "v0.1.0-hotfix"), false)
})

test("CURRENT_VERSION matches package.json and the Tauri bundle version", async () => {
  const { readFile } = await import("node:fs/promises")
  const tauri = JSON.parse(await readFile(new URL("../src-tauri/tauri.conf.json", import.meta.url), "utf8"))
  assert.equal(CURRENT_VERSION, pkg.version)
  assert.equal(tauri.version, pkg.version)
})
