import { ArrowRight, Download as DownloadIcon, FileArchive, Laptop } from "lucide-react"
import { AppleIcon, WindowsIcon } from "@/components/icons"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { formatCount, formatSize, useDownloadCount, useLatestRelease } from "@/hooks/use-github"
import { CHANGELOG_URL, LATEST_DMG_URL, LATEST_WINDOWS_EXE_URL, LATEST_ZIP_URL, RELEASES_URL, REPO_URL } from "@/lib/site"

export function Download() {
  const { data: release, error } = useLatestRelease()
  const downloads = useDownloadCount()
  const versioned = (ext: string) => release?.assets.find((a) => a.name.startsWith("OpenNotchi-") && a.name.endsWith(ext))
  const dmg = versioned(".dmg")
  const zip = versioned(".zip")
  const exe = release?.assets.find((a) => a.name.endsWith(".exe"))
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

        <Tabs defaultValue="macos" className="mt-8 w-full">
          <TabsList className="mx-auto mb-8 flex h-auto w-fit rounded-full bg-white/10 p-1">
            <TabsTrigger value="macos" className="flex items-center gap-2 rounded-full px-5 py-2 text-sm">
              <AppleIcon className="size-4" /> macOS
            </TabsTrigger>
            <TabsTrigger value="windows" className="flex items-center gap-2 rounded-full px-5 py-2 text-sm">
              <WindowsIcon className="size-3.5" /> Windows
            </TabsTrigger>
          </TabsList>

          <TabsContent value="macos">
            <div className="flex flex-wrap justify-center gap-3">
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
            <p className="mt-4 text-xs text-neutral-400">
              Universal binary for Apple Silicon (M1/M2/M3/M4) and Intel · macOS 14 Sonoma or later
            </p>
          </TabsContent>

          <TabsContent value="windows">
            <div className="flex flex-wrap justify-center gap-3">
              <Button size="lg" asChild className="h-12 rounded-full bg-sky-500 px-6 text-white hover:bg-sky-400">
                <a href={exe?.browser_download_url ?? LATEST_WINDOWS_EXE_URL}>
                  <DownloadIcon className="size-4" />
                  Download Windows Setup (.exe){exe && ` · ${formatSize(exe.size)}`}
                </a>
              </Button>
              <Button size="lg" variant="outline" asChild className="h-12 rounded-full px-6">
                <a href={RELEASES_URL} target="_blank" rel="noopener">
                  <Laptop className="size-4" />
                  All Windows Builds
                </a>
              </Button>
            </div>
            <p className="mt-4 text-xs text-neutral-400">
              Compatible with 64-bit Windows 10 &amp; 11 · Lightweight Tauri app (Rust + WebView2)
            </p>
          </TabsContent>
        </Tabs>

        <p className="mt-6 space-x-2 text-[13px] text-muted-foreground">
          <a className="underline-offset-4 hover:text-foreground hover:underline" href={RELEASES_URL} target="_blank" rel="noopener">All releases</a>
          <span>·</span>
          <a className="underline-offset-4 hover:text-foreground hover:underline" href={CHANGELOG_URL} target="_blank" rel="noopener">Changelog</a>
          <span>·</span>
          <a className="underline-offset-4 hover:text-foreground hover:underline" href={REPO_URL} target="_blank" rel="noopener">Source code</a>
        </p>

        {downloads !== null && downloads > 0 && (
          <div className="mt-8 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-4 py-2 text-sm">
            <DownloadIcon className="size-4 text-neutral-400" />
            <span className="font-display font-bold tabular-nums">{formatCount(downloads)}</span>
            <span className="text-muted-foreground">downloads so far</span>
          </div>
        )}

        <Separator className="my-10 bg-white/10" />

        <p className="text-sm text-neutral-400">
          Open the installer or disk image and follow the easy step-by-step setup guide.
        </p>
        <Button variant="link" asChild className="mt-1 text-white">
          <a href="#install">
            Step-by-step install guide <ArrowRight className="size-4" />
          </a>
        </Button>
      </div>
    </section>
  )
}
