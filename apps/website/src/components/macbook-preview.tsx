import { type ReactNode, useEffect, useRef, useState } from "react"
import { AppleIcon, WindowsIcon } from "@/components/icons"
import { animate, AnimatePresence, motion, useInView, useMotionValue, useReducedMotion, useScroll, useSpring, useTransform } from "motion/react"

/** Screenshots of the real app in demo mode. `width` is the notch's width in points on a 1512-point-wide screen. */
const STATES = [
  { id: "ai", label: "AI & 9router", src: "/preview/ai.webp", width: 736, caption: "Real-time AI multi-account quota tracking for OpenAI, Anthropic & 9router with countdown resets and live spend." },
  { id: "banner", label: "Notification Banner", src: "/preview/banner.webp", width: 390, caption: "Interactive drop-down notification banners when Claude Code or coding agents finish tasks or need your input." },
  { id: "notchi", label: "Notchi Mascot", src: "/preview/notchi.webp", width: 386, caption: "An animated 5-bar retro companion living in the closed notch, reacting to music and your presence." },
  { id: "windows", label: "Windows Dynamic Pill", src: "/preview/windows.webp", width: 600, caption: "OpenNotchi Windows dynamic pill with acrylic glass composition, Spotify/browser SMTC audio, and fluid animations." },
  { id: "music", label: "Music", src: "/preview/home.webp", width: 736, caption: "Spotify, Apple Music and YouTube, on a turntable you can scratch." },
  { id: "lyrics", label: "Lyrics", src: "/preview/lyrics.webp", width: 736, caption: "Synced lyrics that light up as they're sung." },
  { id: "themes", label: "Themes", src: "/preview/theme-frosted.webp", width: 736, caption: "Liquid Glass, Frosted and themes that follow your music." },
  { id: "prompter", label: "Teleprompter", src: "/preview/prompter.webp", width: 736, caption: "Your notes right under the camera, so you keep eye contact." },
  { id: "markets", label: "Markets", src: "/preview/markets.webp", width: 736, caption: "IDX and global stocks, crypto and currencies at a glance." },
  { id: "meetings", label: "Meetings", src: "/preview/meeting.webp", width: 438, caption: "A heads-up before each meeting, with one-click Join." },
  { id: "prayer", label: "Prayer times", src: "/preview/prayer.webp", width: 438, caption: "The next prayer in the header, and a reminder when it's time." },
  { id: "photobox", label: "Photobox", src: "/preview/picker.webp", width: 736, caption: "Pose for a strip in 18 frames, then decorate it." },
] as const

const SCREEN_POINTS = 1512
const CYCLE_MS = 4200

