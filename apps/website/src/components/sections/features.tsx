import { useState } from "react"
import { motion, AnimatePresence } from "motion/react"
import {
  BellRing, Bot, Boxes, CalendarClock, Camera, CandlestickChart, ChartLine, CheckCircle2, Clipboard, CloudSun, Coffee, Disc3,
  AudioWaveform, Expand, Hand, Headphones, Heart, Home, Inbox, Languages, MessageSquareQuote, MessagesSquare, Monitor, MoonStar, Palette, Paperclip,
  PictureInPicture2, ScrollText, Search, Share2, ShieldCheck, Sliders, Smile, Smartphone, Sparkles, StickyNote, Terminal, Timer,
  Wand2, Webcam,
  type LucideIcon,
} from "lucide-react"
import { AppleIcon, WindowsIcon } from "@/components/icons"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

type Platform = "all" | "macos" | "windows"

type Feature = {
  icon: LucideIcon
  title: string
  body: string
  os: "all" | "macos" | "windows"
  badgeText?: string
}

const GROUPS: { id: string; label: string; features: Feature[] }[] = [
  {
    id: "ai",
    label: "AI & Notchi",
    features: [
      { icon: MessagesSquare, title: "Notchi chat", body: "Chat with your own 9router accounts (Claude, GPT, Gemini) right in the notch. Answers stream in, and every chat is saved as a session.", os: "all" },
      { icon: Wand2, title: "Change settings by asking", body: "\"Make my notch look nicer\" or \"turn off the mascot\": Notchi knows every setting, changes it for you, and shows an Undo.", os: "all" },
      { icon: Paperclip, title: "Images, files & context", body: "Attach screenshots, images, PDFs and code, or add your clipboard, the song playing, or your AI usage to the next message.", os: "all" },
      { icon: Sparkles, title: "AI Quotas & 9router", body: "Multi-account quota tracking with real provider logos, in Cards, Compact or List layouts, plus today's top models.", os: "all" },
      { icon: ChartLine, title: "Usage analytics", body: "9router requests, tokens and cost as stacked daily bars: hover a day, see your top models, and compare with the previous period.", os: "all", badgeText: "Updated" },
      { icon: Bot, title: "Agents with their own Notchi", body: "Every Claude Code, Codex, Antigravity and Command Code session gets a Notchi acting out its state. Click one for the project, path and last message.", os: "macos", badgeText: "New" },
      { icon: Smile, title: "Notchi the mascot", body: "A little robot beside your notch with a dozen moods: focused during Pomodoro, buzzing on caffeine, dizzy if you poke it too much. Dress it up with ears, a crown or a halo.", os: "all", badgeText: "New moods" },
      { icon: Heart, title: "Interactive petting", body: "Squash/spring physics, WebAudio pop sounds, and floating hearts that level up with consecutive pets.", os: "all" },
      { icon: BellRing, title: "Notification banners", body: "Dynamic Island drop-down banners with WebAudio glass chimes, countdown tracks, and terminal jump button.", os: "all" },
      { icon: Hand, title: "Trackpad gestures", body: "Swipe on the closed notch to skip tracks, scroll its left or right side for volume and brightness, swipe the tab bar to switch tabs. Each one can be turned off.", os: "macos", badgeText: "New" },
      { icon: Search, title: "Instant settings search", body: "Spotlight-style search across all settings with English and full Indonesian keyword synonyms (jaringan, kuota, maskot, lirik).", os: "all" },
      { icon: Sparkles, title: "Apple Intelligence offline", body: "Use macOS Foundation Models and Apple Intelligence for Ask AI on supported Apple Silicon Macs with zero API key costs.", os: "macos", badgeText: "macOS 15.1+" },
      { icon: ShieldCheck, title: "Credential Manager DPAPI", body: "Keys and tokens are securely stored in the Windows Credential Manager rather than plain JSON files.", os: "windows", badgeText: "Windows Vault" },
    ],
  },
  {
    id: "music",
    label: "Music & lyrics",
    features: [
      { icon: Expand, title: "Full-screen player", body: "Opens when your computer sits idle while music plays: big cover, blurred, aurora or spinning-record backdrop, and synced lyrics with translation.", os: "all" },
      { icon: Search, title: "Search & play", body: "Search Spotify or your Music library from the notch and start a song in one click, or just ask Notchi to play it.", os: "macos", badgeText: "macOS" },
      { icon: Disc3, title: "Now playing turntable", body: "Spotify, Apple Music and YouTube on a vinyl you can scratch, with ballistic VU meters and a spectrum.", os: "all" },
      { icon: MessageSquareQuote, title: "Synced lyrics", body: "Time-synchronized LRC lines light up as they're sung. Click any line to seek immediately.", os: "all" },
      { icon: PictureInPicture2, title: "Desktop karaoke lyrics", body: "A floating lyrics widget you can drag anywhere, resize and fade to transparent text.", os: "all" },
      { icon: Languages, title: "Translated lyrics", body: "Every sung line translated beneath the original: on-device on macOS, through your AI provider on Windows.", os: "all" },
      { icon: Share2, title: "Lyric cards & videos", body: "Share standout lines as cards or export full lyric videos with your custom background video and music.", os: "all" },
      { icon: Sliders, title: "Hi-Fi analog decks", body: "Dual ballistic analog VU needle meters and a 9-band digital graphic equalizer for audiophiles.", os: "all" },
      { icon: Smartphone, title: "Windows Media Session (SMTC)", body: "Integrates directly with Windows SMTC to capture Spotify, Chrome, Edge, and media players.", os: "windows", badgeText: "SMTC Engine" },
      { icon: Headphones, title: "AppleScript & Music.app", body: "Deep native AppleScript bridging with Apple Music and Spotify on macOS for zero battery impact.", os: "macos", badgeText: "AppleScript" },
    ],
  },
  {
    id: "system",
    label: "OS Tailored & Style",
    features: [
      { icon: Monitor, title: "3 Notch Styles on Windows", body: "Choose between Pinned to top screen edge, a Floating dynamic pill below bezel, or Auto-Hide that reveals on hover.", os: "windows", badgeText: "Windows Only" },
      { icon: Palette, title: "Acrylic & Mica glass", body: "Native Windows DWM acrylic blur and mica glass composition rendering behind the pill and floating widgets.", os: "windows", badgeText: "Windows DWM" },
      { icon: Headphones, title: "AirPods battery HUD", body: "AirPods case and earbud battery levels, charging status, and audio routing HUD beside the hardware notch.", os: "macos", badgeText: "macOS Only" },
      { icon: Webcam, title: "Hardware camera alerts", body: "A glowing amber/green privacy pill lights up the moment any application activates your camera or microphone.", os: "macos", badgeText: "macOS Privacy" },
      { icon: Coffee, title: "Keep awake caffeine", body: "Prevent your Mac from sleeping for 15 minutes, 1 hour, or indefinitely with a single click from the menu bar.", os: "macos", badgeText: "macOS Only" },
      { icon: Boxes, title: "3D spatial animations", body: "3D Trapdoor Flip, Holographic Depth, and Cube Roll swinging down with top-hinged physics on both platforms.", os: "all" },
      { icon: Palette, title: "Adaptive themes", body: "Real Liquid Glass on macOS 26, Frosted Dark, and album-reactive themes. The idle notch follows your theme too.", os: "all" },
      { icon: ShieldCheck, title: "100% Private by design", body: "Zero accounts, no tracking, and zero telemetry. All agent monitoring and lyrics run locally.", os: "all" },
    ],
  },
  {
    id: "work",
    label: "Work & productivity",
    features: [
      { icon: Timer, title: "Focus timer & Pomodoro", body: "25/5 focus and break cycles shown beside the closed notch as an emptying ring, with session dots and a pulse in the last minute.", os: "all", badgeText: "Updated" },
      { icon: AudioWaveform, title: "Focus soundscapes", body: "Rain, brown noise, vinyl crackle and a crackling hearth, mixed to taste and started automatically with a focus session.", os: "macos", badgeText: "New" },
      { icon: CalendarClock, title: "Meeting reminders", body: "EventKit calendar alerts drop down before your Google Meet / Zoom calls with 1-click Join.", os: "macos", badgeText: "macOS Calendar" },
      { icon: ScrollText, title: "Teleprompter", body: "Your notes scroll right under your camera with adjustable speed and mirror mode for natural eye contact.", os: "all" },
      { icon: StickyNote, title: "Quick notes & scratchpad", body: "A scratchpad in the notch that autosaves as you type, plus quick access to Apple Shortcuts.", os: "all" },
      { icon: Clipboard, title: "Clipboard history", body: "Search and re-copy recent text and images with automatic password manager exclusion.", os: "all" },
      { icon: Inbox, title: "Tray and AirDrop target", body: "Park files on the notch shelf, or drop them into AirDrop directly from the notch.", os: "macos", badgeText: "macOS AirDrop" },
      { icon: Terminal, title: "Dev tools", body: "Localhost ports you can open or stop in one click, CPU, RAM and network, and your GitHub Actions runs, now on Windows too.", os: "all", badgeText: "New on Windows" },
      { icon: CheckCircle2, title: "CI build alerts", body: "A banner drops from the notch when a GitHub Actions workflow passes or fails, and local builds show beside the closed notch.", os: "macos", badgeText: "New" },
    ],
  },
  {
    id: "everyday",
    label: "Everyday lifestyle",
    features: [
      { icon: CloudSun, title: "Weather & forecast", body: "Live local temperatures, precipitation, and weekly forecasts one hover away.", os: "all" },
      { icon: MoonStar, title: "Prayer times & Imsak", body: "Calculates accurate local prayer times offline with discreet notifications at azan.", os: "all" },
      { icon: Home, title: "Smarthome & AC control", body: "Adjust AC temperature, lighting dimmers, and smart plugs via Home Assistant.", os: "all" },
      { icon: Camera, title: "Photobox & mirror", body: "Pose with webcam filters, ring light, and export 19 retro photo strip frames with custom stickers.", os: "all" },
      { icon: CandlestickChart, title: "Markets with live crypto", body: "IDX and global stocks and FX, with crypto (BTC, ETH) updating live every few seconds and each price showing how fresh it is.", os: "macos", badgeText: "Live crypto" },
    ],
  },
]

