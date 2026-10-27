// Accent color from the album artwork, ported from the macOS ArtworkPalette.

import { useEffect, useState } from "react"

const WHITE = "#ffffff"

function toHsv(r: number, g: number, b: number): [number, number, number] {
  const max = Math.max(r, g, b)
  const d = max - Math.min(r, g, b)
  const h = d === 0 ? 0 : max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4
  return [((h * 60) + 360) % 360, max === 0 ? 0 : d / max, max]
}

function hsvToRgb(h: number, s: number, v: number): [number, number, number] {
  const f = (n: number) => {
    const k = (n + h / 60) % 6
    return v - v * s * Math.max(0, Math.min(k, 4 - k, 1))
  }
  return [f(5), f(3), f(1)]
}

/**
 * Most common color in RGBA pixels, favoring saturated colors over greys, black and white,
 * then brightened so it reads on the black pill. Null when there's nothing to go on.
 */
export function accentFromPixels(px: ArrayLike<number>): string | null {
  const buckets = new Map<number, { n: number; r: number; g: number; b: number }>()
  for (let i = 0; i + 3 < px.length; i += 4) {
    const r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255
    const key = (Math.floor(r * 7.99) << 6) | (Math.floor(g * 7.99) << 3) | Math.floor(b * 7.99)
    const bucket = buckets.get(key) ?? { n: 0, r: 0, g: 0, b: 0 }
    bucket.n++, bucket.r += r, bucket.g += g, bucket.b += b
    buckets.set(key, bucket)
  }

  let best: [number, number, number] | null = null
  let bestScore = -1
  for (const { n, r, g, b } of buckets.values()) {
    const [h, s, v] = toHsv(r / n, g / n, b / n)
    let weight = 0.15 + s
    if (v < 0.15) weight *= 0.1
    if (v > 0.92 && s < 0.12) weight *= 0.2
    if (n * weight > bestScore) {
      bestScore = n * weight
      best = [h, s, v]
    }
  }
  if (!best) return null

  const [h, s, v] = best
  // Greys stay grey (the UI falls back to white); colors get a minimum saturation and brightness.
  if (s < 0.08) return WHITE
  const [r, g, b] = hsvToRgb(h, Math.max(s, 0.4), Math.max(v, 0.8))
  return `rgb(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)})`
}

/** The accent (hex or `rgb()`) as an `rgba()` with the given alpha, for canvas gradients. */
export function withAlpha(color: string, alpha: number): string {
  const rgb = color.match(/\d+/g)
  if (color.startsWith("rgb") && rgb) return `rgba(${rgb.slice(0, 3).join(", ")}, ${alpha})`
  let hex = color.replace("#", "")
  if (hex.length === 3) hex = [...hex].map((c) => c + c).join("")
  const n = parseInt(hex.slice(0, 6), 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`
}

/** Accent for the given artwork data URL; white when there's no artwork. */
export function useAccent(src: string | null | undefined): string {
  const [accent, setAccent] = useState(WHITE)
  useEffect(() => {
    if (!src) return setAccent(WHITE)
    let alive = true
    const img = new Image()
    img.onload = () => {
      const canvas = document.createElement("canvas")
      canvas.width = canvas.height = 32
      const ctx = canvas.getContext("2d")
      if (!ctx || !alive) return
      ctx.drawImage(img, 0, 0, 32, 32)
      setAccent(accentFromPixels(ctx.getImageData(0, 0, 32, 32).data) ?? WHITE)
    }
    img.src = src
    return () => {
      alive = false
    }
  }, [src])
  return accent
}
