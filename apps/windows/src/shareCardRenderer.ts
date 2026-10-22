/**
 * High-resolution (1080×1350, 4:5 Instagram/Social ratio) Canvas renderer
 * for OpenNotchi Lyric Share Cards.
 */

export type LyricCardStyle = "aura" | "player" | "polaroid" | "solid" | "paper"

export interface RenderCardOptions {
  title: string
  artist: string
  album?: string
  artworkUrl?: string | null
  accentColor: string
  lines: string[]
  time?: number // position in seconds
  duration?: number // total song duration in seconds
  style: LyricCardStyle
}

const WIDTH = 1080
const HEIGHT = 1350

/** Loads an image into an HTMLImageElement safely */
function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = "anonymous"
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error("Failed to load image"))
    img.src = src
  })
}

/** Draws rounded rectangle path */
function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number,
) {
  ctx.beginPath()
  ctx.moveTo(x + radius, y)
  ctx.lineTo(x + width - radius, y)
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius)
  ctx.lineTo(x + width, y + height - radius)
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height)
  ctx.lineTo(x + radius, y + height)
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius)
  ctx.lineTo(x, y + radius)
  ctx.quadraticCurveTo(x, y, x + radius, y)
  ctx.closePath()
}

/** Word wrapping helper for canvas text */
function wrapText(
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
function formatTime(sec: number): string {
  const s = Math.max(0, Math.floor(sec))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
}

/** Determines whether a hex color is light or dark */
function isLightColor(hex: string): boolean {
  let c = hex.replace("#", "")
  if (c.length === 3) c = c.split("").map((x) => x + x).join("")
  const r = parseInt(c.slice(0, 2), 16) || 0
  const g = parseInt(c.slice(2, 4), 16) || 0
  const b = parseInt(c.slice(4, 6), 16) || 0
  const yiq = (r * 299 + g * 587 + b * 114) / 1000
  return yiq >= 155
}

/** Renders card onto a high-res 1080×1350 canvas */
export async function renderCardToCanvas(options: RenderCardOptions): Promise<HTMLCanvasElement> {
  const canvas = document.createElement("canvas")
  canvas.width = WIDTH
  canvas.height = HEIGHT
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

  // Draw background according to style
  switch (options.style) {
    case "aura":
      drawAuraBackground(ctx, options.accentColor, artworkImg)
      drawAuraContent(ctx, options, artworkImg)
      break
    case "player":
      drawPlayerBackground(ctx, options.accentColor, artworkImg)
      drawPlayerContent(ctx, options, artworkImg)
      break
    case "polaroid":
      drawPolaroidBackground(ctx)
      drawPolaroidContent(ctx, options, artworkImg)
      break
    case "solid":
      drawSolidBackground(ctx, options.accentColor)
      drawSolidContent(ctx, options, artworkImg)
      break
    case "paper":
      drawPaperBackground(ctx)
      drawPaperContent(ctx, options, artworkImg)
      break
  }

  return canvas
}

/* ==========================================================================
   STYLE: AURA
   ========================================================================== */

function drawAuraBackground(
  ctx: CanvasRenderingContext2D,
  accent: string,
  artwork: HTMLImageElement | null,
) {
  // Base dark gradient
  const grad = ctx.createLinearGradient(0, 0, WIDTH, HEIGHT)
  grad.addColorStop(0, "#181424")
  grad.addColorStop(1, "#08070d")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, WIDTH, HEIGHT)

  // Blurred artwork glow
  if (artwork) {
    ctx.save()
    ctx.globalAlpha = 0.4
    ctx.filter = "blur(80px)"
    ctx.drawImage(artwork, -WIDTH * 0.3, -HEIGHT * 0.2, WIDTH * 1.6, HEIGHT * 1.4)
    ctx.filter = "none"
    ctx.restore()
  }

  // Accent radial glow at center-bottom
  const radial = ctx.createRadialGradient(
    WIDTH / 2,
    HEIGHT * 0.6,
    50,
    WIDTH / 2,
    HEIGHT * 0.6,
    WIDTH * 0.75,
  )
  radial.addColorStop(0, accent + "55")
  radial.addColorStop(1, "transparent")
  ctx.fillStyle = radial
  ctx.fillRect(0, 0, WIDTH, HEIGHT)

  // Vignette overlay
  const vig = ctx.createLinearGradient(0, 0, 0, HEIGHT)
  vig.addColorStop(0, "rgba(0,0,0,0.15)")
  vig.addColorStop(0.5, "rgba(0,0,0,0.05)")
  vig.addColorStop(1, "rgba(0,0,0,0.7)")
  ctx.fillStyle = vig
  ctx.fillRect(0, 0, WIDTH, HEIGHT)
}

