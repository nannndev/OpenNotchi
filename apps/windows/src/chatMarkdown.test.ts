import assert from "node:assert/strict"
import { test } from "node:test"
import { parseBlocks, parseInline } from "./chatMarkdown.ts"

test("inline bold, italic, code and links", () => {
  assert.deepEqual(parseInline("a **b** *c* `d` [e](https://x.y)"), [
    { kind: "text", text: "a " },
    { kind: "bold", text: "b" },
    { kind: "text", text: " " },
    { kind: "italic", text: "c" },
    { kind: "text", text: " " },
    { kind: "code", text: "d" },
    { kind: "text", text: " " },
    { kind: "link", text: "e", href: "https://x.y" },
  ])
})

test("plain text and unsafe links stay text", () => {
  assert.deepEqual(parseInline("just text"), [{ kind: "text", text: "just text" }])
  assert.deepEqual(parseInline("[x](javascript:alert(1))"), [{ kind: "text", text: "[x](javascript:alert(1))" }])
  assert.deepEqual(parseInline("2 * 3 * 4"), [{ kind: "text", text: "2 * 3 * 4" }])
})

test("fenced code blocks split from text", () => {
  assert.deepEqual(parseBlocks("Run:\n```sh\nnpm i\nnpm test\n```\nDone"), [
    { kind: "text", parts: [{ kind: "text", text: "Run:\n" }] },
    { kind: "code", lang: "sh", code: "npm i\nnpm test" },
    { kind: "text", parts: [{ kind: "text", text: "Done" }] },
  ])
})

test("an unclosed fence (still streaming) is code to the end", () => {
  assert.deepEqual(parseBlocks("x\n```js\nlet a"), [
    { kind: "text", parts: [{ kind: "text", text: "x\n" }] },
    { kind: "code", lang: "js", code: "let a" },
  ])
})
