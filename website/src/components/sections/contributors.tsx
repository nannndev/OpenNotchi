import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { useContributors } from "@/hooks/use-github"
import { REPO_URL } from "@/lib/site"

export function Contributors() {
  const { data, loading } = useContributors()
  const people = data?.filter((p) => p.type !== "Bot") ?? []

  return (
    <section id="contributors" className="mx-auto max-w-5xl scroll-mt-16 px-4 py-24 text-center">
      <h2 className="font-display text-[clamp(34px,5vw,54px)] font-extrabold tracking-[-0.03em]">Built in the open.</h2>
      <p className="mt-3.5 text-[17px] text-muted-foreground">OpenNotchi is made by these people. Want to join them?</p>

      <div className="mt-11 flex flex-wrap justify-center gap-5">
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
        {!loading && people.length === 0 && (
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
