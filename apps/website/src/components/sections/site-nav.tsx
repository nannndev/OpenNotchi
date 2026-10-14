import { Menu, Star, X } from "lucide-react"
import { useEffect, useState } from "react"
import { GitHubIcon, Wordmark } from "@/components/icons"
import { Button } from "@/components/ui/button"
import { formatCount, useDeveloper, useRepo } from "@/hooks/use-github"
import { DEVELOPER_LOGIN, DEVELOPER_URL, REPO_URL } from "@/lib/site"
import { cn } from "@/lib/utils"

const LINKS = [
  ["Features", "#features"],
  ["Photobox", "#photobox"],
  ["Install", "#install"],
  ["Download", "#download"],
  ["Support", "#support"],
] as const

export function SiteNav() {
  const { data: repo } = useRepo()
  const { data: dev } = useDeveloper()
  const [open, setOpen] = useState(false)
  const [scrolled, setScrolled] = useState(false)
  const stars = repo?.stargazers_count
  const devName = dev?.name || DEVELOPER_LOGIN

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8)
    onScroll()
    window.addEventListener("scroll", onScroll, { passive: true })
    return () => window.removeEventListener("scroll", onScroll)
  }, [])

  return (
    <header
      className={cn(
        "sticky top-0 z-40 transition-colors duration-300",
        scrolled || open
          ? "border-b border-white/10 bg-background/80 backdrop-blur-xl"
          : "border-b border-transparent bg-gradient-to-b from-background from-40% to-transparent",
      )}
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:px-8">
        <div className="flex min-w-0 items-center gap-3">
          <a href="#top" className="flex shrink-0 items-center gap-2.5" onClick={() => setOpen(false)}>
            <img src="/favicon.svg" alt="" className="size-7 invert" />
            <Wordmark className="font-display text-lg font-extrabold" />
          </a>
          <a
            href={DEVELOPER_URL}
            target="_blank"
            rel="noopener"
            title={`Built by ${devName} (@${DEVELOPER_LOGIN})`}
            className="hidden min-w-0 items-center gap-1.5 rounded-full border border-white/10 py-0.5 pr-2.5 pl-0.5 text-xs text-neutral-400 transition hover:border-white/25 hover:text-white sm:inline-flex"
          >
            <img src={`https://github.com/${DEVELOPER_LOGIN}.png?size=48`} alt="" className="size-5 rounded-full bg-white/10" />
            <span className="truncate">
              by <span className="font-medium text-neutral-200">{devName}</span>
            </span>
          </a>
        </div>

        <nav className="flex items-center gap-1 sm:gap-2">
          {LINKS.map(([label, href]) => (
            <Button key={href} variant="ghost" size="sm" asChild className="hidden text-muted-foreground lg:inline-flex">
              <a href={href}>{label}</a>
            </Button>
          ))}
          <a
            href={REPO_URL}
            target="_blank"
            rel="noopener"
            aria-label={`OpenNotchi on GitHub${stars != null ? `, ${stars} stars` : ""}`}
            className="inline-flex h-8 items-center overflow-hidden rounded-full bg-white text-[13px] font-medium text-black transition hover:bg-neutral-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
          >
            <span className="flex items-center gap-1.5 pr-2.5 pl-3">
              <GitHubIcon className="size-4" />
              <span className="hidden sm:inline">GitHub</span>
            </span>
            <span className="flex h-full items-center gap-1 border-l border-black/10 bg-black/[0.06] pr-3 pl-2.5">
              <Star className="size-3.5 fill-black" />
              {stars != null ? formatCount(stars) : "Star"}
            </span>
          </a>
          <Button
            variant="ghost"
            size="icon"
            className="size-8 lg:hidden"
            aria-label={open ? "Close menu" : "Open menu"}
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
          >
            {open ? <X className="size-5" /> : <Menu className="size-5" />}
          </Button>
        </nav>
      </div>

      {open && (
        <div className="border-t border-white/10 px-4 pt-2 pb-5 lg:hidden">
          <nav className="mx-auto flex max-w-6xl flex-col">
            {LINKS.map(([label, href]) => (
              <a
                key={href}
                href={href}
                onClick={() => setOpen(false)}
                className="rounded-lg px-2 py-2.5 text-[15px] text-neutral-300 hover:bg-white/5 hover:text-white"
              >
                {label}
              </a>
            ))}
            <a
              href={DEVELOPER_URL}
              target="_blank"
              rel="noopener"
              className="mt-3 flex items-center gap-3 rounded-xl border border-white/10 p-3 hover:border-white/25"
            >
              <img src={`https://github.com/${DEVELOPER_LOGIN}.png?size=80`} alt="" className="size-9 rounded-full bg-white/10" />
              <span className="flex flex-col leading-tight">
                <span className="text-xs text-neutral-500">Developed by</span>
                <span className="text-sm font-medium">
                  {devName} <span className="text-neutral-500">@{DEVELOPER_LOGIN}</span>
                </span>
              </span>
            </a>
          </nav>
        </div>
      )}
    </header>
  )
}