const PARITY_COMPARISON = [
  {
    dimension: "Form Factor & Placement",
    macos: "Hugs the physical MacBook camera notch with pixel-perfect rounded radii. Zero wasted screen space.",
    windows: "3 Placement styles: Pinned to top screen edge, Floating Dynamic Pill below bezel, or Auto-Hide mode.",
  },
  {
    dimension: "Native Architecture",
    macos: "100% Swift & AppKit, Metal rendering shaders, lightweight memory footprint.",
    windows: "High-performance Rust backend + Tauri v2 + React, with WebView2 acceleration.",
  },
  {
    dimension: "Media & Audio Integration",
    macos: "Native AppleScript bridging for Apple Music & Spotify with zero battery consumption.",
    windows: "Windows System Media Transport Controls (SMTC) supporting Spotify, Chrome, Edge & VLC.",
  },
  {
    dimension: "AI Monitoring & 9router",
    macos: "Agent logs, 9router analytics and Notchi chat through 9router, Apple Intelligence, Anthropic, OpenAI or Ollama.",
    windows: "Agent logs, 9router analytics and Notchi chat through 9router, Anthropic, OpenAI or Ollama.",
  },
  {
    dimension: "Security & Credential Vault",
    macos: "Apple Keychain Services for encrypted API keys and session tokens.",
    windows: "Windows Credential Manager (DPAPI encryption) with zero plaintext keys on disk.",
  },
  {
    dimension: "Notification Chimes",
    macos: "Native macOS NSSound audio framework with glass ping alerts.",
    windows: "Synthesized zero-latency WebAudio frequency oscillator chimes.",
  },
  {
    dimension: "Feature Parity (100% Shared)",
    macos: "Notchi chat & mascot, Full-screen player, Synced Lyrics, Lyric Video Studio, Photobox, Pomodoro, Teleprompter, Settings Search.",
    windows: "Notchi chat & mascot, Full-screen player, Synced Lyrics, Lyric Video Studio, Photobox, Pomodoro, Teleprompter, Settings Search.",
  },
]

