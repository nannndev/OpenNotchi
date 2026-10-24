/** Mirror filters and photobox strip composition (canvas only, no dependencies). Port of macOS PhotoStrip.swift. */

export type MirrorEffect = "natural" | "vivid" | "warm" | "cool" | "film" | "mono" | "dreamy"

/**
 * CSS filters approximating the macOS Core Image looks; the same string drives the live preview and the canvas.
 * Swatches are the macOS picker colors.
 */
export const EFFECTS: Record<MirrorEffect, { name: string; filter: string; swatch: string }> = {
  natural: { name: "Natural", filter: "none", swatch: "linear-gradient(135deg, #d9d9d9, #8c8c8c)" },
  vivid: { name: "Vivid", filter: "saturate(1.35) contrast(1.08)", swatch: "linear-gradient(135deg, #ff2d55, #ff9500)" },
  warm: { name: "Warm", filter: "sepia(0.18) saturate(1.15) hue-rotate(-8deg)", swatch: "linear-gradient(135deg, #ff9500, #cc6633)" },
  cool: { name: "Cool", filter: "saturate(1.05) hue-rotate(12deg) brightness(1.02)", swatch: "linear-gradient(135deg, #32ade6, #007aff)" },
  film: { name: "Film", filter: "sepia(0.35) contrast(1.1) saturate(0.9)", swatch: "linear-gradient(135deg, #e6cc99, #73594d)" },
  mono: { name: "Mono", filter: "grayscale(1) contrast(1.15)", swatch: "linear-gradient(135deg, #ffffff, #000000)" },
  dreamy: { name: "Dreamy", filter: "saturate(0.9) brightness(1.06) blur(0.6px)", swatch: "linear-gradient(135deg, #ffd9f2, #af52de)" },
}

// MARK: - Styles and formats

/** CSS color from 0…1 components, like NSColor(red:green:blue:alpha:). */
const rgb = (r: number, g: number, b: number, a = 1) => `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${a})`
const gray = (w: number, a = 1) => rgb(w, w, w, a)
const WHITE = "#ffffff"
const BLACK = "#000000"

export type StripStyle =
  | "classic" | "receipt" | "social" | "player" | "postcard" | "scrapbook" | "coquette" | "desktop"
  | "film" | "polaroid" | "y2k" | "midnight" | "sakura" | "retro" | "newspaper" | "neon" | "pastel" | "love" | "album"

/** Same order as macOS StripStyle.allCases. swatch = the two picker colors as CSS colors. */
export const STRIP_STYLES: Record<StripStyle, { name: string; swatch: [string, string] }> = {
  classic: { name: "Classic", swatch: [WHITE, gray(0.85)] },
  receipt: { name: "Receipt", swatch: [rgb(0.97, 0.96, 0.94), gray(0.3)] },
  social: { name: "Social Post", swatch: [WHITE, rgb(0.93, 0.29, 0.4)] },
  player: { name: "Player", swatch: [rgb(0.2, 0.75, 0.4), gray(0.08)] },
  postcard: { name: "Postcard", swatch: [rgb(0.85, 0.22, 0.22), rgb(0.13, 0.32, 0.62)] },
  scrapbook: { name: "Scrapbook", swatch: [rgb(0.91, 0.86, 0.77), rgb(0.55, 0.8, 0.7)] },
  coquette: { name: "Coquette", swatch: [rgb(0.97, 0.84, 0.88), rgb(0.76, 0.1, 0.36)] },
  desktop: { name: "Retro PC", swatch: [rgb(0, 0.5, 0.5), gray(0.75)] },
  film: { name: "Film", swatch: [rgb(0.91, 0.64, 0.23), gray(0.08)] },
  polaroid: { name: "Polaroid", swatch: [rgb(0.96, 0.94, 0.9), rgb(0.17, 0.23, 0.4)] },
  y2k: { name: "Y2K", swatch: [rgb(1, 0.54, 0.85), rgb(0.54, 0.48, 1)] },
  midnight: { name: "Midnight", swatch: [gray(0.2), BLACK] },
  sakura: { name: "Sakura", swatch: [rgb(1, 0.89, 0.93), rgb(0.83, 0.42, 0.55)] },
  retro: { name: "Retro", swatch: [rgb(0.91, 0.64, 0.23), rgb(0.85, 0.34, 0.17)] },
  newspaper: { name: "Newspaper", swatch: [rgb(0.93, 0.92, 0.89), gray(0.15)] },
  neon: { name: "Neon", swatch: ["#32ade6", rgb(1, 0.2, 0.75)] },
  pastel: { name: "Pastel Grid", swatch: [rgb(0.81, 0.96, 0.91), rgb(0.98, 0.85, 0.75)] },
  love: { name: "Love", swatch: [rgb(0.9, 0.22, 0.27), "#ff2d55"] },
  album: { name: "Now Playing", swatch: ["#af52de", "#ff9500"] },
}

export type StripFormat = "strip" | "story" | "post" | "postcard" | "square"

/** heightRatio = height ÷ width, or null when the height grows with the number of photos. */
export const STRIP_FORMATS: Record<StripFormat, { name: string; heightRatio: number | null }> = {
  strip: { name: "Photo strip", heightRatio: null },
  story: { name: "Story 9:16", heightRatio: 16 / 9 },
  post: { name: "Post 4:5", heightRatio: 5 / 4 },
  postcard: { name: "Postcard 3:2", heightRatio: 3 / 2 },
  square: { name: "Square 1:1", heightRatio: 1 },
}

/** Photos per photobox session. */
export const STRIP_SHOT_CHOICES: readonly number[] = [1, 2, 3, 4, 6]

/** What's printed on the strip besides the photos. */
export interface StripInfo {
  /** The user's own text; replaces the style's title when non-empty. */
  caption?: string
  date?: Date
  songTitle?: string
  artist?: string
  artwork?: CanvasImageSource | null
  /** Where the song is, for the Player style's progress bar. */
  songPosition?: number
  songDuration?: number
  isPlaying?: boolean
}

// MARK: - Layout (pure, no DOM)

export interface Rect { x: number; y: number; w: number; h: number }

const SIDE: Partial<Record<StripStyle, number>> = { film: 120, social: 0, receipt: 100, postcard: 65, newspaper: 80, classic: 70, polaroid: 65 }
const HEADER: Partial<Record<StripStyle, number>> = { social: 150, postcard: 85, newspaper: 125, classic: 65, film: 50 }
const GAP: Partial<Record<StripStyle, number>> = { film: 28, social: 6, newspaper: 44, polaroid: 30 }
const FOOTER: Record<StripStyle, number> = {
  receipt: 880, social: 430, player: 560, postcard: 520, newspaper: 500, desktop: 300, scrapbook: 430, coquette: 430, pastel: 380,
  polaroid: 440, classic: 440, film: 380, midnight: 400, retro: 440, y2k: 420, sakura: 420, neon: 400, love: 420, album: 460,
}

function grid(area: Rect, count: number, columns: number, gap: number): Rect[] {
  const rows = Math.max(1, Math.floor(count / columns))
  const w = (area.w - (columns - 1) * gap) / columns
  const h = (area.h - (rows - 1) * gap) / rows
  return Array.from({ length: count }, (_, i) => ({ x: area.x + (i % columns) * (w + gap), y: area.y + Math.floor(i / columns) * (h + gap), w, h }))
}

/**
 * Canvas size, photo cells and footer band for `count` photos, exactly as macOS lays them out:
 * a strip grows with the photos (4:3 cells, two columns for grid styles); fixed formats shrink the footer if
 * needed and pick the column count whose cells come closest to 4:3.
 */
export function stripCells(style: StripStyle, format: StripFormat, count: number) {
  const width = 1200
  const side = SIDE[style] ?? 70
  const header = HEADER[style] ?? 0
  const gap = GAP[style] ?? 34
  let footer = FOOTER[style]
  let footerScale = 1.3
  let height: number
  let cells: Rect[]
  const ratio = STRIP_FORMATS[format].heightRatio
  if (ratio) {
    height = Math.round(width * ratio)
    const fit = Math.min(1, (height * 0.3) / footer)
    footer *= fit
    footerScale *= fit
    const area = { x: side, y: header + side, w: width - 2 * side, h: height - header - footer - side - (style === "social" ? 0 : 10) }
    let columns = 1
    let best = Infinity
    for (let c = 1; c <= Math.min(3, count); c++) {
      if (count % c) continue
      const [cell] = grid(area, count, c, gap)
      const off = Math.abs(Math.log(Math.max(cell.w, 1) / Math.max(cell.h, 1) / (4 / 3)))
      if (off < best) [best, columns] = [off, c]
    }
    cells = grid(area, count, columns, gap)
  } else {
    const columns = style === "pastel" && count % 2 === 0 ? 2 : 1
    const rows = count / columns
    const cellW = (width - 2 * side - (columns - 1) * gap) / columns
    const area = { x: side, y: header + side, w: width - 2 * side, h: rows * (cellW * 3) / 4 + (rows - 1) * gap }
    cells = grid(area, count, columns, gap)
    height = Math.ceil(area.y + area.h + footer)
  }
  return { width, height, cells, footer: { x: 0, y: height - footer, w: width, h: footer }, footerScale }
}

// MARK: - Compose

/** 1200px wide, like macOS. photos are any size; crop aspect-fill. */
export function composeStrip(photos: HTMLCanvasElement[], style: StripStyle, format: StripFormat, info: StripInfo): HTMLCanvasElement {
  if (!photos.length) throw new Error("No photos for the strip")
  const shots = photos.map((p) => filtered(p, style))
  const L = stripCells(style, format, shots.length)
  const out = document.createElement("canvas")
  out.width = L.width
  out.height = L.height
  g = out.getContext("2d")!
  const canvas = { x: 0, y: 0, w: L.width, h: L.height }

  drawBackground(style, canvas, info, shots)
  L.cells.forEach((cell, i) => drawPhoto(shots[i % shots.length], cell, style, i))
  if (style === "social") drawSocialHeader(shots[0], L.width)
  // Keep decorations off the photos and the footer text.
  const f = L.footer
  drawDecorations(style, canvas, [...L.cells, { x: 120, y: f.y + 20, w: L.width - 240, h: f.h - 20 }])

  // Footer text is laid out at a base size and scaled up so it reads well on a phone.
  const s = L.footerScale
  const midX = f.x + f.w / 2
  g.save()
  g.translate(midX, f.y)
  g.scale(s, s)
  g.translate(-midX, -f.y)
  drawFooter(style, { x: midX - f.w / s / 2, y: f.y, w: f.w / s, h: f.h / s }, info)
  g.restore()
  return out
}

