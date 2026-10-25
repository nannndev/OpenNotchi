/** What Ask AI knows about OpenNotchi on Windows, and the settings it may change.
 * The model asks for changes with a ```notchi {...}``` block at the end of its answer; the app applies
 * them and shows each one with an Undo, so nothing changes silently. Pure helpers; tested in notchiBrain.test.ts. */
// Type-only imports: settings.ts pulls in React and Tauri, which the Node test runner can't load.
import type { AppSettings } from "./settings"

type Kind = { type: "bool" } | { type: "number"; min: number; max: number } | { type: "choice"; values: { id: string; name: string }[] }
type Option = { id: string; name: string }

/** Choice lists come from settings.ts at runtime (see `withOptions`) so they never drift. */
export type Options = { themes: Option[]; accents: Option[]; borders: Option[]; animations: Option[]; backgrounds: Option[] }

export const editable = (o: Options): { key: keyof AppSettings; info: string; kind: Kind }[] => [
  { key: "theme", info: "Notch look", kind: { type: "choice", values: o.themes } },
  { key: "accentChoice", info: "Accent color", kind: { type: "choice", values: o.accents } },
  { key: "borderStyle", info: "Outline around the notch", kind: { type: "choice", values: o.borders } },
  { key: "openAnimation", info: "How the notch opens", kind: { type: "choice", values: o.animations } },
  { key: "notchMode", info: "Pinned to the top, floating, or hidden until hovered", kind: { type: "choice", values: [{ id: "pinned", name: "Pinned" }, { id: "floating", name: "Floating" }, { id: "autoHide", name: "Auto-hide" }] } },
  { key: "auraGlow", info: "Glow from album colors", kind: { type: "choice", values: [{ id: "off", name: "Off" }, { id: "subtle", name: "Subtle" }, { id: "vibrant", name: "Vibrant" }] } },
  { key: "closeDelayMs", info: "Milliseconds before the notch closes after the pointer leaves", kind: { type: "number", min: 0, max: 2000 } },
  { key: "tabMusic", info: "Music tab", kind: { type: "bool" } },
  { key: "tabClipboard", info: "Clipboard tab", kind: { type: "bool" } },
  { key: "tabTimer", info: "Timer tab", kind: { type: "bool" } },
  { key: "tabNotes", info: "Notes tab", kind: { type: "bool" } },
  { key: "tabPrompter", info: "Teleprompter tab", kind: { type: "bool" } },
  { key: "tabMirror", info: "Mirror (camera) tab", kind: { type: "bool" } },
  { key: "showMascot", info: "Notchi mascot", kind: { type: "bool" } },
  { key: "notificationSounds", info: "Notification sounds", kind: { type: "bool" } },
  { key: "aiAgents", info: "Coding agent status", kind: { type: "bool" } },
  { key: "aiNotify", info: "Banner when an agent finishes or needs you", kind: { type: "bool" } },
  { key: "nowPlayingEnabled", info: "Full-screen player when the PC sits idle while music plays", kind: { type: "bool" } },
  { key: "nowPlayingIdleMinutes", info: "Idle minutes before the full-screen player", kind: { type: "number", min: 0.5, max: 30 } },
  { key: "nowPlayingBackground", info: "Full-screen player background", kind: { type: "choice", values: o.backgrounds } },
  { key: "nowPlayingLyrics", info: "Lyrics on the full-screen player", kind: { type: "bool" } },
  { key: "nowPlayingClock", info: "Clock on the full-screen player", kind: { type: "bool" } },
  { key: "usageLayout", info: "AI quota layout", kind: { type: "choice", values: [{ id: "cards", name: "Cards" }, { id: "compact", name: "Compact" }, { id: "list", name: "List" }] } },
]

export function systemPrompt(s: AppSettings, o: Options): string {
  const values = (k: Kind) =>
    k.type === "bool" ? "true|false" : k.type === "number" ? `${k.min}...${k.max}` : k.values.map((v) => `${v.id} (${v.name})`).join("|")
  const lines = editable(o).map((e) => `- ${e.key} = ${String(s[e.key])} — ${e.info}. Values: ${values(e.kind)}`).join("\n")
  return `You are Notchi, the assistant inside OpenNotchi for Windows: a pill at the top of the screen that opens on hover. \
You answer in a small panel: be concise, plain text, no markdown headings. Reply in the user's language.

Tabs: Music (player with synced lyrics), Clipboard, Timer, Notes, Prompter, Mirror (camera, photobox), AI (9router quota per account, \
usage analytics, coding agent status, and this chat). A full-screen player with lyrics shows when the PC sits idle while music plays.

Current settings:
${lines}

You can change settings, open a tab, open Settings, or open the full-screen player. When the user asks for that, say in one short \
sentence what you'll change, then end your reply with exactly one block:
\`\`\`notchi
{"set": {"theme": "aurora", "showMascot": false}, "tab": "timer", "settings": true, "nowPlaying": true}
\`\`\`
Every field is optional. Use only the keys and values listed above. Don't add the block when nothing should change.`
}

export type Actions = { set?: Record<string, unknown>; tab?: string; settings?: boolean; nowPlaying?: boolean }

/** Splits a reply into the text to show and the action block (also hides a block that is still streaming in). */
export function splitReply(reply: string): { text: string; actions: Actions | null } {
  const start = reply.indexOf("```notchi")
  if (start < 0) return { text: reply, actions: null }
  const text = reply.slice(0, start).trim()
  const rest = reply.slice(start + 9)
  const end = rest.indexOf("```")
  if (end < 0) return { text, actions: null }
  try {
    const parsed = JSON.parse(rest.slice(0, end))
    return { text, actions: parsed && typeof parsed === "object" ? parsed : null }
  } catch {
    return { text, actions: null }
  }
}

export type Change = { key: string; label: string; undo?: Partial<AppSettings> }

/** The valid settings changes in `actions`, each with the old value for Undo. Unknown keys and bad values are dropped. */
export function settingsChanges(actions: Actions, s: AppSettings, o: Options): { patch: Partial<AppSettings>; changes: Change[] } {
  const patch: Record<string, unknown> = {}
  const changes: Change[] = []
  for (const [key, raw] of Object.entries(actions.set ?? {})) {
    const e = editable(o).find((x) => x.key === key)
    if (!e) continue
    let value: unknown
    if (e.kind.type === "bool") {
      value = raw === true || raw === "true" ? true : raw === false || raw === "false" ? false : undefined
    } else if (e.kind.type === "number") {
      const n = Number(raw)
      value = Number.isFinite(n) && n >= e.kind.min && n <= e.kind.max ? n : undefined
    } else {
      const v = String(raw).toLowerCase()
      value = e.kind.values.find((c) => c.id.toLowerCase() === v || c.name.toLowerCase() === v)?.id
    }
    if (value === undefined) continue
    patch[key] = value
    changes.push({ key, label: `${e.info}: ${String(value)}`, undo: { [key]: s[e.key] } as Partial<AppSettings> })
  }
  return { patch: patch as Partial<AppSettings>, changes }
}
