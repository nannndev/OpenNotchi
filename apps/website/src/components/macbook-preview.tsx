import { useEffect, useRef, useState } from "react"
import { AnimatePresence, motion, useInView, useMotionValue, useReducedMotion, useScroll, useSpring, useTransform } from "motion/react"

/** Screenshots of the real app in demo mode. `width` is the notch's width in points on a 1512-point-wide screen. */
const STATES = [
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
const CYCLE_MS = 3600

export function MacBookPreview() {
  const reduce = useReducedMotion()
  const stage = useRef<HTMLDivElement>(null)
  const inView = useInView(stage, { margin: "-15% 0px" })
  // The lid opens once, the first time the laptop comes into view.
  const seen = useInView(stage, { margin: "-15% 0px", once: true })
  const opened = !!reduce || seen
  const [index, setIndex] = useState(0)
  const pausedUntil = useRef(0)

  // Pointer tilt, smoothed with springs.
  const pointerX = useMotionValue(0)
  const pointerY = useMotionValue(0)
  const tiltY = useSpring(useTransform(pointerX, [-1, 1], [-7, 7]), { stiffness: 80, damping: 18 })
  const tiltX = useSpring(useTransform(pointerY, [-1, 1], [4, -4]), { stiffness: 80, damping: 18 })

  // As the page scrolls, the camera comes down from above the laptop to face it.
  // (A negative rotateX brings the top toward you, which is what looking from above looks like.)
  const { scrollYProgress } = useScroll({ target: stage, offset: ["start end", "center center"] })
  const scrollTilt = useTransform(scrollYProgress, [0, 1], reduce ? [-14, -14] : [-30, -14])
  const rotateX = useTransform([scrollTilt, tiltX], ([a, b]: number[]) => a + b)

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
    pausedUntil.current = Date.now() + 12000
  }

  const state = STATES[index]

  return (
    <div className="mx-auto w-full max-w-[1040px]">
      <div
        ref={stage}
        className="relative mx-auto w-[min(92vw,880px)] [perspective:3600px] [perspective-origin:50%_30%]"
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

        <motion.div style={{ rotateX, rotateY: tiltY }} className="relative [transform-style:preserve-3d]">
          {/* Lid */}
          <motion.div
            initial={false}
            animate={{ rotateX: opened ? 8 : -86 }}
            transition={reduce ? { duration: 0 } : { type: "spring", stiffness: 38, damping: 13, mass: 1.2, delay: 0.15 }}
            className="relative aspect-[1.54] w-full origin-bottom [transform-style:preserve-3d]"
          >
            {/* Back of the lid: aluminum, seen while it's closed. */}
            <div className="absolute inset-0 rounded-[3.2%/4.9%] bg-[linear-gradient(160deg,#e4e6ea,#a9adb4)] [backface-visibility:hidden] [transform:rotateY(180deg)_translateZ(1px)]" />
            {/* Front: black bezel around the display. */}
            <div className="absolute inset-0 rounded-[3.2%/4.9%] bg-[#0a0a0b] p-[1.6%] shadow-[inset_0_0_0_1.5px_#3a3b3f] [backface-visibility:hidden]">
              <Screen state={state} />
            </div>
          </motion.div>

          {/* Base, folded flat toward the viewer. */}
          <div className="absolute top-full left-[-1.5%] w-[103%] origin-top [transform:rotateX(90deg)] [transform-style:preserve-3d]">
            <div className="relative aspect-[1.48] rounded-b-[4%] bg-[linear-gradient(180deg,#d9dce0,#b9bdc3)] shadow-[inset_0_2px_0_#f2f3f5]">
              {/* Keyboard well */}
              <div className="absolute top-[7%] left-[9%] h-[44%] w-[82%] rounded-[1.5%] bg-[#1b1c1f] p-[0.8%]">
                <div className="h-full w-full rounded-[1%] bg-[repeating-linear-gradient(0deg,transparent_0_15.6%,#1b1c1f_15.6%_16.67%),repeating-linear-gradient(90deg,#2a2b2f_0_5%,#1b1c1f_5%_5.55%)]" />
              </div>
              {/* Trackpad */}
              <div className="absolute bottom-[8%] left-1/2 h-[34%] w-[42%] -translate-x-1/2 rounded-[3%] bg-[linear-gradient(180deg,#cfd2d6,#c3c6cb)] shadow-[inset_0_0_0_1px_#aeb2b8]" />
            </div>
            {/* Front edge with the opening scoop */}
            <div className="absolute top-full left-0 h-[10px] w-full origin-top rounded-b-[10px] bg-[linear-gradient(180deg,#9ea2a9,#7d8188)] [transform:rotateX(-90deg)]">
              <div className="mx-auto h-[5px] w-[14%] rounded-b-full bg-[#6d7178]" />
            </div>
          </div>
        </motion.div>
      </div>

      {/* State picker */}
      <div className="mt-[clamp(84px,29vw,330px)]">
        <div role="tablist" aria-label="What the notch can show" className="flex gap-1.5 overflow-x-auto px-4 pb-1 [scrollbar-width:none] sm:flex-wrap sm:justify-center">
          {STATES.map((s, i) => (
            <button
              key={s.id}
              role="tab"
              aria-selected={i === index}
              onClick={() => select(i)}
              className={`shrink-0 rounded-full px-3.5 py-1.5 text-[13px] font-medium transition-colors duration-300 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white ${
                i === index ? "bg-white text-black" : "text-neutral-400 hover:bg-white/10 hover:text-white"
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>
        <p aria-live="polite" className="mx-auto mt-4 max-w-md px-4 text-center text-[15px] text-neutral-400">
          {state.caption}
        </p>
      </div>
    </div>
  )
}

function Screen({ state }: { state: (typeof STATES)[number] }) {
  return (
    <div className="relative h-full w-full overflow-hidden rounded-[1.8%/2.8%] bg-[#0d0e10] [container-type:inline-size]">
      <Wallpaper />

      {/* Menu bar, leaving the camera housing clear */}
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

      {/* The notch: the hardware housing, with the app hanging from it */}
      <div className="absolute top-0 left-1/2 h-[3.4cqw] w-[12.5cqw] -translate-x-1/2 rounded-b-[1.1cqw] bg-black" />
      <AnimatePresence mode="popLayout" initial={false}>
        <motion.img
          key={state.id}
          src={state.src}
          alt={`The notch showing ${state.label.toLowerCase()}`}
          draggable={false}
          initial={{ opacity: 0, scaleX: 0.4, scaleY: 0.2 }}
          animate={{ opacity: 1, scaleX: 1, scaleY: 1 }}
          exit={{ opacity: 0, scaleX: 0.55, scaleY: 0.35, transition: { duration: 0.22 } }}
          transition={{ type: "spring", stiffness: 260, damping: 24 }}
          style={{ width: `${(state.width / SCREEN_POINTS) * 100}%`, x: "-50%" }}
          className="absolute top-0 left-1/2 origin-top select-none"
        />
      </AnimatePresence>
    </div>
  )
}

/** Soft waves, after the app icon; quiet so the notch keeps all the color. */
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