function drawAuraContent(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
) {
  const pad = 84

  // 1. Header (Artwork + Title + Artist)
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

  // Title & Artist
  ctx.textAlign = "left"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 42px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.title, pad + artSize + 32, pad + 56)

  ctx.fillStyle = "rgba(255,255,255,0.72)"
  ctx.font = "500 32px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.artist, pad + artSize + 32, pad + 104)

  // 2. Lyrics in center
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: pad + artSize + 140,
    maxWidth: WIDTH - pad * 2,
    maxHeight: HEIGHT - (pad + artSize + 280),
    fontFamily: "'Outfit', 'Segoe UI', system-ui, sans-serif",
    color: "#ffffff",
    align: "left",
  })

  // 3. Footer Branding
  drawFooter(ctx, "rgba(255,255,255,0.65)", pad)
}

/* ==========================================================================
   STYLE: PLAYER
   ========================================================================== */

function drawPlayerBackground(
  ctx: CanvasRenderingContext2D,
  accent: string,
  artwork: HTMLImageElement | null,
) {
  // Midnight backdrop
  const grad = ctx.createLinearGradient(0, 0, 0, HEIGHT)
  grad.addColorStop(0, "#12141c")
  grad.addColorStop(1, "#06070a")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, WIDTH, HEIGHT)

  if (artwork) {
    ctx.save()
    ctx.globalAlpha = 0.28
    ctx.filter = "blur(70px)"
    ctx.drawImage(artwork, -WIDTH * 0.2, -HEIGHT * 0.1, WIDTH * 1.4, HEIGHT * 1.2)
    ctx.filter = "none"
    ctx.restore()
  }

  const radial = ctx.createRadialGradient(
    WIDTH / 2,
    HEIGHT * 0.35,
    20,
    WIDTH / 2,
    HEIGHT * 0.35,
    WIDTH * 0.65,
  )
  radial.addColorStop(0, accent + "33")
  radial.addColorStop(1, "transparent")
  ctx.fillStyle = radial
  ctx.fillRect(0, 0, WIDTH, HEIGHT)
}

