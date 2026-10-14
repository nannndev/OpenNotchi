import { useDeveloper } from "@/hooks/use-github"
import { DEVELOPER_LOGIN, DEVELOPER_URL } from "@/lib/site"
import { cn } from "@/lib/utils"

/** A "made by" pill linking to the developer's GitHub profile. */
export function DeveloperBadge({ className, label = "Made by" }: { className?: string; label?: string }) {
  const { data: dev } = useDeveloper()
  const name = dev?.name || DEVELOPER_LOGIN

  return (
    <a
      href={DEVELOPER_URL}
      target="_blank"
      rel="noopener"
      className={cn(
        "group inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] py-1 pr-3 pl-1 text-[13px] text-neutral-300 transition hover:border-white/25 hover:text-white",
        className,
      )}
    >
      <img
        src={`https://github.com/${DEVELOPER_LOGIN}.png?size=64`}
        alt=""
        className="size-6 rounded-full bg-white/10 ring-1 ring-white/10"
      />
      <span className="text-neutral-500">{label}</span>
      <span className="font-medium">{name}</span>
      {dev?.name && <span className="hidden text-neutral-500 sm:inline">@{DEVELOPER_LOGIN}</span>}
    </a>
  )
}
