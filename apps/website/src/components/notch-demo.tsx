import { AnimatePresence, motion } from "motion/react"
import {
  Check,
  Copy,
  Heart,
  MessageSquareQuote,
  Pause,
  Pipette,
  Play,
  Repeat,
  Shuffle,
  SkipBack,
  SkipForward,
  Terminal,
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
const TABS = ["Home", "Dev", "Timer"] as const
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
    document.addEventListener("click", outside)
    return () => {
      window.clearTimeout(peek)
      document.removeEventListener("click", outside)
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
          height: open ? 228 : 34,
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

        <AnimatePresence initial={false}>
          {!open ? (
            <motion.div
              key="closed"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0, transition: { duration: 0.1 } }}
              className="absolute inset-0 flex items-center justify-between px-3.5"
            >
              {/* Closed Activity: Mini artwork + Waveform (tap toggles play/pause) */}
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  setIsPlaying((p) => !p)
                }}
                title={isPlaying ? "Click to Pause" : "Click to Play"}
                className="group flex items-center gap-2 hover:opacity-85 transition"
              >
                <div className="art size-[22px] rounded-md relative flex items-center justify-center">
                  {!isPlaying && <Play className="size-2.5 fill-white text-white opacity-80" />}
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
                    {/* Vinyl Record Deck & Sleeve */}
                    <div className="relative h-[96px] w-[116px] sm:h-[110px] sm:w-[130px] shrink-0">
                      {/* Vinyl Record Disc (Slides out & spins) */}
                      <div
                        className={cn(
                          "absolute top-1/2 -translate-y-1/2 size-[88px] sm:size-[100px] rounded-full shadow-2xl transition-all duration-500",
                          isPlaying ? "left-6 sm:left-7 spin-vinyl" : "left-2 spin-vinyl spin-vinyl-paused",
                        )}
                        style={{
                          background: "radial-gradient(circle at center, #1b1b1e 0%, #0d0d10 55%, #050506 100%)",
                        }}
                      >
                        {/* Concentric Grooves */}
                        <div className="absolute inset-1 rounded-full border border-white/[0.04]" />
                        <div className="absolute inset-2.5 rounded-full border border-white/[0.07]" />
                        <div className="absolute inset-4 rounded-full border border-white/[0.05]" />
                        <div className="absolute inset-6 rounded-full border border-white/[0.06]" />
                        {/* Specular Vinyl Reflection Sheen */}
                        <div className="absolute inset-0 rounded-full [background:conic-gradient(from_0deg,transparent,rgba(255,255,255,0.14),transparent,rgba(255,255,255,0.05),transparent,rgba(255,255,255,0.14),transparent)]" />
                        {/* Center Album Art Label */}
                        <div className="art absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 size-7 sm:size-8 rounded-full border border-white/20 shadow-inner flex items-center justify-center">
                          <div className="size-2 rounded-full bg-black border border-white/40" />
                        </div>
                      </div>

                      {/* Album Jacket Sleeve */}
                      <div className="art relative size-[92px] sm:size-[104px] shrink-0 rounded-2xl shadow-2xl overflow-hidden border border-white/15">
                        <div className="absolute left-0 inset-y-0 w-0.5 bg-gradient-to-r from-white/30 to-transparent" />
                        <div className="absolute right-0 inset-y-0 w-2.5 bg-gradient-to-l from-black/60 to-transparent" />
                        <button
                          onClick={(e) => {
                            e.stopPropagation()
                            setLyricsMode((m) => !m)
                          }}
                          title={lyricsMode ? "Show player" : "Show lyrics"}
                          className={cn(
                            "absolute right-1.5 bottom-1.5 grid size-[24px] place-items-center rounded-full ring-1 ring-white/25 transition z-10",
                            lyricsMode ? "bg-white text-black" : "bg-black/60 text-white hover:scale-110",
                          )}
                        >
                          <MessageSquareQuote className="size-3" />
                        </button>
                      </div>
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

                        <Wave bars={5} isPlaying={isPlaying} className="hidden h-[30px] w-[50px] justify-end sm:flex [&>span]:w-1" />
                      </>
                    )}
                  </>
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