export function Features() {
  const [platform, setPlatform] = useState<Platform>("all")

  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-8">
      <div className="text-center">
        <h2 className="font-display text-[clamp(34px,5vw,54px)] leading-tight font-extrabold tracking-[-0.03em]">
          Everything, one hover away.
        </h2>
        <p className="mt-3.5 text-[17px] text-neutral-400">
          Tailored natively for macOS hardware and Windows 10 &amp; 11 with full feature parity.
        </p>

        {/* Platform Filter Buttons */}
        <div className="mt-8 inline-flex items-center rounded-full border border-white/10 bg-neutral-900/90 p-1.5 shadow-xl backdrop-blur-md">
          <button
            onClick={() => setPlatform("all")}
            className={`rounded-full px-4 py-2 text-xs font-semibold transition ${
              platform === "all" ? "bg-white text-black shadow-md" : "text-neutral-400 hover:text-white"
            }`}
          >
            All Features
          </button>
          <button
            onClick={() => setPlatform("macos")}
            className={`inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-xs font-semibold transition ${
              platform === "macos" ? "bg-neutral-200 text-black shadow-md" : "text-neutral-400 hover:text-white"
            }`}
          >
            <AppleIcon className="size-3.5" />
            macOS Tailored
          </button>
          <button
            onClick={() => setPlatform("windows")}
            className={`inline-flex items-center gap-1.5 rounded-full px-4 py-2 text-xs font-semibold transition ${
              platform === "windows" ? "bg-sky-400 text-black shadow-md shadow-sky-500/20" : "text-neutral-400 hover:text-white"
            }`}
          >
            <WindowsIcon className="size-3" />
            Windows Tailored
          </button>
        </div>
      </div>

      <Tabs defaultValue={GROUPS[0].id} className="mt-12 w-full">
        <TabsList className="mx-auto flex h-auto w-fit max-w-full justify-start overflow-x-auto rounded-full bg-white/10 p-1 [scrollbar-width:none]">
          {GROUPS.map((g) => {
            const count = g.features.filter((f) => platform === "all" || f.os === "all" || f.os === platform).length
            return (
              <TabsTrigger key={g.id} value={g.id} className="shrink-0 rounded-full px-4 py-2 text-sm">
                {g.label}
                <span className="ml-1.5 text-xs text-neutral-500">{count}</span>
              </TabsTrigger>
            )
          })}
        </TabsList>

        {GROUPS.map((g) => {
          const visibleFeatures = g.features.filter((f) => platform === "all" || f.os === "all" || f.os === platform)

          return (
            <TabsContent key={g.id} value={g.id} className="mt-12">
              <div className="grid gap-x-10 gap-y-11 sm:grid-cols-2 lg:grid-cols-4">
                <AnimatePresence mode="popLayout">
                  {visibleFeatures.map(({ icon: Icon, title, body, os, badgeText }, i) => (
                    <motion.div
                      key={title}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, scale: 0.95 }}
                      transition={{ duration: 0.3, delay: i * 0.03 }}
                      className="group relative border-t border-white/10 pt-5"
                    >
                      <div className="flex items-center justify-between">
                        <Icon className="size-5 text-neutral-300 transition-colors group-hover:text-white" strokeWidth={1.7} />
                        {os === "macos" && (
                          <span className="inline-flex items-center gap-1 rounded-full border border-white/15 bg-white/5 px-2 py-0.5 text-[11px] font-medium text-neutral-300">
                            <AppleIcon className="size-2.5" />
                            {badgeText || "macOS"}
                          </span>
                        )}
                        {os === "windows" && (
                          <span className="inline-flex items-center gap-1 rounded-full border border-sky-400/30 bg-sky-500/10 px-2 py-0.5 text-[11px] font-medium text-sky-300">
                            <WindowsIcon className="size-2.5" />
                            {badgeText || "Windows"}
                          </span>
                        )}
                        {os === "all" &&
                          (badgeText ? (
                            <span className="rounded-full border border-emerald-400/30 bg-emerald-500/10 px-2 py-0.5 text-[10px] font-semibold text-emerald-300">
                              {badgeText}
                            </span>
                          ) : (
                            <span className="rounded-full bg-white/5 px-2 py-0.5 text-[10px] font-medium text-neutral-500">
                              Universal
                            </span>
                          ))}
                      </div>
                      <h3 className="font-display mt-3.5 text-[17px] font-bold text-white">{title}</h3>
                      <p className="mt-1.5 text-sm leading-relaxed text-neutral-400">{body}</p>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            </TabsContent>
          )
        })}
      </Tabs>

      {/* OS Comparison & Architecture Parity Card */}
      <div className="mt-20 overflow-hidden rounded-3xl border border-white/10 bg-gradient-to-b from-neutral-900/60 to-neutral-950/80 p-6 sm:p-10">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-emerald-400/30 bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-400">
              <CheckCircle2 className="size-3.5" />
              Complete Platform Parity
            </div>
            <h3 className="font-display mt-3 text-2xl font-bold text-white sm:text-3xl">
              macOS vs Windows Architecture
            </h3>
            <p className="mt-1.5 text-sm text-neutral-400">
              Engineered natively for each operating system without clunky cross-platform compromises.
            </p>
          </div>
        </div>

        <div className="mt-8 overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead>
              <tr className="border-b border-white/10 text-xs font-semibold uppercase tracking-wider text-neutral-400">
                <th className="py-3 pr-6">Feature Aspect</th>
                <th className="py-3 px-6 text-neutral-200">
                  <span className="inline-flex items-center gap-1.5">
                    <AppleIcon className="size-3.5" /> macOS Edition
                  </span>
                </th>
                <th className="py-3 pl-6 text-sky-400">
                  <span className="inline-flex items-center gap-1.5">
                    <WindowsIcon className="size-3" /> Windows 10 &amp; 11 Edition
                  </span>
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5 font-normal">
              {PARITY_COMPARISON.map((row, idx) => (
                <tr key={idx} className="transition-colors hover:bg-white/[0.02]">
                  <td className="py-4 pr-6 font-medium text-white">{row.dimension}</td>
                  <td className="py-4 px-6 text-neutral-300 leading-relaxed">{row.macos}</td>
                  <td className="py-4 pl-6 text-neutral-300 leading-relaxed">{row.windows}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  )
}
