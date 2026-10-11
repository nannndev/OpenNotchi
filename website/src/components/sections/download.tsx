import { Download as DownloadIcon, FileArchive } from "lucide-react"
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { formatSize, useLatestRelease } from "@/hooks/use-github"
import { CHANGELOG_URL, LATEST_DMG_URL, LATEST_ZIP_URL, RELEASES_URL, REPO_URL } from "@/lib/site"

const STEPS = [
  <><b>Open</b> the .dmg and drag OpenNotchi into Applications.</>,
  <><b>Launch</b> it. It isn't notarized yet, so macOS blocks the first launch.</>,
  <>Go to <b>System Settings → Privacy &amp; Security</b> and click <b>Open Anyway</b>.</>,
  <>Hover your notch. Allow Spotify/Music access when asked.</>,
]

export function Download() {
  const { data: release, error } = useLatestRelease()
  const versioned = (ext: string) => release?.assets.find((a) => a.name.startsWith("OpenNotchi-") && a.name.endsWith(ext))
  const dmg = versioned(".dmg")
  const zip = versioned(".zip")
  const date = release && new Date(release.published_at).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })

  return (
    <section id="download" className="mx-auto max-w-3xl scroll-mt-16 px-4 py-24">
      <div className="rounded-[36px] border border-white/10 bg-[radial-gradient(ellipse_at_top,rgba(255,255,255,0.08),transparent_60%)] bg-neutral-950 p-8 text-center sm:p-16">
        <img src="/icon.png" alt="OpenNotchi app icon" className="mx-auto size-32 drop-shadow-[0_18px_30px_rgba(0,0,0,0.6)]" />
        <h2 className="font-display mt-6 text-[clamp(32px,5vw,48px)] font-extrabold tracking-[-0.03em]">Download OpenNotchi</h2>
        <p className="mt-3 text-[15px] text-neutral-300">
          {release ? (
            <>
              Version <code className="rounded-md bg-white/10 px-2 py-0.5 font-mono text-white">{release.tag_name}</code> · released {date}
            </>
          ) : error ? (
            "First release coming soon. Grab the source on GitHub meanwhile."
          ) : (
            "Checking the latest release…"
          )}
        </p>

        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Button size="lg" asChild className="h-12 rounded-full px-6">
            <a href={dmg?.browser_download_url ?? LATEST_DMG_URL}>
              <DownloadIcon className="size-4" />
              Download .dmg{dmg && ` · ${formatSize(dmg.size)}`}
            </a>
          </Button>
          <Button size="lg" variant="outline" asChild className="h-12 rounded-full px-6">
            <a href={zip?.browser_download_url ?? LATEST_ZIP_URL}>
              <FileArchive className="size-4" />
              Download .zip{zip && ` · ${formatSize(zip.size)}`}
            </a>
          </Button>
        </div>
        <p className="mt-5 space-x-2 text-[13px] text-muted-foreground">
          <a className="underline-offset-4 hover:text-foreground hover:underline" href={RELEASES_URL} target="_blank" rel="noopener">All releases</a>
          <span>·</span>
          <a className="underline-offset-4 hover:text-foreground hover:underline" href={CHANGELOG_URL} target="_blank" rel="noopener">Changelog</a>
          <span>·</span>
          <a className="underline-offset-4 hover:text-foreground hover:underline" href={REPO_URL} target="_blank" rel="noopener">Source code</a>
        </p>

        <Separator className="my-10 bg-white/10" />

        <ol className="mx-auto grid max-w-md gap-3.5 text-left">
          {STEPS.map((step, i) => (
            <li key={i} className="flex gap-3.5 text-sm leading-relaxed text-neutral-300 [&_b]:font-semibold [&_b]:text-white">
              <span className="font-display grid size-[26px] shrink-0 place-items-center rounded-full bg-white/10 text-[13px] font-bold text-white">
                {i + 1}
              </span>
              <span>{step}</span>
            </li>
          ))}
        </ol>

        <Accordion type="single" collapsible className="mx-auto mt-8 max-w-md text-left">
          <AccordionItem value="build" className="border-white/10">
            <AccordionTrigger className="text-muted-foreground">Prefer to build it yourself?</AccordionTrigger>
            <AccordionContent>
              <pre className="overflow-x-auto rounded-xl border border-white/10 bg-black p-4 font-mono text-[13px] leading-relaxed text-neutral-300">
                {`git clone ${REPO_URL}.git\ncd OpenNotchi\nmake install`}
              </pre>
            </AccordionContent>
          </AccordionItem>
          <AccordionItem value="requirements" className="border-white/10">
            <AccordionTrigger className="text-muted-foreground">Requirements</AccordionTrigger>
            <AccordionContent className="text-muted-foreground">
              macOS 14 Sonoma or later. Works best on a MacBook with a notch; other displays get a floating pill.
              Liquid Glass themes need macOS 26.
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      </div>
    </section>
  )
}
