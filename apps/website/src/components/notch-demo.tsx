import { AnimatePresence, motion } from "motion/react"
import {
  Calendar,
  Check,
  Copy,
  Fan,
  Gauge,
  Heart,
  Lightbulb,
  MessageSquareQuote,
  Minus,
  Pause,
  Pipette,
  Play,
  Plus,
  Repeat,
  Shuffle,
  SkipBack,
  SkipForward,
  SlidersHorizontal,
  Snowflake,
  Sparkles,
  Terminal,
  Video,
  Volume2,
  VolumeX,
  XCircle,
} from "lucide-react"
import { useEffect, useRef, useState } from "react"
import { cn } from "@/lib/utils"

const LINES = [
  "Headlights painting the empty road",
  "Radio humming a song we know",
  "Every stop light turning green",
  "Midnight drive, just you and me",
  "City sleeping, we're wide awake",
  "Turn it up for the long way home",
]
const DURATION = 204
const TABS = ["Home", "Smarthome", "Prompter", "Dev", "Timer"] as const
type Tab = (typeof TABS)[number]

const spring = { type: "spring", stiffness: 260, damping: 28 } as const

function fmt(s: number) {
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
}

function Wave({ bars, isPlaying, className }: { bars: number; isPlaying?: boolean; className?: string }) {
  return (
    <div className={cn("flex items-center gap-[3px]", className)}>
      {Array.from({ length: bars }, (_, i) => (
        <span
          key={i}
          className={cn("w-[3px] rounded-full bg-white transition-all", isPlaying ? "wave-bar" : "h-[3px] opacity-40")}
          style={{ animationDelay: `${-i * 0.27}s` }}
        />
      ))}
    </div>
  )
}