/** `wallpaper` is drawn on the desktop under the notch (the hero copy, on wide screens). */
export function MacBookPreview({ wallpaper }: { wallpaper?: ReactNode }) {
  const reduce = useReducedMotion()
  const track = useRef<HTMLDivElement>(null)
  const stage = useRef<HTMLDivElement>(null)
  const inView = useInView(stage, { margin: "-15% 0px" })
  // The lid opens once, the first time the laptop comes into view.
  const seen = useInView(stage, { margin: "-15% 0px", once: true })
  const opened = !!reduce || seen
  const [index, setIndex] = useState(0)
  const [osMode, setOsMode] = useState<"macos" | "windows">("macos")
  const pausedUntil = useRef(0)

  // Pointer tilt, smoothed with springs.
  const pointerX = useMotionValue(0)
  const pointerY = useMotionValue(0)
  const tiltY = useSpring(useTransform(pointerX, [-1, 1], [-7, 7]), { stiffness: 80, damping: 18 })
  const tiltX = useSpring(useTransform(pointerY, [-1, 1], [4, -4]), { stiffness: 80, damping: 18 })

  // The laptop stays pinned while you scroll through its track: the lid closes slowly and the camera
  // rises a little, then the page carries on once it's shut.
  const { scrollYProgress } = useScroll({ target: track, offset: ["start start", "end end"] })
  const scrollTilt = useTransform(scrollYProgress, [0, 0.9], reduce ? [-12, -12] : [-12, -26])
  const rotateX = useTransform([scrollTilt, tiltX], ([a, b]: number[]) => a + b)
  const scrollLid = useTransform(scrollYProgress, [0.05, 0.88], reduce ? [8, 8] : [8, -86])
  const pickerOpacity = useTransform(scrollYProgress, [0.04, 0.28], reduce ? [1, 1] : [1, 0])

  // The lid opens once on arrival, then follows the scroll: closed (-86°) + how far it's open × the scroll angle.
  const openAmount = useMotionValue(reduce ? 1 : 0)
  const lidAngle = useTransform([openAmount, scrollLid], ([o, l]: number[]) => -86 + (l + 86) * o)
  useEffect(() => {
    if (!opened || reduce) return
    const controls = animate(openAmount, 1, { type: "spring", stiffness: 38, damping: 13, mass: 1.2, delay: 0.15 })
    return () => controls.stop()
  }, [opened, reduce, openAmount])

  // Cycle through the notch states while visible, unless someone just picked one.
  useEffect(() => {
    if (!inView || !opened || reduce) return
    const timer = setInterval(() => {
      if (Date.now() < pausedUntil.current) return
      setIndex((i) => (i + 1) % STATES.length)
    }, CYCLE_MS)
    return () => clearInterval(timer)
  }, [inView, opened, reduce])

  const select = (i: number) => {
    setIndex(i)
    if (STATES[i].id === "windows") {
      setOsMode("windows")
    }
    pausedUntil.current = Date.now() + 15000
  }

  const toggleOs = (mode: "macos" | "windows") => {
    setOsMode(mode)
    if (mode === "windows" && STATES[index].id !== "windows") {
      const winIdx = STATES.findIndex((s) => s.id === "windows")
      if (winIdx !== -1) setIndex(winIdx)
    } else if (mode === "macos" && STATES[index].id === "windows") {
      setIndex(0)
    }
    pausedUntil.current = Date.now() + 15000
  }

  const state = STATES[index]

  return (
    <div ref={track} className={reduce ? "" : "relative h-[185svh]"}>
      <div
        className={`mx-auto flex w-full flex-col items-center [--lw:min(92vw,1040px,calc((100svh-320px)*1.08))] ${
          reduce ? "" : "sticky top-0 h-svh justify-center pt-12"
        }`}
      >
        <div
          ref={stage}
          className="relative mx-auto w-[var(--lw)] [perspective:3600px] [perspective-origin:50%_30%]"
          onPointerMove={(e) => {
            if (reduce) return
            const r = e.currentTarget.getBoundingClientRect()
            pointerX.set(((e.clientX - r.left) / r.width) * 2 - 1)
            pointerY.set(((e.clientY - r.top) / r.height) * 2 - 1)
          }}
          onPointerLeave={() => {
            pointerX.set(0)
            pointerY.set(0)
          }}
        >
          {/* Floor shadow */}
          <div className="pointer-events-none absolute inset-x-[6%] bottom-[-4%] h-[14%] rounded-[50%] bg-black/70 blur-2xl" />

          {/* The 3D wrapper itself */}
          <motion.div style={{ rotateX, rotateY: tiltY }} className="pointer-events-none relative [transform-style:preserve-3d]">
            {/* Lid */}
            <motion.div style={{ rotateX: lidAngle }} className="relative aspect-[1.54] w-full origin-bottom [transform-style:preserve-3d]">
              {/* Back of the lid */}
              <div className="absolute inset-0 grid place-items-center rounded-[3.2%/4.9%] bg-[linear-gradient(160deg,#e4e6ea,#a9adb4)] [backface-visibility:hidden] [transform:rotateY(180deg)_translateZ(1px)]">
                {osMode === "windows" ? (
                  <WindowsIcon className="w-[11%] text-[#8d9198] drop-shadow-[0_1px_0_rgba(255,255,255,0.6)]" />
                ) : (
                  <AppleIcon className="w-[12.5%] text-[#8d9198] [&_path]:fill-[url(#lid-logo)] drop-shadow-[0_1px_0_rgba(255,255,255,0.6)]" />
                )}
                <svg width="0" height="0" className="absolute" aria-hidden>
                  <defs>
                    <linearGradient id="lid-logo" x1="0" y1="0" x2="1" y2="1">
                      <stop offset="0" stopColor="#f6f7f9" />
                      <stop offset="0.45" stopColor="#9a9ea6" />
                      <stop offset="1" stopColor="#d5d8dc" />
                    </linearGradient>
                  </defs>
                </svg>
              </div>

              {/* Front: black bezel around display */}
              <div className="pointer-events-auto absolute inset-0 rounded-[3.2%/4.9%] bg-[#0a0a0b] p-[1.6%] shadow-[inset_0_0_0_1.5px_#3a3b3f] [backface-visibility:hidden]">
                <Screen state={state} osMode={osMode}>{wallpaper}</Screen>
              </div>
            </motion.div>

            {/* Base, folded flat toward the viewer */}
            <div className="absolute top-full left-[-1.5%] w-[103%] origin-top [transform:rotateX(90deg)] [transform-style:preserve-3d]">
              <div className="relative aspect-[1.48] rounded-b-[4%] bg-[linear-gradient(180deg,#d9dce0,#b9bdc3)] shadow-[inset_0_2px_0_#f2f3f5]">
                {/* Speaker grilles */}
                <div className="absolute top-[7%] left-[3.2%] h-[44%] w-[5.2%] bg-[radial-gradient(circle,#6f737a_0.9px,transparent_1.2px)] bg-[length:5px_5px] opacity-70" />
                <div className="absolute top-[7%] right-[3.2%] h-[44%] w-[5.2%] bg-[radial-gradient(circle,#6f737a_0.9px,transparent_1.2px)] bg-[length:5px_5px] opacity-70" />
                <Keyboard />
                {/* Trackpad */}
                <div className="absolute bottom-[8%] left-1/2 h-[34%] w-[42%] -translate-x-1/2 rounded-[3%] bg-[linear-gradient(180deg,#cfd2d6,#c3c6cb)] shadow-[inset_0_0_0_1px_#aeb2b8]" />
              </div>
              {/* Front edge scoop */}
              <div className="absolute top-full left-0 h-[10px] w-full origin-top rounded-b-[10px] bg-[linear-gradient(180deg,#9ea2a9,#7d8188)] [transform:rotateX(-90deg)]">
                <div className="mx-auto h-[5px] w-[14%] rounded-b-full bg-[#6d7178]" />
              </div>
            </div>
          </motion.div>
        </div>

        {/* State picker & OS Switcher, below the base */}
        <motion.div style={{ opacity: pickerOpacity }} className="mt-[calc(var(--lw)*0.3)] w-full select-none">
          {/* OS Switcher */}
          <div className="mb-3.5 flex items-center justify-center gap-2">
            <button
              onClick={() => toggleOs("macos")}
              className={`inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-semibold transition ${
                osMode === "macos"
                  ? "bg-white text-black shadow-md shadow-white/10"
                  : "border border-white/10 bg-white/5 text-neutral-400 hover:text-white"
              }`}
            >
              <AppleIcon className="size-3.5" />
              macOS (Hardware Notch)
            </button>
            <button
              onClick={() => toggleOs("windows")}
              className={`inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-semibold transition ${
                osMode === "windows"
                  ? "bg-sky-400 text-black shadow-md shadow-sky-500/20"
                  : "border border-white/10 bg-white/5 text-neutral-400 hover:text-white"
              }`}
            >
              <WindowsIcon className="size-3" />
              Windows (Dynamic Pill)
            </button>
          </div>

          <div role="tablist" aria-label="What the notch can show" className="flex gap-1.5 overflow-x-auto px-4 pb-1 [scrollbar-width:none] sm:flex-wrap sm:justify-center">
            {STATES.map((s, i) => (
              <button
                key={s.id}
                role="tab"
                aria-selected={i === index}
                onClick={() => select(i)}
                className={`shrink-0 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors duration-300 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white ${
                  i === index
                    ? s.id === "windows"
                      ? "bg-sky-400 text-black"
                      : s.id === "ai"
                        ? "bg-violet-400 text-black"
                        : s.id === "notchi"
                          ? "bg-rose-400 text-black"
                          : "bg-white text-black"
                    : "text-neutral-400 hover:bg-white/10 hover:text-white"
                }`}
              >
                {s.label}
              </button>
            ))}
          </div>
          <p aria-live="polite" className="mx-auto mt-3.5 max-w-xl px-4 text-center text-[14.5px] leading-relaxed text-neutral-400">
            {state.caption}
          </p>
        </motion.div>
      </div>
    </div>
  )
}

