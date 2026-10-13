import { motion } from "motion/react"
import { AppleIcon, GitHubIcon } from "@/components/icons"
import { MacBookPreview } from "@/components/macbook-preview"
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
    <section className="relative overflow-hidden px-4 pt-32 pb-28 text-center sm:pt-36">
      <motion.p {...rise(0)} className="text-[13px] font-medium tracking-wide text-neutral-400">
        {release ? `${release.tag_name} · ` : ""}Free and open source for macOS
      </motion.p>

      <motion.h1
        {...rise(0.06)}
        className="font-display mx-auto mt-5 max-w-4xl text-[clamp(46px,8.5vw,100px)] leading-[0.95] font-extrabold tracking-[-0.04em]"
      >
        Your notch,
        <br />
        <span className="text-neutral-500">but alive.</span>
      </motion.h1>

      <motion.p {...rise(0.12)} className="mx-auto mt-6 max-w-xl text-[clamp(16px,2vw,19px)] leading-relaxed text-neutral-300">
        OpenNotchi turns the space around your MacBook's camera into a home for your music, meetings, notes and
        photos. Hover it, and it opens.
      </motion.p>

      <motion.div {...rise(0.18)} className="mt-8 flex flex-wrap justify-center gap-3">
        <Button size="lg" asChild className="h-12 rounded-full px-7 text-[15px]">
          <a href={LATEST_DMG_URL}>
            <AppleIcon className="size-[18px]" />
            Download for macOS
          </a>
        </Button>
        <Button size="lg" variant="outline" asChild className="h-12 rounded-full border-white/15 bg-transparent px-7 text-[15px] hover:bg-white/5">
          <a href={REPO_URL} target="_blank" rel="noopener">
            <GitHubIcon className="size-4" />
            View on GitHub
          </a>
        </Button>
      </motion.div>

      <motion.p {...rise(0.22)} className="mt-4 text-[13px] text-neutral-500">
        {downloads ? `${formatCount(downloads)} downloads · ` : ""}macOS 14 or later · Apple Silicon and Intel
      </motion.p>

      <motion.div {...rise(0.3)} className="mt-[clamp(56px,9vw,104px)]">
        <MacBookPreview />
      </motion.div>
    </section>
  )
}