function drawPlayerContent(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
) {
  const pad = 84

  // 1. Centered Large Album Artwork
  const coverSize = 360
  const coverX = (WIDTH - coverSize) / 2
  const coverY = 100

  // Shadow
  ctx.save()
  ctx.shadowColor = "rgba(0,0,0,0.6)"
  ctx.shadowBlur = 40
  ctx.shadowOffsetY = 18
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
  }

  // Title & Artist
  ctx.textAlign = "center"
  ctx.fillStyle = "#ffffff"
  ctx.font = "bold 44px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.title, WIDTH / 2, coverY + coverSize + 64)

  ctx.fillStyle = "rgba(255,255,255,0.65)"
  ctx.font = "500 30px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.artist, WIDTH / 2, coverY + coverSize + 112)

  // 2. Lyrics
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: coverY + coverSize + 160,
    maxWidth: WIDTH - pad * 2,
    maxHeight: 280,
    fontFamily: "'Outfit', 'Segoe UI', system-ui, sans-serif",
    color: "#ffffff",
    align: "center",
  })

  // 3. Progress Bar & Transport
  const barY = HEIGHT - 240
  const barWidth = WIDTH - pad * 2
  const time = options.time ?? 64
  const duration = options.duration && options.duration > 0 ? options.duration : 210
  const progress = Math.min(Math.max(time / duration, 0), 1)

  // Track background
  ctx.fillStyle = "rgba(255,255,255,0.2)"
  roundRect(ctx, pad, barY, barWidth, 10, 5)
  ctx.fill()

  // Track progress
  ctx.fillStyle = "#ffffff"
  roundRect(ctx, pad, barY, barWidth * progress, 10, 5)
  ctx.fill()

  // Scrubber thumb
  ctx.beginPath()
  ctx.arc(pad + barWidth * progress, barY + 5, 12, 0, Math.PI * 2)
  ctx.fillStyle = "#ffffff"
  ctx.fill()

  // Timestamps
  ctx.font = "600 24px 'Outfit', monospace"
  ctx.fillStyle = "rgba(255,255,255,0.6)"
  ctx.textAlign = "left"
  ctx.fillText(formatTime(time), pad, barY + 44)
  ctx.textAlign = "right"
  ctx.fillText("-" + formatTime(Math.max(0, duration - time)), WIDTH - pad, barY + 44)

  // Transport controls simulation
  drawTransportControls(ctx, barY + 100)

  // Footer branding
  drawFooter(ctx, "rgba(255,255,255,0.5)", pad, HEIGHT - 36)
}

function drawTransportControls(ctx: CanvasRenderingContext2D, y: number) {
  const cx = WIDTH / 2

  // Shuffle icon (small)
  ctx.fillStyle = "rgba(255,255,255,0.55)"
  ctx.font = "26px system-ui"
  ctx.textAlign = "center"
  ctx.fillText("🔀", cx - 210, y + 2)

  // Previous
  ctx.fillStyle = "rgba(255,255,255,0.9)"
  ctx.fillText("⏮", cx - 105, y + 4)

  // Play / Pause Circle
  ctx.beginPath()
  ctx.arc(cx, y, 36, 0, Math.PI * 2)
  ctx.fillStyle = "#ffffff"
  ctx.fill()

  ctx.fillStyle = "#000000"
  ctx.beginPath()
  ctx.rect(cx - 10, y - 12, 7, 24)
  ctx.rect(cx + 3, y - 12, 7, 24)
  ctx.fill()

  // Next
  ctx.fillStyle = "rgba(255,255,255,0.9)"
  ctx.fillText("⏭", cx + 105, y + 4)

  // Heart
  ctx.fillStyle = "#ec4899"
  ctx.fillText("♥", cx + 210, y + 2)
}

/* ==========================================================================
   STYLE: POLAROID
   ========================================================================== */

function drawPolaroidBackground(ctx: CanvasRenderingContext2D) {
  const grad = ctx.createLinearGradient(0, 0, WIDTH, HEIGHT)
  grad.addColorStop(0, "#ece5d8")
  grad.addColorStop(1, "#dad0c0")
  ctx.fillStyle = grad
  ctx.fillRect(0, 0, WIDTH, HEIGHT)

  // Noise texture simulation
  drawGrain(ctx, 0.05, true)
}