/** Placeholder portraits (gradient + white head/shoulders) like macOS samplePhotos, for previews. */
export function samplePhotos(): HTMLCanvasElement[] {
  return [[0.02, 0.08], [0.55, 0.62], [0.9, 0.97], [0.33, 0.42]].map(([h0, h1]) => {
    const c = document.createElement("canvas")
    c.width = 800
    c.height = 600
    const x = c.getContext("2d")!
    const grad = x.createLinearGradient(0, 0, 800, 600)
    grad.addColorStop(0, hsb(h0, 0.45, 0.95))
    grad.addColorStop(1, hsb(h1, 0.6, 0.55))
    x.fillStyle = grad
    x.fillRect(0, 0, 800, 600)
    x.fillStyle = gray(1, 0.85)
    x.beginPath()
    x.ellipse(400, 265, 90, 105, 0, 0, Math.PI * 2) // head
    x.ellipse(400, 580, 200, 190, 0, 0, Math.PI * 2) // shoulders
    x.fill()
    return c
  })
}

function hsb(h: number, s: number, v: number) {
  const l = v * (1 - s / 2)
  const sl = l === 0 || l === 1 ? 0 : (v - l) / Math.min(l, 1 - l)
  return `hsl(${h * 360}, ${sl * 100}%, ${l * 100}%)`
}

/** Saves a canvas as PNG through the webview's download flow. */
export function savePng(canvas: HTMLCanvasElement, name: string): Promise<void> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (!blob) return reject(new Error("Could not encode photo"))
      const url = URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.href = url
      a.download = `${name}.png`
      a.click()
      setTimeout(() => URL.revokeObjectURL(url), 2000)
      resolve()
    }, "image/png")
  })
}

/** Grabs the current video frame, mirrored like the preview, with the effect baked in. */
export function captureFrame(video: HTMLVideoElement, effect: MirrorEffect): HTMLCanvasElement {
  const c = document.createElement("canvas")
  c.width = video.videoWidth
  c.height = video.videoHeight
  const ctx = c.getContext("2d")!
  ctx.filter = EFFECTS[effect].filter
  ctx.translate(c.width, 0)
  ctx.scale(-1, 1)
  ctx.drawImage(video, 0, 0)
  return c
}

// MARK: - Drawing helpers

/** The strip being drawn; composeStrip is synchronous so one shared context is safe (mirrors the Swift statics). */
let g: CanvasRenderingContext2D
/** Widest a centered footer line may be; set per strip. */
let maxTextWidth = Infinity

const SYS = "'Segoe UI', system-ui, sans-serif"
const ROUND = "'Outfit', 'Segoe UI', sans-serif"
const SERIF = "'Newsreader', Georgia, 'Times New Roman', serif"
const MONO = "Consolas, 'Courier New', monospace"
const COURIER = "'Courier New', Consolas, monospace"
const HAND = "'Caveat', 'Segoe Print', cursive"

// Canvas only uses a web font once the document has loaded it; start loading the ones the strips use.
/** Resolves once the strip fonts are loaded (or failed), so a strip drawn right after launch isn't in fallback fonts. */
export const stripFontsReady: Promise<unknown> =
  typeof document === "undefined" || !document.fonts
    ? Promise.resolve()
    : Promise.all(
        ["700 40px Caveat", "400 40px Outfit", "800 40px Outfit", "900 40px Outfit", "700 40px Newsreader", "italic 400 40px Newsreader"].map(
          (f) => document.fonts.load(f).catch(() => {}),
        ),
      )

interface Font { size: number; weight?: number; family?: string; italic?: boolean }
const fnt = (size: number, weight = 400, family = SYS, italic = false): Font => ({ size, weight, family, italic })
const css = (f: Font) => `${f.italic ? "italic " : ""}${f.weight ?? 400} ${f.size}px ${f.family ?? SYS}`

function fill(r: Rect, color: string) {
  g.fillStyle = color
  g.fillRect(r.x, r.y, r.w, r.h)
}

const inset = (r: Rect, dx: number, dy = dx): Rect => ({ x: r.x + dx, y: r.y + dy, w: r.w - 2 * dx, h: r.h - 2 * dy })
const maxX = (r: Rect) => r.x + r.w
const maxY = (r: Rect) => r.y + r.h
const midX = (r: Rect) => r.x + r.w / 2
const midY = (r: Rect) => r.y + r.h / 2

function roundPath(r: Rect, radius: number) {
  g.beginPath()
  g.roundRect(r.x, r.y, r.w, r.h, radius)
}

function ovalPath(r: Rect) {
  g.beginPath()
  g.ellipse(midX(r), midY(r), r.w / 2, r.h / 2, 0, 0, Math.PI * 2)
}

function fillRound(r: Rect, radius: number, color: string) {
  roundPath(r, radius)
  g.fillStyle = color
  g.fill()
}

function strokeRound(r: Rect, radius: number, color: string, width: number) {
  roundPath(r, radius)
  g.strokeStyle = color
  g.lineWidth = width
  g.stroke()
}

function withShadow(color: string, blur: number, ox: number, oy: number, body: () => void) {
  g.save()
  g.shadowColor = color
  g.shadowBlur = blur
  g.shadowOffsetX = ox
  g.shadowOffsetY = oy
  body()
  g.restore()
}

function drawAspectFill(image: CanvasImageSource, r: Rect) {
  const any = image as { naturalWidth?: number; naturalHeight?: number; videoWidth?: number; videoHeight?: number; width?: unknown; height?: unknown }
  const w = any.naturalWidth || any.videoWidth || Number(any.width) || 1
  const h = any.naturalHeight || any.videoHeight || Number(any.height) || 1
  const scale = Math.max(r.w / w, r.h / h)
  g.imageSmoothingQuality = "high"
  g.drawImage(image, midX(r) - (w * scale) / 2, midY(r) - (h * scale) / 2, w * scale, h * scale)
}

/** Photo clipped to a (rounded) rect. */
function clipped(photo: HTMLCanvasElement, r: Rect, radius = 0) {
  g.save()
  roundPath(r, radius)
  g.clip()
  drawAspectFill(photo, r)
  g.restore()
}

/** Gradient over `r` at `angle` degrees like NSGradient.draw(in:angle:) in a flipped context. */
function gradient(r: Rect, angle: number, colors: string[]) {
  const a = (angle * Math.PI) / 180
  const dx = Math.cos(a)
  const dy = Math.sin(a)
  const half = Math.abs((r.w / 2) * dx) + Math.abs((r.h / 2) * dy)
  const grad = g.createLinearGradient(midX(r) - dx * half, midY(r) - dy * half, midX(r) + dx * half, midY(r) + dy * half)
  colors.forEach((c, i) => grad.addColorStop(i / (colors.length - 1), c))
  return grad
}

function setText(f: Font, color: string, kern = 0) {
  g.font = css(f)
  g.fillStyle = color
  g.letterSpacing = `${kern}px`
  g.textBaseline = "top"
  g.textAlign = "left"
}

/** AppKit draws text from the top of its line box, which sits a little above canvas's "top" baseline. */
const lead = (f: Font) => f.size * 0.12

function truncate(text: string, width: number) {
  if (g.measureText(text).width <= width) return text
  const chars = Array.from(text)
  while (chars.length && g.measureText(chars.join("") + "…").width > width) chars.pop()
  return chars.join("") + "…"
}

/** Left-aligned text at its top-left corner, truncated with … past `maxWidth`. */
function draw(text: string, f: Font, color: string, x: number, y: number, maxWidth?: number, kern = 0) {
  setText(f, color, kern)
  g.fillText(maxWidth ? truncate(text, maxWidth) : text, x, y + lead(f))
}

/** Draws centered text (shrunk to fit the strip) and returns its line height. */
function centered(text: string, f: Font, color: string, x: number, y: number, shadow?: string, kern = 0) {
  setText(f, color, kern)
  const w = g.measureText(text).width
  if (w > maxTextWidth) {
    f = { ...f, size: (f.size * maxTextWidth) / w }
    setText(f, color, kern)
  }
  g.textAlign = "center"
  const ty = y + lead(f)
  if (shadow) withShadow(shadow, 18, 0, 0, () => g.fillText(text, x, ty))
  else g.fillText(text, x, ty)
  return f.size * 1.2
}

/** Word-wrapped text inside `r`, like NSAttributedString.draw(in:); lines past the bottom are dropped. */
function wrapped(text: string, f: Font, color: string, r: Rect) {
  setText(f, color)
  const lineH = f.size * 1.2
  let line = ""
  let y = r.y
  for (const word of text.split(" ")) {
    const next = line ? `${line} ${word}` : word
    if (line && g.measureText(next).width > r.w) {
      if (y + lineH > maxY(r) + 1) return
      g.fillText(line, r.x, y)
      y += lineH
      line = word
    } else line = next
  }
  if (line && y + lineH <= maxY(r) + 1) g.fillText(line, r.x, y)
}

function rotated(text: string, f: Font, color: string, cx: number, cy: number) {
  g.save()
  g.translate(cx, cy)
  g.rotate(Math.PI / 2)
  setText(f, color)
  g.textAlign = "center"
  g.textBaseline = "middle"
  g.fillText(text, 0, 0)
  g.restore()
}

function emoji(text: string, size: number, cx: number, cy: number) {
  g.font = `${size}px 'Segoe UI Emoji', 'Apple Color Emoji', sans-serif`
  g.letterSpacing = "0px"
  g.textAlign = "center"
  g.textBaseline = "middle"
  g.fillText(text, cx, cy)
}

