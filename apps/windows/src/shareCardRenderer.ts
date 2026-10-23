/**
 * High-resolution multi-aspect Canvas and Video renderer
 * for OpenNotchi Lyric Share Cards.
 *
 * Supports 10 styles, 3 aspect ratios (4:5 Post, 9:16 Story, 1:1 Square),
 * custom backdrop/cover, active line karaoke sync, and video recording.
 */

export type LyricCardStyle =
  | "aura"
  | "player"
  | "vhs"
  | "cassette"
  | "vinyl"
  | "glass"
  | "polaroid"
  | "paper"
  | "receipt"
  | "solid"

export type CardAspectRatio = "portrait" | "story" | "square"

export type LyricFont = "auto" | "sans" | "system" | "serif" | "mono" | "hand"
export type LyricAlign = "auto" | "left" | "center" | "right"

/** CSS/canvas font stacks; "auto" keeps each frame's own font. */
export const LYRIC_FONTS: Record<Exclude<LyricFont, "auto">, string> = {
  sans: "'Outfit', sans-serif",
  system: "'Segoe UI', system-ui, sans-serif",
  serif: "'Newsreader', Georgia, serif",
  mono: "Consolas, 'Courier New', monospace",
  hand: "'Caveat', cursive",
}

/** A still image or a playing video frame. */
type Backdrop = HTMLImageElement | HTMLVideoElement | null

export interface RenderCardOptions {
  title: string
  artist: string
  album?: string
  artworkUrl?: string | null
  accentColor: string
  lines: string[]
  times?: number[] // timestamps for lines
  time?: number // position in seconds
  duration?: number // total song duration in seconds
  elapsed?: number // elapsed time in seconds (for animation / video)
  activeLineIndex?: number | null // for video karaoke highlight
  style: LyricCardStyle
  aspectRatio: CardAspectRatio
  backdropUrl?: string | null
  backdropBlur?: number
  backdropZoom?: number
  lyricFont?: LyricFont
  fontScale?: number
  textAlign?: LyricAlign
  translations?: Record<string, string>
  showTranslation?: boolean
}

export function getCanvasDimensions(aspectRatio: CardAspectRatio = "portrait"): { width: number; height: number } {
  switch (aspectRatio) {
    case "story":
      return { width: 1080, height: 1920 }
    case "square":
      return { width: 1080, height: 1080 }
    case "portrait":
    default:
      return { width: 1080, height: 1350 }
  }
}

/** Loads an image into an HTMLImageElement safely */
export function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = "anonymous"
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error("Failed to load image"))
    img.src = src
  })
}

/** Draws rounded rectangle path */
export function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number,
) {
  const r = Math.min(radius, width / 2, height / 2)
  ctx.beginPath()
  ctx.moveTo(x + r, y)
  ctx.lineTo(x + width - r, y)
  ctx.quadraticCurveTo(x + width, y, x + width, y + r)
  ctx.lineTo(x + width, y + height - r)
  ctx.quadraticCurveTo(x + width, y + height, x + width - r, y + height)
  ctx.lineTo(x + r, y + height)
  ctx.quadraticCurveTo(x, y + height, x, y + height - r)
  ctx.lineTo(x, y + r)
  ctx.quadraticCurveTo(x, y, x + r, y)
  ctx.closePath()
}

/** Word wrapping helper for canvas text */
export function wrapText(
  ctx: CanvasRenderingContext2D,
  text: string,
  maxWidth: number,
): string[] {
  const words = text.split(" ")
  const lines: string[] = []
  let currentLine = words[0] || ""

  for (let i = 1; i < words.length; i++) {
    const word = words[i]
    const testLine = currentLine + " " + word
    const metrics = ctx.measureText(testLine)
    if (metrics.width > maxWidth) {
      lines.push(currentLine)
      currentLine = word
    } else {
      currentLine = testLine
    }
  }
  if (currentLine) lines.push(currentLine)
  return lines
}

/** Formats seconds into MM:SS */
export function formatTime(sec: number): string {
  const s = Math.max(0, Math.floor(sec))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
}