function drawPolaroidContent(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
) {
  ctx.save()
  // Slight vintage rotation (-2.5 degrees)
  ctx.translate(WIDTH / 2, HEIGHT / 2 - 30)
  ctx.rotate((-2.5 * Math.PI) / 180)
  ctx.translate(-WIDTH / 2, -(HEIGHT / 2 - 30))

  const frameW = 860
  const frameH = 1060
  const frameX = (WIDTH - frameW) / 2
  const frameY = 90

  // White polaroid frame with shadow
  ctx.shadowColor = "rgba(0,0,0,0.22)"
  ctx.shadowBlur = 45
  ctx.shadowOffsetY = 24
  ctx.fillStyle = "#fdfbf7"
  roundRect(ctx, frameX, frameY, frameW, frameH, 12)
  ctx.fill()
  ctx.shadowColor = "transparent"

  // Photo area inside polaroid
  const photoW = frameW - 72
  const photoH = 620
  const photoX = frameX + 36
  const photoY = frameY + 36

  if (artwork) {
    ctx.save()
    roundRect(ctx, photoX, photoY, photoW, photoH, 4)
    ctx.clip()
    ctx.drawImage(artwork, photoX, photoY, photoW, photoH)

    // Dark gradient on photo bottom for tag readability
    const photoGrad = ctx.createLinearGradient(0, photoY + photoH - 120, 0, photoY + photoH)
    photoGrad.addColorStop(0, "transparent")
    photoGrad.addColorStop(1, "rgba(0,0,0,0.6)")
    ctx.fillStyle = photoGrad
    ctx.fillRect(photoX, photoY, photoW, photoH)
    ctx.restore()
  } else {
    ctx.fillStyle = "#e0dad0"
    roundRect(ctx, photoX, photoY, photoW, photoH, 4)
    ctx.fill()
  }

  // Label tag on photo bottom-left
  ctx.fillStyle = "rgba(0,0,0,0.7)"
  ctx.font = "bold 24px 'Outfit', monospace"
  ctx.textAlign = "left"
  const tagText = options.title.toUpperCase()
  const tagWidth = ctx.measureText(tagText).width + 32
  roundRect(ctx, photoX + 24, photoY + photoH - 64, tagWidth, 42, 6)
  ctx.fill()

  ctx.fillStyle = "#ffffff"
  ctx.fillText(tagText, photoX + 40, photoY + photoH - 34)

  // Handwritten Lyrics on bottom section of Polaroid frame
  const lyricsY = photoY + photoH + 54
  ctx.font = "bold 44px 'Caveat', 'Segoe Script', cursive"
  ctx.fillStyle = "#262220"
  ctx.textAlign = "left"

  let curY = lyricsY
  const maxLines = options.lines.slice(0, 4)
  for (const line of maxLines) {
    ctx.fillText(line, photoX + 16, curY)
    curY += 60
  }

  // Artist signature
  ctx.font = "italic 32px 'Caveat', 'Segoe Script', cursive"
  ctx.fillStyle = "rgba(38,34,32,0.65)"
  ctx.fillText(`— ${options.artist}`, photoX + 16, curY + 12)

  ctx.restore()

  // Footer branding at bottom of page
  drawFooter(ctx, "rgba(0,0,0,0.45)", 84, HEIGHT - 50)
}

/* ==========================================================================
   STYLE: SOLID
   ========================================================================== */

function drawSolidBackground(ctx: CanvasRenderingContext2D, accent: string) {
  ctx.fillStyle = accent
  ctx.fillRect(0, 0, WIDTH, HEIGHT)
}

function drawSolidContent(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
) {
  const pad = 84
  const light = isLightColor(options.accentColor)
  const ink = light ? "#121212" : "#ffffff"
  const inkMuted = light ? "rgba(0,0,0,0.65)" : "rgba(255,255,255,0.7)"

  // 1. Header
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
  ctx.font = "bold 42px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.title, pad + artSize + 32, pad + 56)

  ctx.fillStyle = inkMuted
  ctx.font = "500 32px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillText(options.artist, pad + artSize + 32, pad + 104)

  // 2. Lyrics
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: pad + artSize + 140,
    maxWidth: WIDTH - pad * 2,
    maxHeight: HEIGHT - (pad + artSize + 280),
    fontFamily: "'Outfit', 'Segoe UI', system-ui, sans-serif",
    color: ink,
    align: "left",
  })

  // 3. Footer
  drawFooter(ctx, inkMuted, pad)
}

/* ==========================================================================
   STYLE: PAPER
   ========================================================================== */