/** Interactive replica of the app's notch, pinned to the top of the page. */
export function NotchDemo() {
  const [open, setOpen] = useState(false)
  const [tab, setTab] = useState<Tab>("Home")
  const [lyricsMode, setLyricsMode] = useState(false)
  const [elapsed, setElapsed] = useState(72)
  const [isPlaying, setIsPlaying] = useState(true)
  const [isShuffled, setIsShuffled] = useState(false)
  const [isRepeating, setIsRepeating] = useState(false)
  const [isLoved, setIsLoved] = useState(true)
  const [volume, setVolume] = useState(0.75)
  const [isMuted, setIsMuted] = useState(false)
  const [copiedColor, setCopiedColor] = useState(false)
  const [activePorts, setActivePorts] = useState([
    { port: "3000", name: "Next.js", pid: "8421" },
    { port: "5173", name: "Vite App", pid: "9102" },
    { port: "8080", name: "Go API", pid: "1204" },
  ])
  const [peekToast, setPeekToast] = useState<string | null>(null)
  const [deckMode, setDeckMode] = useState<"vu" | "spectrum" | "calendar">("vu")
  const [prompterSpeed, setPrompterSpeed] = useState<number>(1)
  const [prompterPlaying, setPrompterPlaying] = useState<boolean>(true)
  const [prompterMirrored, setPrompterMirrored] = useState<boolean>(false)
  const prompterText = "Good morning team. Today I'm excited to showcase OpenNotchi v0.8.0. By positioning this teleprompter right under your Mac camera, you maintain 100% natural eye contact during video calls and keynotes without looking away."

  // Smarthome State
  const [acTemp, setAcTemp] = useState(24)
  const [acMode, setAcMode] = useState<"cool" | "eco" | "off">("cool")
  const [lightOn, setLightOn] = useState(true)
  const [lightBrightness, setLightBrightness] = useState(85)


  const closeTimer = useRef<number | undefined>(undefined)
  const ref = useRef<HTMLDivElement>(null)

  const show = () => {
    window.clearTimeout(closeTimer.current)
    setOpen(true)
  }
  const hide = (delay = 180) => {
    window.clearTimeout(closeTimer.current)
    closeTimer.current = window.setTimeout(() => setOpen(false), delay)
  }

  useEffect(() => {
    if (!isPlaying) return
    const id = window.setInterval(() => setElapsed((e) => (e >= DURATION ? 0 : e + 1)), 1000)
    return () => window.clearInterval(id)
  }, [isPlaying])

  useEffect(() => {
    // Peek once so visitors notice it's interactive.
    const peek = window.setTimeout(() => {
      show()
      hide(3200)
    }, 900)
    const outside = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && hide(0)
    const onScroll = () => hide(0)
    document.addEventListener("click", outside)
    window.addEventListener("scroll", onScroll, { passive: true })
    return () => {
      window.clearTimeout(peek)
      document.removeEventListener("click", outside)
      window.removeEventListener("scroll", onScroll)
    }
  }, [])

  const line = Math.floor(elapsed / 3) % LINES.length
  const showLyric = Math.floor(elapsed / 9) % 2 === 1

  const killPort = (port: string) => {
    setActivePorts((prev) => prev.filter((p) => p.port !== port))
  }

  const triggerPeek = (text: string) => {
    setPeekToast(text)
    window.setTimeout(() => setPeekToast(null), 2500)
  }

  const adjustTemp = (delta: number) => {
    const next = Math.max(16, Math.min(30, acTemp + delta))
    setAcTemp(next)
    triggerPeek(`AC: ${next}°C · ${acMode.toUpperCase()}`)
  }

  const toggleLight = () => {
    setLightOn((prev) => {
      const next = !prev
      triggerPeek(next ? `Lamps ON (${lightBrightness}%)` : "Lamps OFF")
      return next
    })
  }

  return (
    <div className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center" aria-hidden>
      <motion.div
        ref={ref}
        onMouseEnter={show}
        onMouseLeave={() => hide()}
        onClick={show}
        initial={false}
        animate={{
          width: open ? "min(680px, calc(100vw - 24px))" : 320,
          height: open ? 242 : 34,
          borderBottomLeftRadius: open ? 34 : 14,
          borderBottomRightRadius: open ? 34 : 14,
        }}
        transition={spring}
        className={cn(
          "pointer-events-auto relative overflow-hidden bg-black/95 backdrop-blur-2xl ring-1 ring-white/10 transition-shadow duration-500",
          open && "shadow-[0_28px_70px_rgba(0,0,0,0.85)] ring-white/15",
        )}
      >
        {/* Ambient Artwork Aura Glow */}
        {open && tab === "Home" && (
          <div className="pointer-events-none absolute inset-0 -z-10 overflow-hidden opacity-40">
            <div className="absolute -left-12 -top-6 size-48 rounded-full bg-gradient-to-br from-pink-500 to-purple-600 blur-3xl animate-pulse" />
            <div className="absolute -right-10 bottom-0 size-48 rounded-full bg-gradient-to-tr from-cyan-500 to-indigo-600 blur-3xl" />
          </div>
        )}

        {/* Ambient Smarthome Aura Glow */}
        {open && tab === "Smarthome" && (
          <div className="pointer-events-none absolute inset-0 -z-10 overflow-hidden opacity-35">
            <div
              className={cn(
                "absolute -left-10 -top-10 size-48 rounded-full blur-3xl transition-colors duration-500",
                acMode === "cool" ? "bg-cyan-500" : acMode === "eco" ? "bg-emerald-500" : "bg-neutral-600",
              )}
            />
            <div
              className={cn(
                "absolute -right-10 bottom-0 size-48 rounded-full blur-3xl transition-colors duration-500",
                lightOn ? "bg-amber-400 opacity-60" : "bg-neutral-800 opacity-20",
              )}
            />
          </div>
        )}

        <AnimatePresence initial={false}>
          {!open ? (
            <motion.div
              key="closed"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0, transition: { duration: 0.1 } }}
              className="absolute inset-0 flex items-center justify-between px-3.5"
            >
              {/* Closed Activity: Mini Spinning Vinyl Record + Waveform (tap toggles play/pause) */}
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  setIsPlaying((p) => !p)
                }}
                title={isPlaying ? "Click to Pause" : "Click to Play"}
                className="group flex items-center gap-2 hover:opacity-85 transition"
              >
                <div className="relative size-[22px] rounded-full shrink-0 flex items-center justify-center overflow-hidden border border-white/20 shadow-md">
                  <div
                    className={cn(
                      "absolute inset-0 rounded-full spin-vinyl",
                      !isPlaying && "spin-vinyl-paused",
                    )}
                    style={{
                      background: "radial-gradient(circle at center, #27272a 0%, #18181b 50%, #09090b 100%)",
                    }}
                  >
                    <div className="absolute inset-1 rounded-full border border-white/10" />
                    <div className="absolute inset-0 rounded-full [background:conic-gradient(from_0deg,transparent,rgba(255,255,255,0.18),transparent,rgba(255,255,255,0.18),transparent)]" />
                  </div>
                  <div className="art size-2.5 rounded-full border border-white/30 relative z-10 flex items-center justify-center">
                    <div className="size-0.5 rounded-full bg-black" />
                  </div>
                  {!isPlaying && <Play className="size-2 fill-white text-white opacity-90 absolute z-20" />}
                </div>
                {peekToast && (
                  <span className="text-[11px] font-semibold text-emerald-400 animate-in fade-in zoom-in-95">
                    {peekToast}
                  </span>
                )}
              </button>

              <button
                onClick={(e) => {
                  e.stopPropagation()
                  setIsPlaying((p) => !p)
                }}
                className="flex items-center gap-1.5"
              >
                <Wave bars={4} isPlaying={isPlaying} className="h-[18px]" />
              </button>
            </motion.div>
          ) : (
            <motion.div
              key="open"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1, transition: { delay: 0.1 } }}
              exit={{ opacity: 0, transition: { duration: 0.1 } }}
              style={{ transformOrigin: "top center" }}
              className="absolute inset-0 min-w-[300px] px-4 pt-2.5 pb-4 text-white sm:min-w-[620px] sm:px-7"
            >
              {/* Header Tab Bar */}
              <div className="flex h-[32px] items-center justify-between">
                <div className="flex gap-1.5">
                  {TABS.map((t) => (
                    <button
                      key={t}
                      onClick={(e) => {
                        e.stopPropagation()
                        setTab(t)
                      }}
                      className={cn(
                        "rounded-lg px-2.5 py-1 text-xs font-semibold transition-all",
                        tab === t ? "bg-white/18 text-white shadow-sm" : "text-neutral-400 hover:text-neutral-200",
                      )}
                    >
                      {t}
                    </button>
                  ))}
                </div>
                <div className="hidden items-center gap-2 text-xs font-medium text-neutral-300 sm:flex">
                  <span className="text-[11px] text-neutral-400">AirPods Pro</span>
                  <span className="font-semibold text-emerald-400">92%</span>
                  <span className="h-[11px] w-[22px] rounded-[3px] border border-white/45 p-px">
                    <span className="block h-full w-[90%] rounded-[1.5px] bg-emerald-400" />
                  </span>
                </div>
              </div>

              {/* Main Tab Content */}
              <div className="flex h-[calc(100%-32px)] items-center gap-4 sm:gap-6">
                {tab === "Home" && (
                  <>
                    {/* Turntable Vinyl Deck with Interactive Tonearm Needle */}
                    <div
                      onClick={(e) => {
                        e.stopPropagation()
                        setIsPlaying((p) => !p)
                      }}
                      title={isPlaying ? "Click record to pause (needle lifts)" : "Click record to play (needle drops)"}
                      className="relative size-[96px] sm:size-[104px] shrink-0 rounded-2xl border border-white/15 bg-gradient-to-b from-white/10 to-black/70 backdrop-blur-md p-1.5 flex items-center justify-center shadow-2xl cursor-pointer group hover:border-white/30 transition select-none overflow-hidden"
                    >
                      {/* Turntable Platter Base Ring */}
                      <div className="absolute inset-2 rounded-full border border-white/10 bg-neutral-900 shadow-inner" />

                      {/* Rotating Vinyl Disc */}
                      <div
                        className={cn(
                          "relative size-[82px] sm:size-[90px] rounded-full shadow-2xl transition-all duration-300",
                          isPlaying ? "spin-vinyl" : "spin-vinyl spin-vinyl-paused",
                        )}
                        style={{
                          background: "radial-gradient(circle at center, #1c1c1f 0%, #0d0d10 55%, #050506 100%)",
                        }}
                      >
                        {/* Concentric Grooves */}
                        <div className="absolute inset-1 rounded-full border border-white/[0.04]" />
                        <div className="absolute inset-2.5 rounded-full border border-white/[0.07]" />
                        <div className="absolute inset-4 rounded-full border border-white/[0.05]" />
                        <div className="absolute inset-5.5 rounded-full border border-white/[0.06]" />
                        {/* Specular Vinyl Reflection Sheen */}
                        <div className="absolute inset-0 rounded-full [background:conic-gradient(from_0deg,transparent,rgba(255,255,255,0.15),transparent,rgba(255,255,255,0.06),transparent,rgba(255,255,255,0.15),transparent)]" />
                        {/* Center Album Art Label */}
                        <div className="art absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 size-7 sm:size-8 rounded-full border border-white/20 shadow-inner flex items-center justify-center">
                          <div className="size-2 rounded-full bg-black border border-white/40" />
                        </div>
                      </div>

                      {/* Mechanical Stylus Tonearm Assembly */}
                      <div
                        className="absolute top-0 right-0 pointer-events-none z-20 transition-transform duration-500 ease-out origin-[82px_14px] sm:origin-[88px_14px]"
                        style={{
                          transform: isPlaying ? "rotate(22deg)" : "rotate(2deg)",
                        }}
                      >
                        {/* Tonearm Gimbal Pivot Base */}
                        <div className="absolute right-2 top-2 size-4 rounded-full bg-gradient-to-br from-neutral-100 via-neutral-300 to-neutral-600 shadow-md border border-white/60 flex items-center justify-center">
                          <div className="size-1.5 rounded-full bg-neutral-900 border border-white/40" />
                        </div>
                        {/* Tonearm Metallic Wand Rod */}
                        <div className="absolute right-3.5 top-3.5 h-[52px] sm:h-[58px] w-[2.5px] bg-gradient-to-b from-white via-neutral-300 to-neutral-500 shadow-sm rotate-[-12deg] origin-top rounded-full" />
                        {/* Cartridge Headshell & Ruby Stylus Needle */}
                        <div className="absolute right-[16px] sm:right-[18px] top-[48px] sm:top-[54px] w-2.5 h-3.5 bg-neutral-900 rounded-[2px] border border-white/50 shadow-md flex flex-col items-center justify-end pb-0.5">
                          {/* Ruby Stylus Tip */}
                          <div className={cn("size-1.5 rounded-full bg-rose-500", isPlaying ? "shadow-[0_0_8px_#f43f5e]" : "opacity-70")} />
                        </div>
                      </div>

                      {/* Lyrics Mode Toggle Button in Corner */}
                      <button
                        onClick={(e) => {
                          e.stopPropagation()
                          setLyricsMode((m) => !m)
                        }}
                        title={lyricsMode ? "Show player" : "Show lyrics"}
                        className={cn(
                          "absolute left-1.5 bottom-1.5 grid size-[22px] place-items-center rounded-full ring-1 ring-white/25 transition z-30 shadow-lg",
                          lyricsMode ? "bg-white text-black" : "bg-black/70 text-white hover:scale-110",
                        )}
                      >
                        <MessageSquareQuote className="size-3" />
                      </button>
                    </div>

                    {lyricsMode ? (
                      <>
                        {/* Interactive Click-to-Seek Karaoke Lyrics */}
                        <div className="h-full flex-1 overflow-hidden text-center [mask-image:linear-gradient(transparent,#000_20%,#000_80%,transparent)]">
                          <motion.div animate={{ y: -line * 30 }} transition={spring} className="pt-[48px]">
                            {LINES.map((l, i) => (
                              <button
                                key={l}
                                onClick={(e) => {
                                  e.stopPropagation()
                                  setElapsed(i * 34)
                                }}
                                className={cn(
                                  "font-display block w-full py-1 text-sm sm:text-base font-bold transition-all duration-300 rounded-lg hover:bg-white/10",
                                  i === line ? "scale-105 text-white drop-shadow-[0_0_12px_rgba(255,255,255,0.5)]" : "text-white/30",
                                )}
                              >
                                {l}
                              </button>
                            ))}
                          </motion.div>
                        </div>

                        {/* Mini Player Transport Column */}
                        <div className="hidden w-[114px] shrink-0 flex-col gap-2.5 sm:flex">
                          <div className="flex items-center justify-center gap-3">
                            <button onClick={() => setElapsed((e) => Math.max(0, e - 15))}>
                              <SkipBack className="size-3.5 fill-white" />
                            </button>
                            <button
                              onClick={() => setIsPlaying((p) => !p)}
                              className="size-7 rounded-full bg-white text-black flex items-center justify-center shadow-lg"
                            >
                              {isPlaying ? <Pause className="size-3.5 fill-black" /> : <Play className="size-3.5 fill-black ml-0.5" />}
                            </button>
                            <button onClick={() => setElapsed((e) => Math.min(DURATION, e + 15))}>
                              <SkipForward className="size-3.5 fill-white" />
                            </button>
                          </div>
                          <div className="h-[3px] overflow-hidden rounded-full bg-white/15">
                            <div className="h-full bg-white transition-[width] duration-1000 ease-linear" style={{ width: `${(elapsed / DURATION) * 100}%` }} />
                          </div>
                          <div className="flex justify-between font-mono text-[9px] text-neutral-400">
                            <span>{fmt(elapsed)}</span>
                            <span>{fmt(DURATION)}</span>
                          </div>
                        </div>
                      </>
                    ) : (
                      <>
                        {/* Player View with Full Transport & Volume */}
                        <div className="min-w-0 flex-1 text-center">
                          <div className="font-display text-sm sm:text-base font-bold tracking-tight">Midnight Drive</div>
                          <AnimatePresence mode="wait">
                            <motion.div
                              key={showLyric ? LINES[line] : "artist"}
                              initial={{ opacity: 0, y: 3 }}
                              animate={{ opacity: 1, y: 0 }}
                              exit={{ opacity: 0, y: -3 }}
                              className={cn("truncate text-[12px]", showLyric ? "text-purple-300 font-medium" : "text-neutral-400")}
                            >
                              {showLyric ? `“${LINES[line]}”` : "The Placeholders"}
                            </motion.div>
                          </AnimatePresence>

                          {/* Progress Bar */}
                          <div className="my-2.5 flex items-center gap-2 font-mono text-[9.5px] text-neutral-400">
                            <span>{fmt(elapsed)}</span>
                            <div
                              onClick={(e) => {
                                const rect = e.currentTarget.getBoundingClientRect()
                                const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
                                setElapsed(Math.floor(ratio * DURATION))
                              }}
                              className="h-1 flex-1 overflow-hidden rounded-full bg-white/20 cursor-pointer"
                            >
                              <div
                                className="h-full rounded-full bg-white transition-[width] duration-500 ease-linear"
                                style={{ width: `${(elapsed / DURATION) * 100}%` }}
                              />
                            </div>
                            <span>{fmt(DURATION)}</span>
                          </div>

                          {/* Main Controls Row: Shuffle, Backward, Play/Pause, Forward, Repeat */}
                          <div className="flex items-center justify-center gap-5 sm:gap-6">
                            <button
                              onClick={() => setIsShuffled((s) => !s)}
                              title="Shuffle"
                              className={cn("transition", isShuffled ? "text-pink-400 font-bold" : "text-neutral-400 hover:text-white")}
                            >
                              <Shuffle className="size-3.5" />
                            </button>
                            <button onClick={() => setElapsed((e) => Math.max(0, e - 15))}>
                              <SkipBack className="size-4 fill-white" />
                            </button>
                            <button
                              onClick={() => setIsPlaying((p) => !p)}
                              className="size-8 rounded-full bg-white text-black flex items-center justify-center shadow-lg shadow-white/25 hover:scale-105 transition"
                            >
                              {isPlaying ? <Pause className="size-4 fill-black" /> : <Play className="size-4 fill-black ml-0.5" />}
                            </button>
                            <button onClick={() => setElapsed((e) => Math.min(DURATION, e + 15))}>
                              <SkipForward className="size-4 fill-white" />
                            </button>
                            <button
                              onClick={() => setIsRepeating((r) => !r)}
                              title="Repeat"
                              className={cn("transition", isRepeating ? "text-pink-400 font-bold" : "text-neutral-400 hover:text-white")}
                            >
                              <Repeat className="size-3.5" />
                            </button>
                          </div>

                          {/* Secondary Utilities: Favorite Heart + System Volume Slider */}
                          <div className="mt-2.5 flex items-center justify-between px-2 text-xs text-neutral-400">
                            <button
                              onClick={() => setIsLoved((l) => !l)}
                              className="flex items-center gap-1 hover:text-pink-400 transition"
                            >
                              <Heart className={cn("size-3.5", isLoved ? "fill-pink-500 text-pink-500" : "text-neutral-400")} />
                            </button>

                            {/* Volume Slider Bar */}
                            <div className="flex items-center gap-2">
                              <button
                                onClick={() => setIsMuted((m) => !m)}
                                className="text-neutral-400 hover:text-white transition"
                              >
                                {isMuted ? <VolumeX className="size-3.5 text-rose-400" /> : <Volume2 className="size-3.5" />}
                              </button>
                              <div
                                onClick={(e) => {
                                  const rect = e.currentTarget.getBoundingClientRect()
                                  const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
                                  setVolume(ratio)
                                  if (isMuted) setIsMuted(false)
                                }}
                                className="h-1.5 w-16 sm:w-20 rounded-full bg-white/20 overflow-hidden cursor-pointer"
                              >
                                <div
                                  className={cn("h-full rounded-full transition-all", isMuted ? "bg-white/30" : "bg-white")}
                                  style={{ width: `${(isMuted ? 0 : volume) * 100}%` }}
                                />
                              </div>
                              <span className="font-mono text-[9px] w-6 text-right">
                                {isMuted ? "0%" : `${Math.round(volume * 100)}%`}
                              </span>
                            </div>
                          </div>
                        </div>

                        {/* Symmetrical 104x104 Deck Card (Dual VU Meter / Spectrum / Calendar) */}
                        <div
                          onClick={(e) => {
                            e.stopPropagation()
                            setDeckMode((m) => (m === "vu" ? "spectrum" : m === "spectrum" ? "calendar" : "vu"))
                          }}
                          title="Click to cycle: Dual VU Meter / Spectrum Analyzer / Calendar"
                          className="hidden sm:flex relative size-[96px] sm:size-[104px] shrink-0 rounded-2xl border border-white/15 bg-gradient-to-b from-white/10 to-black/70 backdrop-blur-md p-2 flex-col justify-between overflow-hidden shadow-2xl cursor-pointer group hover:border-white/30 transition select-none"
                        >
                          {/* Header Badge */}
                          <div className="flex items-center justify-between text-[8.5px] font-mono font-semibold tracking-wider text-neutral-400 uppercase">
                            <span className="flex items-center gap-1 text-white/90">
                              {deckMode === "vu" && <Gauge className="size-2.5 text-amber-400" />}
                              {deckMode === "spectrum" && <SlidersHorizontal className="size-2.5 text-cyan-400" />}
                              {deckMode === "calendar" && <Calendar className="size-2.5 text-rose-400" />}
                              {deckMode === "vu" ? "Dual VU" : deckMode === "spectrum" ? "Spectrum" : "Calendar"}
                            </span>
                            <span className="text-[7.5px] text-white/40 group-hover:text-white/80 transition">TAP</span>
                          </div>

                          {deckMode === "vu" && (
                            <div className="relative flex-1 flex flex-col justify-center items-center py-0.5">
                              {/* Vintage Analog VU Meter Face */}
                              <div className="relative w-full h-[58px] rounded-lg bg-gradient-to-b from-[#fbf5dc] via-[#f5e8b8] to-[#edd99c] text-neutral-900 px-1 py-0.5 flex flex-col justify-between overflow-hidden shadow-inner border border-amber-900/30">
                                {/* Scale Arc Labels */}
                                <div className="flex justify-between text-[6.5px] font-mono font-extrabold text-neutral-800 px-1">
                                  <span>-20</span>
                                  <span>-7</span>
                                  <span>0</span>
                                  <span className="text-rose-600 font-black">+3</span>
                                </div>

                                {/* Needle Chamber with Dual L & R Needles */}
                                <div className="relative h-6 w-full overflow-hidden">
                                  {/* Curved Scale Line */}
                                  <div className="absolute inset-x-1.5 top-0.5 h-6 rounded-[100%] border-t-[1.5px] border-neutral-700/60" />
                                  <div className="absolute right-1.5 top-0.5 w-4 h-6 rounded-tr-[100%] border-t-2 border-rose-600" />

                                  {/* L Channel Needle */}
                                  <div
                                    className={cn(
                                      "absolute bottom-0 left-[28%] h-6 w-[1.5px] bg-neutral-950 origin-bottom shadow-sm",
                                      isPlaying ? "animate-[vu-bounce_1.2s_ease-in-out_infinite]" : "rotate-[-26deg]",
                                    )}
                                  />
                                  {/* R Channel Needle */}
                                  <div
                                    className={cn(
                                      "absolute bottom-0 left-[68%] h-6 w-[1.5px] bg-neutral-950 origin-bottom shadow-sm",
                                      isPlaying ? "animate-[vu-bounce_1.4s_ease-in-out_infinite_0.15s]" : "rotate-[-20deg]",
                                    )}
                                  />
                                </div>

                                {/* Bottom Sub-Labels L/R & Peak indicator */}
                                <div className="flex justify-between items-center text-[7px] font-mono font-bold text-neutral-700 px-1.5">
                                  <span>CH-L</span>
                                  <span className="flex items-center gap-0.5">
                                    <span className={cn("size-1 rounded-full", isPlaying ? "bg-rose-500 shadow-[0_0_4px_#ef4444]" : "bg-rose-900/40")} />
                                    <span className="text-[6px] text-rose-800 font-extrabold">PEAK</span>
                                  </span>
                                  <span>CH-R</span>
                                </div>
                              </div>
                            </div>
                          )}

                          {deckMode === "spectrum" && (
                            <div className="flex-1 flex items-end justify-between gap-[2px] px-0.5 py-1">
                              {[
                                { h: "50%", delay: "0.1s", color: "from-emerald-400 to-teal-500" },
                                { h: "75%", delay: "0.22s", color: "from-teal-400 to-cyan-500" },
                                { h: "95%", delay: "0.05s", color: "from-cyan-400 to-blue-500" },
                                { h: "65%", delay: "0.32s", color: "from-blue-400 to-indigo-500" },
                                { h: "85%", delay: "0.18s", color: "from-indigo-400 to-purple-500" },
                                { h: "55%", delay: "0.4s", color: "from-purple-400 to-pink-500" },
                                { h: "90%", delay: "0.12s", color: "from-pink-400 to-rose-500" },
                                { h: "70%", delay: "0.28s", color: "from-rose-400 to-amber-500" },
                              ].map((bar, i) => (
                                <div key={i} className="flex-1 h-full flex items-end">
                                  <div
                                    className={cn(
                                      "w-full rounded-t-sm bg-gradient-to-t shadow-sm transition-all duration-300",
                                      bar.color,
                                    )}
                                    style={{
                                      height: isPlaying ? bar.h : "15%",
                                      animation: isPlaying ? "pulse-glow 0.8s ease-in-out infinite" : "none",
                                      animationDelay: bar.delay,
                                    }}
                                  />
                                </div>
                              ))}
                            </div>
                          )}

                          {deckMode === "calendar" && (
                            <div className="flex-1 flex flex-col items-center justify-center p-0.5">
                              <div className="w-full rounded-xl bg-gradient-to-b from-neutral-900 to-black border border-white/15 overflow-hidden shadow-lg flex flex-col items-center">
                                <div className="w-full bg-rose-600/90 py-0.5 text-center text-[7.5px] font-bold tracking-wider text-white">
                                  OCTOBER
                                </div>
                                <div className="py-1 flex flex-col items-center">
                                  <span className="font-display text-2xl font-black leading-none text-white tracking-tight">14</span>
                                  <span className="text-[7px] font-semibold text-neutral-400 uppercase tracking-wider">Wednesday</span>
                                </div>
                              </div>
                            </div>
                          )}
                        </div>
                      </>
                    )}
                  </>
                )}

                {/* Smarthome Showcase Tab */}
                {tab === "Smarthome" && (
                  <div className="flex w-full items-center justify-between gap-3 text-xs h-full py-0.5">
                    {/* AC Thermostat Card */}
                    <div className="flex flex-1 items-center gap-3 rounded-xl border border-white/10 bg-white/[0.04] p-2.5 h-[98px]">
                      <div className="flex flex-col items-center justify-center shrink-0">
                        <div className="flex items-center gap-1 text-neutral-400 text-[9px] uppercase font-bold tracking-wider mb-0.5">
                          <Snowflake className={cn("size-3", acMode === "cool" ? "text-cyan-400" : "text-neutral-500")} />
                          AC Climate
                        </div>
                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => adjustTemp(-1)}
                            className="size-6 rounded-md bg-white/10 hover:bg-white/20 active:scale-95 flex items-center justify-center font-bold text-white transition"
                          >
                            <Minus className="size-3" />
                          </button>
                          <div className="flex flex-col items-center px-0.5">
                            <span className="font-display text-2xl font-black text-white leading-none">
                              {acTemp}°C
                            </span>
                            <span className="text-[9px] text-cyan-300 font-medium">Target</span>
                          </div>
                          <button
                            onClick={() => adjustTemp(1)}
                            className="size-6 rounded-md bg-white/10 hover:bg-white/20 active:scale-95 flex items-center justify-center font-bold text-white transition"
                          >
                            <Plus className="size-3" />
                          </button>
                        </div>
                      </div>

                      <div className="h-12 w-px bg-white/10 shrink-0" />

                      {/* Modes & Fan */}
                      <div className="flex flex-col justify-between h-full flex-1 py-0.5">
                        <div className="flex items-center gap-1">
                          {(["cool", "eco", "off"] as const).map((m) => (
                            <button
                              key={m}
                              onClick={() => {
                                setAcMode(m)
                                triggerPeek(`AC mode: ${m.toUpperCase()}`)
                              }}
                              className={cn(
                                "flex-1 py-1 rounded text-[9px] font-bold uppercase transition",
                                acMode === m
                                  ? m === "cool"
                                    ? "bg-cyan-500/30 text-cyan-300 border border-cyan-400/30"
                                    : m === "eco"
                                    ? "bg-emerald-500/30 text-emerald-300 border border-emerald-400/30"
                                    : "bg-white/20 text-white"
                                  : "bg-white/5 text-neutral-400 hover:text-white"
                              )}
                            >
                              {m}
                            </button>
                          ))}
                        </div>
                        <div className="flex items-center justify-between text-[9px] text-neutral-400 px-0.5">
                          <span className="flex items-center gap-1"><Fan className="size-2.5 text-cyan-300" /> Auto High</span>
                          <span className="text-neutral-500">22.8°C Room</span>
                        </div>
                      </div>
                    </div>

                    {/* Lighting & Scenes Card */}
                    <div className="flex flex-1 items-center justify-between gap-3 rounded-xl border border-white/10 bg-white/[0.04] p-2.5 h-[98px]">
                      {/* Smart Bulb Toggle & Slider */}
                      <div className="flex flex-col justify-between h-full flex-1 py-0.5">
                        <div className="flex items-center justify-between">
                          <button
                            onClick={toggleLight}
                            className={cn(
                              "flex items-center gap-1.5 px-2 py-0.5 rounded-lg transition font-semibold text-[10px]",
                              lightOn
                                ? "bg-amber-400/25 text-amber-200 border border-amber-400/40 shadow-[0_0_10px_rgba(251,191,36,0.2)]"
                                : "bg-white/10 text-neutral-400 hover:text-white"
                            )}
                          >
                            <Lightbulb className={cn("size-3", lightOn && "fill-amber-300 text-amber-300")} />
                            <span>Desk Lamp</span>
                          </button>
                          <span className="font-mono text-[10px] text-neutral-300 font-bold">{lightOn ? `${lightBrightness}%` : "OFF"}</span>
                        </div>
                        <input
                          type="range"
                          min="10"
                          max="100"
                          disabled={!lightOn}
                          value={lightBrightness}
                          onChange={(e) => {
                            const val = Number(e.target.value)
                            setLightBrightness(val)
                          }}
                          onMouseUp={() => triggerPeek(`Lamp: ${lightBrightness}%`)}
                          className={cn(
                            "h-1.5 w-full cursor-pointer appearance-none rounded-full bg-white/20 accent-amber-400 transition-opacity",
                            !lightOn && "opacity-30 cursor-not-allowed"
                          )}
                        />
                      </div>

                      <div className="h-12 w-px bg-white/10 shrink-0" />

                      {/* Quick Scenes */}
                      <div className="flex flex-col justify-between h-full shrink-0">
                        <span className="text-[8px] uppercase font-bold text-neutral-500 tracking-wider">Scene</span>
                        <div className="flex flex-col gap-1">
                          <button
                            onClick={() => {
                              setAcTemp(22)
                              setAcMode("cool")
                              setLightOn(true)
                              setLightBrightness(100)
                              triggerPeek("Scene: Focus Work (22°C, 100%)")
                            }}
                            className="flex items-center gap-1 px-1.5 py-0.5 rounded bg-white/10 hover:bg-white/20 text-[9px] text-neutral-200 hover:text-white transition font-medium"
                          >
                            <Sparkles className="size-2 text-cyan-300" /> Focus
                          </button>
                          <button
                            onClick={() => {
                              setAcTemp(25)
                              setAcMode("eco")
                              setLightOn(true)
                              setLightBrightness(30)
                              triggerPeek("Scene: Movie Night (25°C, 30%)")
                            }}
                            className="flex items-center gap-1 px-1.5 py-0.5 rounded bg-white/10 hover:bg-white/20 text-[9px] text-neutral-200 hover:text-white transition font-medium"
                          >
                            <Sparkles className="size-2 text-amber-300" /> Movie
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                )}

                {/* Teleprompter Showcase Tab */}
                {tab === "Prompter" && (
                  <div className="flex w-full items-center justify-between gap-4 text-xs h-full py-0.5">
                    {/* Left: Eye Contact Camera Mirror Viewfinder */}
                    <div className="relative w-[130px] sm:w-[150px] h-[98px] rounded-xl bg-black/80 border border-white/15 overflow-hidden shrink-0 flex flex-col justify-between p-2">
                      {/* Top Camera Status */}
                      <div className="flex items-center justify-between">
                        <span className="flex items-center gap-1 text-[9px] text-emerald-400 font-semibold font-mono">
                          <span className="size-1.5 rounded-full bg-emerald-400 animate-pulse" />
                          CAM ACTIVE
                        </span>
                        <Video className="size-3 text-white/50" />
                      </div>

                      {/* Center Simulated Selfie Eye Target */}
                      <div className="relative flex-1 flex flex-col items-center justify-center">
                        <div className="size-8 rounded-full border border-emerald-400/40 bg-emerald-400/10 flex items-center justify-center">
                          <span className="text-xs">👀</span>
                        </div>
                        {/* Notch Eye-Level Target Line */}
                        <div className="absolute top-1 inset-x-0 flex items-center justify-center gap-1">
                          <div className="h-px flex-1 bg-gradient-to-r from-transparent to-emerald-400/60" />
                          <span className="text-[7px] font-mono text-emerald-300 font-semibold uppercase tracking-wider bg-black/70 px-1 rounded">
                            Eye Contact Line
                          </span>
                          <div className="h-px flex-1 bg-gradient-to-l from-transparent to-emerald-400/60" />
                        </div>
                      </div>

                      <div className="text-[8px] text-center font-mono text-neutral-400">
                        Natural Gaze Mode
                      </div>
                    </div>

                    {/* Right: Live Auto-Scrolling Teleprompter Script */}
                    <div className="flex-1 h-[98px] flex flex-col justify-between bg-white/[0.04] border border-white/10 rounded-xl p-2.5 overflow-hidden">
                      {/* Script Auto-Scroll Box */}
                      <div className="relative flex-1 overflow-hidden [mask-image:linear-gradient(transparent,#000_15%,#000_85%,transparent)]">
                        <div
                          className={cn(
                            "text-neutral-200 font-medium text-[11px] sm:text-xs leading-relaxed select-none transition-transform duration-1000",
                            prompterMirrored && "-scale-x-100",
                          )}
                          style={{
                            animation: prompterPlaying ? `float-reverse ${9 / prompterSpeed}s linear infinite` : "none",
                          }}
                        >
                          {prompterText}
                        </div>
                      </div>

                      {/* Prompter Controls Bar */}
                      <div className="flex items-center justify-between pt-1 border-t border-white/10 text-[10px]">
                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => setPrompterPlaying((p) => !p)}
                            className="flex items-center gap-1 rounded bg-white/15 px-2 py-0.5 hover:bg-white/25 transition font-semibold text-white"
                          >
                            {prompterPlaying ? <Pause className="size-2.5 fill-white" /> : <Play className="size-2.5 fill-white" />}
                            {prompterPlaying ? "Pause" : "Scroll"}
                          </button>
                          <button
                            onClick={() => setPrompterSpeed((s) => (s === 1 ? 1.5 : s === 1.5 ? 2.5 : 1))}
                            className="rounded bg-white/10 px-1.5 py-0.5 text-neutral-300 hover:text-white font-mono text-[9px]"
                          >
                            {prompterSpeed}x
                          </button>
                        </div>
                        <button
                          onClick={() => setPrompterMirrored((m) => !m)}
                          className={cn(
                            "rounded px-1.5 py-0.5 text-[9px] transition font-mono",
                            prompterMirrored ? "bg-purple-500/30 text-purple-300 font-bold" : "text-neutral-400 hover:text-white",
                          )}
                        >
                          {prompterMirrored ? "🪞 Mirrored" : "Mirror"}
                        </button>
                      </div>
                    </div>
                  </div>
                )}

                {/* Developer Tools Showcase Tab */}
                {tab === "Dev" && (
                  <div className="flex w-full items-center justify-between gap-4 text-xs">
                    {/* Active Ports List with 1-Click Kill */}
                    <div className="flex-1 space-y-1.5">
                      <div className="flex items-center justify-between text-[11px] font-semibold text-neutral-400">
                        <span className="flex items-center gap-1.5">
                          <Terminal className="size-3 text-cyan-400" /> Active Localhost Ports
                        </span>
                        <span className="text-[10px] text-neutral-500">Auto-detected</span>
                      </div>
                      <div className="flex flex-wrap gap-1.5">
                        {activePorts.map((p) => (
                          <div
                            key={p.port}
                            className="group flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-2 py-1 transition hover:border-rose-500/40"
                          >
                            <span className="size-1.5 rounded-full bg-emerald-400" />
                            <span className="font-mono font-bold text-white">:{p.port}</span>
                            <span className="text-neutral-400 text-[10px]">{p.name}</span>
                            <button
                              onClick={() => killPort(p.port)}
                              title={`Kill PID ${p.pid}`}
                              className="text-neutral-500 hover:text-rose-400 transition ml-0.5"
                            >
                              <XCircle className="size-3" />
                            </button>
                          </div>
                        ))}
                        {activePorts.length === 0 && (
                          <button
                            onClick={() =>
                              setActivePorts([
                                { port: "3000", name: "Next.js", pid: "8421" },
                                { port: "5173", name: "Vite App", pid: "9102" },
                              ])
                            }
                            className="rounded-lg border border-dashed border-white/20 px-2 py-1 text-[11px] text-neutral-400 hover:text-white"
                          >
                            + Reset Ports
                          </button>
                        )}
                      </div>
                    </div>

                    {/* Color Picker & HUD Quick Testers */}
                    <div className="flex flex-col gap-2 rounded-xl border border-white/10 bg-white/5 p-2.5">
                      <div className="flex items-center justify-between gap-3">
                        <span className="text-[11px] font-medium text-neutral-300 flex items-center gap-1.5">
                          <Pipette className="size-3 text-indigo-400" /> Eyedropper
                        </span>
                        <button
                          onClick={() => {
                            setCopiedColor(true)
                            window.setTimeout(() => setCopiedColor(false), 1500)
                          }}
                          className="flex items-center gap-1 rounded bg-indigo-500/20 px-1.5 py-0.5 font-mono text-[10px] text-indigo-300 hover:bg-indigo-500/30"
                        >
                          <span className="size-2 rounded-full bg-indigo-400" />
                          #6366F1
                          {copiedColor ? <Check className="size-2.5 text-emerald-400" /> : <Copy className="size-2.5" />}
                        </button>
                      </div>

                      <div className="flex items-center gap-1.5 text-[10px]">
                        <span className="text-neutral-400">Test HUD:</span>
                        <button
                          onClick={() => triggerPeek("Volume 75%")}
                          className="rounded bg-white/10 px-1.5 py-0.5 hover:bg-white/20 transition text-neutral-300"
                        >
                          Volume
                        </button>
                        <button
                          onClick={() => triggerPeek("AirPods 94%")}
                          className="rounded bg-white/10 px-1.5 py-0.5 hover:bg-white/20 transition text-neutral-300"
                        >
                          AirPods
                        </button>
                        <button
                          onClick={() => triggerPeek("MagSafe Connected")}
                          className="rounded bg-white/10 px-1.5 py-0.5 hover:bg-white/20 transition text-neutral-300"
                        >
                          Power
                        </button>
                      </div>
                    </div>
                  </div>
                )}

                {/* Pomodoro Focus Timer Tab */}
                {tab === "Timer" && (
                  <div className="flex w-full items-center justify-center gap-8">
                    <div className="relative size-[110px] shrink-0">
                      <svg viewBox="0 0 100 100" className="size-full -rotate-90">
                        <circle cx="50" cy="50" r="44" className="fill-none stroke-white/10" strokeWidth="6" />
                        <circle cx="50" cy="50" r="44" className="timer-ring fill-none stroke-white" strokeWidth="6" strokeLinecap="round" />
                      </svg>
                      <span className="font-display absolute inset-0 grid place-items-center text-2xl font-bold">24:59</span>
                    </div>
                    <div className="flex flex-col gap-1.5 text-sm text-neutral-400">
                      <strong className="font-display text-xl text-white">Focus</strong>
                      The countdown stays visible beside the notch.
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  )
}
