// Light markdown for chat bubbles, like the macOS app: fenced code blocks, inline code,
// **bold**, *italic* and [links](https://…). Everything else stays plain text (React escapes it).

export type Inline =
  | { kind: "text"; text: string }
  | { kind: "bold" | "italic" | "code"; text: string }
  | { kind: "link"; text: string; href: string }

export type Block = { kind: "code"; lang: string; code: string } | { kind: "text"; parts: Inline[] }

// Emphasis can't start or end with a space, so "2 * 3 * 4" stays text (as in CommonMark).
const INLINE = /`([^`\n]+)`|\*\*(\S(?:[^*\n]*\S)?)\*\*|\*(\S(?:[^*\n]*\S)?)\*|\[([^\]\n]+)\]\((https?:\/\/[^)\s]+)\)/g

export function parseInline(text: string): Inline[] {
  const out: Inline[] = []
  let last = 0
  for (const m of text.matchAll(INLINE)) {
    if (m.index > last) out.push({ kind: "text", text: text.slice(last, m.index) })
    if (m[1] !== undefined) out.push({ kind: "code", text: m[1] })
    else if (m[2] !== undefined) out.push({ kind: "bold", text: m[2] })
    else if (m[3] !== undefined) out.push({ kind: "italic", text: m[3] })
    else out.push({ kind: "link", text: m[4], href: m[5] })
    last = m.index + m[0].length
  }
  if (last < text.length) out.push({ kind: "text", text: text.slice(last) })
  return out
}

/** Splits on ``` fences; an unclosed fence (still streaming) runs to the end. */
export function parseBlocks(src: string): Block[] {
  const blocks: Block[] = []
  const parts = src.split(/^```/m)
  parts.forEach((part, i) => {
    if (i % 2 === 0) {
      const text = part.replace(/^\n/, i ? "" : "\n").replace(/^\n/, "")
      if (text) blocks.push({ kind: "text", parts: parseInline(text) })
    } else {
      const nl = part.indexOf("\n")
      const lang = nl === -1 ? part.trim() : part.slice(0, nl).trim()
      const code = nl === -1 ? "" : part.slice(nl + 1).replace(/\n$/, "")
      blocks.push({ kind: "code", lang, code })
    }
  })
  return blocks
}
