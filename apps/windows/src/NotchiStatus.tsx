import {
  BatteryLow,
  CheckCircle2,
  Clock,
  Hand,
  Heart,
  Moon,
  Music2,
  Sparkles,
} from "lucide-react"
import { useEffect, useState, type CSSProperties } from "react"
import type { NotchiMood } from "./notchi"

interface NotchiStatusProps {
  mood: NotchiMood
  size: number
  accent: string
  pets: number
}

export function NotchiStatus({ mood, size, accent, pets }: NotchiStatusProps) {
  const [timeStr, setTimeStr] = useState("")

  useEffect(() => {
    const updateTime = () => {
      const d = new Date()
      setTimeStr(
        d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })
      )
    }
    updateTime()
    const timer = setInterval(updateTime, 1000)
    return () => clearInterval(timer)
  }, [])

  const isWhite = !accent || accent.toLowerCase() === "#ffffff" || accent === "white" || accent === "rgb(255, 255, 255)"
  const effectiveAccent = isWhite ? "#D1D1D6" : accent

  const boxStyle: CSSProperties = {
    width: size,
    height: size,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    position: "relative",
  }

  switch (mood) {
    case "busy":
      return (
        <div style={boxStyle} title="AI agent working…">
          <div className="notchi-busy-ring" style={{ width: size * 0.8, height: size * 0.8 }}>
            <div
              className="notchi-spinner-arc"
              style={{ borderColor: effectiveAccent, borderTopColor: "transparent" }}
            />
            <Sparkles
              size={size * 0.38}
              style={{ color: effectiveAccent, filter: `drop-shadow(0 0 3px ${effectiveAccent})` }}
            />
          </div>
        </div>
      )

    case "happy":
      return (
        <div style={boxStyle} title="Agent finished!">
          <div className="notchi-bounce">
            <CheckCircle2
              size={size * 0.72}
              color="#22c55e"
              style={{ filter: "drop-shadow(0 0 4px rgba(34,197,94,0.6))" }}
            />
          </div>
        </div>
      )

    case "alert":
      return (
        <div style={boxStyle} title="Agent needs your approval!">
          <div className="notchi-wiggle">
            <Hand
              size={size * 0.72}
              color="#f97316"
              style={{ filter: "drop-shadow(0 0 4px rgba(249,115,22,0.6))" }}
            />
          </div>
        </div>
      )

    case "loved":
      return (
        <div style={boxStyle} title={pets >= 3 ? "So happy!" : "Petted ♥"}>
          <div className="notchi-bounce">
            {pets >= 3 ? (
              <div
                style={{
                  width: size * 0.75,
                  height: size * 0.75,
                  borderRadius: "50%",
                  border: "2px solid #ec4899",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  filter: "drop-shadow(0 0 4px rgba(236,72,153,0.6))",
                }}
              >
                <Heart size={size * 0.42} color="#ec4899" fill="#ec4899" />
              </div>
            ) : (
              <Heart
                size={size * 0.72}
                color="#ec4899"
                fill="#ec4899"
                style={{ filter: "drop-shadow(0 0 4px rgba(236,72,153,0.6))" }}
              />
            )}
          </div>
        </div>
      )

    case "tired":
      return (
        <div style={boxStyle} title="Battery low">
          <div className="notchi-pulse">
            <BatteryLow
              size={size * 0.72}
              color="#ef4444"
              style={{ filter: "drop-shadow(0 0 4px rgba(239,68,68,0.6))" }}
            />
          </div>
        </div>
      )

    case "vibing":
      return (
        <div style={boxStyle} title="Listening to music">
          <div className="notchi-pulse">
            <Music2
              size={size * 0.72}
              color={effectiveAccent}
              style={{ filter: `drop-shadow(0 0 4px ${effectiveAccent})` }}
            />
          </div>
        </div>
      )

    case "sleepy":
      return (
        <div style={boxStyle} title="Sleepy… zz">
          <div className="notchi-pulse">
            <Moon
              size={size * 0.7}
              color={effectiveAccent}
              style={{ opacity: 0.75, filter: `drop-shadow(0 0 3px ${effectiveAccent})` }}
            />
          </div>
        </div>
      )

    case "idle":
    default:
      return (
        <div
          style={{
            ...boxStyle,
            flexDirection: "column",
            gap: 1,
            userSelect: "none",
          }}
          title={timeStr}
        >
          <Clock size={size * 0.42} color={effectiveAccent} style={{ opacity: 0.85 }} />
          <span
            style={{
              fontSize: 8.5,
              fontWeight: 700,
              fontFamily: "monospace",
              color: "rgba(255,255,255,0.85)",
              lineHeight: 1,
            }}
          >
            {timeStr}
          </span>
        </div>
      )
  }
}
