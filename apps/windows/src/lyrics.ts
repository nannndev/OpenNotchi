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

/** Helper to create an inclusive range array [start ... end] */
export function makeRange(start: number, end: number): number[] {
  if (start > end) return []
  const res: number[] = []
  for (let i = start; i <= end; i++) {
    res.push(i)
  }
  return res
}

/**
 * Calculates next selection when user taps a line in Lyric Share.
 * Follows the macOS OpenNotchi / Spotify algorithm:
 * - Tapping top boundary unselects / drops it
 * - Tapping bottom boundary unselects / drops it
 * - Tapping inside trims the selection to that line
 * - Tapping the only selected line unselects it (empty selection)
 * - Tapping within reach (<= maxLines) stretches the selection
 * - Tapping beyond reach (> maxLines) starts a new selection at the tapped line
 */
export function getNextLyricSelection(
  current: number[],
  idx: number,
  maxLines = 8,
): number[] {
  if (current.length === 0) {
    return [idx]
  }

  // If only one line is selected and tapped again, unselect it
  if (current.length === 1 && current[0] === idx) {
    return []
  }

  const lower = Math.min(...current)
  const upper = Math.max(...current)

  // 1. Tapping the top boundary drops it (unselect top)
  if (idx === lower) {
    return makeRange(lower + 1, upper)
  }

  // 2. Tapping the bottom boundary drops it (unselect bottom)
  if (idx === upper) {
    return makeRange(lower, upper - 1)
  }

  // 3. Tapping inside trims to that line
  if (idx > lower && idx < upper) {
    return makeRange(lower, idx)
  }

  // 4. Tapping outside: within reach stretches, beyond reach starts fresh
  const min = Math.min(idx, lower)
  const max = Math.max(idx, upper)
  const span = max - min + 1

  if (span <= maxLines) {
    return makeRange(min, max)
  }

  // Too far away from current selection, start fresh at tapped index
  return [idx]
}