/** Rows of a MacBook keyboard: [label, width in key units]. */
const KEY_ROWS: [string, number][][] = [
  [["esc", 1.5], ...["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"].map((k): [string, number] => [k, 1]), ["", 1]],
  [...["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="].map((k): [string, number] => [k, 1]), ["delete", 1.5]],
  [["tab", 1.5], ...["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\"].map((k): [string, number] => [k, 1])],
  [["caps lock", 1.8], ...["A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'"].map((k): [string, number] => [k, 1]), ["return", 1.7]],
  [["shift", 2.3], ...["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"].map((k): [string, number] => [k, 1]), ["shift", 2.2]],
  [["fn", 1], ["control", 1], ["option", 1], ["command", 1.25], ["", 5], ["command", 1.25], ["option", 1]],
]

function Key({ label, units, short }: { label: string; units: number; short?: boolean }) {
  const isWord = label.length > 2
  return (
    <div
      style={{ flexGrow: units, flexBasis: 0 }}
      className={`relative min-w-0 rounded-[0.35cqw] bg-[linear-gradient(180deg,#2c2d31,#232427)] shadow-[inset_0_1px_0_rgba(255,255,255,0.07),0_1px_0_#0c0c0e] ${
        short ? "h-[62%] self-end" : "h-full"
      }`}
    >
      {label && (
        <span
          className={`absolute leading-none font-medium text-white/75 ${
            isWord ? "bottom-[14%] text-[0.72cqw]" : "inset-0 grid place-items-center text-[1.15cqw]"
          } ${isWord && label !== "return" && label !== "delete" ? "left-[10%]" : isWord ? "right-[10%]" : ""}`}
        >
          {label}
        </span>
      )}
    </div>
  )
}

function Keyboard() {
  return (
    <div className="absolute top-[7%] left-1/2 flex h-[44%] w-[84%] -translate-x-1/2 flex-col gap-[1.6%] rounded-[1.2%] bg-[#141517] p-[0.9%] [container-type:inline-size]">
      {KEY_ROWS.map((row, r) => (
        <div key={r} className={`flex gap-[0.55%] ${r === 0 ? "h-[11%]" : "flex-1"}`}>
          {row.map(([label, units], i) => (
            <Key key={i} label={label} units={units} />
          ))}
          {r === KEY_ROWS.length - 1 && (
            <div className="flex gap-[0.55%]" style={{ flexGrow: 3, flexBasis: 0 }}>
              <Key label="◀" units={1} short />
              <div className="flex flex-col gap-[6%]" style={{ flexGrow: 1, flexBasis: 0 }}>
                <Key label="▲" units={1} />
                <Key label="▼" units={1} />
              </div>
              <Key label="▶" units={1} short />
            </div>
          )}
        </div>
      ))}
    </div>
  )
}

function Screen({ state, osMode, children }: { state: (typeof STATES)[number]; osMode: "macos" | "windows"; children?: ReactNode }) {
  const isWindows = osMode === "windows"

  return (
    <div className="relative h-full w-full overflow-hidden rounded-[1.8%/2.8%] bg-[#0d0e10] [container-type:inline-size]">
      {isWindows ? <WallpaperWindows /> : <Wallpaper />}
      {children && <div className="absolute inset-x-0 top-[34%] bottom-[5%] hidden sm:block">{children}</div>}

      {/* OS Top Navigation Bar */}
      {isWindows ? (
        /* Windows 11 Top Edge */
        <div className="absolute inset-x-0 top-0 flex h-[2.8cqw] items-center justify-between px-[1.6cqw] text-[1.05cqw] font-normal text-white/60">
          <div className="flex items-center gap-[1.2cqw]">
            <span className="text-[0.95cqw] font-semibold text-sky-400">Desktop 1</span>
          </div>
          <div className="flex items-center gap-[1.2cqw] tabular-nums text-white/70">
            <span>60 Hz · HDR</span>
          </div>
        </div>
      ) : (
        /* macOS Finder Menu bar */
        <div className="absolute inset-x-0 top-0 flex h-[3.4cqw] items-center justify-between bg-black/35 px-[1.6cqw] text-[1.15cqw] font-medium text-white/85 backdrop-blur-sm">
          <div className="flex items-center gap-[1.5cqw]">
            <span className="font-semibold">Finder</span>
            <span>File</span>
            <span>Edit</span>
            <span>View</span>
            <span>Window</span>
          </div>
          <div className="flex items-center gap-[1.3cqw] tabular-nums">
            <span>Mon 13 Oct</span>
            <span>9:41</span>
          </div>
        </div>
      )}

      {/* The Notch / Dynamic Pill Housing */}
      {isWindows ? (
        <div className="absolute top-[0.6cqw] left-1/2 h-[3.2cqw] w-[13.5cqw] -translate-x-1/2 rounded-full border border-sky-400/40 bg-black/90 shadow-[0_4px_16px_rgba(14,165,233,0.25)] backdrop-blur-md" />
      ) : (
        <div className="absolute top-0 left-1/2 h-[3.4cqw] w-[12.5cqw] -translate-x-1/2 rounded-b-[1.1cqw] bg-black" />
      )}

      {/* Active Notch State Image */}
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.img
          key={`${state.id}-${osMode}`}
          src={state.src}
          alt={`The notch showing ${state.label.toLowerCase()}`}
          draggable={false}
          initial={{ opacity: 0, scaleX: 0.4, scaleY: 0.2 }}
          animate={{ opacity: 1, scaleX: 1, scaleY: 1 }}
          exit={{ opacity: 0, scaleX: 0.55, scaleY: 0.35, transition: { duration: 0.22 } }}
          transition={{ type: "spring", stiffness: 260, damping: 24 }}
          style={{ width: `${(state.width / SCREEN_POINTS) * 100}%`, x: "-50%" }}
          className={`absolute left-1/2 origin-top select-none ${isWindows ? "top-[0.8cqw]" : "top-0"}`}
        />
      </AnimatePresence>

      {/* Windows 11 Taskbar at Bottom */}
      {isWindows && (
        <div className="absolute inset-x-0 bottom-0 flex h-[3.6cqw] items-center justify-between border-t border-white/10 bg-black/60 px-[2cqw] backdrop-blur-xl">
          {/* Centered Windows Icons */}
          <div className="mx-auto flex items-center gap-[1.2cqw]">
            <WindowsIcon className="size-[1.4cqw] text-sky-400" />
            <div className="h-[1.8cqw] w-[7cqw] rounded-full border border-white/15 bg-white/10 px-[0.8cqw] text-[0.85cqw] text-neutral-400 flex items-center">
              Search
            </div>
            <div className="size-[1.3cqw] rounded-[0.3cqw] bg-neutral-800 border border-white/10" />
            <div className="size-[1.3cqw] rounded-[0.3cqw] bg-sky-500/20 border border-sky-400/40" />
          </div>
          {/* Right System Tray */}
          <div className="flex items-center gap-[1cqw] text-[0.85cqw] text-white/80 tabular-nums">
            <span className="font-semibold text-sky-400">OpenNotchi</span>
            <span>ENG</span>
            <span>18:30</span>
          </div>
        </div>
      )}
    </div>
  )
}

/** Soft macOS waves */
function Wallpaper() {
  return (
    <svg className="absolute inset-0 h-full w-full" viewBox="0 0 1512 982" preserveAspectRatio="xMidYMid slice" aria-hidden>
      <defs>
        <radialGradient id="wp-glow" cx="50%" cy="0%" r="75%">
          <stop offset="0" stopColor="#3a3b40" />
          <stop offset="1" stopColor="#0d0e10" />
        </radialGradient>
      </defs>
      <rect width="1512" height="982" fill="url(#wp-glow)" />
      {Array.from({ length: 9 }, (_, i) => (
        <path
          key={i}
          d={`M-40 ${560 + i * 46} C 300 ${480 + i * 40}, 620 ${700 + i * 30}, 960 ${600 + i * 38} S 1420 ${520 + i * 44}, 1560 ${590 + i * 40}`}
          fill="none"
          stroke="white"
          strokeOpacity={0.05 + i * 0.008}
          strokeWidth="2"
        />
      ))}
    </svg>
  )
}

/** Windows 11 Modern Aurora Mesh Wallpaper */
function WallpaperWindows() {
  return (
    <svg className="absolute inset-0 h-full w-full" viewBox="0 0 1512 982" preserveAspectRatio="xMidYMid slice" aria-hidden>
      <defs>
        <radialGradient id="win-glow" cx="50%" cy="30%" r="80%">
          <stop offset="0%" stopColor="#0369a1" stopOpacity="0.45" />
          <stop offset="45%" stopColor="#0f172a" stopOpacity="0.85" />
          <stop offset="100%" stopColor="#020617" stopOpacity="1" />
        </radialGradient>
        <linearGradient id="win-wave" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#38bdf8" stopOpacity="0.15" />
          <stop offset="100%" stopColor="#818cf8" stopOpacity="0.05" />
        </linearGradient>
      </defs>
      <rect width="1512" height="982" fill="url(#win-glow)" />
      <path
        d="M-50 400 C 350 200, 700 700, 1100 350 S 1400 500, 1600 420 L 1600 982 L -50 982 Z"
        fill="url(#win-wave)"
      />
      <circle cx="756" cy="420" r="320" fill="#0284c7" opacity="0.12" filter="blur(60px)" />
    </svg>
  )
}
