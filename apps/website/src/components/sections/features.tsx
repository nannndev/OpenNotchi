import { motion } from "motion/react"
import { AirplayIcon, CandlestickChart, Clipboard, CloudSun, Inbox, MessageSquareQuote, Music, Palette, Smartphone, Sparkles, Timer, Wifi, type LucideIcon } from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"

const FEATURES: { icon: LucideIcon; title: string; body: string }[] = [
  { icon: Music, title: "Now Playing", body: "Spotify, Apple Music and YouTube in your browser, with artwork, seekable progress and controls." },
  { icon: AirplayIcon, title: "Live video preview", body: "The YouTube video you're watching plays along in the notch, muted and in sync." },
  { icon: MessageSquareQuote, title: "Synced lyrics", body: "Flip the player into lyrics mode. Lines light up as they're sung; tap one to jump there." },
  { icon: Smartphone, title: "Spotify on any device", body: "Playing on your iPhone or speaker? Connect Spotify to see it, read along and skip from your Mac." },
  { icon: CandlestickChart, title: "Markets", body: "Your own watchlist of Indonesian and global stocks, indices, crypto and currencies." },
  { icon: Inbox, title: "File tray", body: "Drop files on the notch to park them, then drag them out wherever you need." },
  { icon: Wifi, title: "AirDrop", body: "Drop a file on the AirDrop zone and it's on its way to a nearby device." },
  { icon: Clipboard, title: "Clipboard history", body: "Search and re-copy recent text and images. Password-manager copies are skipped." },
  { icon: Sparkles, title: "Live activities", body: "Charging, AirPods battery and a volume & brightness HUD, right beside the notch." },
  { icon: CloudSun, title: "Weather & calendar", body: "Today's weather, your next events and battery level, at a glance." },
  { icon: Timer, title: "Timer & mirror", body: "Pomodoro countdowns that stay visible, and a quick camera mirror." },
  { icon: Palette, title: "Make it yours", body: "Liquid Glass and music-adaptive themes, custom shortcut, and updates that install themselves." },
]

const THEMES = [
  ["Liquid Glass", "bg-gradient-to-br from-white/25 to-white/5 backdrop-blur"],
  ["Music Adaptive", "bg-gradient-to-br from-neutral-600 to-neutral-950"],
  ["Frosted", "bg-gradient-to-b from-neutral-700 to-neutral-800"],
  ["Midnight", "bg-gradient-to-br from-[#0d0f29] to-[#1f1447]"],
  ["Aurora", "bg-[radial-gradient(circle_at_0_100%,rgba(45,212,191,.5),transparent_60%),radial-gradient(circle_at_100%_0,rgba(168,85,247,.5),transparent_60%)] bg-[#08090c]"],
  ["Classic Black", "bg-black"],
]

export function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-16 px-4 py-24 sm:px-8">
      <h2 className="font-display text-center text-[clamp(34px,5vw,54px)] leading-tight font-extrabold tracking-[-0.03em]">
        Everything, one hover away.
      </h2>
      <p className="mt-3.5 text-center text-[17px] text-muted-foreground">
        No subscriptions, no locked features. Everything in the box is free.
      </p>

      <div className="mt-14 grid gap-3.5 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map(({ icon: Icon, title, body }, i) => (
          <motion.div
            key={title}
            initial={{ opacity: 0, y: 14 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: "-60px" }}
            transition={{ duration: 0.5, delay: (i % 4) * 0.06 }}
          >
            <Card className="h-full bg-gradient-to-b from-white/[0.05] to-white/[0.015] transition-all duration-300 hover:-translate-y-0.5 hover:ring-white/20">
              <CardContent>
                <div className="grid size-11 place-items-center rounded-xl bg-white/10">
                  <Icon className="size-5" strokeWidth={1.8} />
                </div>
                <h3 className="font-display mt-4 mb-2 text-lg font-bold">{title}</h3>
                <p className="text-sm leading-relaxed text-muted-foreground">{body}</p>
              </CardContent>
            </Card>
          </motion.div>
        ))}
      </div>

      <div className="mt-16 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
        {THEMES.map(([name, bg]) => (
          <div key={name} className={`flex h-24 items-end rounded-b-[26px] border border-t-0 border-white/10 px-4 pb-3 text-[13px] font-semibold ${bg}`}>
            {name}
          </div>
        ))}
      </div>
    </section>
  )
}
