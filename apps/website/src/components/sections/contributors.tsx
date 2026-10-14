import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { GitHubIcon } from "@/components/icons"
import { useContributors, useDeveloper } from "@/hooks/use-github"
import { DEVELOPER_LOGIN, DEVELOPER_URL, REPO_URL } from "@/lib/site"

export function Contributors() {
  const { data, loading } = useContributors()
  const { data: dev } = useDeveloper()
  const humans = data?.filter((p) => p.type !== "Bot") ?? []
  // The creator already has their own card above, so list everyone else.
  const people = humans.filter((p) => p.login.toLowerCase() !== DEVELOPER_LOGIN.toLowerCase())

  return (
    <section id="contributors" className="mx-auto max-w-5xl scroll-mt-16 px-4 py-24 text-center">
      <h2 className="font-display text-[clamp(34px,5vw,54px)] font-extrabold tracking-[-0.03em]">Built in the open.</h2>
      <p className="mt-3.5 text-[17px] text-muted-foreground">OpenNotchi is made by these people. Want to join them?</p>

      <a
        href={DEVELOPER_URL}
        target="_blank"
        rel="noopener"
        className="group mx-auto mt-11 flex max-w-md items-center gap-4 rounded-[22px] border border-white/10 bg-white/[0.03] p-4 text-left transition hover:border-white/25"
      >
        <Avatar className="size-16 ring-1 ring-white/15">
          <AvatarImage src={dev?.avatar_url ?? `https://github.com/${DEVELOPER_LOGIN}.png?size=128`} alt={DEVELOPER_LOGIN} />
          <AvatarFallback>{DEVELOPER_LOGIN.slice(0, 2).toUpperCase()}</AvatarFallback>
        </Avatar>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="text-xs font-medium tracking-wide text-neutral-500 uppercase">Creator & maintainer</span>
          <span className="font-display truncate text-xl font-bold">{dev?.name || DEVELOPER_LOGIN}</span>
          <span className="truncate text-sm text-muted-foreground">{dev?.bio || `@${DEVELOPER_LOGIN} on GitHub`}</span>
        </span>
        <GitHubIcon className="size-5 shrink-0 text-neutral-500 transition group-hover:text-white" />
      </a>

      <div className="mt-8 flex flex-wrap justify-center gap-5">
        {loading &&
          Array.from({ length: 3 }, (_, i) => <div key={i} className="size-[72px] animate-pulse rounded-full bg-white/5" />)}
        {people.map((p) => (
          <Tooltip key={p.login}>
            <TooltipTrigger asChild>
              <a href={p.html_url} target="_blank" rel="noopener" className="group flex w-24 flex-col items-center gap-2">
                <Avatar className="size-[72px] ring-1 ring-white/10">
                  <AvatarImage src={`${p.avatar_url}&s=144`} alt={p.login} className="grayscale transition duration-300 group-hover:grayscale-0" />
                  <AvatarFallback>{p.login.slice(0, 2).toUpperCase()}</AvatarFallback>
                </Avatar>
                <span className="max-w-24 truncate text-[13px] text-neutral-300">{p.login}</span>
              </a>
            </TooltipTrigger>
            <TooltipContent>
              {p.contributions} commit{p.contributions === 1 ? "" : "s"}
            </TooltipContent>
          </Tooltip>
        ))}
        {!loading && humans.length === 0 && (
          <Button variant="outline" asChild className="rounded-full">
            <a href={`${REPO_URL}/graphs/contributors`} target="_blank" rel="noopener">See contributors on GitHub</a>
          </Button>
        )}
      </div>

      <div className="mt-10 flex flex-wrap justify-center gap-3">
        <Button variant="outline" asChild className="h-10 rounded-full px-5">
          <a href={`${REPO_URL}#readme`} target="_blank" rel="noopener">Read the docs</a>
        </Button>
        <Button variant="outline" asChild className="h-10 rounded-full px-5">
          <a href={`${REPO_URL}/issues`} target="_blank" rel="noopener">Report a bug or idea</a>
        </Button>
      </div>
    </section>
  )
}
