import { useEffect, useRef, useState, type CSSProperties } from "react"
import { notchiLevel, type NotchiMood } from "./notchi"

interface NotchiMascotProps {
  mood: NotchiMood
  size: number
  accent: string
  gaze?: number
  pettedAt?: number | null
  hovered?: boolean
  onClick?: () => void
  onHoverChange?: (hovered: boolean) => void
  onRectChange?: (rect: { x: number; y: number; width: number; height: number } | null) => void
}

export function NotchiMascot({
  mood,
  size,
  accent,
  gaze = 0,
  pettedAt = null,
  hovered = false,
  onClick,
  onHoverChange,
  onRectChange,
}: NotchiMascotProps) {
  const [t, setT] = useState(0)
  const containerRef = useRef<HTMLDivElement>(null)

  // 30fps animation tick for body language
  useEffect(() => {
    let frameId: number
    const start = performance.now()
    const loop = (now: number) => {
      setT((now - start) / 1000)
      frameId = requestAnimationFrame(loop)
    }
    frameId = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(frameId)
  }, [])

  // Report Notchi's bounding box relative to the pill whenever it mounts/resizes
  useEffect(() => {
    if (!onRectChange) return
    const el = containerRef.current
    if (!el) {
      onRectChange(null)
      return
    }

    const pill = el.closest(".pill")
    if (!pill) {
      onRectChange(null)
      return
    }

    const updateRect = () => {
      const pRect = pill.getBoundingClientRect()
      const nRect = el.getBoundingClientRect()
      onRectChange({
        x: nRect.left - pRect.left,
        y: nRect.top - pRect.top,
        width: nRect.width,
        height: nRect.height,
      })
    }

    updateRect()
    window.addEventListener("resize", updateRect)
    return () => {
      window.removeEventListener("resize", updateRect)
      onRectChange(null)
    }
  }, [onRectChange, size])

  // Time since last pet
  const now = Date.now()
  const sincePet = pettedAt ? (now - pettedAt) / 1000 : Infinity

  // Pet squish & spring: squashes down for 0.5s then springs back
  const squish = sincePet < 0.5 ? 1 - 0.4 * Math.sin((sincePet / 0.5) * Math.PI) : 1
  const shake = mood === "alert" ? Math.sin(t * 32) * size * 0.025 : 0

  // Color & tint
  const isWhite = !accent || accent.toLowerCase() === "#ffffff" || accent === "white" || accent === "rgb(255, 255, 255)"
  const effectiveAccent = isWhite ? "#D1D1D6" : accent

  let tint = effectiveAccent
  if (mood === "alert") tint = "#f97316"
  if (mood === "loved") tint = "#ec4899"

  // Glow strength
  let glowOpacity = 0.45
  if (mood === "alert" || mood === "loved" || mood === "vibing") glowOpacity = 0.85
  else if (mood === "happy" || mood === "busy") glowOpacity = 0.6
  else if (mood === "tired" || mood === "sleepy") glowOpacity = 0.2

  const width = size * 0.86
  const height = size * 0.86
  const barWidth = width / (5 + 4 * 0.55)
  const spacing = barWidth * 0.55

  // Extras
  // Sleepy: drifting "z"
  const zProgress = (t / 2.4) % 1
  // Vibing: rising notes
  const noteProgress = (t / 1.8) % 1
  const isAltNote = Math.floor(t / 1.8) % 2 === 0
  // Alert: blinking "!"
  const alertBlink = Math.sin(t * 8) > 0

  return (
    <div
      ref={containerRef}
      className={`notchi-mascot-container ${hovered ? "hovered" : ""}`}
      style={
        {
          width: size,
          height: size,
          transform: `scale(${hovered ? 1.15 : 1})`,
          transition: "transform 0.25s cubic-bezier(0.34, 1.56, 0.64, 1)",
          cursor: "pointer",
          position: "relative",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          userSelect: "none",
        } as CSSProperties
      }
      onClick={onClick}
      onMouseEnter={() => onHoverChange?.(true)}
      onMouseLeave={() => onHoverChange?.(false)}
      title="Click to pet Notchi · hover pill to open"
    >
      {/* 5 Bars */}
      <div
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: spacing,
          width,
          height,
          transform: `translateX(${shake}px)`,
          opacity: mood === "tired" || mood === "sleepy" ? 0.7 : 1,
          filter: `drop-shadow(0 0 3.5px ${tint}${Math.round(glowOpacity * 255)
            .toString(16)
            .padStart(2, "0")}) drop-shadow(0 0 8px ${tint}${Math.round(glowOpacity * 0.5 * 255)
            .toString(16)
            .padStart(2, "0")})`,
        }}
      >
        {[0, 1, 2, 3, 4].map((i) => {
          const lvl = notchiLevel(i, mood, t, gaze) * squish
          const barH = Math.max(barWidth, height * Math.min(1, Math.max(0.12, lvl)))
          return (
            <div
              key={i}
              style={{
                width: barWidth,
                height: barH,
                borderRadius: barWidth / 2,
                background:
                  mood === "alert"
                    ? "linear-gradient(to bottom, #ffc066, #f97316)"
                    : mood === "loved"
                    ? "linear-gradient(to bottom, #ffb3d9, #ec4899)"
                    : `linear-gradient(to bottom, #ffffff, ${tint})`,
              }}
            />
          )
        })}
      </div>

      {/* Mood Extra: Drifting 'z' for sleepy */}
      {mood === "sleepy" && (
        <span
          style={{
            position: "absolute",
            left: size * 0.4 + zProgress * size * 0.08,
            top: -size * 0.1 - zProgress * size * 0.18,
            fontSize: size * 0.28,
            fontWeight: 800,
            color: tint,
            opacity: 0.8 * (1 - zProgress),
            pointerEvents: "none",
          }}
        >
          z
        </span>
      )}

      {/* Mood Extra: Blinking '!' for alert */}
      {mood === "alert" && (
        <span
          style={{
            position: "absolute",
            left: size * 0.46,
            top: -size * 0.12,
            fontSize: size * 0.32,
            fontWeight: 900,
            color: "#f97316",
            opacity: alertBlink ? 1 : 0.35,
            pointerEvents: "none",
          }}
        >
          !
        </span>
      )}

      {/* Mood Extra: Floating notes for vibing */}
      {mood === "vibing" && (
        <span
          style={{
            position: "absolute",
            left: size * 0.44 + Math.sin(noteProgress * Math.PI * 2) * size * 0.04,
            top: -size * 0.08 - noteProgress * size * 0.22,
            fontSize: size * 0.24,
            fontWeight: 700,
            color: tint,
            opacity: 0.85 * (1 - noteProgress),
            pointerEvents: "none",
          }}
        >
          {isAltNote ? "♪" : "♫"}
        </span>
      )}

      {/* Mood Extra: Floating hearts when petted */}
      {sincePet < 1.6 && (
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {[0, 1, 2].map((i) => {
            const progress = sincePet / 1.6
            const xOff = (i - 1) * size * 0.22
            const yOff = -size * 0.15 - progress * size * (0.25 + i * 0.08)
            const heartSize = size * (0.16 + i * 0.04)
            return (
              <span
                key={i}
                style={{
                  position: "absolute",
                  left: "50%",
                  top: "50%",
                  transform: `translate(calc(-50% + ${xOff}px), calc(-50% + ${yOff}px))`,
                  fontSize: heartSize,
                  color: "#ec4899",
                  opacity: 1 - progress,
                  filter: "drop-shadow(0 0 3px rgba(236,72,153,0.6))",
                }}
              >
                ♥
              </span>
            )
          })}
        </div>
      )}
    </div>
  )
}
