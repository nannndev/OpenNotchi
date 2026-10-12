import { AnimatePresence, motion } from "motion/react"
import { MessageSquareQuote, Pause, SkipBack, SkipForward } from "lucide-react"
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
const TABS = ["Home", "Timer"] as const
type Tab = (typeof TABS)[number]

const spring = { type: "spring", stiffness: 260, damping: 28 } as const

function fmt(s: number) {
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
}

function Wave({ bars, className }: { bars: number; className?: string }) {
  return (
    <div className={cn("flex items-center gap-[3px]", className)}>
      {Array.from({ length: bars }, (_, i) => (
        <span key={i} className="wave-bar w-[3px] rounded-full bg-white" style={{ animationDelay: `${-i * 0.27}s` }} />
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
    const id = window.setInterval(() => setElapsed((e) => (e >= DURATION ? 0 : e + 1)), 1000)
    // Peek once so visitors notice it's interactive.
    const peek = window.setTimeout(() => {
      show()
      hide(3200)
    }, 900)
    const outside = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && hide(0)
    document.addEventListener("click", outside)
    return () => {
      window.clearInterval(id)
      window.clearTimeout(peek)
      document.removeEventListener("click", outside)
    }
  }, [])

  const line = Math.floor(elapsed / 3) % LINES.length
  const showLyric = Math.floor(elapsed / 9) % 2 === 1

  return (
    <div className="pointer-events-none fixed inset-x-0 top-0 z-50 flex justify-center" aria-hidden>
      <motion.div
        ref={ref}
        onMouseEnter={show}
        onMouseLeave={() => hide()}
        onClick={show}
        initial={false}
        animate={{
          width: open ? "min(640px, calc(100vw - 24px))" : 300,
          height: open ? 214 : 34,
          borderBottomLeftRadius: open ? 34 : 14,
          borderBottomRightRadius: open ? 34 : 14,
        }}
        transition={spring}
        className={cn(
          "pointer-events-auto relative overflow-hidden bg-black ring-1 ring-white/5 transition-shadow duration-500",
          open && "shadow-[0_24px_60px_rgba(0,0,0,0.7)] ring-white/10",
        )}
      >
        <AnimatePresence initial={false}>
          {!open ? (
            <motion.div
              key="closed"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0, transition: { duration: 0.1 } }}
              className="absolute inset-0 flex items-center justify-between px-3.5"
            >
              <div className="art size-[22px] rounded-md" />
              <Wave bars={4} className="h-[18px]" />
            </motion.div>
          ) : (
            <motion.div
              key="open"
              initial={{ opacity: 0, scale: 0.96 }}
              animate={{ opacity: 1, scale: 1, transition: { delay: 0.1 } }}
              exit={{ opacity: 0, transition: { duration: 0.1 } }}
              style={{ transformOrigin: "top center" }}
              className="absolute inset-0 min-w-[300px] px-4 pt-2 pb-5 text-white sm:min-w-[560px] sm:px-7"
            >
              <div className="flex h-[30px] items-center justify-between">
                <div className="flex gap-1">
                  {TABS.map((t) => (
                    <button
                      key={t}
                      onClick={(e) => {
                        e.stopPropagation()
                        setTab(t)
                      }}
                      className={cn(
                        "rounded-lg px-2.5 py-1 text-xs font-semibold text-neutral-400 transition-colors",
                        tab === t && "bg-white/15 text-white",
                      )}
                    >
                      {t}
                    </button>
                  ))}
                </div>
                <div className="hidden items-center gap-1.5 text-xs font-medium sm:flex">
                  87%
                  <span className="h-[11px] w-[22px] rounded-[3px] border border-white/45 p-px">
                    <span className="block h-full w-[85%] rounded-[1.5px] bg-white" />
                  </span>
                </div>
              </div>

              <div className="flex h-[calc(100%-30px)] items-center gap-5">
                {tab === "Home" && (
                  <>
                    <div className="art relative size-[84px] shrink-0 rounded-2xl shadow-2xl sm:size-[118px]">
                      <button
                        onClick={(e) => {
                          e.stopPropagation()
                          setLyricsMode((m) => !m)
                        }}
                        title={lyricsMode ? "Show player" : "Show lyrics"}
                        className={cn(
                          "absolute right-1.5 bottom-1.5 grid size-[26px] place-items-center rounded-full ring-1 ring-white/25 transition",
                          lyricsMode ? "bg-white text-black" : "bg-black/55 text-white hover:scale-110",
                        )}
                      >
                        <MessageSquareQuote className="size-3" />
                      </button>
                    </div>

                    {lyricsMode ? (
                      <>
                        <div className="h-full flex-1 overflow-hidden text-center [mask-image:linear-gradient(transparent,#000_25%,#000_75%,transparent)]">
                          <motion.div animate={{ y: -line * 32 }} transition={spring} className="pt-[54px]">
                            {LINES.map((l, i) => (
                              <p
                                key={l}
                                className={cn(
                                  "font-display py-1.5 text-base font-bold transition-all duration-500",
                                  i === line ? "scale-105 text-white" : "text-white/25",
                                )}
                              >
                                {l}
                              </p>
                            ))}
                          </motion.div>
                        </div>
                        <div className="hidden w-[110px] shrink-0 flex-col gap-3 sm:flex">
                          <div className="flex items-center justify-center gap-4">
                            <SkipBack className="size-3.5 fill-white" />
                            <Pause className="size-5 fill-white" />
                            <SkipForward className="size-3.5 fill-white" />
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
                        <div className="min-w-0 flex-1 text-center">
                          <div className="font-display text-base font-bold">Midnight Drive</div>
                          <AnimatePresence mode="wait">
                            <motion.div
                              key={showLyric ? LINES[line] : "artist"}
                              initial={{ opacity: 0, y: 4 }}
                              animate={{ opacity: 1, y: 0 }}
                              exit={{ opacity: 0, y: -4 }}
                              className={cn("mt-0.5 truncate text-[13px]", showLyric ? "text-white" : "text-neutral-400")}
                            >
                              {showLyric ? LINES[line] : "The Placeholders"}
                            </motion.div>
                          </AnimatePresence>
                          <div className="my-3.5 flex items-center gap-2 font-mono text-[10px] text-neutral-400">
                            <span>{fmt(elapsed)}</span>
                            <div className="h-1 flex-1 overflow-hidden rounded-full bg-white/20">
                              <div className="h-full rounded-full bg-white transition-[width] duration-1000 ease-linear" style={{ width: `${(elapsed / DURATION) * 100}%` }} />
                            </div>
                            <span>{fmt(DURATION)}</span>
                          </div>
                          <div className="flex items-center justify-center gap-8">
                            <SkipBack className="size-4 fill-white" />
                            <Pause className="size-6 fill-white" />
                            <SkipForward className="size-4 fill-white" />
                          </div>
                        </div>
                        <Wave bars={5} className="hidden h-[30px] w-[60px] justify-end sm:flex [&>span]:w-1" />
                      </>
                    )}
                  </>
                )}

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
                      The countdown stays beside the notch.
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