/** Small vector stand-ins for the SF Symbols the macOS strips use, centered at (cx, cy). */
function symbol(name: string, color: string, cx: number, cy: number, size: number) {
  const s = size / 2
  g.save()
  g.translate(cx, cy)
  g.fillStyle = color
  g.strokeStyle = color
  g.lineWidth = size * 0.09
  g.lineCap = "round"
  g.lineJoin = "round"
  g.beginPath()
  const heart = () => {
    g.moveTo(0, s * 0.85)
    g.bezierCurveTo(-s * 1.25, 0, -s * 0.85, -s * 1.05, 0, -s * 0.42)
    g.bezierCurveTo(s * 0.85, -s * 1.05, s * 1.25, 0, 0, s * 0.85)
    g.closePath()
  }
  const star = () => {
    for (let i = 0; i < 10; i++) {
      const r = i % 2 ? s * 0.45 : s
      const a = -Math.PI / 2 + (i * Math.PI) / 5
      g.lineTo(Math.cos(a) * r, Math.sin(a) * r + s * 0.08)
    }
    g.closePath()
  }
  const tri = (x: number, w: number, dir: number) => {
    g.moveTo(x, -s * 0.6)
    g.lineTo(x + w * dir, 0)
    g.lineTo(x, s * 0.6)
    g.closePath()
  }
  switch (name) {
    case "heart.fill": heart(); g.fill(); break
    case "heart": heart(); g.stroke(); break
    case "star.fill": star(); g.fill(); break
    case "star": star(); g.stroke(); break
    case "sparkle":
      g.moveTo(0, -s)
      g.quadraticCurveTo(s * 0.12, -s * 0.12, s, 0)
      g.quadraticCurveTo(s * 0.12, s * 0.12, 0, s)
      g.quadraticCurveTo(-s * 0.12, s * 0.12, -s, 0)
      g.quadraticCurveTo(-s * 0.12, -s * 0.12, 0, -s)
      g.fill()
      break
    case "sun.max":
    case "sun.max.fill":
      g.arc(0, 0, s * 0.42, 0, Math.PI * 2)
      if (name === "sun.max.fill") g.fill()
      else g.stroke()
      g.beginPath()
      for (let i = 0; i < 8; i++) {
        const a = (i * Math.PI) / 4
        g.moveTo(Math.cos(a) * s * 0.65, Math.sin(a) * s * 0.65)
        g.lineTo(Math.cos(a) * s * 0.95, Math.sin(a) * s * 0.95)
      }
      g.stroke()
      break
    case "cloud.fill":
      g.arc(-s * 0.4, s * 0.15, s * 0.38, 0, Math.PI * 2)
      g.arc(s * 0.05, -s * 0.15, s * 0.5, 0, Math.PI * 2)
      g.arc(s * 0.5, s * 0.15, s * 0.38, 0, Math.PI * 2)
      g.rect(-s * 0.4, s * 0.15, s * 0.9, s * 0.38)
      g.fill()
      break
    case "scribble":
      g.moveTo(-s, s * 0.3)
      for (let i = 0; i < 4; i++) g.quadraticCurveTo(-s + (i + 0.5) * s * 0.5, i % 2 ? s * 0.9 : -s * 0.9, -s + (i + 1) * s * 0.5, s * 0.1 * (i % 2 ? -1 : 1))
      g.stroke()
      break
    case "music.note":
      g.ellipse(-s * 0.25, s * 0.55, s * 0.32, s * 0.24, -0.4, 0, Math.PI * 2)
      g.fill()
      g.fillRect(s * 0.02, -s * 0.9, s * 0.13, s * 1.45)
      g.beginPath()
      g.moveTo(s * 0.15, -s * 0.9)
      g.quadraticCurveTo(s * 0.7, -s * 0.6, s * 0.5, -s * 0.15)
      g.stroke()
      break
    case "camera":
      g.roundRect(-s, -s * 0.55, s * 2, s * 1.4, s * 0.25)
      g.moveTo(-s * 0.35, -s * 0.55)
      g.lineTo(-s * 0.2, -s * 0.8)
      g.lineTo(s * 0.2, -s * 0.8)
      g.lineTo(s * 0.35, -s * 0.55)
      g.stroke()
      g.beginPath()
      g.arc(0, s * 0.15, s * 0.38, 0, Math.PI * 2)
      g.stroke()
      break
    case "bubble.right":
      g.ellipse(0, -s * 0.05, s * 0.9, s * 0.8, 0, Math.PI * 0.3, Math.PI * 2.15)
      g.lineTo(s * 0.9, s * 0.85)
      g.closePath()
      g.stroke()
      break
    case "paperplane":
      g.moveTo(-s * 0.9, -s * 0.1)
      g.lineTo(s * 0.9, -s * 0.85)
      g.lineTo(s * 0.2, s * 0.9)
      g.lineTo(-s * 0.05, s * 0.05)
      g.closePath()
      g.moveTo(-s * 0.05, s * 0.05)
      g.lineTo(s * 0.9, -s * 0.85)
      g.stroke()
      break
    case "bookmark":
      g.moveTo(-s * 0.6, -s * 0.9)
      g.lineTo(s * 0.6, -s * 0.9)
      g.lineTo(s * 0.6, s * 0.9)
      g.lineTo(0, s * 0.4)
      g.lineTo(-s * 0.6, s * 0.9)
      g.closePath()
      g.stroke()
      break
    case "airplane":
      g.font = `${size}px 'Segoe UI Symbol', ${SYS}`
      g.textAlign = "center"
      g.textBaseline = "middle"
      g.fillText("✈︎", 0, 0)
      break
    case "play.fill": tri(-s * 0.45, s * 1.1, 1); g.fill(); break
    case "pause.fill":
      g.roundRect(-s * 0.55, -s * 0.7, s * 0.38, s * 1.4, s * 0.08)
      g.roundRect(s * 0.17, -s * 0.7, s * 0.38, s * 1.4, s * 0.08)
      g.fill()
      break
    case "forward.fill": tri(-s, s, 1); tri(0, s, 1); g.fill(); break
    case "backward.fill": tri(s, s, -1); tri(0, s, -1); g.fill(); break
    case "shuffle":
      g.moveTo(-s, -s * 0.5)
      g.bezierCurveTo(0, -s * 0.5, 0, s * 0.5, s * 0.8, s * 0.5)
      g.moveTo(-s, s * 0.5)
      g.bezierCurveTo(0, s * 0.5, 0, -s * 0.5, s * 0.8, -s * 0.5)
      for (const y of [-0.5, 0.5]) {
        g.moveTo(s * 0.5, (y - 0.25) * s)
        g.lineTo(s * 0.85, y * s)
        g.lineTo(s * 0.5, (y + 0.25) * s)
      }
      g.stroke()
      break
    case "repeat":
      g.moveTo(-s * 0.9, s * 0.1)
      g.lineTo(-s * 0.9, -s * 0.4)
      g.lineTo(s * 0.8, -s * 0.4)
      g.moveTo(s * 0.9, -s * 0.1)
      g.lineTo(s * 0.9, s * 0.4)
      g.lineTo(-s * 0.8, s * 0.4)
      g.moveTo(s * 0.5, -s * 0.7)
      g.lineTo(s * 0.85, -s * 0.4)
      g.lineTo(s * 0.5, -s * 0.1)
      g.moveTo(-s * 0.5, s * 0.1)
      g.lineTo(-s * 0.85, s * 0.4)
      g.lineTo(-s * 0.5, s * 0.7)
      g.stroke()
      break
  }
  g.restore()
}

function petal(cx: number, cy: number, size: number, angle: number) {
  g.save()
  g.translate(cx, cy)
  g.rotate((angle * Math.PI) / 180)
  g.fillStyle = rgb(1, 0.66, 0.78, 0.85)
  g.beginPath()
  g.moveTo(0, -size / 2)
  g.bezierCurveTo(size * 0.6, -size / 3, size * 0.4, size / 3, 0, size / 2)
  g.bezierCurveTo(-size * 0.4, size / 3, -size * 0.6, -size / 3, 0, -size / 2)
  g.fill()
  g.restore()
}

/** Classic 3D bevel: light top-left, dark bottom-right (reversed when sunken). */
function bevel(r: Rect, raised: boolean) {
  fill(r, gray(0.75))
  const [tl, br] = raised ? [WHITE, gray(0.35)] : [gray(0.35), WHITE]
  fill({ x: r.x, y: r.y, w: r.w, h: 3 }, tl)
  fill({ x: r.x, y: r.y, w: 3, h: r.h }, tl)
  fill({ x: r.x, y: maxY(r) - 3, w: r.w, h: 3 }, br)
  fill({ x: maxX(r) - 3, y: r.y, w: 3, h: r.h }, br)
}

// MARK: - Dates and randomness

const pad2 = (n: number) => String(n).padStart(2, "0")

/** Subset of DateFormatter patterns used by the strips. */
function formatDate(d: Date, pattern: string) {
  return pattern.replace(/EEEE|MMMM|yyyy|yy|MM|dd|HH|mm|ss|d/g, (t) => {
    switch (t) {
      case "EEEE": return d.toLocaleString("en-US", { weekday: "long" })
      case "MMMM": return d.toLocaleString("en-US", { month: "long" })
      case "yyyy": return String(d.getFullYear())
      case "yy": return pad2(d.getFullYear() % 100)
      case "MM": return pad2(d.getMonth() + 1)
      case "dd": return pad2(d.getDate())
      case "HH": return pad2(d.getHours())
      case "mm": return pad2(d.getMinutes())
      case "ss": return pad2(d.getSeconds())
      default: return String(d.getDate())
    }
  })
}

const U64 = (1n << 64n) - 1n

/** Same xorshift and the same Swift random(in:) algorithms as macOS, so decorations land in the same places. */
class SeededRandom {
  private state: bigint
  constructor(seed: bigint) {
    this.state = ((seed * 0x9e3779b97f4a7c15n) & U64) | 1n
  }
  next() {
    let s = this.state
    s ^= (s << 13n) & U64
    s ^= s >> 7n
    s ^= (s << 17n) & U64
    this.state = s
    return s
  }
  /** Lemire's unbiased 0..<n, like Swift's next(upperBound:). */
  private below(n: bigint) {
    let m = this.next() * n
    if ((m & U64) < n) {
      const t = ((1n << 64n) - n) % n
      while ((m & U64) < t) m = this.next() * n
    }
    return m >> 64n
  }
  /** Double.random(in: a...b) */
  range(a: number, b: number) {
    const max = 1n << 53n
    const r = this.below(max + 1n)
    return r === max ? b : (b - a) * (Number(r) / 2 ** 53) + a
  }
  bool() {
    return ((this.next() >> 17n) & 1n) === 0n
  }
  pick<T>(items: readonly T[]) {
    return items[Number(this.below(BigInt(items.length)))]
  }
}

