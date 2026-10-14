import { motion } from "motion/react"
import {
  Boxes, CalendarClock, Camera, CandlestickChart, Clipboard, CloudSun, Disc3, Headphones, Home, Inbox,
  MessageSquareQuote, Monitor, MoonStar, Palette, ScrollText, ShieldCheck, Sliders, Smartphone, Terminal,
  Timer, type LucideIcon,
} from "lucide-react"

const FEATURES: { icon: LucideIcon; title: string; body: string }[] = [
  { icon: Disc3, title: "Now playing", body: "Spotify, Apple Music and YouTube on a vinyl you can scratch, with VU meters and a spectrum." },
  { icon: Home, title: "Smart home & AC", body: "Control AC temperature, lighting dimmers, and smart plugs via Home Assistant and Shortcuts." },
  { icon: Boxes, title: "3D spatial animations", body: "3D Trapdoor Flip, Holographic Depth, and Cube Roll swinging down with top-hinged physics." },
  { icon: Monitor, title: "Multi-display island", body: "Follows your active screen or floats as an island pill on external monitors." },
  { icon: MessageSquareQuote, title: "Synced lyrics", body: "Lines light up as they're sung. Click one to jump there." },
  { icon: ScrollText, title: "Teleprompter", body: "Your notes scroll right under the camera, so you keep eye contact on calls." },
  { icon: Camera, title: "Photobox", body: "Strips in 18 frames, sized for a story or post, decorated with stickers and stamps." },
  { icon: CalendarClock, title: "Meeting reminders", body: "A heads-up drops out of the notch before each event, with one-click Join." },
  { icon: MoonStar, title: "Prayer times", body: "The next prayer in the header and a reminder at each one, worked out on your Mac." },
  { icon: CandlestickChart, title: "Markets", body: "IDX and global stocks, indices, crypto and currencies in a watchlist you choose." },
  { icon: Terminal, title: "Dev ports", body: "See what's running on localhost and stop it in a click." },
  { icon: Inbox, title: "Tray and AirDrop", body: "Park files on the notch, or drop them on AirDrop and watch them go." },
  { icon: Clipboard, title: "Clipboard history", body: "Find and re-copy recent text and images. Password managers are skipped." },
  { icon: Headphones, title: "Live activities", body: "AirPods battery, charging, and a volume and brightness HUD beside the notch." },
  { icon: CloudSun, title: "Weather and calendar", body: "Today's weather and your next events, one hover away." },
  { icon: Timer, title: "Focus timer", body: "Pomodoro countdowns that stay beside the notch while you work." },
  { icon: Sliders, title: "Hi-Fi audio decks", body: "Dual ballistic analog VU needle meters and a 9-band digital graphic equalizer." },
  { icon: Smartphone, title: "Spotify on any device", body: "Playing on your phone or a speaker? See it and control it from your Mac." },
  { icon: Palette, title: "Make it yours", body: "Themes that follow your music, nine open animations, your own shortcut." },
  { icon: ShieldCheck, title: "Private by design", body: "No account, no tracking. Gestures and prayer times run on your Mac." },
]

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-8">
      <h2 className="font-display text-center text-[clamp(34px,5vw,54px)] leading-tight font-extrabold tracking-[-0.03em]">
        Everything, one hover away.
      </h2>
      <p className="mt-3.5 text-center text-[17px] text-neutral-400">No subscriptions and nothing locked. It's all in the free download.</p>

      <div className="mt-16 grid gap-x-10 gap-y-11 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map(({ icon: Icon, title, body }, i) => (
          <motion.div
            key={title}
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-40px" }}
            transition={{ duration: 0.45, delay: (i % 4) * 0.05 }}
            className="border-t border-white/10 pt-5"
          >
            <Icon className="size-5 text-neutral-300" strokeWidth={1.7} />
            <h3 className="font-display mt-3.5 text-[17px] font-bold">{title}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-neutral-400">{body}</p>
          </motion.div>
        ))}
      </div>
    </section>
  )
}
