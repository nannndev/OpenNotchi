import { AppWindow, ArrowRight, Check, Copy, Download, FolderOpen, Laptop, ShieldCheck } from "lucide-react"
import { useState } from "react"
import { AppleIcon, WindowsIcon } from "@/components/icons"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { LATEST_DMG_URL, LATEST_WINDOWS_EXE_URL, REPO_URL } from "@/lib/site"

function Step({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <li className="flex gap-4">
      <span className="font-display grid size-8 shrink-0 place-items-center rounded-full bg-white/10 text-sm font-bold">{n}</span>
      <div className="pt-1">
        <h4 className="font-semibold text-white">{title}</h4>
        <div className="mt-1 text-sm leading-relaxed text-neutral-400 [&_b]:font-semibold [&_b]:text-neutral-200">{children}</div>
      </div>
    </li>
  )
}

function CopyCommand({ command }: { command: string }) {
  const [copied, setCopied] = useState(false)
  return (
    <div className="mt-3 flex items-start gap-2 rounded-xl border border-white/10 bg-black p-3">
      <pre className="flex-1 overflow-x-auto font-mono text-[13px] leading-relaxed whitespace-pre-wrap text-neutral-300">{command}</pre>
      <button
        onClick={() => {
          navigator.clipboard?.writeText(command).then(() => {
            setCopied(true)
            setTimeout(() => setCopied(false), 1500)
          })
        }}
        className="rounded-md p-1.5 text-neutral-400 transition hover:bg-white/10 hover:text-white"
        aria-label="Copy command"
      >
        {copied ? <Check className="size-4" /> : <Copy className="size-4" />}
      </button>
    </div>
  )
}

/** Drag-to-Applications illustration for the first step. */
function DragIllustration() {
  return (
    <div className="mt-4 flex items-center justify-center gap-6 rounded-2xl border border-white/10 bg-gradient-to-b from-white/[0.04] to-transparent p-6">
      <div className="flex flex-col items-center gap-2 text-xs text-neutral-400">
        <img src="/icon.png" alt="" className="size-16" />
        OpenNotchi
      </div>
      <ArrowRight className="size-6 text-neutral-500" />
      <div className="flex flex-col items-center gap-2 text-xs text-neutral-400">
        <div className="grid size-16 place-items-center rounded-2xl bg-gradient-to-b from-sky-400 to-blue-600">
          <AppWindow className="size-8 text-white" />
        </div>
        Applications
      </div>
    </div>
  )
}

const PERMISSIONS = [
  ["Automation (Spotify, Music)", "Show what's playing and control playback", "Asked when you first play music"],
  ["Bluetooth", "Show AirPods and other devices when they connect", "Asked on first launch"],
  ["Calendar", "Today's events next to the player", "Only if you click Connect Calendar"],
  ["Location", "Weather for where you are", "Only if you choose “Use my location”"],
  ["Camera", "Mirror tab", "Only when you open Mirror"],
  ["Accessibility", "Volume & brightness HUD in the notch", "Only if you turn the HUD on"],
  ["Browser JavaScript", "YouTube in Chrome, Brave, Edge, Arc or Safari", "Turn on “Allow JavaScript from Apple Events” in the browser"],
  ["Spotify account", "Spotify playing on your iPhone or speaker", "Optional: Settings → Media → Connect Spotify"],
]