/** A random point in the margins, never on a photo. */
function scatter(canvas: Rect, avoid: Rect[], rng: SeededRandom) {
  for (let i = 0; i < 40; i++) {
    const x = rng.range(10, canvas.w - 10)
    const y = rng.range(10, canvas.h - 10)
    if (!avoid.some((c) => x >= c.x - 24 && x < maxX(c) + 24 && y >= c.y - 24 && y < maxY(c) + 24)) return [x, y] as const
  }
  return [30, 30] as const
}

function barcode(rng: SeededRandom, from: number, to: number, y: number, h: number, minW: number, maxW: number, minGap: number, maxGap: number) {
  for (let x = from; x < to; ) {
    const w = rng.range(minW, maxW)
    g.fillRect(x, y, w, h)
    x += w + rng.range(minGap, maxGap)
  }
}

// MARK: - Photos

const PHOTO_FILTERS: Partial<Record<StripStyle, string>> = {
  newspaper: "grayscale(1) contrast(2.2) brightness(0.85)",
  receipt: "grayscale(1) contrast(1.35) brightness(1.06)",
  retro: "sepia(0.25) saturate(1.5) contrast(1.1)",
  postcard: "sepia(0.3) saturate(0.6) contrast(0.92) brightness(1.08)",
  polaroid: "sepia(0.3) saturate(0.6) contrast(0.95) brightness(1.08)",
  film: "saturate(0.85) contrast(0.95) brightness(1.05)",
  midnight: "contrast(1.15) saturate(0.95)",
  sakura: "saturate(1.12) brightness(1.03) contrast(1.02)",
  y2k: "saturate(1.7) contrast(1.15)",
  classic: "contrast(1.05) saturate(1.02)",
}
const VIGNETTE: Partial<Record<StripStyle, number>> = { film: 0.55, midnight: 0.4 }

/** Per-style photo tint (Core Image looks approximated with CSS filters and a radial vignette). */
function filtered(photo: HTMLCanvasElement, style: StripStyle) {
  const filter = PHOTO_FILTERS[style]
  if (!filter) return photo
  const c = document.createElement("canvas")
  c.width = photo.width
  c.height = photo.height
  const x = c.getContext("2d")!
  x.filter = filter
  x.drawImage(photo, 0, 0)
  x.filter = "none"
  const v = VIGNETTE[style]
  if (v) {
    const r = Math.hypot(c.width, c.height) / 2
    const grad = x.createRadialGradient(c.width / 2, c.height / 2, r * 0.45, c.width / 2, c.height / 2, r)
    grad.addColorStop(0, "rgba(0,0,0,0)")
    grad.addColorStop(1, `rgba(0,0,0,${v})`)
    x.fillStyle = grad
    x.fillRect(0, 0, c.width, c.height)
  }
  return c
}

function drawPhoto(photo: HTMLCanvasElement, cell: Rect, style: StripStyle, index: number) {
  switch (style) {
    case "receipt":
    case "social":
      clipped(photo, cell)
      break

    case "player":
      clipped(photo, cell, 26)
      break

    case "coquette":
      withShadow(rgb(0.6, 0.2, 0.3, 0.25), 14, 0, 4, () => fillRound(cell, 30, WHITE))
      clipped(photo, inset(cell, 14), 20)
      emoji("🎀", 84, midX(cell), cell.y + 6)
      break

    case "scrapbook": {
      // Printed photos, slightly crooked, held down with washi tape.
      const angles = [-2.2, 1.8, -1.3, 2.4]
      g.save()
      g.translate(midX(cell), midY(cell))
      g.rotate((angles[index % angles.length] * Math.PI) / 180)
      g.translate(-midX(cell), -midY(cell))
      const paper = inset(cell, 18, 12)
      withShadow(gray(0, 0.25), 12, 2, 5, () => fill(paper, gray(0.99)))
      clipped(photo, inset(paper, 18))
      const tapes = [rgb(0.62, 0.86, 0.78, 0.8), rgb(0.98, 0.72, 0.78, 0.8), rgb(0.98, 0.88, 0.55, 0.8), rgb(0.7, 0.78, 0.98, 0.8)]
      g.translate(midX(paper), paper.y + 4)
      g.rotate(((index % 2 === 0 ? -6 : 5) * Math.PI) / 180)
      fill({ x: -100, y: -24, w: 200, h: 48 }, tapes[index % tapes.length])
      g.restore()
      break
    }

    case "postcard": {
      withShadow(gray(0, 0.2), 14, 0, 4, () => fillRound(cell, 8, gray(0.99)))
      const border = inset(cell, 14)
      clipped(photo, border, 5)
      strokeRound(border, 5, gray(0.1, 0.1), 1.5)
      // Photo mounting tabs on corners.
      g.fillStyle = rgb(0.82, 0.74, 0.62, 0.9)
      for (const [x, y] of [[cell.x + 8, cell.y + 8], [maxX(cell) - 8, cell.y + 8], [cell.x + 8, maxY(cell) - 8], [maxX(cell) - 8, maxY(cell) - 8]]) {
        const sx = x > midX(cell) ? -1 : 1
        const sy = y > midY(cell) ? -1 : 1
        g.beginPath()
        g.moveTo(x, y)
        g.lineTo(x + 22 * sx, y)
        g.lineTo(x, y + 22 * sy)
        g.closePath()
        g.fill()
      }
      break
    }

    case "desktop":
      drawWindow(photo, cell, `photo_${index + 1}.jpg`)
      break

    case "classic": {
      withShadow(gray(0, 0.12), 12, 0, 3, () => fillRound(cell, 10, WHITE))
      const frame = inset(cell, 12)
      clipped(photo, frame, 6)
      strokeRound(frame, 6, gray(0, 0.08), 1)
      // Corner crosshair markers.
      g.strokeStyle = gray(0.4, 0.35)
      g.lineWidth = 1
      g.beginPath()
      for (const [x, y] of [[cell.x + 6, cell.y + 6], [maxX(cell) - 6, cell.y + 6], [cell.x + 6, maxY(cell) - 6], [maxX(cell) - 6, maxY(cell) - 6]]) {
        g.moveTo(x - 6, y)
        g.lineTo(x + 6, y)
        g.moveTo(x, y - 6)
        g.lineTo(x, y + 6)
      }
      g.stroke()
      break
    }

    case "polaroid": {
      withShadow(gray(0, 0.22), 16, 1, 5, () => fillRound(cell, 8, rgb(0.99, 0.985, 0.97)))
      const area = { x: cell.x + 16, y: cell.y + 16, w: cell.w - 32, h: cell.h - 32 - 46 }
      clipped(photo, area, 4)
      strokeRound(area, 4, gray(0, 0.15), 1.2)
      // Seam line for the chemical pod at the bottom.
      fill({ x: cell.x + 16, y: maxY(cell) - 14.5, w: cell.w - 32, h: 1 }, gray(0.85, 0.5))
      // Polaroid's 5-color rainbow block, bottom right.
      const bars = [rgb(0.92, 0.22, 0.21), rgb(0.98, 0.52, 0.16), rgb(0.98, 0.82, 0.18), rgb(0.27, 0.72, 0.38), rgb(0.16, 0.62, 0.88)]
      const rx = maxX(cell) - 24 - bars.length * 4.5
      bars.forEach((c, i) => fill({ x: rx + i * 4.5, y: maxY(cell) - 32, w: 4.5, h: 16 }, c))
      draw("SX-70 COLOR", fnt(13, 700), gray(0.45, 0.65), cell.x + 20, maxY(cell) - 32)
      break
    }

    case "film": {
      fill(cell, BLACK)
      clipped(photo, inset(cell, 4))
      g.strokeStyle = rgb(0.91, 0.64, 0.23, 0.9)
      g.lineWidth = 1
      const b = inset(cell, -2)
      g.strokeRect(b.x, b.y, b.w, b.h)
      g.lineWidth = 1.5
      for (const [x, y] of [[cell.x - 6, cell.y - 6], [maxX(cell) + 6, cell.y - 6], [cell.x - 6, maxY(cell) + 6], [maxX(cell) + 6, maxY(cell) + 6]]) {
        const sx = x < midX(cell) ? 1 : -1
        const sy = y < midY(cell) ? 1 : -1
        g.beginPath()
        g.moveTo(x, y + 8 * sy)
        g.lineTo(x, y)
        g.lineTo(x + 8 * sx, y)
        g.stroke()
      }
      break
    }

    case "newspaper":
      withShadow(gray(0, 0.15), 6, 1, 2, () => fill(cell, WHITE))
      clipped(photo, inset(cell, 4))
      g.strokeStyle = BLACK
      g.lineWidth = 2.5
      g.strokeRect(cell.x, cell.y, cell.w, cell.h)
      draw(`Fig. ${index + 1} — Special dispatch from the scene`, fnt(16, 400, SERIF, true), gray(0.2, 0.9), cell.x + 4, maxY(cell) + 8)
      break

    case "retro": {
      withShadow(rgb(0.4, 0.2, 0.1, 0.22), 14, 0, 5, () => fillRound(cell, 26, rgb(0.99, 0.96, 0.9)))
      const frame = inset(cell, 14)
      clipped(photo, frame, 20)
      strokeRound(frame, 20, rgb(0.85, 0.34, 0.17, 0.85), 3)
      break
    }

    case "midnight":
      withShadow(gray(0, 0.4), 20, 0, 6, () => fillRound(cell, 16, gray(0.08)))
      clipped(photo, inset(cell, 6), 12)
      strokeRound(cell, 16, gray(1, 0.28), 1.5)
      draw(`[ ARCHIVE // 0${index + 1} ]`, fnt(12, 700, MONO), gray(1, 0.65), cell.x + 16, cell.y + 12)
      break

    case "y2k": {
      withShadow(rgb(0.6, 0.3, 0.9, 0.3), 16, 0, 5, () => fillRound(cell, 28, WHITE))
      const f = inset(cell, 10)
      g.save()
      roundPath(f, 20)
      g.clip()
      drawAspectFill(photo, f)
      // Camcorder OSD overlay.
      ovalPath({ x: f.x + 16, y: f.y + 16, w: 14, h: 14 })
      g.fillStyle = rgb(1, 0.15, 0.2)
      g.fill()
      draw("REC", fnt(15, 700), WHITE, f.x + 36, f.y + 14)
      draw(`SP  00:0${index + 1}:28`, fnt(14, 700, MONO), WHITE, f.x + 78, f.y + 15)
      setText(fnt(14, 700), WHITE)
      g.textAlign = "right"
      g.fillText("HQ 4:3  [▮▮▯]", maxX(f) - 16, f.y + 14)
      g.strokeStyle = gray(1, 0.7)
      g.lineWidth = 1.5
      g.beginPath()
      g.moveTo(midX(f) - 22, midY(f))
      g.lineTo(midX(f) + 22, midY(f))
      g.moveTo(midX(f), midY(f) - 22)
      g.lineTo(midX(f), midY(f) + 22)
      g.stroke()
      draw("'04 10 12", fnt(16, 700, MONO), rgb(1, 0.65, 0.15, 0.95), f.x + 16, maxY(f) - 26)
      g.restore()
      break
    }

    case "sakura": {
      withShadow(rgb(0.9, 0.45, 0.6, 0.22), 14, 0, 4, () => fillRound(cell, 24, WHITE))
      const frame = inset(cell, 12)
      clipped(photo, frame, 16)
      strokeRound(frame, 16, rgb(0.9, 0.55, 0.68, 0.6), 1.5)
      petal(maxX(cell) - 10, cell.y + 12, 24, 35)
      break
    }

    case "neon": {
      const tube = index % 2 === 0 ? "#00ffff" : rgb(1, 0.2, 0.75)
      const frame = inset(cell, 8)
      withShadow(tube, 28, 0, 0, () => strokeRound(frame, 20, tube, 5))
      strokeRound(frame, 20, WHITE, 1.8)
      clipped(photo, inset(frame, 7), 14)
      break
    }

    case "pastel": {
      withShadow(rgb(0.2, 0.4, 0.3, 0.14), 12, 0, 4, () => fillRound(cell, 20, WHITE))
      clipped(photo, inset(cell, 14), 12)
      const tapes = [rgb(0.98, 0.78, 0.82, 0.85), rgb(0.72, 0.9, 0.82, 0.85), rgb(0.98, 0.92, 0.65, 0.85), rgb(0.82, 0.84, 0.98, 0.85)]
      fillRound({ x: midX(cell) - 55, y: cell.y - 4, w: 110, h: 26 }, 4, tapes[index % tapes.length])
      break
    }

    case "love": {
      withShadow(rgb(0.8, 0.1, 0.2, 0.25), 16, 0, 4, () => fillRound(cell, 22, WHITE))
      const frame = inset(cell, 12)
      clipped(photo, frame, 14)
      strokeRound(frame, 14, rgb(0.88, 0.2, 0.3, 0.7), 1.5)
      symbol("heart.fill", rgb(0.9, 0.2, 0.3, 0.8), maxX(cell) - 16, maxY(cell) - 16, 18)
      break
    }

    case "album": {
      withShadow(gray(0, 0.35), 16, 0, 5, () => fillRound(cell, 16, gray(0.15, 0.9)))
      const frame = inset(cell, 8)
      clipped(photo, frame, 10)
      strokeRound(frame, 10, gray(1, 0.3), 1.2)
      draw(`TRACK 0${index + 1}`, fnt(13, 700, MONO), gray(1, 0.7), cell.x + 16, cell.y + 12)
      break
    }
  }
}

