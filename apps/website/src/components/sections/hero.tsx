import { motion } from "motion/react"
import { Disc, Gauge, Sparkles, Terminal, Video } from "lucide-react"
import { AppleIcon, GitHubIcon } from "@/components/icons"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { formatCount, useDownloadCount, useLatestRelease } from "@/hooks/use-github"
import { LATEST_DMG_URL, REPO_URL } from "@/lib/site"

const rise = (delay: number) => ({
  initial: { opacity: 0, y: 18 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.7, delay, ease: [0.22, 1, 0.36, 1] as const },
})

export function Hero() {
  const { data: release } = useLatestRelease()
  const downloads = useDownloadCount()

  return (
    <section className="relative mx-auto max-w-5xl px-4 pt-36 pb-20 text-center sm:pt-40 overflow-hidden">
      {/* Dynamic Aurora Ambient Glow Orbs */}
      <div className="pointer-events-none absolute -top-44 left-1/2 -translate-x-1/2 -z-10 h-[520px] w-full max-w-4xl bg-[radial-gradient(ellipse_60%_50%_at_50%_25%,rgba(168,85,247,0.22),transparent_70%)] blur-3xl pulse-glow" />
      <div className="pointer-events-none absolute -top-24 left-[10%] -z-10 size-[380px] rounded-full bg-emerald-500/12 blur-3xl float-gentle" />
      <div className="pointer-events-none absolute -top-24 right-[10%] -z-10 size-[380px] rounded-full bg-cyan-500/12 blur-3xl float-reverse" />

      {/* Release Badge */}
      <motion.div {...rise(0)}>
        <Badge
          variant="outline"
          className="gap-2 rounded-full border-white/15 bg-white/[0.04] px-4 py-1.5 text-[13px] font-medium text-neutral-200 shadow-lg backdrop-blur-md hover:border-white/25 transition"
        >
          <span className="size-2 rounded-full bg-emerald-400 shadow-[0_0_10px_#34d399] animate-pulse" />
          {release ? `${release.tag_name} is out` : "v0.7.0 is out"} · Free &amp; Open Source
        </Badge>
      </motion.div>

      {/* Hero Headline */}
      <motion.h1
        {...rise(0.08)}
        className="font-display mt-7 text-[clamp(48px,9vw,104px)] leading-[0.96] font-extrabold tracking-[-0.04em]"
      >
        Your notch,
        <br />
        <span className="bg-gradient-to-r from-neutral-200 via-white to-neutral-400 bg-clip-text text-transparent">
          but alive.
        </span>
      </motion.h1>

      {/* Subtitle */}
      <motion.p
        {...rise(0.16)}
        className="mx-auto mt-6 max-w-2xl text-[clamp(16px,2vw,19px)] leading-relaxed text-neutral-300"
      >
        OpenNotchi transforms the MacBook notch into a living desktop dynamic island. Eye-contact teleprompter, DJ turntable with dual analog VU meters, developer port killer, and Korean photobox — right where your eyes already look.
      </motion.p>

      {/* CTA Buttons */}
      <motion.div {...rise(0.24)} className="mt-9 flex flex-wrap justify-center gap-3">
        <Button size="lg" asChild className="h-12 rounded-full px-7 text-[15px] shadow-lg shadow-white/10 hover:shadow-white/20 transition hover:scale-105">
          <a href={LATEST_DMG_URL}>
            <AppleIcon className="size-[18px]" />
            Download for macOS
          </a>
        </Button>
        <Button size="lg" variant="outline" asChild className="h-12 rounded-full px-7 text-[15px] border-white/20 bg-white/5 backdrop-blur hover:bg-white/10 transition hover:scale-105">
          <a href={REPO_URL} target="_blank" rel="noopener">
            <GitHubIcon className="size-4" />
            View on GitHub
          </a>
        </Button>
      </motion.div>

      {/* Meta Specs */}
      <motion.p {...rise(0.3)} className="mt-5 text-[13px] text-muted-foreground">
        {release ? `${release.tag_name} · ` : ""}
        {downloads ? `${formatCount(downloads)} downloads · ` : ""}
        macOS 14 or later · Apple Silicon &amp; Intel · MIT license
      </motion.p>

      {/* Floating Interactive Micro-Badge Stage */}
      <motion.div
        {...rise(0.38)}
        className="relative mx-auto mt-14 max-w-3xl pt-2 pb-6"
      >
        <div className="flex flex-wrap items-center justify-center gap-2.5 sm:gap-3 text-xs sm:text-[13px]">
          <div className="flex items-center gap-2 rounded-full border border-emerald-500/30 bg-emerald-950/20 px-3.5 py-1.5 font-medium text-emerald-300 shadow-md backdrop-blur float-gentle">
            <Video className="size-3.5 text-emerald-400" />
            <span>Eye-Contact Prompter</span>
          </div>

          <div className="flex items-center gap-2 rounded-full border border-amber-500/30 bg-amber-950/20 px-3.5 py-1.5 font-medium text-amber-300 shadow-md backdrop-blur float-reverse">
            <Gauge className="size-3.5 text-amber-400" />
            <span>Dual Analog VU Meter</span>
          </div>

          <div className="flex items-center gap-2 rounded-full border border-purple-500/30 bg-purple-950/20 px-3.5 py-1.5 font-medium text-purple-300 shadow-md backdrop-blur float-gentle">
            <Disc className="size-3.5 text-purple-400" />
            <span>DJ Turntable &amp; Stylus</span>
          </div>

          <div className="flex items-center gap-2 rounded-full border border-cyan-500/30 bg-cyan-950/20 px-3.5 py-1.5 font-medium text-cyan-300 shadow-md backdrop-blur float-reverse">
            <Terminal className="size-3.5 text-cyan-400" />
            <span>Port Killer (:3000)</span>
          </div>

          <div className="flex items-center gap-2 rounded-full border border-pink-500/30 bg-pink-950/20 px-3.5 py-1.5 font-medium text-pink-300 shadow-md backdrop-blur float-gentle">
            <Sparkles className="size-3.5 text-pink-400" />
            <span>6 Physics Engines</span>
          </div>
        </div>

        <p className="mt-4 text-[12px] text-neutral-400">
          💡 <span className="text-neutral-300 font-medium">Try it live:</span> Hover the notch at the very top of your screen to inspect the interactive player, meters, and prompter!
        </p>
      </motion.div>
    </section>
  )
}
