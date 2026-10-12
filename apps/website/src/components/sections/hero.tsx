import { motion } from "motion/react"
import { AppleIcon, GitHubIcon } from "@/components/icons"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { formatCount, useDownloadCount, useLatestRelease } from "@/hooks/use-github"
import { LATEST_DMG_URL, REPO_URL } from "@/lib/site"

const rise = (delay: number) => ({
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.7, delay, ease: [0.22, 1, 0.36, 1] as const },
})

export function Hero() {
  const { data: release } = useLatestRelease()
  const downloads = useDownloadCount()

  return (
    <section className="relative mx-auto max-w-5xl px-4 pt-36 pb-20 text-center sm:pt-40">
      <div className="pointer-events-none absolute inset-x-0 -top-52 -z-10 h-[700px] bg-[radial-gradient(ellipse_50%_50%_at_50%_30%,rgba(255,255,255,0.1),transparent_70%)]" />

      <motion.div {...rise(0)}>
        <Badge variant="outline" className="gap-2 rounded-full px-3.5 py-1 text-[13px] font-normal text-neutral-300">
          <span className="size-1.5 rounded-full bg-white shadow-[0_0_10px_white]" />
          {release ? `${release.tag_name} is out · Free & open source` : "Free & open source"}
        </Badge>
      </motion.div>

      <motion.h1 {...rise(0.08)} className="font-display mt-6 text-[clamp(48px,9vw,104px)] leading-[0.98] font-extrabold tracking-[-0.035em]">
        Your notch,
        <br />
        <span className="text-muted-foreground">but alive.</span>
      </motion.h1>

      <motion.p {...rise(0.16)} className="mx-auto mt-6 max-w-xl text-[clamp(16px,2vw,19px)] leading-relaxed text-neutral-300">
        OpenNotchi turns the MacBook notch into a little hub for your music, synced lyrics, files, AirDrop, clipboard and
        timers. Hover the notch at the top of this page to try it.
      </motion.p>

      <motion.div {...rise(0.24)} className="mt-9 flex flex-wrap justify-center gap-3">
        <Button size="lg" asChild className="h-12 rounded-full px-6 text-[15px]">
          <a href={LATEST_DMG_URL}>
            <AppleIcon className="size-[18px]" />
            Download for macOS
          </a>
        </Button>
        <Button size="lg" variant="outline" asChild className="h-12 rounded-full px-6 text-[15px]">
          <a href={REPO_URL} target="_blank" rel="noopener">
            <GitHubIcon className="size-4" />
            View on GitHub
          </a>
        </Button>
      </motion.div>

      <motion.p {...rise(0.3)} className="mt-5 text-[13px] text-muted-foreground">
        {release ? `${release.tag_name} · ` : ""}
        {downloads ? `${formatCount(downloads)} downloads · ` : ""}
        macOS 14 or later · Apple Silicon &amp; Intel · MIT license
      </motion.p>
    </section>
  )
}