/** A Windows-98-style window with the photo inside. */
function drawWindow(photo: HTMLCanvasElement, cell: Rect, title: string) {
  bevel(cell, true)
  const inner = inset(cell, 6)
  const bar = { x: inner.x, y: inner.y, w: inner.w, h: 46 }
  g.fillStyle = gradient(bar, 0, [rgb(0, 0, 0.5), rgb(0.06, 0.52, 0.82)])
  g.fillRect(bar.x, bar.y, bar.w, bar.h)
  draw(title, fnt(24, 700), WHITE, bar.x + 14, bar.y + 9)
  ;["_", "□", "×"].forEach((glyph, i) => {
    const b = { x: maxX(bar) - (3 - i) * 42 - 4, y: bar.y + 7, w: 36, h: 32 }
    bevel(b, true)
    setText(fnt(22, 800), BLACK)
    g.textAlign = "center"
    g.textBaseline = "middle"
    g.fillText(glyph, midX(b), midY(b) + 1)
  })
  const area = { x: inner.x + 4, y: maxY(bar) + 6, w: inner.w - 8, h: maxY(inner) - maxY(bar) - 10 }
  bevel(inset(area, -3), false)
  clipped(photo, area)
}

// MARK: - Background

function averageColor(image: CanvasImageSource): [number, number, number] | null {
  try {
    const c = document.createElement("canvas")
    c.width = c.height = 32 // a 1×1 drawImage samples a few pixels instead of averaging
    const x = c.getContext("2d", { willReadFrequently: true })!
    x.drawImage(image, 0, 0, 32, 32)
    const d = x.getImageData(0, 0, 32, 32).data
    const sum = [0, 0, 0]
    for (let i = 0; i < d.length; i += 4) for (let k = 0; k < 3; k++) sum[k] += d[i + k]
    return sum.map((v) => v / 1024 / 255) as [number, number, number]
  } catch {
    return null // cross-origin artwork taints the canvas
  }
}

