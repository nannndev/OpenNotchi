import { Check, Coffee, GitFork, HandHeart, Heart, Share2, Star } from "lucide-react"
import { useState } from "react"
import { cn } from "@/lib/utils"
import { formatCount, useRepo } from "@/hooks/use-github"
import { REPO_URL, SITE_URL, SUPPORT_LINKS } from "@/lib/site"

export function Support() {
  const { data: repo } = useRepo()
  const [shared, setShared] = useState(false)

  const share = async () => {
    const data = { title: "OpenNotchi", text: "A free, open-source Dynamic Notch for macOS", url: SITE_URL }
    try {
      if (navigator.share) {
        await navigator.share(data)
      } else {
        await navigator.clipboard.writeText(SITE_URL)
        setShared(true)
        setTimeout(() => setShared(false), 1800)
      }
    } catch {
      // Share sheet dismissed.
    }
  }

  return (
    <section id="support" className="mx-auto max-w-5xl scroll-mt-16 px-4 py-24 text-center">
      <div className="mx-auto grid size-14 place-items-center rounded-2xl bg-white/10">
        <Heart className="size-6 fill-white" />
      </div>
      <h2 className="font-display mt-6 text-[clamp(34px,5vw,54px)] font-extrabold tracking-[-0.03em]">Support OpenNotchi</h2>
      <p className="mx-auto mt-3.5 max-w-xl text-[17px] text-muted-foreground">
        OpenNotchi is free and always will be. If it makes your Mac a little nicer, here's how you can help it grow.
      </p>

      {SUPPORT_LINKS.length > 0 && (
        <div className="mt-10 flex flex-wrap justify-center gap-3">
          {SUPPORT_LINKS.map((link) => {
            const Icon = link.brand === "buymeacoffee" ? Coffee : HandHeart
            return (
              <a
                key={link.url}
                href={link.url}
                target="_blank"
                rel="noopener"
                className={cn(
                  "group inline-flex items-center gap-3 rounded-full py-2.5 pr-6 pl-2.5 text-left transition hover:-translate-y-0.5",
                  link.brand === "buymeacoffee" ? "bg-[#FFDD00] text-black" : "bg-[#FAAE2B] text-black",
                )}
              >
                <span className="grid size-9 place-items-center rounded-full bg-black/10">
                  <Icon className="size-[18px]" />
                </span>
                <span className="flex flex-col leading-tight">
                  <span className="font-display text-[15px] font-bold">{link.name}</span>
                  <span className="text-xs opacity-70">{link.description}</span>
                </span>
              </a>
            )
          })}
        </div>
      )}

      <div className="mt-10 grid gap-3.5 text-left sm:grid-cols-3">
        <a href={REPO_URL} target="_blank" rel="noopener" className="group rounded-[22px] border border-white/10 bg-white/[0.03] p-6 transition hover:border-white/25">
          <Star className="size-5 transition group-hover:fill-white" />
          <h3 className="font-display mt-4 text-lg font-bold">Star on GitHub</h3>
          <p className="mt-1.5 text-sm text-muted-foreground">
            Stars help other people find the project.{repo && repo.stargazers_count > 0 ? ` ${formatCount(repo.stargazers_count)} so far.` : ""}
          </p>
        </a>
        <button onClick={share} className="group rounded-[22px] border border-white/10 bg-white/[0.03] p-6 text-left transition hover:border-white/25">
          {shared ? <Check className="size-5" /> : <Share2 className="size-5" />}
          <h3 className="font-display mt-4 text-lg font-bold">{shared ? "Link copied" : "Tell a friend"}</h3>
          <p className="mt-1.5 text-sm text-muted-foreground">Share OpenNotchi with someone who has a notch to spare.</p>
        </button>
        <a href={`${REPO_URL}/issues`} target="_blank" rel="noopener" className="group rounded-[22px] border border-white/10 bg-white/[0.03] p-6 transition hover:border-white/25">
          <GitFork className="size-5" />
          <h3 className="font-display mt-4 text-lg font-bold">Contribute</h3>
          <p className="mt-1.5 text-sm text-muted-foreground">Report bugs, suggest features or send a pull request.</p>
        </a>
      </div>
    </section>
  )
}
