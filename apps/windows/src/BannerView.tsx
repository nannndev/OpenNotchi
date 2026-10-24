import { Bell, Check, Hand, Info, Sparkles, X } from "lucide-react"
import { useEffect, useState, type CSSProperties } from "react"
import { bannerRemaining, type Banner } from "./banner"

interface BannerViewProps {
  banner: Banner
  onDismiss: () => void
  isHovered?: boolean
}

export function BannerView({ banner, onDismiss, isHovered = false }: BannerViewProps) {
  const [shownAt] = useState(() => Date.now())
  const [pausedAt, setPausedAt] = useState<number | null>(null)
  const [totalPausedMs, setTotalPausedMs] = useState(0)
  const [progress, setProgress] = useState(1.0)
  const [appeared, setAppeared] = useState(false)

  // Appear animation on mount
  useEffect(() => {
    const t = setTimeout(() => setAppeared(true), 20)
    return () => clearTimeout(t)
  }, [])

  // Handle hover pause
  useEffect(() => {
    if (isHovered) {
      if (pausedAt === null) {
        setPausedAt(Date.now())
      }
    } else {
      if (pausedAt !== null) {
        setTotalPausedMs((prev) => prev + (Date.now() - pausedAt))
        setPausedAt(null)
      }
    }
  }, [isHovered, pausedAt])

  // Countdown timer tick and auto-dismiss
  useEffect(() => {
    const duration = banner.duration ?? 10
    const interval = setInterval(() => {
      const now = Date.now()
      const rem = bannerRemaining(shownAt, duration, now, pausedAt, totalPausedMs)
      setProgress(rem)
      if (rem <= 0 && !isHovered) {
        onDismiss()
      }
    }, 40)
    return () => clearInterval(interval)
  }, [banner.duration, shownAt, pausedAt, totalPausedMs, isHovered, onDismiss])

  const renderIcon = () => {
    switch (banner.icon) {
      case "checkmark":
        return <Check size={17} strokeWidth={2.5} />
      case "hand":
        return <Hand size={17} strokeWidth={2.2} />
      case "bell":
        return <Bell size={17} strokeWidth={2.2} />
      case "info":
        return <Info size={17} strokeWidth={2.2} />
      default:
        return <Sparkles size={17} strokeWidth={2.2} />
    }
  }

  const isAttention = banner.kind === "attention"

  return (
    <div
      className="notchi-banner"
      style={
        {
          "--banner-tint": banner.tint,
        } as CSSProperties
      }
    >
      {/* Beside the notch (top row) */}
      <div className="banner-top-row">
        <div className="banner-dot-wrap">
          <span className={`banner-dot ${isAttention ? "pulse" : ""}`} />
        </div>
        <div className="banner-top-spacer" />
        <span className="banner-badge">{banner.badge}</span>
      </div>

      {/* Main content below the notch */}
      <div className="banner-main-row">
        <div className={`banner-icon-circle ${appeared ? "pop" : ""}`}>{renderIcon()}</div>

        <div className={`banner-text-block ${appeared ? "slide" : ""}`}>
          <div className="banner-title" title={banner.title}>
            {banner.title}
          </div>
          {banner.subtitle && (
            <div className="banner-subtitle" title={banner.subtitle}>
              {banner.subtitle}
            </div>
          )}
        </div>

        {banner.actionTitle && (
          <button
            className="banner-action-btn"
            onClick={(e) => {
              e.stopPropagation()
              banner.onAction?.()
              onDismiss()
            }}
          >
            {banner.actionTitle}
          </button>
        )}

        <button
          className="banner-close-btn"
          onClick={(e) => {
            e.stopPropagation()
            onDismiss()
          }}
          title="Dismiss"
          aria-label="Dismiss banner"
        >
          <X size={11} strokeWidth={2.5} />
        </button>
      </div>

      {/* Thin 2px countdown bar shrinking over duration */}
      <div className="banner-progress-track">
        <div className="banner-progress-fill" style={{ width: `${Math.max(0, progress * 100)}%` }} />
      </div>

      {/* Soft tinted bottom glow */}
      <div className="banner-bottom-glow" />
    </div>
  )
}