function drawBackground(style: StripStyle, canvas: Rect, info: StripInfo, photos: HTMLCanvasElement[]) {
  switch (style) {
    case "receipt": {
      fill(canvas, rgb(0.86, 0.85, 0.82))
      // Paper with torn, zigzag ends.
      const paper = inset(canvas, 50, 0)
      const tooth = 22
      g.beginPath()
      g.moveTo(paper.x, paper.y + tooth)
      let x = paper.x
      let up = true
      while (x < maxX(paper)) {
        x = Math.min(x + tooth, maxX(paper))
        g.lineTo(x, paper.y + (up ? 0 : tooth))
        up = !up
      }
      g.lineTo(maxX(paper), maxY(paper) - tooth)
      up = true
      while (x > paper.x) {
        x = Math.max(x - tooth, paper.x)
        g.lineTo(x, maxY(paper) - (up ? 0 : tooth))
        up = !up
      }
      g.closePath()
      withShadow(gray(0, 0.2), 16, 0, 4, () => {
        g.fillStyle = rgb(0.985, 0.98, 0.965)
        g.fill()
      })
      break
    }

    case "social":
      fill(canvas, WHITE)
      break

    case "player": {
      // Backdrop tinted like a music app's now playing screen: from the cover art, else the photos.
      const [r, gg, b] = (info.artwork && averageColor(info.artwork)) || averageColor(photos[0]) || [0.2, 0.3, 0.5]
      g.fillStyle = gradient(canvas, -90, [rgb(r * 0.65, gg * 0.65, b * 0.65), gray(0.06)])
      g.fillRect(0, 0, canvas.w, canvas.h)
      break
    }

    case "scrapbook":
      fill(canvas, rgb(0.91, 0.86, 0.77))
      g.fillStyle = rgb(0.8, 0.72, 0.6, 0.5)
      g.beginPath()
      for (let y = 24; y < canvas.h; y += 40) for (let x = 24; x < canvas.w; x += 40) {
        g.moveTo(x + 5, y + 2.5)
        g.arc(x + 2.5, y + 2.5, 2.5, 0, Math.PI * 2)
      }
      g.fill()
      break

    case "coquette":
      fill(canvas, rgb(0.97, 0.84, 0.88))
      // Gingham: translucent white bands both ways.
      for (let x = 0; x < canvas.w; x += 80) fill({ x, y: 0, w: 40, h: canvas.h }, gray(1, 0.32))
      for (let y = 0; y < canvas.h; y += 80) fill({ x: 0, y, w: canvas.w, h: 40 }, gray(1, 0.32))
      break

    case "postcard": {
      const paperColor = rgb(0.985, 0.97, 0.94)
      const blue = rgb(0.13, 0.32, 0.62)
      fill(canvas, paperColor)
      drawAirmailBorder(canvas, 32, 42)
      const card = inset(canvas, 32)
      fill(card, paperColor)
      const frame = inset(card, 10)
      g.strokeStyle = rgb(0.75, 0.68, 0.58, 0.6)
      g.lineWidth = 1.5
      g.strokeRect(frame.x, frame.y, frame.w, frame.h)
      const badge = { x: frame.x + 20, y: frame.y + 14, w: 270, h: 40 }
      fillRound(badge, 6, blue)
      setText(fnt(16, 700), WHITE, 1.5)
      g.textAlign = "center"
      g.textBaseline = "middle"
      g.fillText("✈  PAR AVION  ·  AIR MAIL", midX(badge), midY(badge))
      break
    }

    case "desktop": {
      fill(canvas, rgb(0, 0.5, 0.5))
      // Taskbar along the bottom.
      const bar = { x: 0, y: maxY(canvas) - 76, w: canvas.w, h: 76 }
      fill(bar, gray(0.75))
      fill({ x: 0, y: bar.y, w: canvas.w, h: 3 }, WHITE)
      const start = { x: 12, y: bar.y + 12, w: 150, h: 52 }
      bevel(start, true)
      draw("▦ Start", fnt(28, 800), BLACK, start.x + 18, start.y + 10)
      const clock = { x: canvas.w - 162, y: bar.y + 12, w: 150, h: 52 }
      bevel(clock, false)
      setText(fnt(26, 500, MONO), BLACK)
      g.textAlign = "center"
      g.fillText(formatDate(info.date ?? new Date(), "HH:mm"), midX(clock), clock.y + 12)
      break
    }

    case "classic": {
      fill(canvas, rgb(0.985, 0.982, 0.975))
      const card = inset(canvas, 20)
      strokeRound(card, 10, gray(0, 0.08), 1.2)
      centered("✦  KOREA SELF PHOTO BOOTH  ·  AUTOMATIC STUDIO  ✦", fnt(15, 500, ROUND), gray(0.35, 0.8), midX(canvas), card.y + 16, undefined, 2)
      break
    }

    case "midnight":
      g.fillStyle = gradient(canvas, -90, [rgb(0.08, 0.08, 0.1), rgb(0.03, 0.03, 0.04)])
      g.fillRect(0, 0, canvas.w, canvas.h)
      strokeRound(inset(canvas, 18), 8, gray(1, 0.12), 1)
      break

    case "film": {
      fill(canvas, rgb(0.06, 0.06, 0.07))
      g.fillStyle = rgb(0.92, 0.91, 0.88)
      for (let y = 24; y < canvas.h - 30; y += 82) {
        for (const x of [34, canvas.w - 34 - 36]) {
          g.beginPath()
          g.roundRect(x, y, 36, 50, 8)
          g.fill()
        }
      }
      draw("▶ KODAK PORTRA 400  ·  5094  ·  SAFETY FILM  ·  ISO 400/27°", fnt(18, 700, COURIER), rgb(0.91, 0.64, 0.23, 0.9), 120, 16)
      break
    }

    case "polaroid":
      fill(canvas, rgb(0.96, 0.945, 0.91))
      break

    case "y2k":
      g.fillStyle = gradient(canvas, -70, [rgb(1, 0.58, 0.88), rgb(0.64, 0.52, 1), rgb(0.48, 0.86, 1)])
      g.fillRect(0, 0, canvas.w, canvas.h)
      break

    case "sakura":
      g.fillStyle = gradient(canvas, -90, [rgb(1, 0.95, 0.97), rgb(1, 0.86, 0.92)])
      g.fillRect(0, 0, canvas.w, canvas.h)
      break

    case "retro": {
      fill(canvas, rgb(0.96, 0.93, 0.84))
      const colors = [rgb(0.91, 0.64, 0.23), rgb(0.85, 0.34, 0.17), rgb(0.72, 0.18, 0.14), rgb(0.38, 0.18, 0.1)]
      colors.forEach((c, i) => {
        fill({ x: 18 + i * 10, y: 0, w: 10, h: canvas.h }, c)
        fill({ x: canvas.w - 18 - (4 - i) * 10, y: 0, w: 10, h: canvas.h }, c)
      })
      break
    }

    case "newspaper":
      fill(canvas, rgb(0.94, 0.93, 0.89))
      centered("✦ THE DAILY CHRONICLE ✦", fnt(46, 700, SERIF), BLACK, midX(canvas), 14, undefined, 3)
      fill({ x: 40, y: 68, w: canvas.w - 80, h: 2.5 }, BLACK)
      fill({ x: 40, y: 73, w: canvas.w - 80, h: 1 }, BLACK)
      centered("VOL. CVIII · NO. 42  ·  SPECIAL PHOTO EDITION  ·  PRICE: TWO CENTS", fnt(15, 400, SERIF), gray(0.2), midX(canvas), 79)
      fill({ x: 40, y: 98, w: canvas.w - 80, h: 1.5 }, BLACK)
      break

    case "neon":
      g.fillStyle = gradient(canvas, -90, [rgb(0.04, 0.03, 0.12), rgb(0.09, 0.04, 0.22)])
      g.fillRect(0, 0, canvas.w, canvas.h)
      break

    case "pastel":
      fill(canvas, rgb(0.92, 0.97, 0.94))
      g.strokeStyle = rgb(0.65, 0.82, 0.75, 0.35)
      g.lineWidth = 1
      g.beginPath()
      for (let x = 24; x < canvas.w; x += 32) {
        g.moveTo(x, 0)
        g.lineTo(x, canvas.h)
      }
      for (let y = 24; y < canvas.h; y += 32) {
        g.moveTo(0, y)
        g.lineTo(canvas.w, y)
      }
      g.stroke()
      break

    case "love":
      g.fillStyle = gradient(canvas, -90, [rgb(0.58, 0.08, 0.16), rgb(0.35, 0.04, 0.09)])
      g.fillRect(0, 0, canvas.w, canvas.h)
      break

    case "album":
      if (info.artwork) {
        g.save()
        g.filter = `blur(${canvas.w / 24}px)`
        drawAspectFill(info.artwork, inset(canvas, -canvas.w / 12))
        g.restore()
        fill(canvas, gray(0, 0.45))
      } else {
        fill(canvas, rgb(0.08, 0.08, 0.09))
        g.strokeStyle = gray(1, 0.06)
        g.lineWidth = 1.2
        for (let dr = 20; dr < 320; dr += 30) {
          ovalPath(inset({ x: midX(canvas) - 350, y: -100, w: 700, h: 700 }, dr))
          g.stroke()
        }
      }
      break
  }
}

function drawAirmailBorder(canvas: Rect, border: number, stripe: number) {
  g.save()
  const inner = inset(canvas, border)
  g.beginPath()
  g.rect(canvas.x, canvas.y, canvas.w, canvas.h)
  g.rect(inner.x, inner.y, inner.w, inner.h)
  g.clip("evenodd")
  fill(canvas, WHITE)
  const step = stripe * 1.4 * 2
  const band = (x: number, color: string) => {
    g.beginPath()
    g.moveTo(x, 0)
    g.lineTo(x + stripe, 0)
    g.lineTo(x + stripe - canvas.h, canvas.h)
    g.lineTo(x - canvas.h, canvas.h)
    g.closePath()
    g.fillStyle = color
    g.fill()
  }
  for (let x = -canvas.h - 200; x < canvas.w + canvas.h + 200; x += step) {
    band(x, rgb(0.85, 0.22, 0.22))
    band(x + stripe * 1.4, rgb(0.13, 0.32, 0.62))
  }
  g.restore()
}

function drawSocialHeader(avatar: HTMLCanvasElement, width: number) {
  const a = { x: 30, y: 30, w: 90, h: 90 }
  // Story ring around the avatar.
  const ring = inset(a, -6)
  ovalPath(ring)
  g.fillStyle = gradient(ring, 45, ["#ffcc00", "#ff9500", "#ff2d55", "#af52de"])
  g.fill()
  ovalPath(inset(a, -2))
  g.fillStyle = WHITE
  g.fill()
  g.save()
  ovalPath(a)
  g.clip()
  drawAspectFill(avatar, a)
  g.restore()
  draw("bestie.diaries", fnt(34, 700), BLACK, 146, 32)
  draw("Original audio", fnt(26), gray(0.45), 146, 76)
  draw("•••", fnt(34, 700), BLACK, width - 90, 46)
}

// MARK: - Decorations

function drawDecorations(style: StripStyle, canvas: Rect, avoid: Rect[]) {
  const rng = new SeededRandom(7n)
  // Argument order matches the Swift calls so the RNG sequence (and the layout) is the same.
  switch (style) {
    case "scrapbook": {
      const doodles = ["star", "heart", "sparkle", "sun.max", "scribble", "music.note", "camera"]
      for (let i = 0; i < 18; i++) {
        const name = rng.pick(doodles)
        const [x, y] = scatter(canvas, avoid, rng)
        symbol(name, rgb(0.23, 0.18, 0.18, 0.75), x, y, rng.range(22, 40))
      }
      break
    }
    case "coquette":
      for (let i = 0; i < 22; i++) {
        const color = gray(1, rng.range(0.5, 0.9))
        const [x, y] = scatter(canvas, avoid, rng)
        symbol("heart.fill", color, x, y, rng.range(16, 34))
      }
      break
    case "y2k":
      for (let i = 0; i < 26; i++) {
        const size = rng.range(22, 54)
        const name = rng.bool() ? "sparkle" : "star.fill"
        const [x, y] = scatter(canvas, avoid, rng)
        symbol(name, WHITE, x, y, size)
      }
      break
    case "sakura":
      for (let i = 0; i < 30; i++) {
        const [x, y] = scatter(canvas, avoid, rng)
        const size = rng.range(18, 34)
        petal(x, y, size, rng.range(0, 360))
      }
      break
    case "love":
      for (let i = 0; i < 28; i++) {
        const color = rgb(1, 0.75, 0.8, rng.range(0.6, 1))
        const [x, y] = scatter(canvas, avoid, rng)
        symbol("heart.fill", color, x, y, rng.range(20, 50))
      }
      break
    case "film": {
      const color = rgb(0.91, 0.64, 0.23)
      const f = fnt(22, 700, COURIER)
      avoid.slice(0, -1).forEach((cell, i) => {
        draw(`${i + 1}  ▸  ${i + 1}A`, f, color, cell.x, maxY(cell) + 4)
        rotated("PORTRA 400  ▸", f, rgb(0.91, 0.64, 0.23, 0.8), canvas.w - 105, midY(cell))
      })
      break
    }
    case "neon":
      for (let i = 0; i < 14; i++) {
        const color = rng.bool() ? "#00ffff" : rgb(1, 0.3, 0.8)
        const [x, y] = scatter(canvas, avoid, rng)
        symbol("sparkle", color, x, y, rng.range(16, 30))
      }
      break
    case "midnight":
      for (let i = 0; i < 16; i++) {
        const color = gray(1, rng.range(0.2, 0.6))
        const [x, y] = scatter(canvas, avoid, rng)
        symbol("sparkle", color, x, y, rng.range(14, 24))
      }
      break
    case "pastel": {
      const stickers = ["sparkle", "heart.fill", "cloud.fill", "sun.max.fill", "star.fill"]
      const colors = [rgb(0.98, 0.72, 0.78, 0.75), rgb(0.65, 0.82, 0.75, 0.75), rgb(0.98, 0.88, 0.55, 0.75), rgb(0.75, 0.82, 0.98, 0.75)]
      for (let i = 0; i < 16; i++) {
        const name = rng.pick(stickers)
        const color = rng.pick(colors)
        const [x, y] = scatter(canvas, avoid, rng)
        symbol(name, color, x, y, rng.range(18, 34))
      }
      break
    }
  }
}

// MARK: - Footer

