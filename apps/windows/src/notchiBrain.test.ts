import assert from "node:assert/strict"
import { test } from "node:test"
import { settingsChanges, splitReply, type Options } from "./notchiBrain.ts"
import type { AppSettings } from "./settings.ts"

const opts: Options = {
  themes: [{ id: "liquidGlass", name: "Liquid Glass" }, { id: "aurora", name: "Aurora" }],
  accents: [], borders: [], animations: [],
  backgrounds: [{ id: "blur", name: "Blurred cover" }, { id: "vinyl", name: "Spinning record" }],
}
const settings = { theme: "liquidGlass", showMascot: true, closeDelayMs: 300, nowPlayingBackground: "blur" } as AppSettings

test("action block is hidden from the chat and parsed", () => {
  const r = splitReply('Switching to Aurora.\n```notchi\n{"set": {"theme": "aurora", "showMascot": "false"}, "tab": "timer"}\n```')
  assert.equal(r.text, "Switching to Aurora.")
  assert.equal(r.actions?.tab, "timer")
  assert.equal(splitReply('Half done ```notchi {"set":').text, "Half done")
  assert.equal(splitReply("No changes.").actions, null)
  assert.equal(splitReply("```notchi\nnot json\n```").actions, null)
})

test("only listed keys with valid values become changes, with undo values", () => {
  const { patch, changes } = settingsChanges(
    { set: { theme: "Aurora", showMascot: "false", closeDelayMs: 99999, nope: 1, nowPlayingBackground: "vinyl" } },
    settings,
    opts,
  )
  assert.deepEqual(patch, { theme: "aurora", showMascot: false, nowPlayingBackground: "vinyl" })
  assert.equal(changes.length, 3)
  assert.deepEqual(changes[0].undo, { theme: "liquidGlass" })
})