/** Formats time into digital timecode HH:MM:SS.CC */
export function formatTimecode(sec: number): string {
  const s = Math.max(0, sec)
  const totalSec = Math.floor(s)
  const h = Math.floor(totalSec / 3600)
  const m = Math.floor((totalSec % 3600) / 60)
  const sc = totalSec % 60
  const cs = Math.floor((s - totalSec) * 100)
  return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:${String(sc).padStart(2, "0")}.${String(cs).padStart(2, "0")}`
}

/** Determines whether a hex color is light or dark */
export function isLightColor(hex: string): boolean {
  let c = hex.replace("#", "")
  if (c.length === 3) c = c.split("").map((x) => x + x).join("")
  const r = parseInt(c.slice(0, 2), 16) || 0
  const g = parseInt(c.slice(2, 4), 16) || 0
  const b = parseInt(c.slice(4, 6), 16) || 0
  const yiq = (r * 299 + g * 587 + b * 114) / 1000
  return yiq >= 155
}

/** Grain noise texture overlay */
export function drawGrain(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  opacity: number,
  dark = false,
) {
  ctx.save()
  const grainCanvas = document.createElement("canvas")
  grainCanvas.width = 120
  grainCanvas.height = 120
  const gctx = grainCanvas.getContext("2d")
  if (!gctx) {
    ctx.restore()
    return
  }

  const imgData = gctx.createImageData(120, 120)
  const d = imgData.data
  for (let i = 0; i < d.length; i += 4) {
    const val = dark ? 0 : 255
    d[i] = val
    d[i + 1] = val
    d[i + 2] = val
    d[i + 3] = Math.random() * (opacity * 255)
  }
  gctx.putImageData(imgData, 0, 0)

  ctx.fillStyle = ctx.createPattern(grainCanvas, "repeat") || "transparent"
  ctx.fillRect(0, 0, width, height)
  ctx.restore()
}

/** Universal card footer branding */
export function drawFooter(
  ctx: CanvasRenderingContext2D,
  color: string,
  pad: number,
  width: number,
  height: number,
  align: "left" | "center" = "left",
) {
  ctx.save()
  ctx.font = "bold 26px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillStyle = color
  ctx.textAlign = align
  const x = align === "center" ? width / 2 : pad
  const y = height - 56
  ctx.fillText("❝  OpenNotchi", x, y)
  ctx.restore()
}

/** Draws custom background image with blur & dark gradient overlay if present */
function drawCustomBackdrop(
  ctx: CanvasRenderingContext2D,
  backdrop: Backdrop,
  width: number,
  height: number,
  blur = 12,
  zoom = 1,
) {
  if (!backdrop) return
  const bw = backdrop instanceof HTMLVideoElement ? backdrop.videoWidth : backdrop.width
  const bh = backdrop instanceof HTMLVideoElement ? backdrop.videoHeight : backdrop.height
  if (!bw || !bh) return
  ctx.save()
  if (blur > 0) {
    ctx.filter = `blur(${blur * 2}px)`
  }
  // Cover scale
  const scale = Math.max((width + blur * 4) / bw, (height + blur * 4) / bh) * zoom
  const w = bw * scale
  const h = bh * scale
  const x = (width - w) / 2
  const y = (height - h) / 2
  ctx.drawImage(backdrop, x, y, w, h)
  ctx.filter = "none"

  // Vignette overlay
  const overlay = ctx.createLinearGradient(0, 0, 0, height)
  overlay.addColorStop(0, "rgba(0,0,0,0.35)")
  overlay.addColorStop(0.5, "rgba(0,0,0,0.5)")
  overlay.addColorStop(1, "rgba(0,0,0,0.8)")
  ctx.fillStyle = overlay
  ctx.fillRect(0, 0, width, height)
  ctx.restore()
}

/* ==========================================================================
   LYRICS BLOCK RENDERER
   ========================================================================== */

interface LyricsBlockConfig {
  x: number
  y: number
  maxWidth: number
  maxHeight: number
  fontFamily: string
  color: string
  align: "left" | "center"
  fontWeight?: string
  lyricFont?: LyricFont
  fontScale?: number
  textAlign?: LyricAlign
  activeLineIndex?: number | null
  style?: LyricCardStyle
  translations?: Record<string, string>
  showTranslation?: boolean
}

export function drawLyricsBlock(
  ctx: CanvasRenderingContext2D,
  lines: string[],
  config: LyricsBlockConfig,
) {
  const totalChars = lines.join(" ").length
  let fontSize = 60
  if (totalChars > 220) fontSize = 38
  else if (totalChars > 160) fontSize = 44
  else if (totalChars > 100) fontSize = 50
  else if (totalChars > 60) fontSize = 56
  fontSize = Math.round(fontSize * (config.fontScale ?? 1))
  if (config.lyricFont && config.lyricFont !== "auto") config = { ...config, fontFamily: LYRIC_FONTS[config.lyricFont] }
  const align = config.textAlign && config.textAlign !== "auto" ? config.textAlign : config.align
  const alignX = align === "center" ? ctx.canvas.width / 2 : align === "right" ? config.x + config.maxWidth : config.x

  const lineHeight = fontSize * 1.42
  const activeIdx = config.activeLineIndex ?? null

  let currentY = config.y
  ctx.textAlign = align

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    const isCurrent = activeIdx === null || activeIdx === i

    ctx.save()

    // Opacity / Dimming for non-current lines in karaoke mode
    if (activeIdx !== null && !isCurrent) {
      ctx.globalAlpha = 0.32
    }

    // Active line highlight in paper style: subtle yellow marker
    if (config.style === "paper" && isCurrent && activeIdx !== null) {
      ctx.save()
      ctx.font = `${config.fontWeight ?? "bold"} ${fontSize}px ${config.fontFamily}`
      const metrics = ctx.measureText(line)
      const padX = 14
      const drawX = align === "center" ? (ctx.canvas.width - metrics.width) / 2 : align === "right" ? alignX - metrics.width : config.x
      ctx.fillStyle = "rgba(245, 158, 11, 0.28)"
      roundRect(ctx, drawX - padX, currentY - fontSize + 6, metrics.width + padX * 2, fontSize + 8, 8)
      ctx.fill()
      ctx.restore()
    }

    // Active line glow in neon / aura / glass styles
    if (isCurrent && activeIdx !== null) {
      if (config.style === "vhs") {
        ctx.shadowColor = "#00ffff"
        ctx.shadowBlur = 16
      } else if (config.style === "glass" || config.style === "aura") {
        ctx.shadowColor = "rgba(255,255,255,0.85)"
        ctx.shadowBlur = 14
      }
    }

    ctx.font = `${isCurrent ? "bold" : (config.fontWeight ?? "500")} ${fontSize}px ${config.fontFamily}`
    ctx.fillStyle = config.color

    const wrapped = wrapText(ctx, line, config.maxWidth)
    for (const wrapLine of wrapped) {
      const drawX = alignX
      ctx.fillText(wrapLine, drawX, currentY)
      currentY += lineHeight
    }

    // Translation line if enabled
    if (config.showTranslation && config.translations && config.translations[line]) {
      const trans = config.translations[line]
      ctx.font = `italic 500 ${Math.round(fontSize * 0.6)}px ${config.fontFamily}`
      ctx.fillStyle = isCurrent ? "rgba(255,255,255,0.75)" : "rgba(255,255,255,0.3)"
      const drawX = alignX
      ctx.fillText(trans, drawX, currentY)
      currentY += fontSize * 0.75
    }

    ctx.restore()
    currentY += fontSize * 0.28 // line margin
  }
}

/* ==========================================================================
   STYLE 1: AURA
   ========================================================================== */

function drawAura(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Base dark gradient
  const grad = ctx.createLinearGradient(0, 0, width, height)
  grad.addColorStop(0, "#181424")
  grad.addColorStop(1, "#08070d")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  } else if (artwork) {
    ctx.save()
    ctx.globalAlpha = 0.45
    ctx.filter = "blur(80px)"
    ctx.drawImage(artwork, -width * 0.3, -height * 0.2, width * 1.6, height * 1.4)
    ctx.filter = "none"
    ctx.restore()
  }

  // Accent radial glow
  const elapsed = options.elapsed ?? 0
  const pulse = options.activeLineIndex !== null ? Math.sin(elapsed * 2.5) * 0.08 : 0
  const radial = ctx.createRadialGradient(
    width / 2,
    height * 0.62,
    40,
    width / 2,
    height * 0.62,
    width * (0.8 + pulse),
  )
  radial.addColorStop(0, options.accentColor + "66")
  radial.addColorStop(1, "transparent")
  ctx.fillStyle = radial
  ctx.fillRect(0, 0, width, height)

  drawGrain(ctx, width, height, 0.06)

  // Header
  const pad = 84
  const artSize = 130
  if (artwork) {
    ctx.save()
    roundRect(ctx, pad, pad, artSize, artSize, 24)
    ctx.clip()
    ctx.drawImage(artwork, pad, pad, artSize, artSize)
    ctx.restore()
  } else {
    ctx.fillStyle = "rgba(255,255,255,0.15)"
    roundRect(ctx, pad, pad, artSize, artSize, 24)
    ctx.fill()
  }

  ctx.textAlign = "left"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 42px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.title, pad + artSize + 32, pad + 56)

  ctx.fillStyle = "rgba(255,255,255,0.72)"
  ctx.font = "500 32px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.artist, pad + artSize + 32, pad + 104)

  // Lyrics
  const lyricsY = pad + artSize + 120
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: height - lyricsY - 140,
    fontFamily: "'Outfit', 'Segoe UI', system-ui, sans-serif",
    color: "#ffffff",
    align: "left",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "aura",
    translations: options.translations,
    showTranslation: options.showTranslation,
  })

  drawFooter(ctx, "rgba(255,255,255,0.65)", pad, width, height)
}

/* ==========================================================================
   STYLE 2: PLAYER
   ========================================================================== */

function drawPlayer(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  const grad = ctx.createLinearGradient(0, 0, 0, height)
  grad.addColorStop(0, "#12141c")
  grad.addColorStop(1, "#06070a")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  } else if (artwork) {
    ctx.save()
    ctx.globalAlpha = 0.3
    ctx.filter = "blur(70px)"
    ctx.drawImage(artwork, -width * 0.2, -height * 0.1, width * 1.4, height * 1.2)
    ctx.filter = "none"
    ctx.restore()
  }

  const radial = ctx.createRadialGradient(
    width / 2,
    height * 0.32,
    30,
    width / 2,
    height * 0.32,
    width * 0.7,
  )
  radial.addColorStop(0, options.accentColor + "40")
  radial.addColorStop(1, "transparent")
  ctx.fillStyle = radial
  ctx.fillRect(0, 0, width, height)

  drawGrain(ctx, width, height, 0.06)

  const pad = 84
  const coverSize = options.aspectRatio === "story" ? 420 : 340
  const coverX = (width - coverSize) / 2
  const coverY = options.aspectRatio === "story" ? 140 : 90

  // Cover Shadow
  ctx.save()
  ctx.shadowColor = "rgba(0,0,0,0.65)"
  ctx.shadowBlur = 48
  ctx.shadowOffsetY = 20
  if (artwork) {
    roundRect(ctx, coverX, coverY, coverSize, coverSize, 32)
    ctx.fillStyle = "#000"
    ctx.fill()
  }
  ctx.restore()

  if (artwork) {
    ctx.save()
    roundRect(ctx, coverX, coverY, coverSize, coverSize, 32)
    ctx.clip()
    ctx.drawImage(artwork, coverX, coverY, coverSize, coverSize)
    ctx.restore()
  } else {
    ctx.fillStyle = "rgba(255,255,255,0.12)"
    roundRect(ctx, coverX, coverY, coverSize, coverSize, 32)
    ctx.fill()
  }

  // Title & Artist
  ctx.textAlign = "center"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 44px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.title, width / 2, coverY + coverSize + 64)

  ctx.fillStyle = "rgba(255,255,255,0.68)"
  ctx.font = "500 30px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.artist, width / 2, coverY + coverSize + 112)

  // Lyrics
  const lyricsY = coverY + coverSize + 160
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: 280,
    fontFamily: "'Outfit', 'Segoe UI', system-ui, sans-serif",
    color: "#ffffff",
    align: "center",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "player",
  })

  // Transport & Progress Bar
  const barY = height - 240
  const barWidth = width - pad * 2
  const time = (options.time ?? 0) + (options.elapsed ?? 0)
  const duration = options.duration && options.duration > 0 ? options.duration : 210
  const progress = Math.min(Math.max(time / duration, 0), 1)

  // Track bar
  ctx.fillStyle = "rgba(255,255,255,0.22)"
  roundRect(ctx, pad, barY, barWidth, 10, 5)
  ctx.fill()

  // Progress
  ctx.fillStyle = "#ffffff"
  roundRect(ctx, pad, barY, Math.max(10, barWidth * progress), 10, 5)
  ctx.fill()

  // Thumb
  ctx.beginPath()
  ctx.arc(pad + barWidth * progress, barY + 5, 12, 0, Math.PI * 2)
  ctx.fillStyle = "#ffffff"
  ctx.fill()

  // Timestamps
  ctx.font = "600 24px 'Outfit', monospace"
  ctx.fillStyle = "rgba(255,255,255,0.65)"
  ctx.textAlign = "left"
  ctx.fillText(formatTime(time), pad, barY + 44)
  ctx.textAlign = "right"
  ctx.fillText("-" + formatTime(Math.max(0, duration - time)), width - pad, barY + 44)

  // Transport Buttons
  const cx = width / 2
  const ty = barY + 105
  ctx.fillStyle = "rgba(255,255,255,0.55)"
  ctx.font = "28px system-ui"
  ctx.textAlign = "center"
  ctx.fillText("🔀", cx - 210, ty + 2)

  ctx.fillStyle = "rgba(255,255,255,0.9)"
  ctx.fillText("⏮", cx - 105, ty + 4)

  ctx.beginPath()
  ctx.arc(cx, ty, 38, 0, Math.PI * 2)
  ctx.fillStyle = "#ffffff"
  ctx.fill()

  ctx.fillStyle = "#000000"
  ctx.beginPath()
  ctx.rect(cx - 11, ty - 13, 8, 26)
  ctx.rect(cx + 3, ty - 13, 8, 26)
  ctx.fill()

  ctx.fillStyle = "rgba(255,255,255,0.9)"
  ctx.fillText("⏭", cx + 105, ty + 4)

  ctx.fillStyle = "#ec4899"
  ctx.fillText("♥", cx + 210, ty + 2)

  drawFooter(ctx, "rgba(255,255,255,0.5)", pad, width, height, "center")
}

/* ==========================================================================
   STYLE 3: VHS 90s
   ========================================================================== */

function drawVHS(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Pure black VHS tape backdrop
  ctx.fillStyle = "#020204"
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 8, options.backdropZoom)
  }

  const elapsed = options.elapsed ?? 0

  // VHS Scanlines
  ctx.save()
  const scanOffset = Math.floor(elapsed * 45) % 4
  ctx.fillStyle = "rgba(0, 0, 0, 0.45)"
  for (let y = scanOffset; y < height; y += 4) {
    ctx.fillRect(0, y, width, 1.8)
  }
  ctx.restore()

  drawGrain(ctx, width, height, 0.12, false)

  const pad = 84

  // Top Status Bar: REC & SP & AUTO
  const isBlink = Math.floor(elapsed * 2) % 2 === 0
  ctx.save()
  // Red REC dot
  ctx.beginPath()
  ctx.arc(pad + 12, pad + 12, 12, 0, Math.PI * 2)
  ctx.fillStyle = isBlink ? "#ff2a2a" : "rgba(255, 42, 42, 0.3)"
  ctx.fill()

  ctx.font = "900 32px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "#ffffff"
  ctx.textAlign = "left"
  ctx.fillText("REC", pad + 36, pad + 22)

  // SP Badge
  roundRect(ctx, pad + 120, pad - 2, 54, 34, 6)
  ctx.fillStyle = "rgba(255,255,255,0.22)"
  ctx.fill()
  ctx.font = "bold 22px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "#ffffff"
  ctx.textAlign = "center"
  ctx.fillText("SP", pad + 147, pad + 23)

  // Right side: AUTO & Battery
  ctx.textAlign = "right"
  ctx.font = "bold 26px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "rgba(255,255,255,0.85)"
  ctx.fillText("AUTO  [■■□]", width - pad, pad + 22)
  ctx.restore()

  // Neon Green Digital Timecode
  ctx.save()
  ctx.font = "bold 44px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "#33ff66"
  ctx.shadowColor = "#33ff66"
  ctx.shadowBlur = 12
  ctx.textAlign = "left"
  ctx.fillText(formatTimecode(elapsed), pad, pad + 86)
  ctx.restore()

  // Middle: Uppercase Heavy Monospace Lyrics with Cyan Neon Glow
  const lyricsY = height * 0.4
  drawLyricsBlock(ctx, options.lines.map((l) => l.toUpperCase()), {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: height * 0.4,
    fontFamily: "'Courier New', Consolas, monospace",
    color: "#ffffff",
    align: "left",
    fontWeight: "900",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "vhs",
  })

  // Bottom VHS bar: Title, Artist & PLAY ▶
  ctx.save()
  ctx.textAlign = "left"
  ctx.font = "900 32px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "#ffffff"
  ctx.fillText(options.title.toUpperCase(), pad, height - pad - 36)

  ctx.font = "bold 24px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "rgba(255,255,255,0.7)"
  ctx.fillText(options.artist.toUpperCase(), pad, height - pad)

  ctx.textAlign = "right"
  ctx.font = "900 36px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "#33ff66"
  ctx.shadowColor = "#33ff66"
  ctx.shadowBlur = 10
  ctx.fillText("PLAY ▶", width - pad, height - pad - 12)
  ctx.restore()
}

/* ==========================================================================
   STYLE 4: CASSETTE
   ========================================================================== */

function drawCassette(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Dark textured charcoal
  ctx.fillStyle = "#141416"
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  }

  drawGrain(ctx, width, height, 0.08)

  const pad = 84

  // Mini Header
  const artSize = 100
  if (artwork) {
    ctx.save()
    roundRect(ctx, pad, pad, artSize, artSize, 16)
    ctx.clip()
    ctx.drawImage(artwork, pad, pad, artSize, artSize)
    ctx.restore()
  }

  ctx.textAlign = "left"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 38px 'Outfit', sans-serif"
  ctx.fillText(options.title, pad + artSize + 28, pad + 48)

  ctx.fillStyle = "rgba(255,255,255,0.65)"
  ctx.font = "500 28px 'Outfit', sans-serif"
  ctx.fillText(options.artist, pad + artSize + 28, pad + 90)

  // Cassette Tape Body
  const casW = width - pad * 2
  const casH = 260
  const casX = pad
  const casY = pad + artSize + 36

  // Outer shell
  ctx.save()
  roundRect(ctx, casX, casY, casW, casH, 20)
  ctx.fillStyle = "#222226"
  ctx.shadowColor = "rgba(0,0,0,0.5)"
  ctx.shadowBlur = 30
  ctx.shadowOffsetY = 12
  ctx.fill()
  ctx.strokeStyle = "rgba(255,255,255,0.18)"
  ctx.lineWidth = 3
  ctx.stroke()
  ctx.restore()

  // Cassette Paper Sticker Label
  const lblPad = 18
  const lblW = casW - lblPad * 2
  const lblH = casH - lblPad * 2
  const lblX = casX + lblPad
  const lblY = casY + lblPad

  ctx.save()
  roundRect(ctx, lblX, lblY, lblW, lblH, 12)
  ctx.fillStyle = "#f3eee3"
  ctx.fill()

  // Label Header: SIDE A red badge + Handwritten Title + C-60
  roundRect(ctx, lblX + 24, lblY + 18, 90, 36, 6)
  ctx.fillStyle = "#dc2626"
  ctx.fill()
  ctx.font = "900 20px monospace"
  ctx.fillStyle = "#ffffff"
  ctx.textAlign = "center"
  ctx.fillText("SIDE A", lblX + 69, lblY + 43)

  ctx.font = "bold 32px 'Caveat', cursive, sans-serif"
  ctx.fillStyle = "#1e1e24"
  ctx.textAlign = "center"
  ctx.fillText(options.title, lblX + lblW / 2, lblY + 44)

  ctx.font = "bold 22px monospace"
  ctx.fillStyle = "rgba(30,30,36,0.65)"
  ctx.textAlign = "right"
  ctx.fillText("C-60", lblX + lblW - 24, lblY + 43)

  // Dark Cassette Window
  const winW = lblW - 48
  const winH = 110
  const winX = lblX + 24
  const winY = lblY + 70
  roundRect(ctx, winX, winY, winW, winH, 10)
  ctx.fillStyle = "#0c0d10"
  ctx.fill()

  // Spools & Tape
  const elapsed = options.elapsed ?? 0
  const rot = (elapsed * 180 * Math.PI) / 180

  const drawSpool = (cx: number, cy: number) => {
    ctx.save()
    ctx.translate(cx, cy)
    ctx.rotate(rot)

    // White outer ring
    ctx.beginPath()
    ctx.arc(0, 0, 36, 0, Math.PI * 2)
    ctx.fillStyle = "#f5f5f7"
    ctx.fill()

    // Black center
    ctx.beginPath()
    ctx.arc(0, 0, 15, 0, Math.PI * 2)
    ctx.fillStyle = "#0c0d10"
    ctx.fill()

    // 6 spokes
    ctx.fillStyle = "rgba(0,0,0,0.5)"
    for (let i = 0; i < 6; i++) {
      ctx.rotate((60 * Math.PI) / 180)
      ctx.fillRect(-3, -34, 6, 16)
    }
    ctx.restore()
  }

  // Left & Right spools
  drawSpool(winX + winW * 0.28, winY + winH / 2)
  // Brown magnetic tape strip
  ctx.fillStyle = "#452618"
  roundRect(ctx, winX + winW * 0.42, winY + winH / 2 - 16, winW * 0.16, 32, 4)
  ctx.fill()
  drawSpool(winX + winW * 0.72, winY + winH / 2)

  ctx.restore()

  // Lyrics Block
  const lyricsY = casY + casH + 64
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: height - lyricsY - 120,
    fontFamily: "'Outfit', sans-serif",
    color: "#ffffff",
    align: "left",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "cassette",
  })

  drawFooter(ctx, "rgba(255,255,255,0.6)", pad, width, height)
}

/* ==========================================================================
   STYLE 5: VINYL
   ========================================================================== */

function drawVinyl(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Deep sleek gradient
  const grad = ctx.createLinearGradient(0, 0, 0, height)
  grad.addColorStop(0, "#19181d")
  grad.addColorStop(1, "#070709")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  }

  drawGrain(ctx, width, height, 0.07)

  const pad = 84

  // Header
  const artSize = 100
  if (artwork) {
    ctx.save()
    roundRect(ctx, pad, pad, artSize, artSize, 16)
    ctx.clip()
    ctx.drawImage(artwork, pad, pad, artSize, artSize)
    ctx.restore()
  }

  ctx.textAlign = "left"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 38px 'Outfit', sans-serif"
  ctx.fillText(options.title, pad + artSize + 28, pad + 48)

  ctx.fillStyle = "rgba(255,255,255,0.65)"
  ctx.font = "500 28px 'Outfit', sans-serif"
  ctx.fillText(options.artist, pad + artSize + 28, pad + 90)

  // Vinyl & Sleeve center composition
  const elapsed = options.elapsed ?? 0
  const sleeveSize = options.aspectRatio === "story" ? 420 : 360
  const sleeveX = pad + 40
  const sleeveY = pad + artSize + 50

  // Vinyl Disc sliding out from sleeve
  const discX = sleeveX + sleeveSize * 0.65
  const discY = sleeveY + sleeveSize / 2
  const discRadius = sleeveSize * 0.48
  const rot = (elapsed * 90 * Math.PI) / 180

  ctx.save()
  ctx.translate(discX, discY)
  ctx.rotate(rot)

  // Outer black vinyl circle
  ctx.beginPath()
  ctx.arc(0, 0, discRadius, 0, Math.PI * 2)
  ctx.fillStyle = "#0c0d10"
  ctx.shadowColor = "rgba(0,0,0,0.6)"
  ctx.shadowBlur = 32
  ctx.fill()

  // Concentric groove rings
  ctx.lineWidth = 1.5
  for (let r = discRadius * 0.55; r < discRadius * 0.95; r += 14) {
    ctx.beginPath()
    ctx.arc(0, 0, r, 0, Math.PI * 2)
    ctx.strokeStyle = "rgba(255,255,255,0.06)"
    ctx.stroke()
  }

  // Center Album Label
  const labelRadius = discRadius * 0.38
  ctx.save()
  ctx.beginPath()
  ctx.arc(0, 0, labelRadius, 0, Math.PI * 2)
  ctx.clip()
  if (artwork) {
    ctx.drawImage(artwork, -labelRadius, -labelRadius, labelRadius * 2, labelRadius * 2)
  } else {
    ctx.fillStyle = options.accentColor
    ctx.fill()
  }
  ctx.restore()

  // Spindle center hole
  ctx.beginPath()
  ctx.arc(0, 0, 10, 0, Math.PI * 2)
  ctx.fillStyle = "#ffffff"
  ctx.fill()
  ctx.beginPath()
  ctx.arc(0, 0, 8, 0, Math.PI * 2)
  ctx.fillStyle = "#000000"
  ctx.fill()
  ctx.restore()

  // Album Artwork Sleeve (on top of disc with shadow)
  ctx.save()
  roundRect(ctx, sleeveX, sleeveY, sleeveSize, sleeveSize, 18)
  ctx.shadowColor = "rgba(0,0,0,0.7)"
  ctx.shadowBlur = 40
  ctx.shadowOffsetX = -10
  ctx.shadowOffsetY = 12
  if (artwork) {
    ctx.clip()
    ctx.drawImage(artwork, sleeveX, sleeveY, sleeveSize, sleeveSize)
  } else {
    ctx.fillStyle = "#1e1e24"
    ctx.fill()
  }
  ctx.restore()

  // Lyrics Block
  const lyricsY = sleeveY + sleeveSize + 70
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: height - lyricsY - 120,
    fontFamily: "'Outfit', sans-serif",
    color: "#ffffff",
    align: "left",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "vinyl",
  })

  drawFooter(ctx, "rgba(255,255,255,0.6)", pad, width, height)
}

/* ==========================================================================
   STYLE 6: GLASS
   ========================================================================== */

function drawGlass(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Vibrant ambient backdrop
  const grad = ctx.createLinearGradient(0, 0, width, height)
  grad.addColorStop(0, "#160e28")
  grad.addColorStop(1, "#070b18")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  } else if (artwork) {
    ctx.save()
    ctx.globalAlpha = 0.5
    ctx.filter = "blur(75px)"
    ctx.drawImage(artwork, -width * 0.2, -height * 0.2, width * 1.4, height * 1.4)
    ctx.filter = "none"
    ctx.restore()
  }

  // Accent and purple dual radial glow
  const r1 = ctx.createRadialGradient(width * 0.2, height * 0.3, 20, width * 0.2, height * 0.3, width * 0.6)
  r1.addColorStop(0, options.accentColor + "55")
  r1.addColorStop(1, "transparent")
  ctx.fillStyle = r1
  ctx.fillRect(0, 0, width, height)

  const r2 = ctx.createRadialGradient(width * 0.8, height * 0.7, 20, width * 0.8, height * 0.7, width * 0.6)
  r2.addColorStop(0, "#8b5cf644")
  r2.addColorStop(1, "transparent")
  ctx.fillStyle = r2
  ctx.fillRect(0, 0, width, height)

  drawGrain(ctx, width, height, 0.05)

  const pad = 84
  const elapsed = options.elapsed ?? 0

  // Floating Glass Capsule Header
  const pillH = 76
  const pillY = pad
  const pillW = width - pad * 2
  ctx.save()
  roundRect(ctx, pad, pillY, pillW, pillH, pillH / 2)
  ctx.fillStyle = "rgba(0, 0, 0, 0.55)"
  ctx.fill()
  ctx.strokeStyle = "rgba(255, 255, 255, 0.16)"
  ctx.lineWidth = 1.5
  ctx.stroke()

  // Circle art inside pill
  const circArtSize = 52
  const circArtX = pad + 12
  const circArtY = pillY + (pillH - circArtSize) / 2
  ctx.save()
  ctx.beginPath()
  ctx.arc(circArtX + circArtSize / 2, circArtY + circArtSize / 2, circArtSize / 2, 0, Math.PI * 2)
  ctx.clip()
  if (artwork) {
    ctx.drawImage(artwork, circArtX, circArtY, circArtSize, circArtSize)
  } else {
    ctx.fillStyle = options.accentColor
    ctx.fill()
  }
  ctx.restore()

  // Pill Title & Artist
  ctx.textAlign = "left"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 28px 'Outfit', sans-serif"
  ctx.fillText(options.title, circArtX + circArtSize + 18, pillY + 34)

  ctx.fillStyle = "rgba(255,255,255,0.65)"
  ctx.font = "500 22px 'Outfit', sans-serif"
  ctx.fillText(options.artist, circArtX + circArtSize + 18, pillY + 62)

  // Animated Equalizer Bars on right
  const eqX = pad + pillW - 60
  const eqY = pillY + pillH / 2
  for (let i = 0; i < 4; i++) {
    const h = 10 + Math.sin(elapsed * 6 + i * 1.5) * 8
    roundRect(ctx, eqX + i * 8, eqY - h / 2, 4, h, 2)
    ctx.fillStyle = options.accentColor
    ctx.fill()
  }
  ctx.restore()

  // Frosted Glass Lyrics Card
  const cardY = pillY + pillH + 48
  const cardW = width - pad * 2
  const cardH = height - cardY - 140

  ctx.save()
  roundRect(ctx, pad, cardY, cardW, cardH, 32)
  ctx.fillStyle = "rgba(255, 255, 255, 0.08)"
  ctx.shadowColor = "rgba(0, 0, 0, 0.35)"
  ctx.shadowBlur = 35
  ctx.shadowOffsetY = 16
  ctx.fill()

  // Gradient Glass Border
  const borderGrad = ctx.createLinearGradient(pad, cardY, pad + cardW, cardY + cardH)
  borderGrad.addColorStop(0, options.accentColor + "aa")
  borderGrad.addColorStop(0.5, "#a855f7aa")
  borderGrad.addColorStop(1, "rgba(255,255,255,0.25)")
  ctx.strokeStyle = borderGrad
  ctx.lineWidth = 2.5
  ctx.stroke()
  ctx.restore()

  // Lyrics inside glass card
  drawLyricsBlock(ctx, options.lines, {
    x: pad + 40,
    y: cardY + 90,
    maxWidth: cardW - 80,
    maxHeight: cardH - 120,
    fontFamily: "'Outfit', sans-serif",
    color: "#ffffff",
    align: "left",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "glass",
  })

  drawFooter(ctx, "rgba(255,255,255,0.65)", pad, width, height)
}

/* ==========================================================================
   STYLE 7: POLAROID
   ========================================================================== */

function drawPolaroid(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Warm table surface
  const grad = ctx.createLinearGradient(0, 0, width, height)
  grad.addColorStop(0, "#ece5d8")
  grad.addColorStop(1, "#dad0c0")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, width, height)

  drawGrain(ctx, width, height, 0.05, true)

  const elapsed = options.elapsed ?? 0
  const bobbing = options.activeLineIndex !== null ? Math.sin(elapsed * 1.5) * 0.4 : 0

  ctx.save()
  // Slight vintage rotation (-2.5 degrees + subtle animation)
  ctx.translate(width / 2, height / 2 - 20)
  ctx.rotate(((-2.5 + bobbing) * Math.PI) / 180)
  ctx.translate(-width / 2, -(height / 2 - 20))

  const frameW = width - 180
  const frameH = height - 240
  const frameX = (width - frameW) / 2
  const frameY = 90

  // White polaroid frame with deep shadow
  ctx.save()
  ctx.shadowColor = "rgba(0,0,0,0.24)"
  ctx.shadowBlur = 48
  ctx.shadowOffsetY = 24
  ctx.fillStyle = "#fdfbf7"
  roundRect(ctx, frameX, frameY, frameW, frameH, 16)
  ctx.fill()
  ctx.restore()

  // Photo area inside polaroid
  const photoW = frameW - 72
  const photoH = frameH * 0.58
  const photoX = frameX + 36
  const photoY = frameY + 36

  const photoImg = artwork
  if (photoImg) {
    ctx.save()
    roundRect(ctx, photoX, photoY, photoW, photoH, 6)
    ctx.clip()
    // Cover photo
    const scale = Math.max(photoW / photoImg.width, photoH / photoImg.height)
    const pw = photoImg.width * scale
    const ph = photoImg.height * scale
    ctx.drawImage(photoImg, photoX + (photoW - pw) / 2, photoY + (photoH - ph) / 2, pw, ph)

    // Dark gradient on photo bottom for tag readability
    const photoGrad = ctx.createLinearGradient(0, photoY + photoH - 120, 0, photoY + photoH)
    photoGrad.addColorStop(0, "transparent")
    photoGrad.addColorStop(1, "rgba(0,0,0,0.65)")
    ctx.fillStyle = photoGrad
    ctx.fillRect(photoX, photoY, photoW, photoH)
    ctx.restore()
  } else {
    ctx.fillStyle = "#e0dad0"
    roundRect(ctx, photoX, photoY, photoW, photoH, 6)
    ctx.fill()
  }

  // Label tag on photo bottom-left
  ctx.save()
  ctx.fillStyle = "rgba(0,0,0,0.7)"
  ctx.font = "bold 24px 'Outfit', monospace"
  ctx.textAlign = "left"
  const tagText = options.title.toUpperCase()
  const tagWidth = ctx.measureText(tagText).width + 36
  roundRect(ctx, photoX + 24, photoY + photoH - 64, tagWidth, 42, 6)
  ctx.fill()

  ctx.fillStyle = "#ffffff"
  ctx.fillText(tagText, photoX + 42, photoY + photoH - 35)
  ctx.restore()

  // Handwritten Lyrics on bottom section of Polaroid frame
  const lyricsY = photoY + photoH + 60
  drawLyricsBlock(ctx, options.lines.slice(0, 5), {
    x: photoX + 20,
    y: lyricsY,
    maxWidth: photoW - 40,
    maxHeight: frameH - (photoH + 80),
    fontFamily: "'Caveat', cursive, sans-serif",
    color: "#262220",
    align: "left",
    fontWeight: "bold",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "polaroid",
  })

  // Artist signature
  ctx.save()
  ctx.font = "italic bold 32px 'Caveat', cursive, sans-serif"
  ctx.fillStyle = "rgba(38,34,32,0.68)"
  ctx.textAlign = "left"
  ctx.fillText(`— ${options.artist}`, photoX + 20, frameY + frameH - 36)
  ctx.restore()

  ctx.restore() // un-rotate

  drawFooter(ctx, "rgba(0,0,0,0.45)", 84, width, height)
}

/* ==========================================================================
   STYLE 8: PAPER
   ========================================================================== */

function drawPaper(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Vintage cream editorial parchment
  ctx.fillStyle = "#f6f3eb"
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 18, options.backdropZoom)
  }

  drawGrain(ctx, width, height, 0.08, true)

  const pad = 96
  const ink = "#221d1b"
  const inkMuted = "rgba(34,29,27,0.65)"

  // Giant decorative quote mark
  ctx.font = "bold 190px 'Newsreader', 'Playfair Display', Georgia, serif"
  ctx.fillStyle = "rgba(34,29,27,0.1)"
  ctx.textAlign = "left"
  ctx.fillText("“", pad - 30, pad + 120)

  // Header: Mini artwork + Title + Artist (Serif)
  const artSize = 110
  if (artwork) {
    ctx.save()
    roundRect(ctx, pad, pad + 40, artSize, artSize, 14)
    ctx.clip()
    ctx.drawImage(artwork, pad, pad + 40, artSize, artSize)
    ctx.restore()
  }

  ctx.fillStyle = ink
  ctx.font = "600 42px 'Newsreader', 'Playfair Display', Georgia, serif"
  ctx.fillText(options.title, pad + artSize + 32, pad + 96)

  ctx.fillStyle = inkMuted
  ctx.font = "italic 32px 'Newsreader', 'Playfair Display', Georgia, serif"
  ctx.fillText(options.artist, pad + artSize + 32, pad + 142)

  // Lyrics Block in Serif
  const lyricsY = pad + artSize + 170
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: height - lyricsY - 140,
    fontFamily: "'Newsreader', 'Playfair Display', Georgia, serif",
    color: ink,
    align: "left",
    fontWeight: "500",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "paper",
  })

  drawFooter(ctx, inkMuted, pad, width, height)
}

/* ==========================================================================
   STYLE 9: RECEIPT
   ========================================================================== */

function drawReceipt(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Dark charcoal counter
  ctx.fillStyle = "#161619"
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  }

  drawGrain(ctx, width, height, 0.06)

  const pad = 84
  const recW = width - pad * 2
  const recH = height - pad * 2
  const recX = pad
  const recY = pad

  // Receipt Paper Shadow
  ctx.save()
  ctx.shadowColor = "rgba(0,0,0,0.5)"
  ctx.shadowBlur = 36
  ctx.shadowOffsetY = 16
  ctx.fillStyle = "#f5f2e9"
  ctx.fillRect(recX, recY, recW, recH)
  ctx.restore()

  // Perforated Zig-Zag Top & Bottom
  const toothW = 20
  const toothH = 14
  ctx.fillStyle = "#161619"
  // Top teeth
  for (let x = recX; x < recX + recW; x += toothW) {
    ctx.beginPath()
    ctx.moveTo(x, recY)
    ctx.lineTo(x + toothW / 2, recY + toothH)
    ctx.lineTo(x + toothW, recY)
    ctx.fill()
  }
  // Bottom teeth
  for (let x = recX; x < recX + recW; x += toothW) {
    ctx.beginPath()
    ctx.moveTo(x, recY + recH)
    ctx.lineTo(x + toothW / 2, recY + recH - toothH)
    ctx.lineTo(x + toothW, recY + recH)
    ctx.fill()
  }

  // Receipt Header Content
  const elapsed = options.elapsed ?? 0
  const innerPad = 48
  let curY = recY + 54

  ctx.textAlign = "center"
  ctx.font = "900 30px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "#1c1c1f"
  ctx.fillText("*** OPENNOTCHI ARCHIVE ***", recX + recW / 2, curY)
  curY += 40

  ctx.font = "bold 22px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "rgba(28,28,31,0.65)"
  ctx.textAlign = "left"
  ctx.fillText("AUDIO #1024", recX + innerPad, curY)
  ctx.textAlign = "right"
  ctx.fillText(options.activeLineIndex !== null ? `TIME: ${formatTime(elapsed)}` : "TRACK CASSETTE", recX + recW - innerPad, curY)
  curY += 28

  // Dashed line
  ctx.textAlign = "center"
  ctx.fillStyle = "rgba(28,28,31,0.3)"
  ctx.font = "bold 22px 'Courier New', Consolas, monospace"
  ctx.fillText("--------------------------------------------------", recX + recW / 2, curY)
  curY += 34

  // Track Title & Artist
  ctx.textAlign = "left"
  ctx.fillStyle = "#1c1c1f"
  ctx.font = "bold 28px 'Courier New', Consolas, monospace"
  ctx.fillText(options.title.toUpperCase(), recX + innerPad, curY)

  ctx.textAlign = "right"
  ctx.fillStyle = "rgba(28,28,31,0.7)"
  ctx.font = "500 24px 'Courier New', Consolas, monospace"
  ctx.fillText(options.artist.toUpperCase(), recX + recW - innerPad, curY)
  curY += 28

  ctx.textAlign = "center"
  ctx.fillStyle = "rgba(28,28,31,0.3)"
  ctx.fillText("--------------------------------------------------", recX + recW / 2, curY)
  curY += 46

  // Itemized Lyrics Lines
  const activeIdx = options.activeLineIndex ?? null
  for (let i = 0; i < options.lines.length; i++) {
    const isCurrent = activeIdx === null || activeIdx === i
    const prefix = isCurrent && activeIdx !== null ? "► " : String(i + 1).padStart(2, "0") + " "

    ctx.save()
    if (activeIdx !== null && !isCurrent) {
      ctx.globalAlpha = 0.35
    }

    ctx.font = `${isCurrent ? "900" : "bold"} 26px 'Courier New', Consolas, monospace`
    ctx.fillStyle = isCurrent && activeIdx !== null ? "#dc2626" : "#1c1c1f"
    ctx.textAlign = "left"
    ctx.fillText(prefix, recX + innerPad, curY)

    ctx.fillStyle = "#1c1c1f"
    const wrapped = wrapText(ctx, options.lines[i], recW - innerPad * 2 - 60)
    for (let w = 0; w < wrapped.length; w++) {
      ctx.fillText(wrapped[w], recX + innerPad + 50, curY)
      curY += 36
    }
    curY += 10
    ctx.restore()
  }

  // Bottom Barcode Pattern
  curY = recY + recH - 120
  ctx.textAlign = "center"
  ctx.fillStyle = "rgba(28,28,31,0.3)"
  ctx.fillText("--------------------------------------------------", recX + recW / 2, curY)
  curY += 24

  // Barcode bars
  const barCodeW = 340
  const barCodeStartX = recX + (recW - barCodeW) / 2
  for (let b = 0; b < 36; b++) {
    const bw = b % 3 === 0 ? 5 : b % 5 === 0 ? 7 : 2
    ctx.fillStyle = "#1c1c1f"
    ctx.fillRect(barCodeStartX + b * 9.5, curY, bw, 34)
  }
  curY += 52

  ctx.font = "bold 20px 'Courier New', Consolas, monospace"
  ctx.fillStyle = "rgba(28,28,31,0.6)"
  ctx.textAlign = "center"
  ctx.fillText("THANK YOU FOR LISTENING", recX + recW / 2, curY)
}

/* ==========================================================================
   STYLE 10: SOLID
   ========================================================================== */

function drawSolid(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  // Vibrant solid accent color with dynamic lighting sweep
  ctx.fillStyle = options.accentColor
  ctx.fillRect(0, 0, width, height)

  if (backdrop) {
    drawCustomBackdrop(ctx, backdrop, width, height, options.backdropBlur ?? 16, options.backdropZoom)
  }

  // Dynamic light sweep
  const elapsed = options.elapsed ?? 0
  const ang = (elapsed * 1.5 * Math.PI) / 180
  const sweep = ctx.createLinearGradient(
    width / 2 + Math.cos(ang) * width * 0.5,
    height / 2 + Math.sin(ang) * height * 0.5,
    width / 2 - Math.cos(ang) * width * 0.5,
    height / 2 - Math.sin(ang) * height * 0.5,
  )
  sweep.addColorStop(0, "rgba(255,255,255,0.12)")
  sweep.addColorStop(0.5, "transparent")
  sweep.addColorStop(1, "rgba(0,0,0,0.18)")
  ctx.fillStyle = sweep
  ctx.fillRect(0, 0, width, height)

  drawGrain(ctx, width, height, 0.05)

  const pad = 84
  const light = isLightColor(options.accentColor)
  const ink = light ? "#121212" : "#ffffff"
  const inkMuted = light ? "rgba(0,0,0,0.65)" : "rgba(255,255,255,0.72)"

  // Header
  const artSize = 130
  if (artwork) {
    ctx.save()
    roundRect(ctx, pad, pad, artSize, artSize, 24)
    ctx.clip()
    ctx.drawImage(artwork, pad, pad, artSize, artSize)
    ctx.restore()
  }

  ctx.textAlign = "left"
  ctx.fillStyle = ink
  ctx.font = "bold 42px 'Outfit', sans-serif"
  ctx.fillText(options.title, pad + artSize + 32, pad + 56)

  ctx.fillStyle = inkMuted
  ctx.font = "500 32px 'Outfit', sans-serif"
  ctx.fillText(options.artist, pad + artSize + 32, pad + 104)

  // Lyrics
  const lyricsY = pad + artSize + 130
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: lyricsY,
    maxWidth: width - pad * 2,
    maxHeight: height - lyricsY - 140,
    fontFamily: "'Outfit', sans-serif",
    color: ink,
    align: "left",
    activeLineIndex: options.activeLineIndex,
    lyricFont: options.lyricFont,
    fontScale: options.fontScale,
    textAlign: options.textAlign,
    style: "solid",
  })

  drawFooter(ctx, inkMuted, pad, width, height)
}

/* ==========================================================================
   FRAME DISPATCHER
   ========================================================================== */

export function drawCardFrame(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
  backdrop: Backdrop,
  width: number,
  height: number,
) {
  switch (options.style) {
    case "player":
      drawPlayer(ctx, options, artwork, backdrop, width, height)
      break
    case "vhs":
      drawVHS(ctx, options, artwork, backdrop, width, height)
      break
    case "cassette":
      drawCassette(ctx, options, artwork, backdrop, width, height)
      break
    case "vinyl":
      drawVinyl(ctx, options, artwork, backdrop, width, height)
      break
    case "glass":
      drawGlass(ctx, options, artwork, backdrop, width, height)
      break
    case "polaroid":
      drawPolaroid(ctx, options, artwork, backdrop, width, height)
      break
    case "paper":
      drawPaper(ctx, options, artwork, backdrop, width, height)
      break
    case "receipt":
      drawReceipt(ctx, options, artwork, backdrop, width, height)
      break
    case "solid":
      drawSolid(ctx, options, artwork, backdrop, width, height)
      break
    case "aura":
    default:
      drawAura(ctx, options, artwork, backdrop, width, height)
      break
  }
}

/** Renders high-res canvas */
export async function renderCardToCanvas(options: RenderCardOptions): Promise<HTMLCanvasElement> {
  const { width, height } = getCanvasDimensions(options.aspectRatio)
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext("2d")
  if (!ctx) throw new Error("Could not get canvas context")

  let artworkImg: HTMLImageElement | null = null
  if (options.artworkUrl) {
    try {
      artworkImg = await loadImage(options.artworkUrl)
    } catch {
      artworkImg = null
    }
  }

  let backdropImg: HTMLImageElement | null = null
  if (options.backdropUrl) {
    try {
      backdropImg = await loadImage(options.backdropUrl)
    } catch {
      backdropImg = null
    }
  }

  drawCardFrame(ctx, options, artworkImg, backdropImg, width, height)
  return canvas
}

/** Generates a PNG Blob from render options */
export async function exportCardToBlob(options: RenderCardOptions): Promise<Blob> {
  const canvas = await renderCardToCanvas(options)
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (blob) resolve(blob)
      else reject(new Error("Failed to create blob from canvas"))
    }, "image/png")
  })
}

/** Copies the card image blob to system clipboard */
export async function copyCardToClipboard(blob: Blob): Promise<void> {
  await navigator.clipboard.write([
    new ClipboardItem({
      "image/png": blob,
    }),
  ])
}

/** Downloads card as a file */
export function downloadCardImage(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  a.download = filename.endsWith(".png") ? filename : `${filename}.png`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  setTimeout(() => URL.revokeObjectURL(url), 2000)
}

/** Exports animated video (WebM/MP4) from canvas frames with progress callback */
export async function exportVideo(
  options: RenderCardOptions,
  totalDuration: number,
  fps = 30,
  onProgress?: (progress: number) => void,
  media: { videoUrl?: string | null; musicUrl?: string | null; musicStart?: number } = {},
): Promise<Blob> {
  const { width, height } = getCanvasDimensions(options.aspectRatio)
  const canvas = document.createElement("canvas")
  canvas.width = width
  canvas.height = height
  const ctx = canvas.getContext("2d")
  if (!ctx) throw new Error("Could not get canvas context")

  let artworkImg: HTMLImageElement | null = null
  if (options.artworkUrl) {
    try {
      artworkImg = await loadImage(options.artworkUrl)
    } catch {
      artworkImg = null
    }
  }

  let backdropImg: HTMLImageElement | null = null
  if (options.backdropUrl) {
    try {
      backdropImg = await loadImage(options.backdropUrl)
    } catch {
      backdropImg = null
    }
  }

  let bgVideo: HTMLVideoElement | null = null
  if (media.videoUrl) {
    bgVideo = document.createElement("video")
    bgVideo.src = media.videoUrl
    bgVideo.loop = true
    bgVideo.playsInline = true
    await new Promise((r) => { bgVideo!.onloadeddata = r; bgVideo!.onerror = r })
  }

  let music: HTMLAudioElement | null = null
  if (media.musicUrl) {
    music = new Audio(media.musicUrl)
    music.loop = true
    await new Promise((r) => { music!.onloadedmetadata = r; music!.onerror = r })
    // Song file shorter than the lyric offset (e.g. a clip): start from its beginning.
    const start = media.musicStart ?? 0
    music.currentTime = start < (music.duration || 0) ? start : 0
  }

  const stream = canvas.captureStream(fps)

  // Music wins; otherwise keep the background clip's own sound. Routed only to the recording, not the speakers.
  const audioSource = music ?? bgVideo
  const audioCtx = audioSource ? new AudioContext() : null
  if (audioCtx && audioSource) {
    const dest = audioCtx.createMediaStreamDestination()
    audioCtx.createMediaElementSource(audioSource).connect(dest)
    dest.stream.getAudioTracks().forEach((t) => stream.addTrack(t))
  }
  const mimeTypes = [
    "video/mp4",
    "video/webm;codecs=vp9",
    "video/webm;codecs=vp8",
    "video/webm",
  ]
  const mimeType = mimeTypes.find((t) => typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported(t)) || "video/webm"

  const recorder = new MediaRecorder(stream, {
    mimeType,
    videoBitsPerSecond: 8_500_000,
  })

  const chunks: Blob[] = []
  recorder.ondataavailable = (e) => {
    if (e.data && e.data.size > 0) chunks.push(e.data)
  }

  const completionPromise = new Promise<Blob>((resolve, reject) => {
    recorder.onstop = () => {
      resolve(new Blob(chunks, { type: mimeType }))
    }
    recorder.onerror = (e) => reject(e)
  })

  await Promise.all([bgVideo?.play(), music?.play()])
  recorder.start()

  const frameDelay = 1000 / fps
  const startedAt = performance.now()

  for (let elapsed = 0; elapsed < totalDuration; elapsed = (performance.now() - startedAt) / 1000) {

    let activeLineIndex = 0
    if (options.times && options.times.length > 0) {
      const songStartTime = options.times[0] ?? 0
      const currentSongTime = songStartTime + elapsed
      let found = 0
      for (let i = 0; i < options.times.length; i++) {
        if (options.times[i] <= currentSongTime) {
          found = i
        }
      }
      activeLineIndex = found
    } else {
      const progress = Math.min(Math.max(elapsed / totalDuration, 0), 0.999)
      activeLineIndex = Math.floor(progress * options.lines.length)
    }

    drawCardFrame(
      ctx,
      {
        ...options,
        elapsed,
        activeLineIndex,
      },
      artworkImg,
      bgVideo ?? backdropImg,
      width,
      height,
    )

    if (onProgress) {
      onProgress(Math.min(1, elapsed / totalDuration))
    }

    await new Promise((r) => setTimeout(r, frameDelay))
  }

  recorder.stop()
  bgVideo?.pause()
  music?.pause()
  try {
    return await completionPromise
  } finally {
    audioCtx?.close()
  }
}

/** Downloads exported video file */
export function downloadVideo(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.href = url
  const ext = blob.type.includes("mp4") ? ".mp4" : ".webm"
  a.download = filename.endsWith(".mp4") || filename.endsWith(".webm") ? filename : `${filename}${ext}`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  setTimeout(() => URL.revokeObjectURL(url), 2000)
}