function drawFooter(style: StripStyle, rect: Rect, info: StripInfo) {
  const date = info.date ?? new Date()
  const ds = (p: string) => formatDate(date, p)
  const center = midX(rect)
  const custom = info.caption?.trim() || undefined
  const title = (fallback: string) => custom ?? fallback
  maxTextWidth = rect.w - 60
  let y = rect.y

  switch (style) {
    case "receipt": {
      const mono = fnt(29, 400, MONO)
      const bold = fnt(29, 700, MONO)
      const ink = gray(0.12)
      const columns = 32
      const line = (l: string, r = "") => l + " ".repeat(Math.max(1, columns - l.length - r.length)) + r
      const rule = "-".repeat(columns)
      y += 34
      y += centered(`★ ${(custom ?? "PHOTOBOX").toUpperCase()} ★`, fnt(42, 800, MONO), ink, center, y) + 6
      for (const [text, f] of [
        ["OPEN DAILY · NO REFUNDS ON VIBES", mono], [line(ds("dd/MM/yyyy"), ds("HH:mm")), mono], [rule, mono],
        [line("4x CORE MEMORY", "PRICELESS"), mono], [line("1x GOOD VIBES", "FREE"), mono], [line("1x INSIDE JOKE", "FREE"), mono],
        [rule, mono], [line("TOTAL", "PRICELESS"), bold],
      ] as const) {
        y += centered(text, f, ink, center, y) + 2
      }
      g.fillStyle = ink
      barcode(new SeededRandom(BigInt(Math.floor(date.getTime() / 1000)) / 60n), center - 200, center + 200, y + 18, 70, 2, 7, 2, 6)
      centered("THANK YOU, COME AGAIN ♡", mono, ink, center, y + 100)
      break
    }

    case "social": {
      const x = rect.x + 24
      y += 20
      ;["heart.fill", "bubble.right", "paperplane"].forEach((name, i) =>
        symbol(name, i === 0 ? rgb(0.93, 0.22, 0.33) : BLACK, x + 20 + i * 76, y + 24, 40),
      )
      symbol("bookmark", BLACK, maxX(rect) - 44, y + 24, 40)
      y += 72
      draw("Liked by you and 1,024 others", fnt(30, 600), BLACK, x, y)
      y += 44
      draw("bestie.diaries ", fnt(30, 600), BLACK, x, y)
      const nameW = g.measureText("bestie.diaries ").width
      draw(custom ?? "core memories unlocked ✨", fnt(30), BLACK, x + nameW, y, rect.w - 48 - nameW)
      y += 44
      draw("View all 128 comments", fnt(27), gray(0.5), x, y)
      y += 40
      draw(ds("d MMMM").toUpperCase(), fnt(21, 500), gray(0.55), x, y)
      break
    }

    case "player": {
      // The song that was playing when the strip was taken; your text becomes the "playing from" line.
      const x = rect.x + 54
      const width = rect.w - 108
      y += 30
      const songTitle = info.songTitle ?? custom ?? "our little moments"
      const artist = info.artist ?? "you & me"
      if (info.songTitle && custom) {
        draw("PLAYING FROM  " + custom.toUpperCase(), fnt(20, 700), gray(1, 0.6), x, y, width)
        y += 34
      }
      let textX = x
      if (info.artwork) {
        const thumb = { x, y: y + 4, w: 96, h: 96 }
        g.save()
        roundPath(thumb, 10)
        g.clip()
        g.drawImage(info.artwork, thumb.x, thumb.y, thumb.w, thumb.h)
        g.restore()
        textX += 116
      }
      draw(songTitle, fnt(46, 700), WHITE, textX, y, x + width - 70 - textX)
      symbol("heart.fill", rgb(0.2, 0.85, 0.45), x + width - 20, y + 32, 40)
      y += 60
      draw(artist, fnt(30, 500), gray(1, 0.6), textX, y, x + width - 70 - textX)
      y += 82
      const duration = info.songDuration ?? 225
      const position = Math.min(info.songPosition ?? 84, duration)
      const fraction = position / duration
      fill({ x, y, w: width, h: 6 }, gray(1, 0.25))
      fill({ x, y, w: width * fraction, h: 6 }, WHITE)
      ovalPath({ x: x + width * fraction - 10, y: y - 7, w: 20, h: 20 })
      g.fill()
      y += 20
      const clock = (sec: number) => `${Math.floor(sec / 60)}:${pad2(Math.floor(sec) % 60)}`
      draw(clock(position), fnt(22, 500, MONO), gray(1, 0.6), x, y)
      setText(fnt(22, 500, MONO), gray(1, 0.6))
      g.textAlign = "right"
      g.fillText("-" + clock(duration - position), x + width, y)
      y += 90
      const controls: [string, number][] = [["shuffle", 32], ["backward.fill", 44], ["", 0], ["forward.fill", 44], ["repeat", 32]]
      controls.forEach(([name, size], i) => {
        const cx = x + 16 + ((width - 32) * i) / 4
        if (name) return symbol(name, WHITE, cx, y, size)
        // Play button: white disc with a dark pause glyph.
        ovalPath({ x: cx - 46, y: y - 46, w: 92, h: 92 })
        g.fillStyle = WHITE
        g.fill()
        symbol(info.isPlaying === false ? "play.fill" : "pause.fill", gray(0.1), cx, y, 38)
      })
      break
    }

    case "scrapbook": {
      const ink = rgb(0.23, 0.18, 0.18)
      y += 40
      y += centered(custom ?? "our little adventure", fnt(72, 700, HAND), ink, center, y)
      centered(`— ${ds("dd.MM.yy")} —`, fnt(34, 700, HAND), rgb(0.23, 0.18, 0.18, 0.7), center, y + 10)
      break
    }

    case "coquette": {
      const rose = rgb(0.76, 0.1, 0.36)
      y += 30
      y += centered(custom ?? "lovely", fnt(110, 700, HAND), rose, center, y)
      centered(`🎀  ${ds("dd · MM · yyyy")}  🎀`, fnt(28, 600, ROUND), rgb(0.76, 0.1, 0.36, 0.8), center, y)
      break
    }

    case "postcard":
      drawPostcardFooter(rect, custom, date)
      break

    case "desktop":
      centered(custom ?? "my_memories.exe", fnt(54, 700, COURIER), WHITE, center, y + 34, gray(0, 0.6))
      break

    case "classic": {
      y += 28
      centered(title("LIFE FOUR CUTS").toUpperCase(), fnt(60, 900, ROUND), gray(0.1), center, y, undefined, 3.5)
      y += 66
      centered("MEMORIES OF THE DAY · HARU PHOTO STUDIO", fnt(20, 600), gray(0.45), center, y)
      y += 30
      centered(ds("yyyy.MM.dd  ·  HH:mm"), fnt(21, 500, MONO), gray(0.5), center, y)
      y += 34
      // Photobooth barcode.
      g.fillStyle = gray(0.15)
      barcode(new SeededRandom(BigInt(Math.floor(date.getTime() / 1000)) / 100n), center - 160, center + 160, y, 40, 2, 6, 2, 5)
      centered("PHOTO ID: #042918 · AUTOMATIC SYSTEM", fnt(13, 700, MONO), gray(0.4, 0.8), center, y + 46)
      break
    }

    case "midnight":
      y += 28
      centered(custom ?? "OPENNOTCHI ARCHIVE", fnt(54, 700, SERIF), WHITE, center, y, undefined, 3.5)
      y += 68
      centered("COLLECTION N° 01  ·  PRIVATE EXHIBITION", fnt(20, 600), gray(0.65), center, y)
      y += 30
      centered("№ 0084 / LIMITED EDITION", fnt(17, 700, MONO), gray(0.5), center, y)
      y += 28
      centered(ds("yyyy.MM.dd  ·  HH:mm:ss") + " UTC", fnt(19, 500, MONO), gray(0.45), center, y)
      break

    case "film": {
      const amber = rgb(0.91, 0.64, 0.23)
      y += 24
      y += centered(title("KODAK PORTRA 400"), fnt(48, 700, COURIER), amber, center, y) + 4
      centered("EXPOSURE: 36 EXP  ·  C-41 PROCESS  ·  COLOR NEGATIVE", fnt(21, 700, COURIER), rgb(0.91, 0.64, 0.23, 0.8), center, y)
      y += 32
      centered("’26  10  12", fnt(30, 700, COURIER), rgb(1, 0.45, 0.15), center, y, rgb(1, 0.3, 0.1, 0.6))
      break
    }

    case "polaroid": {
      const ink = rgb(0.12, 0.18, 0.32)
      y += 28
      y += centered(title("good times ✌️"), fnt(76, 700, HAND), ink, center, y) + 4
      centered(ds("d MMMM yyyy"), fnt(34, 700, HAND), rgb(0.12, 0.18, 0.32, 0.75), center, y)
      y += 44
      centered("★ POLAROID COLOR 600 FILM ★", fnt(18, 700), gray(0.45, 0.7), center, y)
      break
    }

    case "y2k": {
      y += 24
      y += centered(custom ? `✦ ${custom} ✦` : "✦ cyber besties ✦", fnt(68, 900, ROUND), WHITE, center, y, rgb(0.5, 0.2, 0.9, 0.8)) + 4
      const bar = { x: center - 210, y, w: 420, h: 40 }
      fillRound(bar, 20, gray(1, 0.25))
      draw(`● ONLINE  ·  ♪ ${info.songTitle ?? "Favorite Track"}`, fnt(17, 700), WHITE, bar.x + 20, bar.y + 10, 380)
      y += 50
      centered(ds("MM/dd/yyyy") + "  [SP 00:24:12]", fnt(24, 700, ROUND), gray(1, 0.9), center, y)
      break
    }

    case "sakura": {
      const pink = rgb(0.78, 0.25, 0.45)
      y += 20
      y += centered(title("sakura days"), fnt(84, 700, HAND), pink, center, y)
      centered("桜の季節  ·  SPRINGTIME MEMORIES", fnt(22, 600), rgb(0.78, 0.25, 0.45, 0.85), center, y)
      y += 34
      const seal = { x: center - 22, y, w: 44, h: 44 }
      fillRound(seal, 8, rgb(0.82, 0.2, 0.2, 0.9))
      setText(fnt(24, 700), WHITE)
      g.textAlign = "center"
      g.textBaseline = "middle"
      g.fillText("桜", midX(seal), midY(seal) + 1)
      y += 52
      centered(ds("yyyy . MM . dd"), fnt(24, 600, ROUND), rgb(0.78, 0.25, 0.45, 0.75), center, y)
      break
    }

    case "retro": {
      const brown = rgb(0.42, 0.2, 0.1)
      const orange = rgb(0.85, 0.34, 0.17)
      y += 20
      centered(title("GROOVY"), fnt(84, 900, ROUND), brown, center, y, orange)
      y += 92
      centered("☀  SUPER 8 SOUND  ☀  CALIFORNIA 1978", fnt(24, 500, ROUND), orange, center, y)
      y += 34
      centered(ds("MMMM d, yyyy").toUpperCase(), fnt(22, 500, ROUND), rgb(0.42, 0.2, 0.1, 0.8), center, y)
      break
    }

    case "newspaper": {
      y += 16
      fill({ x: rect.x + 30, y, w: rect.w - 60, h: 3 }, BLACK)
      y += 8
      y += centered(title("MOMENTS THAT MADE HISTORY").toUpperCase(), fnt(62, 700, SERIF), BLACK, center, y) + 4
      fill({ x: rect.x + 30, y, w: rect.w - 60, h: 1.5 }, BLACK)
      y += 10
      centered(ds("EEEE, MMMM d, yyyy").toUpperCase() + "  ·  CITY EDITION  ·  FREE", fnt(22, 400, SERIF), gray(0.2), center, y)
      y += 34
      const body = fnt(16, 400, SERIF)
      const colW = (rect.w - 100) / 2
      wrapped("Eyewitnesses confirm today was one for the record books. Spirits remained extraordinary throughout, with genuine laughter echoed across every frame captured.", body, gray(0.25), { x: rect.x + 40, y, w: colW - 10, h: 80 })
      wrapped("Analysts predict these memories will remain timeless for decades to come. Special souvenir print issued by OpenNotchi Press.", body, gray(0.25), { x: center + 10, y, w: colW - 10, h: 80 })
      break
    }

    case "neon": {
      const pink = rgb(1, 0.25, 0.8)
      y += 24
      y += centered(title("main character"), fnt(72, 800, ROUND), pink, center, y, pink) + 4
      centered("ネオン  ·  TOKYO NIGHTS 2026", fnt(24, 700), "#00ffff", center, y)
      y += 36
      centered(ds("dd.MM.yyyy") + "  22:50:00", fnt(24, 700, ROUND), WHITE, center, y, "#00ffff")
      break
    }

    case "pastel": {
      const green = rgb(0.12, 0.45, 0.35)
      y += 22
      y += centered(title("core memories ♡"), fnt(64, 800, ROUND), green, center, y) + 2
      centered("— today was pure magic ✨ —", fnt(30, 700, HAND), rgb(0.12, 0.45, 0.35, 0.8), center, y)
      y += 36
      centered(ds("EEEE, d MMMM yyyy"), fnt(24, 600, ROUND), rgb(0.12, 0.45, 0.35, 0.7), center, y)
      break
    }

    case "love": {
      y += 18
      y += centered(title("mon amour ♡"), fnt(88, 700, HAND), WHITE, center, y, rgb(0.5, 0, 0.1, 0.6))
      const seal = { x: center - 26, y, w: 52, h: 52 }
      withShadow(gray(0, 0.3), 8, 0, 2, () => {
        ovalPath(seal)
        g.fillStyle = rgb(0.65, 0.1, 0.15)
        g.fill()
      })
      symbol("heart.fill", rgb(1, 0.85, 0.6), midX(seal), midY(seal), 24)
      y += 62
      centered("PARIS  ·  AVEC AMOUR  ·  " + ds("yyyy"), fnt(22, 600), gray(1, 0.9), center, y)
      break
    }

    case "album": {
      y += 24
      const thumb = 130
      const text = info.songTitle ?? "Midnight Drive"
      const sub = info.artist ?? "The Placeholders"
      const titleFont = fnt(46, 800, ROUND)
      setText(titleFont, WHITE)
      const titleWidth = Math.min(g.measureText(text).width, rect.w - thumb - 220)
      const startX = center - (thumb + 30 + titleWidth) / 2
      const disc = { x: startX, y, w: thumb, h: thumb }
      if (info.artwork) {
        g.save()
        roundPath(disc, 14)
        g.clip()
        g.drawImage(info.artwork, disc.x, disc.y, thumb, thumb)
        g.restore()
      } else {
        ovalPath(disc)
        g.fillStyle = gray(0.12)
        g.fill()
        g.strokeStyle = gray(1, 0.2)
        g.lineWidth = 1
        for (const dr of [18, 32, 46]) {
          ovalPath(inset(disc, dr))
          g.stroke()
        }
        ovalPath(inset(disc, 45))
        g.fillStyle = rgb(0.85, 0.25, 0.25)
        g.fill()
        symbol("music.note", WHITE, midX(disc), midY(disc), 20)
      }
      const textX = startX + thumb + 26
      draw(custom ?? "♪ NOW PLAYING", fnt(20, 700, ROUND), gray(1, 0.7), textX, y + 2, rect.w - thumb - 100)
      draw(text, titleFont, WHITE, textX, y + 28, titleWidth + 1)
      draw(sub, fnt(26, 500, ROUND), gray(1, 0.75), textX, y + 84, titleWidth + 1)
      const badgeY = y + 140
      draw("[ HI-RES AUDIO · STEREO ]", fnt(16, 700, MONO), gray(1, 0.55), startX, badgeY)
      g.fillStyle = gray(1, 0.65)
      ;[12, 22, 16, 28, 34, 20, 14, 30, 24, 18, 26, 12].forEach((h, i) => {
        g.beginPath()
        g.roundRect(startX + 240 + i * 8, badgeY + 16 - h, 4, h, 2)
        g.fill()
      })
      break
    }
  }
}

