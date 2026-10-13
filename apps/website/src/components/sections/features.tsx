import { useState } from "react"
import { motion } from "motion/react"
import {
  AirplayIcon,
  CandlestickChart,
  Clipboard,
  CloudSun,
  Disc,
  Gauge,
  Inbox,
  MessageSquareQuote,
  MoonStar,
  ScanFace,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Terminal,
  Timer,
  Video,
  XCircle,
  type LucideIcon,
} from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"
import { cn } from "@/lib/utils"

const AUX_FEATURES: { icon: LucideIcon; title: string; body: string }[] = [
  { icon: MessageSquareQuote, title: "Interactive Synced Lyrics", body: "Flip to synced lyrics with depth blur. Hover for instant play cues or click any line to seek there." },
  { icon: Sparkles, title: "AirPods & Fluid HUD", body: "Left/Right/Case battery drop-down card and springy fluid HUD capsule for system volume, brightness and mic." },
  { icon: Smartphone, title: "Spotify on Any Device", body: "Playing on your iPhone, iPad, or smart speaker? Connect Spotify to see it, read lyrics, and control playback from your Mac." },
  { icon: Inbox, title: "Shelf Tray & AirDrop", body: "Park files on the notch with real thumbnails, or drag files to trigger instant AirDrop with visual progress." },
  { icon: Clipboard, title: "Clipboard History", body: "Search and re-copy recent text and images with full privacy. Password-manager copies are automatically excluded." },
  { icon: CloudSun, title: "Weather & Calendar", body: "Live precipitation forecasts, upcoming calendar events, and battery telemetry at a single glance." },
  { icon: Timer, title: "Pomodoro Focus Timer", body: "Pomodoro countdowns that stay subtly pinned beside the notch with gentle chime notifications." },
  { icon: CandlestickChart, title: "Markets & Crypto Watch", body: "Track Indonesian and global stocks, market indices, crypto pairs, and currency exchange rates in real-time." },
  { icon: MoonStar, title: "Prayer Times & Qibla", body: "Accurate prayer timetables directly in the header bar. Supports Kemenag, MWL, ISNA, and custom calculation methods." },
  { icon: AirplayIcon, title: "Live Video PiP Preview", body: "Keep YouTube tutorials and live streams playing inside the notch, muted and perfectly in sync." },
  { icon: ScanFace, title: "HD Mirror & Studio Looks", body: "Quick camera mirror check with soft beauty light, portrait depth blur, and gesture shortcuts." },
  { icon: ShieldCheck, title: "Private by Design", body: "Zero telemetry, zero user tracking, and zero cloud accounts. Everything executes locally on your Mac." },
]

const PHYSICS_MODES = [
  { name: "Bouncy Island", desc: "Jelly spring with fluid bounce", spring: "stiffness: 260, damping: 20" },
  { name: "Waterfall Drop", desc: "-65pt cascade from bezel", spring: "stiffness: 300, damping: 28" },
  { name: "Snappy Pro", desc: "Ultra-fast 160ms transition", spring: "stiffness: 420, damping: 32" },
  { name: "Elastic Pop", desc: "Playful overshooting recoil", spring: "stiffness: 340, damping: 18" },
  { name: "Gentle Float", desc: "Smooth luxury glide", spring: "stiffness: 180, damping: 24" },
  { name: "Instant", desc: "Zero delay snap", spring: "duration: 0.1s" },
]

const THEMES = [
  ["Liquid Glass", "bg-gradient-to-br from-white/25 to-white/5 backdrop-blur-xl border-white/20"],
  ["Music Adaptive", "bg-gradient-to-br from-purple-900/60 to-neutral-950 border-purple-500/30"],
  ["Frosted Obsidian", "bg-gradient-to-b from-neutral-800/80 to-neutral-950 border-neutral-700/40"],
  ["Midnight Indigo", "bg-gradient-to-br from-[#0d0f29] to-[#1f1447] border-indigo-500/30"],
  ["Aurora Borealis", "bg-[radial-gradient(circle_at_0_100%,rgba(45,212,191,.5),transparent_60%),radial-gradient(circle_at_100%_0,rgba(168,85,247,.5),transparent_60%)] bg-[#08090c] border-emerald-500/30"],
  ["Classic Jet Black", "bg-black border-white/10"],
]

