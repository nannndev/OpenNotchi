// Pure TypeScript source-code syntax & live-typing engine (shared by CodeLyrics.tsx and unit tests).

export type TokenRole =
  | "keyword"
  | "typeName"
  | "function"
  | "identifier"
  | "attribute"
  | "op"
  | "punctuation"
  | "quote"

export interface CodeToken {
  text: string
  role: TokenRole
}

export interface CodeLineTemplate {
  prefix: CodeToken[]
  suffix: CodeToken[]
}

export function fileSlug(title: string, artist: string): string {
  const a = slugPart(artist, "track")
  const t = slugPart(title, "lyrics")
  return `${a}/${t}.swift`
}

function slugPart(raw: string, fallback: string): string {
  const lower = raw.toLowerCase()
  let out = ""
  let prevUnderscore = false
  for (const ch of lower) {
    if (/[a-z0-9]/.test(ch)) {
      out += ch
      prevUnderscore = false
    } else if (!prevUnderscore && out.length > 0) {
      out += "_"
      prevUnderscore = true
    }
    if (out.length >= 20) break
  }
  const trimmed = out.replace(/^_+|_+$/g, "")
  return trimmed || fallback
}

export function typingSplit(
  text: string,
  lineStart: number,
  nextStart: number | null,
  position: number
): { typed: string; ghost: string; column: number; isComplete: boolean } {
  if (!text) return { typed: "", ghost: "", column: 1, isComplete: true }
  const rawSpan = Math.max(0.6, (nextStart ?? lineStart + 4.0) - lineStart)
  const span = Math.max(0.85, Math.min(rawSpan, 6.5) * 0.78)
  const elapsed = position - lineStart
  const progress = Math.min(1, Math.max(0, elapsed / span))
  const total = text.length
  const count = Math.min(total, Math.max(0, Math.round(total * progress)))
  return {
    typed: text.slice(0, count),
    ghost: text.slice(count),
    column: count + 1,
    isComplete: count >= total,
  }
}

export function cursorVisible(nowMs: number, isPlaying: boolean): boolean {
  const freq = isPlaying ? 2.4 : 1.6
  return Math.floor((nowMs / 1000) * freq) % 2 === 0
}

export function templateForLine(index: number, text: string, compact = false): CodeLineTemplate {
  const ln = String(index + 1).padStart(2, "0")
  const selector = Math.abs(index * 3 + text.length) % (compact ? 10 : 14)

  if (compact) {
    switch (selector) {
      case 0:
        return {
          prefix: [{ text: "let ", role: "keyword" }, { text: `l${ln}`, role: "identifier" }, { text: " = ", role: "op" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ";", role: "punctuation" }],
        }
      case 1:
        return {
          prefix: [{ text: "await ", role: "keyword" }, { text: "sing", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
        }
      case 2:
        return {
          prefix: [{ text: "lyrics", role: "identifier" }, { text: ".", role: "punctuation" }, { text: "push", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ")", role: "punctuation" }],
        }
      case 3:
        return {
          prefix: [{ text: "return ", role: "keyword" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ";", role: "punctuation" }],
        }
      case 4:
        return {
          prefix: [{ text: "const ", role: "keyword" }, { text: "v", role: "identifier" }, { text: " = ", role: "op" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ";", role: "punctuation" }],
        }
      case 5:
        return {
          prefix: [{ text: "Heart", role: "typeName" }, { text: ".", role: "punctuation" }, { text: "echo", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ")", role: "punctuation" }],
        }
      case 6:
        return {
          prefix: [{ text: "@Live ", role: "attribute" }, { text: "var ", role: "keyword" }, { text: "s", role: "identifier" }, { text: " = ", role: "op" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }],
        }
      case 7:
        return {
          prefix: [{ text: "yield ", role: "keyword" }, { text: "-> ", role: "op" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }],
        }
      case 8:
        return {
          prefix: [{ text: "Pulse", role: "typeName" }, { text: "::", role: "op" }, { text: "emit", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
        }
      default:
        return {
          prefix: [{ text: "log", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
          suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
        }
    }
  }

  switch (selector) {
    case 0:
      return {
        prefix: [{ text: "let ", role: "keyword" }, { text: `line_${ln}`, role: "identifier" }, { text: " = ", role: "op" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ";", role: "punctuation" }],
      }
    case 1:
      return {
        prefix: [{ text: "await ", role: "keyword" }, { text: "stream", role: "identifier" }, { text: ".", role: "punctuation" }, { text: "emit", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
      }
    case 2:
      return {
        prefix: [{ text: "lyrics", role: "identifier" }, { text: ".", role: "punctuation" }, { text: "push", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
      }
    case 3:
      return {
        prefix: [{ text: "return ", role: "keyword" }, { text: "Heart", role: "typeName" }, { text: ".", role: "punctuation" }, { text: "echo", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
      }
    case 4:
      return {
        prefix: [{ text: "const ", role: "keyword" }, { text: "verse", role: "identifier" }, { text: ": ", role: "op" }, { text: "String", role: "typeName" }, { text: " = ", role: "op" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ";", role: "punctuation" }],
      }
    case 5:
      return {
        prefix: [{ text: "if ", role: "keyword" }, { text: "playing ", role: "identifier" }, { text: "{ ", role: "punctuation" }, { text: "sing", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ") }", role: "punctuation" }],
      }
    case 6:
      return {
        prefix: [{ text: "memory", role: "identifier" }, { text: ".", role: "punctuation" }, { text: "append", role: "function" }, { text: "(", role: "punctuation" }, { text: "note", role: "identifier" }, { text: ": ", role: "op" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ")", role: "punctuation" }],
      }
    case 7:
      return {
        prefix: [{ text: "@Live ", role: "attribute" }, { text: "var ", role: "keyword" }, { text: "chorus", role: "identifier" }, { text: " = ", role: "op" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }],
      }
    case 8:
      return {
        prefix: [{ text: "console", role: "typeName" }, { text: ".", role: "punctuation" }, { text: "log", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
      }
    case 9:
      return {
        prefix: [{ text: "yield ", role: "keyword" }, { text: "-> ", role: "op" }, { text: "Verse", role: "typeName" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ")", role: "punctuation" }],
      }
    case 10:
      return {
        prefix: [{ text: "Pulse", role: "typeName" }, { text: "::", role: "op" }, { text: "dispatch", role: "function" }, { text: "(", role: "punctuation" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ");", role: "punctuation" }],
      }
    case 11:
      return {
        prefix: [{ text: "guard ", role: "keyword" }, { text: "voice ", role: "identifier" }, { text: "else ", role: "keyword" }, { text: "{ ", role: "punctuation" }, { text: "return ", role: "keyword" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: " }", role: "punctuation" }],
      }
    case 12:
      return {
        prefix: [{ text: "track", role: "identifier" }, { text: ".", role: "punctuation" }, { text: "render", role: "function" }, { text: "(", role: "punctuation" }, { text: "line", role: "identifier" }, { text: ": ", role: "op" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ")", role: "punctuation" }],
      }
    default:
      return {
        prefix: [{ text: "export ", role: "keyword" }, { text: "default ", role: "keyword" }, { text: '"', role: "quote" }],
        suffix: [{ text: '"', role: "quote" }, { text: ";", role: "punctuation" }],
      }
  }
}