function drawPostcardFooter(rect: Rect, caption: string | undefined, date: Date) {
  const ink = rgb(0.16, 0.2, 0.28)
  const label = gray(0.4, 0.8)
  const dividerX = midX(rect)
  const topY = rect.y + 24
  const bottomY = maxY(rect) - 24
  fill({ x: dividerX - 0.75, y: topY + 40, w: 1.5, h: bottomY - topY - 40 }, rgb(0.75, 0.7, 0.64, 0.7))
  centered("CARTE POSTALE  ★  POST CARD", fnt(36, 700, SERIF), rgb(0.25, 0.22, 0.2, 0.9), dividerX, topY)

  // Left: message.
  const msgLeft = rect.x + 50
  let msgY = topY + 54
  draw("MESSAGE / CORRESPONDENCE:", fnt(18, 700), label, msgLeft, msgY)
  msgY += 34
  wrapped(caption ?? "Greetings from OpenNotchi! Wishing you were here ♡", fnt(44, 700, HAND), ink, { x: msgLeft, y: msgY, w: dividerX - msgLeft - 30, h: 160 })
  draw(`Date: ${formatDate(date, "d MMMM yyyy")}`, fnt(28, 700, HAND), rgb(0.16, 0.2, 0.28, 0.8), msgLeft, bottomY - 35)

  // Right: stamp, postmark and address lines.
  const rightX = dividerX + 35
  const stamp = { x: maxX(rect) - 50 - 130, y: topY + 45, w: 130, h: 160 }
  drawPerforatedStamp(stamp, rgb(0.85, 0.22, 0.22))
  symbol("airplane", WHITE, midX(stamp), stamp.y + 65, 48)
  centered("AIR MAIL", fnt(16, 700), WHITE, midX(stamp), stamp.y + 115)
  centered("50¢", fnt(22, 700), WHITE, midX(stamp), stamp.y + 20)
  drawPostmark(stamp.x - 10, stamp.y + 70, formatDate(date, "d MMMM yyyy").toUpperCase())

  let addrY = maxY(stamp) + 35
  draw("ADDRESS / DESTINATAIRE:", fnt(18, 700), label, rightX, addrY)
  addrY += 34
  for (const line of ["To: __________________________________", "     __________________________________", "     __________________________________", "     OpenNotchi · Special Delivery ✈"]) {
    draw(line, fnt(22, 700, COURIER), gray(0.35, 0.85), rightX, addrY, maxX(rect) - 30 - rightX)
    addrY += 36
  }
}

function drawPerforatedStamp(r: Rect, color: string) {
  withShadow(gray(0, 0.2), 8, 1, 2, () => fill(r, gray(0.99)))
  fill(inset(r, 10), color)
  g.fillStyle = rgb(0.985, 0.97, 0.94)
  g.beginPath()
  const hole = (x: number, y: number) => {
    g.moveTo(x + 4.5, y)
    g.arc(x, y, 4.5, 0, Math.PI * 2)
  }
  for (let x = r.x + 8; x < maxX(r); x += 12) {
    hole(x, r.y)
    hole(x, maxY(r))
  }
  for (let y = r.y + 8; y < maxY(r); y += 12) {
    hole(r.x, y)
    hole(maxX(r), y)
  }
  g.fill()
}

function drawPostmark(cx: number, cy: number, dateString: string) {
  const ink = rgb(0.12, 0.18, 0.3, 0.8)
  g.strokeStyle = ink
  g.lineWidth = 2.5
  g.beginPath()
  g.arc(cx, cy, 55, 0, Math.PI * 2)
  g.stroke()
  g.lineWidth = 1.2
  g.beginPath()
  g.arc(cx, cy, 47, 0, Math.PI * 2)
  g.stroke()
  const saved = maxTextWidth
  maxTextWidth = 84
  centered("AIR MAIL POST", fnt(10, 700), ink, cx, cy - 28)
  centered(dateString, fnt(11, 700, COURIER), ink, cx, cy - 6)
  centered("★ VERIFIED ★", fnt(10, 700), ink, cx, cy + 16)
  maxTextWidth = saved
  g.strokeStyle = ink
  g.lineWidth = 2
  g.beginPath()
  for (const dy of [-16, 0, 16]) {
    g.moveTo(cx - 55, cy + dy)
    g.bezierCurveTo(cx - 80, cy + dy - 10, cx - 110, cy + dy + 10, cx - 135, cy + dy)
  }
  g.stroke()
}