export function InstallGuide() {
  return (
    <section id="install" className="mx-auto max-w-4xl scroll-mt-16 px-4 py-24">
      <h2 className="font-display text-center text-[clamp(34px,5vw,54px)] font-extrabold tracking-[-0.03em]">How to install</h2>
      <p className="mt-3.5 text-center text-[17px] text-muted-foreground">Takes about a minute. Choose your operating system below.</p>

      <Tabs defaultValue="macos" className="mt-10">
        <TabsList className="mx-auto flex h-auto w-fit rounded-full bg-white/10 p-1">
          <TabsTrigger value="macos" className="flex items-center gap-2 rounded-full px-5 py-2 text-sm">
            <AppleIcon className="size-4" /> macOS Guide
          </TabsTrigger>
          <TabsTrigger value="windows" className="flex items-center gap-2 rounded-full px-5 py-2 text-sm">
            <WindowsIcon className="size-3.5" /> Windows Guide
          </TabsTrigger>
        </TabsList>

        {/* macOS Guide */}
        <TabsContent value="macos" className="mt-8">
          <Tabs defaultValue="install">
            <TabsList className="mx-auto flex h-auto w-fit flex-wrap justify-center rounded-full bg-white/5 p-1">
              <TabsTrigger value="install" className="rounded-full px-4">1. Install</TabsTrigger>
              <TabsTrigger value="launch" className="rounded-full px-4">2. First launch</TabsTrigger>
              <TabsTrigger value="permissions" className="rounded-full px-4">3. Permissions</TabsTrigger>
              <TabsTrigger value="more" className="rounded-full px-4">Updates &amp; more</TabsTrigger>
            </TabsList>

            <div className="mt-6 rounded-[28px] border border-white/10 bg-neutral-950 p-6 sm:p-10">
              <TabsContent value="install">
                <ol className="grid gap-6">
                  <Step n={1} title="Download the app">
                    Grab <a className="text-white underline underline-offset-4" href={LATEST_DMG_URL}>OpenNotchi.dmg</a>. It's one universal file for Apple Silicon and Intel Macs.
                  </Step>
                  <Step n={2} title="Drag it into Applications">
                    Open the downloaded <b>.dmg</b> and drag <b>OpenNotchi</b> onto the <b>Applications</b> folder.
                    <DragIllustration />
                  </Step>
                  <Step n={3} title="Open it from Applications">
                    Eject the disk image, then open OpenNotchi from <b>Applications</b> or Launchpad. There's no window: the app lives in your notch and the menu bar.
                  </Step>
                </ol>
              </TabsContent>

              <TabsContent value="launch">
                <div className="mb-6 flex gap-3 rounded-2xl border border-amber-400/20 bg-amber-400/5 p-4 text-sm text-amber-100/90">
                  <ShieldCheck className="mt-0.5 size-5 shrink-0 text-amber-300" />
                  <p>
                    OpenNotchi isn't notarized by Apple yet (that needs a paid developer account), so macOS blocks the first launch.
                    It's open source: you can read every line on <a className="underline underline-offset-4" href={REPO_URL} target="_blank" rel="noopener">GitHub</a>.
                  </p>
                </div>
                <ol className="grid gap-6">
                  <Step n={1} title="Open the app once">
                    macOS says Apple couldn't verify OpenNotchi. Click <b>Done</b> (not Move to Trash).
                  </Step>
                  <Step n={2} title="Allow it in System Settings">
                    Open <b>System Settings → Privacy &amp; Security</b>, scroll down to <b>“OpenNotchi” was blocked</b> and click <b>Open Anyway</b>. Confirm with your password or Touch ID.
                  </Step>
                  <Step n={3} title="Hover your notch">
                    That's it. Move the pointer to the notch (or press <b>⌥⌘N</b>) and it opens.
                  </Step>
                </ol>
                <p className="mt-8 text-sm text-neutral-400">
                  No Terminal needed. Only if you prefer it, this does the same as <b className="text-neutral-200">Open Anyway</b>:
                </p>
                <CopyCommand command="xattr -dr com.apple.quarantine /Applications/OpenNotchi.app" />
              </TabsContent>

              <TabsContent value="permissions">
                <p className="mb-5 text-sm text-neutral-400">
                  OpenNotchi only asks for what a feature needs, when you use it. You can change any of these later in{" "}
                  <b className="text-neutral-200">System Settings → Privacy &amp; Security</b>.
                </p>
                <div className="overflow-hidden rounded-2xl border border-white/10">
                  {PERMISSIONS.map(([name, why, when], i) => (
                    <div key={name} className={`grid gap-1 p-4 text-sm sm:grid-cols-[200px_1fr_auto] sm:items-center sm:gap-4 ${i > 0 ? "border-t border-white/10" : ""}`}>
                      <span className="font-semibold text-white">{name}</span>
                      <span className="text-neutral-400">{why}</span>
                      <span className="text-xs text-neutral-500">{when}</span>
                    </div>
                  ))}
                </div>
              </TabsContent>

              <TabsContent value="more">
                <ol className="grid gap-6">
                  <Step n={1} title="Updates install themselves">
                    From v0.2.0 on, OpenNotchi checks GitHub for new versions and offers to update. You can also click <b>Check for Updates…</b> in the menu bar icon.
                  </Step>
                  <Step n={2} title="Build from source">
                    Needs Xcode 16 or later.
                    <CopyCommand command={`git clone ${REPO_URL}.git\ncd OpenNotchi\nmake install`} />
                  </Step>
                  <Step n={3} title="Uninstall">
                    Quit from the menu bar icon, then drag OpenNotchi from Applications to the Trash.
                  </Step>
                </ol>
              </TabsContent>
            </div>
          </Tabs>
        </TabsContent>

        {/* Windows Guide */}
        <TabsContent value="windows" className="mt-8">
          <div className="rounded-[28px] border border-white/10 bg-neutral-950 p-6 sm:p-10">
            <div className="mb-6 flex gap-3 rounded-2xl border border-sky-400/20 bg-sky-400/5 p-4 text-sm text-sky-100/90">
              <Laptop className="mt-0.5 size-5 shrink-0 text-sky-300" />
              <p>
                OpenNotchi for Windows is built with <b>Tauri v2</b> (Rust + React). It runs as a lightweight top-center screen pill with pass-through clicks and hardware-accelerated spring animations.
              </p>
            </div>

            <ol className="grid gap-6">
              <Step n={1} title="Download the Windows Installer">
                Download <a className="text-white underline underline-offset-4" href={LATEST_WINDOWS_EXE_URL}>OpenNotchi-Windows-setup.exe</a> from GitHub Releases.
              </Step>
              <Step n={2} title="Run the setup (SmartScreen)">
                If Windows Defender SmartScreen shows a blue warning window, click <b>“More info”</b> and then click <b>“Run anyway”</b>. OpenNotchi is 100% open source.
              </Step>
              <Step n={3} title="Hover near the top center of your screen">
                Move your cursor to the top center of your monitor. The pill expands smoothly to show your currently playing music, synced lyrics, focus timer, clipboard, and quick notes.
              </Step>
              <Step n={4} title="Customize in Settings">
                Right-click the OpenNotchi tray icon or click the gear ⚙️ icon in the pill header to access <b>Settings</b>: choose from 8 themes, 9 opening animations, monitor selection, and autostart at login.
              </Step>
            </ol>

            <p className="mt-8 text-sm text-neutral-400">
              Want to run or build from source? Needs Node 22+ and Rust:
            </p>
            <CopyCommand command={`git clone ${REPO_URL}.git\ncd OpenNotchi/apps/windows\nnpm install\nnpm run tauri dev`} />
          </div>
        </TabsContent>
      </Tabs>

      <div className="mt-8 flex flex-wrap justify-center gap-3 text-sm text-muted-foreground">
        <a href={LATEST_DMG_URL} className="inline-flex items-center gap-2 rounded-full border border-white/10 px-4 py-2 text-white hover:border-white/30">
          <Download className="size-4" /> Download for macOS (.dmg)
        </a>
        <a href={LATEST_WINDOWS_EXE_URL} className="inline-flex items-center gap-2 rounded-full border border-sky-400/30 px-4 py-2 text-sky-200 hover:border-sky-400/50">
          <Download className="size-4" /> Download for Windows (.exe)
        </a>
        <a href={`${REPO_URL}/issues`} target="_blank" rel="noopener" className="inline-flex items-center gap-2 rounded-full border border-white/10 px-4 py-2 hover:text-white">
          <FolderOpen className="size-4" /> Stuck? Open an issue
        </a>
      </div>
    </section>
  )
}
