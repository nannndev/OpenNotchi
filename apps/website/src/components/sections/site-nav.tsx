import { Star } from "lucide-react"
import { GitHubIcon, Wordmark } from "@/components/icons"
import { Button } from "@/components/ui/button"
import { useRepo } from "@/hooks/use-github"
import { REPO_URL } from "@/lib/site"

export function SiteNav() {
  const { data: repo } = useRepo()
  const stars = repo?.stargazers_count

  return (
    <header className="sticky top-0 z-40 bg-gradient-to-b from-background from-40% to-transparent">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3.5 sm:px-8">
        <a href="#top" className="flex items-center gap-2.5">
          <img src="/favicon.svg" alt="" className="size-7 invert" />
          <Wordmark className="font-display text-lg font-extrabold" />
        </a>
        <nav className="flex items-center gap-1 sm:gap-2">
          {[
            ["Features", "#features"],
            ["Install", "#install"],
            ["Download", "#download"],
            ["Support", "#support"],
          ].map(([label, href]) => (
            <Button key={href} variant="ghost" size="sm" asChild className="hidden text-muted-foreground lg:inline-flex">
              <a href={href}>{label}</a>
            </Button>
          ))}
          <Button variant="outline" size="sm" asChild className="rounded-full">
            <a href={REPO_URL} target="_blank" rel="noopener">
              <GitHubIcon className="size-4" />
              <Star className="size-3.5" />
              {stars ?? "Star"}
            </a>
          </Button>
        </nav>
      </div>
    </header>
  )
}
