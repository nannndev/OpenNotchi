import { useEffect, useRef, useState, type CSSProperties } from "react"
import type { NotchiMood } from "./notchi"

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

/**
 * Notchi 2.0: Cyber-Bot / Visor Robot Companion
 * A futuristic micro-robot living right in your notch / pill.
 * Features an OLED visor, animated LED eyes (blinking, eye gaze tracking, heart eyes,
 * scanning mode, cyber headphones when vibing to music), glowing antenna, and interactive petting.
 */
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

  // 30fps animation tick for body language, blinking, and floating particles
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

  // Squish & bounce physics on click / pet
  const squishY = sincePet < 0.45 ? 1 - 0.35 * Math.sin((sincePet / 0.45) * Math.PI) : 1
  const squishX = sincePet < 0.45 ? 1 + 0.25 * Math.sin((sincePet / 0.45) * Math.PI) : 1
  const hopY = mood === "happy" ? -Math.abs(Math.sin(t * 7)) * 3 : 0
  const shakeX = mood === "alert" ? Math.sin(t * 36) * 1.5 : 0
  const floatY = mood === "idle" || mood === "sleepy" ? Math.sin(t * 2) * 0.8 : 0

  // Colors & LED Tints
  const isWhite = !accent || accent.toLowerCase() === "#ffffff" || accent === "white" || accent === "rgb(255, 255, 255)"
  const effectiveAccent = isWhite ? "#38bdf8" : accent

  let eyeColor = effectiveAccent
  let shellGlow = effectiveAccent
  if (mood === "alert") {
    eyeColor = "#f97316"
    shellGlow = "#f97316"
  } else if (mood === "loved") {
    eyeColor = "#ec4899"
    shellGlow = "#ec4899"
  } else if (mood === "happy") {
    eyeColor = "#10b981"
    shellGlow = "#10b981"
  } else if (mood === "tired") {
    eyeColor = "#94a3b8"
    shellGlow = "#64748b"
  }

  // Blinking: every 3.5s, eyes do a quick blink
  const blinkCycle = t % 3.5
  const isBlinking = (mood === "idle" || mood === "busy") && blinkCycle < 0.16
  const blinkScale = isBlinking ? 0.1 : 1

  // Gaze tracking offset
  const gazeShift = mood === "idle" ? Math.max(-2.2, Math.min(2.2, gaze * 2.2)) : 0

  // Extras
  const zProgress = (t / 2.2) % 1
  const noteProgress = (t / 1.7) % 1
  const isAltNote = Math.floor(t / 1.7) % 2 === 0
  const alertBlink = Math.sin(t * 10) > 0

  return (
    <div
      ref={containerRef}
      className={`notchi-mascot-container ${hovered ? "hovered" : ""}`}
      style={
        {
          width: size,
          height: size,
          transform: `scale(${hovered ? 1.15 : 1})`,
          transition: "transform 0.22s cubic-bezier(0.34, 1.56, 0.64, 1)",
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
      title="Click to pet Notchi Cyber-Bot · hover pill to open"
    >
      {/* Robot Body Container */}
      <div
        style={{
          width: size,
          height: size,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          transform: `translate(${shakeX}px, ${hopY + floatY}px) scale(${squishX}, ${squishY})`,
          transformOrigin: "bottom center",
          transition: "transform 0.05s linear",
          filter: `drop-shadow(0 0 4px ${shellGlow}44)`,
        }}
      >
        <svg
          viewBox="0 0 32 32"
          width={size}
          height={size}
          style={{ overflow: "visible" }}
        >
          <defs>
            {/* Robot Head Gradient */}
            <linearGradient id="notchi-helmet" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#242832" />
              <stop offset="100%" stopColor="#111318" />
            </linearGradient>

            {/* Visor Glass Gradient */}
            <linearGradient id="notchi-visor-gloss" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#ffffff" stopOpacity="0.22" />
              <stop offset="60%" stopColor="#ffffff" stopOpacity="0" />
            </linearGradient>

            {/* Neon Glow Filter */}
            <filter id="notchi-glow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="0.8" result="blur" />
              <feComposite in="SourceGraphic" in2="blur" operator="over" />
            </filter>
          </defs>

          {/* Top Antenna */}
          <line
            x1="16"
            y1="4.5"
            x2="16"
            y2="7.5"
            stroke="#475569"
            strokeWidth="1.6"
            strokeLinecap="round"
          />
          <circle
            cx="16"
            cy="3.8"
            r="1.8"
            fill={eyeColor}
            filter="url(#notchi-glow)"
            style={{
              opacity: mood === "alert" && alertBlink ? 1 : 0.85,
            }}
          />

          {/* Headphone Arcs when Vibing to Music */}
          {mood === "vibing" && (
            <path
              d="M 2.5 16 A 13.5 13.5 0 0 1 29.5 16"
              fill="none"
              stroke={effectiveAccent}
              strokeWidth="2.2"
              strokeLinecap="round"
              filter="url(#notchi-glow)"
            />
          )}

          {/* Left Ear Pad */}
          <rect
            x="1.8"
            y="12"
            width="3.2"
            height="9"
            rx="1.6"
            fill={mood === "vibing" ? effectiveAccent : "#334155"}
            stroke={mood === "vibing" ? "#fff" : "rgba(255,255,255,0.15)"}
            strokeWidth="0.8"
          />

          {/* Right Ear Pad */}
          <rect
            x="27"
            y="12"
            width="3.2"
            height="9"
            rx="1.6"
            fill={mood === "vibing" ? effectiveAccent : "#334155"}
            stroke={mood === "vibing" ? "#fff" : "rgba(255,255,255,0.15)"}
            strokeWidth="0.8"
          />

          {/* Robot Head / Helmet Base */}
          <rect
            x="4"
            y="7.5"
            width="24"
            height="18"
            rx="6.5"
            fill="url(#notchi-helmet)"
            stroke="rgba(255, 255, 255, 0.16)"
            strokeWidth="1"
          />

          {/* OLED Visor Screen */}
          <rect
            x="6"
            y="9.5"
            width="20"
            height="14"
            rx="4.5"
            fill="#06070a"
            stroke="rgba(255, 255, 255, 0.08)"
            strokeWidth="0.7"
          />

          {/* Visor Glass Reflection */}
          <path
            d="M 6.8 11.5 Q 16 9.8 25.2 12.2 L 25.2 10.5 Q 16 9 6.8 10.5 Z"
            fill="url(#notchi-visor-gloss)"
          />

          {/* Cheeks / Blushing on Loved & Happy */}
          {(mood === "loved" || mood === "happy") && (
            <>
              <circle cx="8.5" cy="19.5" r="1.4" fill="#f43f5e" opacity="0.65" />
              <circle cx="23.5" cy="19.5" r="1.4" fill="#f43f5e" opacity="0.65" />
            </>
          )}

          {/* --- Animated Visor Face / Eyes by Mood --- */}
          {mood === "loved" ? (
            /* Heart Eyes ♥ ♥ */
            <g fill={eyeColor} filter="url(#notchi-glow)">
              <path
                d={`M ${11.5 + gazeShift} 18.5 L ${8.5 + gazeShift} 15.2 A 1.8 1.8 0 0 1 11.5 13.5 A 1.8 1.8 0 0 1 14.5 15.2 Z`}
                transform={`scale(1, ${blinkScale})`}
                style={{ transformOrigin: "11.5px 16px" }}
              />
              <path
                d={`M ${20.5 + gazeShift} 18.5 L ${17.5 + gazeShift} 15.2 A 1.8 1.8 0 0 1 20.5 13.5 A 1.8 1.8 0 0 1 23.5 15.2 Z`}
                transform={`scale(1, ${blinkScale})`}
                style={{ transformOrigin: "20.5px 16px" }}
              />
            </g>
          ) : mood === "happy" ? (
            /* Joyful Smiling Arcs ^ ^ */
            <g
              stroke={eyeColor}
              strokeWidth="2.2"
              strokeLinecap="round"
              fill="none"
              filter="url(#notchi-glow)"
            >
              <path d={`M ${9 + gazeShift} 18 Q ${11.5 + gazeShift} 14.2 ${14 + gazeShift} 18`} />
              <path d={`M ${18 + gazeShift} 18 Q ${20.5 + gazeShift} 14.2 ${23 + gazeShift} 18`} />
            </g>
          ) : mood === "vibing" ? (
            /* Chill Groove Arcs ~ ~ */
            <g
              stroke={eyeColor}
              strokeWidth="2.2"
              strokeLinecap="round"
              fill="none"
              filter="url(#notchi-glow)"
            >
              <path d={`M ${9 + gazeShift} 16 Q ${11.5 + gazeShift} 18.2 ${14 + gazeShift} 16`} />
              <path d={`M ${18 + gazeShift} 16 Q ${20.5 + gazeShift} 18.2 ${23 + gazeShift} 16`} />
            </g>
          ) : mood === "sleepy" ? (
            /* Relaxed Closed Eyes - - */
            <g
              stroke={eyeColor}
              strokeWidth="2"
              strokeLinecap="round"
              fill="none"
              opacity="0.75"
            >
              <line x1="9.5" y1="16.5" x2="13.5" y2="16.5" />
              <line x1="18.5" y1="16.5" x2="22.5" y2="16.5" />
            </g>
          ) : mood === "tired" ? (
            /* Drooping Sad Eyes v v */
            <g
              stroke={eyeColor}
              strokeWidth="2"
              strokeLinecap="round"
              fill="none"
              opacity="0.6"
            >
              <line x1="9.5" y1="15.8" x2="13.5" y2="17.2" />
              <line x1="18.5" y1="17.2" x2="22.5" y2="15.8" />
            </g>
          ) : mood === "busy" ? (
            /* Cyber Scanning Slits */
            <g fill={eyeColor} filter="url(#notchi-glow)">
              <rect
                x={9 + gazeShift}
                y={15}
                width="5"
                height={2.2 * blinkScale}
                rx="1.1"
              />
              <rect
                x={18 + gazeShift}
                y={15}
                width="5"
                height={2.2 * blinkScale}
                rx="1.1"
              />
              {/* Scan dot sweeping across */}
              <circle
                cx={11.5 + 4.5 * Math.sin(t * 8)}
                cy={16.1}
                r="1"
                fill="#ffffff"
              />
            </g>
          ) : mood === "alert" ? (
            /* Startled Wide Alert Eyes O O */
            <g fill={eyeColor} filter="url(#notchi-glow)">
              <circle
                cx="11.5"
                cy="16"
                r="3.2"
                fill={alertBlink ? eyeColor : "transparent"}
                stroke={eyeColor}
                strokeWidth="1.6"
              />
              <circle
                cx="20.5"
                cy="16"
                r="3.2"
                fill={alertBlink ? eyeColor : "transparent"}
                stroke={eyeColor}
                strokeWidth="1.6"
              />
              <circle cx="11.5" cy="16" r="1.2" fill="#fff" />
              <circle cx="20.5" cy="16" r="1.2" fill="#fff" />
            </g>
          ) : (
            /* Standard Idle LED Eyes (with Blink + Gaze) */
            <g fill={eyeColor} filter="url(#notchi-glow)">
              <rect
                x={11.5 + gazeShift - 1.8}
                y={16 - 2.8 * blinkScale}
                width="3.6"
                height={5.6 * blinkScale}
                rx="1.8"
              />
              <rect
                x={20.5 + gazeShift - 1.8}
                y={16 - 2.8 * blinkScale}
                width="3.6"
                height={5.6 * blinkScale}
                rx="1.8"
              />
              {/* Eye Catchlight Highlights */}
              {!isBlinking && (
                <>
                  <circle cx={12.2 + gazeShift} cy={14.8} r="0.8" fill="#ffffff" />
                  <circle cx={21.2 + gazeShift} cy={14.8} r="0.8" fill="#ffffff" />
                </>
              )}
            </g>
          )}
        </svg>
      </div>

      {/* Mood Extra: Drifting 'z' for Sleepy */}
      {mood === "sleepy" && (
        <span
          style={{
            position: "absolute",
            left: size * 0.44 + zProgress * size * 0.1,
            top: -size * 0.1 - zProgress * size * 0.22,
            fontSize: size * 0.28,
            fontWeight: 800,
            color: eyeColor,
            opacity: 0.85 * (1 - zProgress),
            pointerEvents: "none",
            filter: "drop-shadow(0 0 2px rgba(0,0,0,0.8))",
          }}
        >
          z
        </span>
      )}

      {/* Mood Extra: Blinking '!' for Alert */}
      {mood === "alert" && (
        <span
          style={{
            position: "absolute",
            left: size * 0.46,
            top: -size * 0.16,
            fontSize: size * 0.34,
            fontWeight: 900,
            color: "#f97316",
            opacity: alertBlink ? 1 : 0.35,
            pointerEvents: "none",
            filter: "drop-shadow(0 0 4px #f97316)",
          }}
        >
          !
        </span>
      )}

      {/* Mood Extra: Floating Music Notes for Vibing */}
      {mood === "vibing" && (
        <span
          style={{
            position: "absolute",
            left: size * 0.46 + Math.sin(noteProgress * Math.PI * 2) * size * 0.06,
            top: -size * 0.1 - noteProgress * size * 0.25,
            fontSize: size * 0.26,
            fontWeight: 700,
            color: eyeColor,
            opacity: 0.9 * (1 - noteProgress),
            pointerEvents: "none",
            filter: "drop-shadow(0 0 3px rgba(0,0,0,0.8))",
          }}
        >
          {isAltNote ? "♪" : "♫"}
        </span>
      )}

      {/* Mood Extra: Floating Hearts when Petted */}
      {sincePet < 1.6 && (
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {[0, 1, 2].map((i) => {
            const progress = sincePet / 1.6
            const xOff = (i - 1) * size * 0.24
            const yOff = -size * 0.18 - progress * size * (0.28 + i * 0.08)
            const heartSize = size * (0.18 + i * 0.04)
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
                  filter: "drop-shadow(0 0 4px rgba(236,72,153,0.7))",
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
