// Synced lyrics from LRCLIB (https://lrclib.net), same source and parsing as the macOS LyricsManager.

export type LyricLine = { time: number; text: string }
export type Lyrics = { synced: LyricLine[]; plain: string | null }

const cache = new Map<string, Lyrics | null>()

/** Parses LRC text ("[01:23.45] line"); a line with several stamps is repeated at each one. */
export function parseLRC(text: string): LyricLine[] {
  const lines: LyricLine[] = []
  for (const raw of text.split(/\r?\n/)) {
    const stamps = [...raw.matchAll(/\[(\d+):(\d+(?:\.\d+)?)\]/g)]
    if (!stamps.length) continue
    const last = stamps[stamps.length - 1]
    const lyric = raw.slice(last.index! + last[0].length).trim()
    for (const s of stamps) lines.push({ time: Number(s[1]) * 60 + Number(s[2]), text: lyric })
  }
  return lines.sort((a, b) => a.time - b.time)
}

/** Strips suffixes like " - Remastered 2009" and "(feat. X)" for the looser search. */
export function cleanTitle(title: string): string {
  let cleaned = title
  const dash = cleaned.lastIndexOf(" - ")
  if (dash >= 0 && /remaster|live|version|mono|stereo|edit|mix|deluxe/i.test(cleaned.slice(dash + 3))) {
    cleaned = cleaned.slice(0, dash)
  }
  return cleaned.replace(/\s*[([](feat|ft|with)\.?[^)\]]*[)\]]/i, "")
}

/** Index of the line being sung at `position` seconds. */
export function currentIndex(lines: LyricLine[], position: number): number | null {
  let found: number | null = null
  for (let i = 0; i < lines.length && lines[i].time <= position + 0.25; i++) found = i
  return found
}

type LrcRecord = { syncedLyrics?: string | null; plainLyrics?: string | null; instrumental?: boolean }

async function request<T>(path: string, params: Record<string, string>): Promise<T | null> {
  const url = `https://lrclib.net${path}?${new URLSearchParams(params)}`
  const res = await fetch(url)
  if (!res.ok) return null
  return res.json() as Promise<T>
}

function toLyrics(record: LrcRecord | undefined | null): Lyrics | null {
  if (!record) return null
  const synced = record.syncedLyrics ? parseLRC(record.syncedLyrics) : []
  if (!synced.length && !record.plainLyrics) return null
  return { synced, plain: record.plainLyrics ?? null }
}

export async function fetchLyrics(title: string, artist: string, album: string, duration: number): Promise<Lyrics | null> {
  const key = `${title}\u0000${artist}`
  if (cache.has(key)) return cache.get(key)!

  const exact: Record<string, string> = { track_name: title, artist_name: artist, album_name: album }
  if (duration > 0) exact.duration = String(Math.round(duration))
  let lyrics = toLyrics(await request<LrcRecord>("/api/get", exact).catch(() => null))
  if (!lyrics) {
    const results = await request<LrcRecord[]>("/api/search", { track_name: cleanTitle(title), artist_name: artist }).catch(() => null)
    lyrics = toLyrics(results?.find((r) => r.syncedLyrics) ?? results?.[0])
  }
  cache.set(key, lyrics)
  return lyrics
}