interface PortItem {
  port: string
  name: string
}

export function Features() {
  const [activePhysics, setActivePhysics] = useState<number>(0)
  const [bentoDeckMode, setBentoDeckMode] = useState<"vu" | "spectrum">("vu")
  const [demoPorts, setDemoPorts] = useState<PortItem[]>([
    { port: "3000", name: "Next.js" },
    { port: "5173", name: "Vite" },
    { port: "8080", name: "Go API" },
  ])
  const [killedToast, setKilledToast] = useState<string | null>(null)

  const handleKill = (p: string) => {
    setDemoPorts((prev: PortItem[]) => prev.filter((item: PortItem) => item.port !== p))
    setKilledToast(`:${p} killed`)
    setTimeout(() => setKilledToast(null), 2000)
  }

  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-8">
      {/* Section Header */}
      <div className="text-center">
        <span className="font-mono text-xs uppercase tracking-widest text-emerald-400">
          Feature Ecosystem · v0.7.0
        </span>
        <h2 className="font-display mt-2 text-[clamp(34px,5vw,56px)] leading-tight font-extrabold tracking-[-0.035em]">
          Engineered for your notch.
          <br />
          <span className="bg-gradient-to-r from-neutral-300 to-white bg-clip-text text-transparent">
            Not just pinned to it.
          </span>
        </h2>
        <p className="mx-auto mt-3.5 max-w-xl text-[17px] text-muted-foreground">
          No subscriptions, no paywalls. Every feature is free, open source, and written in 100% native Swift for minimal CPU usage.
        </p>
      </div>

      {/* Flagship Bento Grid */}
      <div className="mt-16 grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {/* Bento 1: Eye-Contact Teleprompter (2 Cols on LG) */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.5 }}
          className="lg:col-span-2"
        >
          <Card className="h-full border-white/10 bg-gradient-to-br from-emerald-950/20 via-neutral-900/40 to-neutral-950/60 p-6 sm:p-8 backdrop-blur-xl hover:border-emerald-500/30 transition-all duration-300">
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
              <div className="flex items-center gap-3">
                <div className="grid size-12 place-items-center rounded-2xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-300 shadow-inner">
                  <Video className="size-6" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[11px] font-mono font-semibold uppercase text-emerald-400">Flagship • v0.7.0</span>
                    <span className="rounded-full bg-emerald-500/20 px-2 py-0.5 text-[10px] font-bold text-emerald-300">Natural Gaze</span>
                  </div>
                  <h3 className="font-display text-xl sm:text-2xl font-bold text-white">
                    Webcam Eye-Contact Teleprompter
                  </h3>
                </div>
              </div>
            </div>

            <p className="mt-4 text-[15px] leading-relaxed text-neutral-300 max-w-2xl">
              Read presentation notes, pitches, or interview cheat-sheets directly below your Mac camera lens. Auto-scrolls smoothly so you maintain 100% natural, direct eye contact with your audience.
            </p>

            {/* Interactive Teleprompter Micro-Stage */}
            <div className="mt-6 rounded-2xl border border-white/10 bg-black/60 p-4 shadow-2xl relative overflow-hidden">
              <div className="flex items-center justify-between border-b border-white/10 pb-2.5 text-xs">
                <span className="flex items-center gap-1.5 font-mono text-[11px] text-emerald-400">
                  <span className="size-2 rounded-full bg-emerald-400 animate-pulse" />
                  FaceTime HD Camera · Active
                </span>
                <span className="text-[11px] text-neutral-400 font-mono">1.5x Auto-Scroll</span>
              </div>

              {/* Gaze Target Guide */}
              <div className="my-3 flex items-center justify-center gap-2">
                <div className="h-px flex-1 bg-gradient-to-r from-transparent to-emerald-400/40" />
                <span className="rounded-full bg-emerald-500/20 border border-emerald-500/30 px-3 py-1 font-mono text-[10px] font-semibold text-emerald-300 uppercase tracking-wider">
                  👁️ Eye Level Contact Guide
                </span>
                <div className="h-px flex-1 bg-gradient-to-l from-transparent to-emerald-400/40" />
              </div>

              {/* Scrolling Text Script */}
              <div className="relative h-20 overflow-hidden [mask-image:linear-gradient(transparent,#000_20%,#000_80%,transparent)]">
                <div className="space-y-2 text-sm text-neutral-200 text-center font-medium float-gentle">
                  <p className="text-white font-bold">“Welcome to the OpenNotchi product demo.”</p>
                  <p className="text-neutral-400">“Notice how my eyes never drift down to secondary notes.”</p>
                  <p className="text-neutral-400">“Everything flows smoothly directly beneath the bezel.”</p>
                </div>
              </div>
            </div>
          </Card>
        </motion.div>

        {/* Bento 2: Dual Analog VU Meter Deck */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.5, delay: 0.1 }}
          className="lg:col-span-1"
        >
          <Card className="h-full border-white/10 bg-gradient-to-br from-amber-950/20 via-neutral-900/40 to-neutral-950/60 p-6 sm:p-8 backdrop-blur-xl hover:border-amber-500/30 transition-all duration-300 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-3">
                <div className="grid size-12 place-items-center rounded-2xl bg-amber-500/15 border border-amber-500/30 text-amber-300 shadow-inner">
                  <Gauge className="size-6" />
                </div>
                <div>
                  <span className="text-[11px] font-mono font-semibold uppercase text-amber-400">Audio Deck • v0.7.0</span>
                  <h3 className="font-display text-xl font-bold text-white">Dual Analog VU Meter</h3>
                </div>
              </div>

              <p className="mt-4 text-sm leading-relaxed text-neutral-300">
                Vintage amber meter face with dual ballistic needles, peak indicators, and instant toggle to 9-band digital equalizer.
              </p>
            </div>

            {/* Interactive VU / Spectrum Toggle Widget */}
            <div
              onClick={() => setBentoDeckMode((m: "vu" | "spectrum") => (m === "vu" ? "spectrum" : "vu"))}
              className="mt-6 rounded-2xl border border-white/10 bg-black/60 p-4 shadow-xl cursor-pointer group hover:border-amber-400/40 transition"
              title="Click to toggle VU Meter / Spectrum"
            >
              <div className="flex justify-between items-center text-[10px] font-mono text-neutral-400 pb-2 border-b border-white/10">
                <span className="text-amber-300 font-bold uppercase">{bentoDeckMode === "vu" ? "Dual VU Face" : "9-Band Spectrum"}</span>
                <span className="text-white/40 group-hover:text-white transition">CLICK TO FLIP</span>
              </div>

              {bentoDeckMode === "vu" ? (
                <div className="mt-3 h-20 rounded-xl bg-gradient-to-b from-[#fbf4d8] to-[#edd99c] p-2 flex flex-col justify-between border border-amber-900/30 shadow-inner">
                  <div className="flex justify-between text-[8px] font-mono font-black text-neutral-800">
                    <span>-20dB</span>
                    <span>-5dB</span>
                    <span className="text-rose-600">+3dB</span>
                  </div>
                  <div className="relative h-8 overflow-hidden">
                    <div className="absolute inset-x-2 top-1 h-8 rounded-[100%] border-t-2 border-neutral-700/60" />
                    <div className="absolute bottom-0 left-[30%] h-8 w-[2px] bg-neutral-900 origin-bottom animate-[vu-bounce_1.2s_ease-in-out_infinite]" />
                    <div className="absolute bottom-0 left-[70%] h-8 w-[2px] bg-neutral-900 origin-bottom animate-[vu-bounce_1.4s_ease-in-out_infinite_0.15s]" />
                  </div>
                  <div className="flex justify-between text-[8px] font-mono font-bold text-neutral-700">
                    <span>LEFT</span>
                    <span className="text-rose-600 font-black">● PEAK</span>
                    <span>RIGHT</span>
                  </div>
                </div>
              ) : (
                <div className="mt-3 h-20 flex items-end justify-between gap-1 px-1">
                  {[40, 75, 95, 60, 85, 50, 90, 70, 80].map((h, i) => (
                    <div
                      key={i}
                      className="w-full rounded-t-sm bg-gradient-to-t from-cyan-400 to-emerald-400 animate-pulse"
                      style={{ height: `${h}%`, animationDelay: `${i * 0.1}s`, animationDuration: "0.8s" }}
                    />
                  ))}
                </div>
              )}
            </div>
          </Card>
        </motion.div>

        {/* Bento 3: DJ Turntable & Stylus */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.5, delay: 0.15 }}
          className="lg:col-span-1"
        >
          <Card className="h-full border-white/10 bg-gradient-to-br from-purple-950/20 via-neutral-900/40 to-neutral-950/60 p-6 sm:p-8 backdrop-blur-xl hover:border-purple-500/30 transition-all duration-300 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-3">
                <div className="grid size-12 place-items-center rounded-2xl bg-purple-500/15 border border-purple-500/30 text-purple-300 shadow-inner">
                  <Disc className="size-6" />
                </div>
                <div>
                  <span className="text-[11px] font-mono font-semibold uppercase text-purple-400">Turntable • v0.7.0</span>
                  <h3 className="font-display text-xl font-bold text-white">DJ Vinyl &amp; Tonearm</h3>
                </div>
              </div>

              <p className="mt-4 text-sm leading-relaxed text-neutral-300">
                Interactive tonearm drops onto spinning grooves when playing and lifts on pause. Concentric vinyl sheen, scratch cues, and mini spinning disc in closed notch.
              </p>
            </div>

            <div className="mt-6 flex items-center justify-center p-4 rounded-2xl border border-white/10 bg-black/60 shadow-xl">
              <div className="relative size-24 rounded-full spin-vinyl" style={{ background: "radial-gradient(circle at center, #27272a 0%, #18181b 55%, #09090b 100%)" }}>
                <div className="absolute inset-1.5 rounded-full border border-white/10" />
                <div className="absolute inset-3 rounded-full border border-white/10" />
                <div className="absolute inset-0 rounded-full [background:conic-gradient(from_0deg,transparent,rgba(255,255,255,0.18),transparent,rgba(255,255,255,0.18),transparent)]" />
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 size-7 rounded-full bg-gradient-to-br from-purple-500 to-indigo-600 border border-white/30 flex items-center justify-center">
                  <div className="size-1.5 rounded-full bg-black" />
                </div>
              </div>
            </div>
          </Card>
        </motion.div>

        {/* Bento 4: 6 Notch Physics Engines */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className="lg:col-span-1"
        >
          <Card className="h-full border-white/10 bg-gradient-to-br from-pink-950/20 via-neutral-900/40 to-neutral-950/60 p-6 sm:p-8 backdrop-blur-xl hover:border-pink-500/30 transition-all duration-300 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-3">
                <div className="grid size-12 place-items-center rounded-2xl bg-pink-500/15 border border-pink-500/30 text-pink-300 shadow-inner">
                  <Sparkles className="size-6" />
                </div>
                <div>
                  <span className="text-[11px] font-mono font-semibold uppercase text-pink-400">Physics • v0.7.0</span>
                  <h3 className="font-display text-xl font-bold text-white">6 Physics Engines</h3>
                </div>
              </div>

              <p className="mt-4 text-sm leading-relaxed text-neutral-300">
                Choose the spring physics that matches your mood: Bouncy Island, Waterfall Drop, Snappy Pro, Elastic Pop, or Gentle Float.
              </p>
            </div>

            <div className="mt-6 space-y-1.5">
              <div className="grid grid-cols-2 gap-1.5">
                {PHYSICS_MODES.slice(0, 4).map((p, i) => (
                  <button
                    key={p.name}
                    onClick={() => setActivePhysics(i)}
                    className={cn(
                      "rounded-lg px-2.5 py-1.5 text-left text-xs font-medium transition border",
                      activePhysics === i
                        ? "bg-pink-500/20 border-pink-500/40 text-pink-200"
                        : "bg-white/5 border-white/5 text-neutral-400 hover:text-white",
                    )}
                  >
                    {p.name}
                  </button>
                ))}
              </div>
              <div className="text-[11px] font-mono text-pink-300/80 pt-1">
                Spring: {PHYSICS_MODES[activePhysics].spring}
              </div>
            </div>
          </Card>
        </motion.div>

        {/* Bento 5: Developer Port Killer */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{ duration: 0.5, delay: 0.25 }}
          className="lg:col-span-1"
        >
          <Card className="h-full border-white/10 bg-gradient-to-br from-cyan-950/20 via-neutral-900/40 to-neutral-950/60 p-6 sm:p-8 backdrop-blur-xl hover:border-cyan-500/30 transition-all duration-300 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-3">
                <div className="grid size-12 place-items-center rounded-2xl bg-cyan-500/15 border border-cyan-500/30 text-cyan-300 shadow-inner">
                  <Terminal className="size-6" />
                </div>
                <div>
                  <span className="text-[11px] font-mono font-semibold uppercase text-cyan-400">Dev Suite</span>
                  <h3 className="font-display text-xl font-bold text-white">Localhost Port Killer</h3>
                </div>
              </div>

              <p className="mt-4 text-sm leading-relaxed text-neutral-300">
                Detect orphan localhost ports and kill stuck dev servers with 1 click. Plus screen color eyedropper and audio device routing.
              </p>
            </div>

            <div className="mt-6 rounded-2xl border border-white/10 bg-black/60 p-3 shadow-xl">
              <div className="flex items-center justify-between text-[11px] font-mono text-neutral-400 pb-2">
                <span>Active Local Ports</span>
                {killedToast && <span className="text-rose-400 font-bold">{killedToast}</span>}
              </div>
              <div className="flex flex-wrap gap-1.5">
                {demoPorts.map((p: PortItem) => (
                  <div
                    key={p.port}
                    className="flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-2 py-1 text-xs"
                  >
                    <span className="size-1.5 rounded-full bg-emerald-400" />
                    <span className="font-mono font-bold text-white">:{p.port}</span>
                    <button
                      onClick={() => handleKill(p.port)}
                      title={`Kill :${p.port}`}
                      className="text-neutral-500 hover:text-rose-400 transition"
                    >
                      <XCircle className="size-3" />
                    </button>
                  </div>
                ))}
                {demoPorts.length === 0 && (
                  <button
                    onClick={() => setDemoPorts([{ port: "3000", name: "Next.js" }, { port: "5173", name: "Vite" }])}
                    className="text-xs text-cyan-400 hover:underline"
                  >
                    + Reset Ports
                  </button>
                )}
              </div>
            </div>
          </Card>
        </motion.div>
      </div>

      {/* Auxiliary Features Secondary Grid */}
      <div className="mt-16">
        <h3 className="font-display text-center text-2xl font-bold tracking-tight text-white mb-8">
          Plus all the tools you already rely on
        </h3>
        <div className="grid gap-3.5 sm:grid-cols-2 lg:grid-cols-3">
          {AUX_FEATURES.map(({ icon: Icon, title, body }, i) => (
            <motion.div
              key={title}
              initial={{ opacity: 0, y: 14 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-40px" }}
              transition={{ duration: 0.4, delay: (i % 3) * 0.05 }}
            >
              <Card className="h-full border-white/10 bg-white/[0.03] backdrop-blur-md transition-all duration-300 hover:border-white/20 hover:-translate-y-1">
                <CardContent className="p-5">
                  <div className="grid size-10 place-items-center rounded-xl bg-white/10 text-white">
                    <Icon className="size-5" strokeWidth={1.8} />
                  </div>
                  <h4 className="font-display mt-3.5 mb-1.5 text-base font-bold text-white">{title}</h4>
                  <p className="text-xs leading-relaxed text-muted-foreground">{body}</p>
                </CardContent>
              </Card>
            </motion.div>
          ))}
        </div>
      </div>

      {/* Dynamic Themes Showcase Bar */}
      <div className="mt-20">
        <div className="text-center mb-6">
          <span className="font-mono text-xs uppercase tracking-widest text-neutral-400">Appearance Engine</span>
          <h3 className="font-display text-2xl font-bold text-white mt-1">Adaptive Liquid Themes</h3>
        </div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          {THEMES.map(([name, bg]) => (
            <div
              key={name}
              className={`flex h-24 items-end rounded-b-[24px] border border-t-0 p-3.5 text-xs font-semibold text-white shadow-xl ${bg}`}
            >
              {name}
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