function drawPaperBackground(ctx: CanvasRenderingContext2D) {
  ctx.fillStyle = "#f6f3eb"
  ctx.fillRect(0, 0, WIDTH, HEIGHT)
  drawGrain(ctx, 0.08, true)
}

function drawPaperContent(
  ctx: CanvasRenderingContext2D,
  options: RenderCardOptions,
  artwork: HTMLImageElement | null,
) {
  const pad = 96
  const ink = "#221d1b"
  const inkMuted = "rgba(34,29,27,0.65)"

  // Giant decorative quote mark
  ctx.font = "bold 180px 'Newsreader', 'Playfair Display', Georgia, serif"
  ctx.fillStyle = "rgba(34,29,27,0.1)"
  ctx.textAlign = "left"
  ctx.fillText("“", pad - 30, pad + 110)

  // Header: Mini artwork + Title + Artist (Serif)
  const artSize = 110
  if (artwork) {
    ctx.save()
    roundRect(ctx, pad, pad + 40, artSize, artSize, 12)
    ctx.clip()
    ctx.drawImage(artwork, pad, pad + 40, artSize, artSize)
    ctx.restore()
  }

  ctx.fillStyle = ink
  ctx.font = "600 40px 'Newsreader', 'Playfair Display', Georgia, serif"
  ctx.fillText(options.title, pad + artSize + 32, pad + 94)

  ctx.fillStyle = inkMuted
  ctx.font = "italic 30px 'Newsreader', 'Playfair Display', Georgia, serif"
  ctx.fillText(options.artist, pad + artSize + 32, pad + 138)

  // Lyrics Block in Serif
  drawLyricsBlock(ctx, options.lines, {
    x: pad,
    y: pad + artSize + 170,
    maxWidth: WIDTH - pad * 2,
    maxHeight: HEIGHT - (pad + artSize + 300),
    fontFamily: "'Newsreader', 'Playfair Display', Georgia, serif",
    color: ink,
    align: "left",
    fontWeight: "500",
  })

  // Footer
  drawFooter(ctx, inkMuted, pad)
}

/* ==========================================================================
   HELPERS
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
}

function drawLyricsBlock(
  ctx: CanvasRenderingContext2D,
  lines: string[],
  config: LyricsBlockConfig,
) {
  const totalChars = lines.join(" ").length
  let fontSize = 64
  if (totalChars > 160) fontSize = 42
  else if (totalChars > 100) fontSize = 48
  else if (totalChars > 60) fontSize = 56

  const lineHeight = fontSize * 1.45
  ctx.font = `${config.fontWeight ?? "bold"} ${fontSize}px ${config.fontFamily}`
  ctx.fillStyle = config.color
  ctx.textAlign = config.align

  let currentY = config.y
  for (const line of lines) {
    const wrapped = wrapText(ctx, line, config.maxWidth)
    for (const wrapLine of wrapped) {
      const drawX = config.align === "center" ? WIDTH / 2 : config.x
      ctx.fillText(wrapLine, drawX, currentY)
      currentY += lineHeight
    }
    currentY += fontSize * 0.35 // small paragraph spacing between lines
  }
}

function drawFooter(
  ctx: CanvasRenderingContext2D,
  color: string,
  pad: number,
  yPos: number = HEIGHT - 70,
) {
  ctx.font = "bold 26px 'Outfit', 'Segoe UI', system-ui, sans-serif"
  ctx.fillStyle = color
  ctx.textAlign = "left"
  ctx.fillText("❝  OpenNotchi", pad, yPos)
}

function drawGrain(ctx: CanvasRenderingContext2D, opacity: number, dark = false) {
  ctx.save()
  const grainCanvas = document.createElement("canvas")
  grainCanvas.width = 120
  grainCanvas.height = 120
  const gctx = grainCanvas.getContext("2d")
  if (!gctx) return

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
  ctx.fillRect(0, 0, WIDTH, HEIGHT)
  ctx.restore()
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
  setTimeout(() => URL.revokeObjectURL(url), 1500)
}
