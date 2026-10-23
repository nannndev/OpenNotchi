import { motion } from "motion/react"
import {
  Boxes, CalendarClock, Camera, CandlestickChart, Clipboard, CloudSun, Coffee, Disc3, Download, Headphones, Home, Inbox,
  Languages, MessageSquareQuote, Monitor, MoonStar, Palette, PictureInPicture2, ScrollText, Share2, ShieldCheck, Sliders,
  Smartphone, StickyNote, Terminal, Timer, Webcam, type LucideIcon,
} from "lucide-react"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

type Feature = { icon: LucideIcon; title: string; body: string }

// Grouped so the section stays two rows tall instead of one long wall of 27 cards.
const GROUPS: { id: string; label: string; features: Feature[] }[] = [
  {
    id: "music",
    label: "Music & lyrics",
    features: [
      { icon: Disc3, title: "Now playing", body: "Spotify, Apple Music and YouTube on a vinyl you can scratch, with VU meters and a spectrum." },
      { icon: MessageSquareQuote, title: "Synced lyrics", body: "Lines light up as they're sung. Click one to jump there." },
      { icon: PictureInPicture2, title: "Desktop lyrics", body: "A floating karaoke widget you can drag, resize and fade to just the words." },
      { icon: Languages, title: "Translated lyrics", body: "Each line translated on your Mac, offline and free, right under the original." },
      { icon: Share2, title: "Lyric cards & videos", body: "Share a few lines as a card or a lyric video with your own background and music." },
      { icon: Sliders, title: "Hi-Fi audio decks", body: "Dual ballistic analog VU needle meters and a 9-band digital graphic equalizer." },
      { icon: Smartphone, title: "Spotify on any device", body: "Playing on your phone or a speaker? See it and control it from your Mac." },
    ],
  },
  {
    id: "work",
    label: "Work",
    features: [
      { icon: Timer, title: "Focus timer", body: "Pomodoro focus and breaks that cycle on their own and stay beside the notch." },
      { icon: CalendarClock, title: "Meeting reminders", body: "A heads-up drops out of the notch before each event, with one-click Join." },
      { icon: ScrollText, title: "Teleprompter", body: "Your notes scroll right under the camera, so you keep eye contact on calls." },
      { icon: StickyNote, title: "Quick notes", body: "A scratchpad in the notch that saves as you type, plus your Apple Shortcuts." },
      { icon: Clipboard, title: "Clipboard history", body: "Find and re-copy recent text and images. Password managers are skipped." },
      { icon: Inbox, title: "Tray and AirDrop", body: "Park files on the notch, or drop them on AirDrop and watch them go." },
      { icon: Terminal, title: "Dev ports", body: "See what's running on localhost and stop it in a click." },
    ],
  },
  {
    id: "everyday",
    label: "Everyday",
    features: [
      { icon: CloudSun, title: "Weather and calendar", body: "Today's weather and your next events, one hover away." },
      { icon: MoonStar, title: "Prayer times", body: "The next prayer in the header and a reminder at each one, worked out on your Mac." },
      { icon: Home, title: "Smart home & AC", body: "Control AC temperature, lighting dimmers, and smart plugs via Home Assistant and Shortcuts." },
      { icon: Camera, title: "Photobox", body: "Strips in 18 frames, sized for a story or post, decorated with stickers and stamps." },
      { icon: CandlestickChart, title: "Markets", body: "IDX and global stocks, indices, crypto and currencies in a watchlist you choose." },
    ],
  },
  {
    id: "system",
    label: "System & style",
    features: [
      { icon: Headphones, title: "Live activities", body: "AirPods battery, charging, and a volume and brightness HUD beside the notch." },
      { icon: Webcam, title: "Camera & mic alerts", body: "A pill lights up the moment any app starts using your camera or microphone." },
      { icon: Coffee, title: "Keep awake", body: "Stop your Mac sleeping for 15 minutes, an hour, or until you say so." },
      { icon: Download, title: "Download done", body: "Finished downloads drop out of the notch with a button to open them." },
      { icon: Palette, title: "Make it yours", body: "Themes that follow your music, nine open animations, your own shortcut." },
      { icon: Boxes, title: "3D spatial animations", body: "3D Trapdoor Flip, Holographic Depth, and Cube Roll swinging down with top-hinged physics." },
      { icon: Monitor, title: "macOS & Windows parity", body: "Swift for macOS and Rust + Tauri for Windows, sharing all 8 themes, 9 animations, and synced lyrics." },
      { icon: ShieldCheck, title: "Private by design", body: "No account, no tracking. Gestures and prayer times run on your Mac." },
    ],
  },
]

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-8">
      <h2 className="font-display text-center text-[clamp(34px,5vw,54px)] leading-tight font-extrabold tracking-[-0.03em]">
        Everything, one hover away.
      </h2>
      <p className="mt-3.5 text-center text-[17px] text-neutral-400">No subscriptions and nothing locked. It's all in the free download.</p>

      <Tabs defaultValue={GROUPS[0].id} className="mt-12 w-full">
        <TabsList className="mx-auto flex h-auto w-fit max-w-full justify-start overflow-x-auto rounded-full bg-white/10 p-1 [scrollbar-width:none]">
          {GROUPS.map((g) => (
            <TabsTrigger key={g.id} value={g.id} className="shrink-0 rounded-full px-4 py-2 text-sm">
              {g.label}
              <span className="ml-1.5 text-xs text-neutral-500">{g.features.length}</span>
            </TabsTrigger>
          ))}
        </TabsList>

        {GROUPS.map((g) => (
          <TabsContent key={g.id} value={g.id} className="mt-12">
            <div className="grid gap-x-10 gap-y-11 sm:grid-cols-2 lg:grid-cols-4">
              {g.features.map(({ icon: Icon, title, body }, i) => (
                <motion.div
                  key={title}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.35, delay: i * 0.04 }}
                  className="border-t border-white/10 pt-5"
                >
                  <Icon className="size-5 text-neutral-300" strokeWidth={1.7} />
                  <h3 className="font-display mt-3.5 text-[17px] font-bold">{title}</h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-neutral-400">{body}</p>
                </motion.div>
              ))}
            </div>
          </TabsContent>
        ))}
      </Tabs>
    </section>
  )
}
