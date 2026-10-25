import { DeveloperBadge } from "@/components/developer-badge"
import { AppleIcon, GitHubIcon, WindowsIcon } from "@/components/icons"
import { MacBookPreview } from "@/components/macbook-preview"
import { formatCount, useDownloadCount, useLatestRelease } from "@/hooks/use-github"
import { LATEST_DMG_URL, LATEST_WINDOWS_EXE_URL, REPO_URL } from "@/lib/site"

/**
 * The hero copy. On wide screens it's the wallpaper of the 3D MacBook (sized in container units, so it
 * scales with the laptop); on phones the screen is too small to read, so it sits above the laptop.
 */
function HeroCopy({ onScreen }: { onScreen?: boolean }) {
  const { data: release } = useLatestRelease()
  const downloads = useDownloadCount()
  const s = (screen: string, page: string) => (onScreen ? screen : page)

  return (
    <div className="flex h-full flex-col items-center justify-center text-center">
      <p className={`font-medium tracking-wide text-neutral-400 ${s("text-[1.15cqw]", "text-[13px]")}`}>
        {release ? `${release.tag_name} · ` : ""}Free and open source for macOS &amp; Windows
      </p>
      <h1
        className={`font-display font-extrabold tracking-[-0.04em] ${s("mt-[1.4cqw] text-[6.6cqw] leading-[0.95]", "mt-4 text-[clamp(44px,13vw,64px)] leading-[0.95]")}`}
      >
        Your notch,
        <br />
        <span className="text-neutral-500">but alive.</span>
      </h1>
      <p className={`text-neutral-300 ${s("mt-[1.6cqw] max-w-[48cqw] text-[1.55cqw] leading-snug", "mt-5 max-w-sm text-base leading-relaxed")}`}>
        OpenNotchi turns your camera notch or screen edge into a home for your music, synced lyrics, an AI that can change your settings, focus timers and notes. Hover it, and it opens.
      </p>
      <div className={`flex flex-wrap justify-center ${s("mt-[2.2cqw] gap-[0.8cqw]", "mt-7 gap-3")}`}>
        <a
          href={LATEST_DMG_URL}
          className={`inline-flex items-center rounded-full bg-white font-medium text-black transition hover:bg-neutral-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white ${s(
            "h-[3.6cqw] gap-[0.6cqw] px-[1.8cqw] text-[1.25cqw]",
            "h-12 gap-2 px-5 text-[14.5px]",
          )}`}
        >
          <AppleIcon className={s("size-[1.4cqw]", "size-[17px]")} />
          macOS
        </a>
        <a
          href={LATEST_WINDOWS_EXE_URL}
          className={`inline-flex items-center rounded-full border border-sky-400/30 bg-sky-500/10 font-medium text-sky-200 backdrop-blur transition hover:bg-sky-500/20 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sky-400 ${s(
            "h-[3.6cqw] gap-[0.6cqw] px-[1.8cqw] text-[1.25cqw]",
            "h-12 gap-2 px-5 text-[14.5px]",
          )}`}
        >
          <WindowsIcon className={s("size-[1.25cqw]", "size-[15px]")} />
          Windows
        </a>
        <a
          href={REPO_URL}
          target="_blank"
          rel="noopener"
          className={`inline-flex items-center rounded-full border border-white/20 bg-black/30 font-medium text-white backdrop-blur transition hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white ${s(
            "h-[3.6cqw] gap-[0.6cqw] px-[1.6cqw] text-[1.25cqw]",
            "h-12 gap-2 px-5 text-[14.5px]",
          )}`}
        >
          <GitHubIcon className={s("size-[1.25cqw]", "size-4")} />
          GitHub
        </a>
      </div>
      <p className={`text-neutral-500 ${s("mt-[1.4cqw] text-[1.05cqw]", "mt-4 text-[13px]")}`}>
        {downloads ? `${formatCount(downloads)} downloads · ` : ""}macOS 14+ (Silicon &amp; Intel) · Windows 10 &amp; 11
      </p>
    </div>
  )
}

export function Hero() {
  return (
    <section className="relative px-2 pt-24 pb-10 sm:pt-0">
      <div className="mb-14 px-2 sm:hidden">
        <HeroCopy />
      </div>
      <MacBookPreview wallpaper={<HeroCopy onScreen />} />
      <div className="mt-8 flex justify-center">
        <DeveloperBadge label="Crafted by" />
      </div>
    </section>
  )
}
