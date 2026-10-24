/** Mirror filters and photobox strip composition (canvas only, no dependencies). */

export type MirrorEffect = "natural" | "vivid" | "warm" | "cool" | "film" | "mono" | "dreamy"

/** CSS filters approximating the macOS Core Image looks; the same string drives the live preview and the canvas. */
export const EFFECTS: Record<MirrorEffect, { name: string; filter: string }> = {
  natural: { name: "Natural", filter: "none" },
  vivid: { name: "Vivid", filter: "saturate(1.35) contrast(1.08)" },
  warm: { name: "Warm", filter: "sepia(0.18) saturate(1.15) hue-rotate(-8deg)" },
  cool: { name: "Cool", filter: "saturate(1.05) hue-rotate(12deg) brightness(1.02)" },
  film: { name: "Film", filter: "sepia(0.35) contrast(1.1) saturate(0.9)" },
  mono: { name: "Mono", filter: "grayscale(1) contrast(1.15)" },
  dreamy: { name: "Dreamy", filter: "saturate(0.9) brightness(1.06) blur(0.6px)" },
}

export type StripStyle = "classic" | "film" | "polaroid" | "midnight" | "sakura"

export const STRIP_STYLES: Record<StripStyle, { name: string; bg: string; ink: string }> = {
  classic: { name: "Classic", bg: "#ffffff", ink: "#222222" },
  film: { name: "Film", bg: "#141414", ink: "#e8a33b" },
  polaroid: { name: "Polaroid", bg: "#f5f0e6", ink: "#2b3a66" },
  midnight: { name: "Midnight", bg: "#0d0d12", ink: "#ffffff" },
  sakura: { name: "Sakura", bg: "#ffe3ec", ink: "#d36b8c" },
}

/** Pixel layout of a vertical strip: `count` 4:3 photos stacked with a caption band at the bottom. */
export function stripLayout(count: number, photoWidth = 600) {
  const pad = Math.round(photoWidth * 0.06)
  const photoH = Math.round((photoWidth * 3) / 4)
  const caption = Math.round(photoWidth * 0.22)
  return {
    width: photoWidth + pad * 2,
    height: pad + count * (photoH + pad) + caption,
    pad,
    photoW: photoWidth,
    photoH,
    slotY: (i: number) => pad + i * (photoH + pad),
    captionY: pad + count * (photoH + pad),
  }
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

/** Draws `shots` onto a strip, cropping each to 4:3 like object-fit: cover. */
export function composeStrip(shots: HTMLCanvasElement[], style: StripStyle, caption: string): HTMLCanvasElement {
  const L = stripLayout(shots.length)
  const { bg, ink } = STRIP_STYLES[style]
  const c = document.createElement("canvas")
  c.width = L.width
  c.height = L.height
  const ctx = c.getContext("2d")!
  ctx.fillStyle = bg
  ctx.fillRect(0, 0, c.width, c.height)

  shots.forEach((shot, i) => {
    const scale = Math.max(L.photoW / shot.width, L.photoH / shot.height)
    const sw = L.photoW / scale
    const sh = L.photoH / scale
    ctx.drawImage(shot, (shot.width - sw) / 2, (shot.height - sh) / 2, sw, sh, L.pad, L.slotY(i), L.photoW, L.photoH)
  })

  ctx.fillStyle = ink
  ctx.textAlign = "center"
  ctx.font = `700 ${Math.round(L.photoW * 0.07)}px 'Outfit', sans-serif`
  ctx.fillText(caption, c.width / 2, L.captionY + L.pad * 1.6)
  ctx.font = `500 ${Math.round(L.photoW * 0.04)}px 'Outfit', sans-serif`
  ctx.globalAlpha = 0.6
  ctx.fillText(new Date().toLocaleDateString(), c.width / 2, L.captionY + L.pad * 2.9)
  return c
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
