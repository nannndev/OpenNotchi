import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import { test } from "node:test"
import { fileURLToPath } from "node:url"
import {
  filterSettingItems,
  matchSettingItem,
  SETTING_ITEMS,
  type SettingItem,
} from "./settingsSearch.ts"

const __dirname = path.dirname(fileURLToPath(import.meta.url))

test("matcher: word order independence", () => {
  // "speed network" finds "Network speed and traffic"
  const item = SETTING_ITEMS.find((s) => s.id === "network-speed")!
  assert.ok(item)
  assert.equal(matchSettingItem(item, "speed network"), true)
  assert.equal(matchSettingItem(item, "network speed"), true)
})

test("matcher: case insensitivity", () => {
  const item = SETTING_ITEMS.find((s) => s.id === "general-mascot")!
  assert.ok(item)
  assert.equal(matchSettingItem(item, "NOTCHI MASCOT"), true)
  assert.equal(matchSettingItem(item, "notchi mascot"), true)
  assert.equal(matchSettingItem(item, "NoTcHi"), true)
})

test("matcher: Indonesian keywords", () => {
  // Check Indonesian synonyms specified in prompt:
  // jaringan, trafik, maskot, lirik, terjemah, cuaca, sholat, adzan, saham, bunyi, suara, notif
  const queries = [
    { query: "jaringan", expectedId: "network-speed" },
    { query: "trafik", expectedId: "network-speed" },
    { query: "maskot", expectedId: "general-mascot" },
    { query: "lirik", expectedId: "tab-music" },
    { query: "terjemah", expectedId: "tab-music" },
    { query: "cuaca", expectedId: "weather-forecast" },
    { query: "sholat", expectedId: "prayer-times" },
    { query: "adzan", expectedId: "prayer-times" },
    { query: "saham", expectedId: "markets-ticker" },
    { query: "bunyi", expectedId: "general-sounds" },
    { query: "suara", expectedId: "general-sounds" },
    { query: "notif", expectedId: "general-sounds" },
  ]

  for (const { query, expectedId } of queries) {
    const matches = filterSettingItems(SETTING_ITEMS, query)
    const found = matches.some((m) => m.id === expectedId)
    assert.ok(found, `Expected query "${query}" to match item with id "${expectedId}"`)
  }
})

test("matcher: returns empty array on no match", () => {
  const matches = filterSettingItems(SETTING_ITEMS, "xyznonexistentquery123")
  assert.equal(matches.length, 0)
})

test("coverage scanner: extracts toggle-title labels from settings .tsx files and ensures all are indexed", () => {
  const settingsFiles = [
    path.join(__dirname, "SettingsWindow.tsx"),
    path.join(__dirname, "MirrorSettings.tsx"),
    path.join(__dirname, "AISettings.tsx"),
  ]

  const extractedLabels: { label: string; file: string }[] = []

  // Regex to extract contents of <div className="toggle-title">...</div>
  const titleRegex = /<div\s+className=["']toggle-title["'][^>]*>([\s\S]*?)<\/div>/g

  for (const filePath of settingsFiles) {
    const content = fs.readFileSync(filePath, "utf-8")
    let match: RegExpExecArray | null
    while ((match = titleRegex.exec(content)) !== null) {
      // Strip any nested tags like <Music size={16} /> and trim
      const rawText = match[1].replace(/<[^>]+>/g, "").trim()
      // Skip dynamic JSX expressions like {STRIP_STYLES[...].name}
      if (rawText && !rawText.startsWith("{")) {
        extractedLabels.push({ label: rawText, file: path.basename(filePath) })
      }
    }
  }

  assert.ok(extractedLabels.length >= 20, `Expected at least 20 setting controls, found ${extractedLabels.length}`)

  const indexedTitles = new Set(SETTING_ITEMS.map((item) => item.title.toLowerCase().trim()))

  const missingLabels: string[] = []
  for (const { label, file } of extractedLabels) {
    if (!indexedTitles.has(label.toLowerCase())) {
      missingLabels.push(`[${file}] "${label}"`)
    }
  }

  assert.deepEqual(
    missingLabels,
    [],
    `The following settings controls from .tsx files are missing from SETTING_ITEMS in settingsSearch.ts:\n${missingLabels.join("\n")}`
  )
})
