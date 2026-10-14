import { GitHubIcon, Wordmark } from "@/components/icons"
import { useDeveloper } from "@/hooks/use-github"
import { CHANGELOG_URL, DEVELOPER_LOGIN, DEVELOPER_URL, RELEASES_URL, REPO_URL } from "@/lib/site"

export function SiteFooter() {
  const { data: dev } = useDeveloper()
  const devName = dev?.name || DEVELOPER_LOGIN

  return (
    <footer className="border-t border-white/10">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-4 py-10 text-[13px] text-muted-foreground sm:px-8 md:flex-row md:items-center md:justify-between">
        <div className="flex flex-col gap-2">
          <a href="#top" className="flex items-center gap-2 text-foreground">
            <img src="/favicon.svg" alt="" className="size-5 invert" />
            <Wordmark className="font-display font-extrabold" />
          </a>
          <p>
            Made with care by{" "}
            <a href={DEVELOPER_URL} target="_blank" rel="noopener" className="font-medium text-foreground underline-offset-4 hover:underline">
              {devName}
            </a>
            {dev?.name ? ` (@${DEVELOPER_LOGIN})` : ""}. Free and open source under the MIT license. Not affiliated with Apple.
          </p>
        </div>
        <nav className="flex flex-wrap items-center gap-x-5 gap-y-2">
          <a href={RELEASES_URL} target="_blank" rel="noopener" className="hover:text-foreground">Releases</a>
          <a href={CHANGELOG_URL} target="_blank" rel="noopener" className="hover:text-foreground">Changelog</a>
          <a href={`${REPO_URL}/issues`} target="_blank" rel="noopener" className="hover:text-foreground">Issues</a>
          <a href={REPO_URL} target="_blank" rel="noopener" className="inline-flex items-center gap-1.5 text-foreground hover:opacity-80">
            <GitHubIcon className="size-4" />
            GitHub
          </a>
        </nav>
      </div>
    </footer>
  )
}
