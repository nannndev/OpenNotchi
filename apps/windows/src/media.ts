import { invoke } from "@tauri-apps/api/core"
import { useEffect, useState } from "react"
import { currentIndex, fetchLyrics, type Lyrics } from "./lyrics"

export type NowPlaying = {
  title: string
  artist: string
  album: string
  isPlaying: boolean
  position: number
  duration: number
  updatedAt: number
  artwork: string | null
  source: string
}

/** Song position right now, extrapolated from the last report while playing. */
export function positionAt(np: NowPlaying, now = Date.now()): number {
  const pos = np.isPlaying ? np.position + (now - np.updatedAt) / 1000 : np.position
  return np.duration > 0 ? Math.min(Math.max(pos, 0), np.duration) : Math.max(pos, 0)
}

export const control = (action: "toggle" | "next" | "previous" | "seek", seekTo?: number) =>
  invoke("media_control", { action, seekTo }).catch(() => {})

/** Polls Windows' media session; artwork is only re-read when the track changes. */
export function useNowPlaying(): NowPlaying | null {
  const [np, setNp] = useState<NowPlaying | null>(null)
  useEffect(() => {
    let key = ""
    let artwork: string | null = null
    let alive = true
    const poll = async () => {
      const next = await invoke<NowPlaying | null>("now_playing", { withArtwork: false }).catch(() => null)
      if (!alive) return
      const nextKey = next ? `${next.title}\u0000${next.artist}\u0000${next.source}` : ""
      if (next && nextKey !== key) {
        key = nextKey
        artwork = (await invoke<NowPlaying | null>("now_playing", { withArtwork: true }).catch(() => null))?.artwork ?? null
      }
      setNp(next ? { ...next, artwork } : null)
    }
    poll()
    const id = setInterval(poll, 1000)
    return () => {
      alive = false
      clearInterval(id)
    }
  }, [])
  return np
}

export function useLyrics(np: NowPlaying | null): Lyrics | null | "loading" {
  const [lyrics, setLyrics] = useState<Lyrics | null | "loading">(null)
  const key = np ? `${np.title}\u0000${np.artist}` : ""
  useEffect(() => {
    if (!np) return setLyrics(null)
    let alive = true
    setLyrics("loading")
    fetchLyrics(np.title, np.artist, np.album, np.duration).then((l) => alive && setLyrics(l))
    return () => {
      alive = false
    }
    // Only refetch when the track changes, not on every position update.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key])
  return lyrics
}

/** Re-renders every `ms` so time-based UI (progress, current lyric) keeps moving. */
export function useTick(ms: number) {
  const [, setTick] = useState(0)
  useEffect(() => {
    const id = setInterval(() => setTick((t) => t + 1), ms)
    return () => clearInterval(id)
  }, [ms])
}

export function currentLine(np: NowPlaying | null, lyrics: Lyrics | null | "loading"): { index: number | null; text: string | null } {
  if (!np || !lyrics || lyrics === "loading" || !lyrics.synced.length) return { index: null, text: null }
  const index = currentIndex(lyrics.synced, positionAt(np))
  return { index, text: index === null ? null : lyrics.synced[index].text || "♪" }
}

export function formatTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
}
