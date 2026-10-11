import { Wordmark } from "@/components/icons"
import { REPO_URL } from "@/lib/site"

export function SiteFooter() {
  return (
    <footer className="border-t border-white/10">
      <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-x-7 gap-y-3 px-4 py-9 text-[13px] text-muted-foreground sm:px-8">
        <a href="#top" className="flex items-center gap-2 text-foreground">
          <img src="/favicon.svg" alt="" className="size-5 invert" />
          <Wordmark className="font-display font-extrabold" />
        </a>
        <p>Free and open source under the MIT license. Not affiliated with Apple.</p>
        <a href={REPO_URL} target="_blank" rel="noopener" className="hover:text-foreground">GitHub</a>
      </div>
    </footer>
  )
}
