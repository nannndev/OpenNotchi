import { motion } from "motion/react"
import { Badge } from "@/components/ui/badge"

// Rendered by the app's own strip composer from placeholder portraits.
const STRIPS = [
  { src: "/photobox/receipt.jpg", name: "Receipt", tilt: -5 },
  { src: "/photobox/player.jpg", name: "Player", tilt: 3 },
  { src: "/photobox/coquette.jpg", name: "Coquette", tilt: -2 },
  { src: "/photobox/scrapbook.jpg", name: "Scrapbook", tilt: 4 },
  { src: "/photobox/film.jpg", name: "Film", tilt: -3 },
]

const FRAMES = [
  "Receipt", "Social Post", "Player", "Scrapbook", "Coquette", "Retro PC", "Film", "Polaroid", "Y2K",
  "Midnight", "Sakura", "Retro", "Newspaper", "Neon", "Pastel Grid", "Love", "Now Playing", "Classic",
]

const POINTS = [
  ["✌️", "Hold up a peace sign and the countdown starts. 👍 throws confetti."],
  ["🎵", "The Player frame shows the song you're listening to."],
  ["📐", "1 to 6 photos, as a classic strip or sized for a story, post or square."],
  ["📤", "Saved to Pictures and dropped in the Tray, ready to AirDrop."],
]

export function Photobox() {
  return (
    <section id="photobox" className="relative scroll-mt-16 overflow-hidden border-y border-white/5 bg-gradient-to-b from-white/[0.03] to-transparent py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-8">
        <div className="text-center">
          <Badge variant="outline" className="rounded-full px-3 py-1 text-xs">New in 0.4</Badge>
          <h2 className="font-display mt-5 text-[clamp(34px,5vw,54px)] leading-tight font-extrabold tracking-[-0.03em]">
            A photobooth in your notch.
          </h2>
          <p className="mx-auto mt-3.5 max-w-2xl text-[17px] text-muted-foreground">
            Open the Mirror, pick a frame and strike a pose. OpenNotchi counts down, snaps your photos and lays them
            out in one of 18 frames, with your own text if you like.
          </p>
        </div>

        <div className="mt-14 flex items-end justify-center gap-3 sm:gap-6">
          {STRIPS.map(({ src, name, tilt }, i) => (
            <motion.figure
              key={name}
              initial={{ opacity: 0, y: 30, rotate: 0 }}
              whileInView={{ opacity: 1, y: 0, rotate: tilt }}
              viewport={{ once: true, margin: "-80px" }}
              transition={{ duration: 0.6, delay: i * 0.08, type: "spring", bounce: 0.3 }}
              whileHover={{ rotate: 0, y: -8, scale: 1.04 }}
              className={`shrink-0 ${i > 2 ? "hidden md:block" : ""}`}
            >
              <img
                src={src}
                alt={`${name} photobox frame`}
                loading="lazy"
                className="h-[clamp(260px,40vw,440px)] w-auto rounded-md shadow-2xl shadow-black/60 ring-1 ring-white/10"
              />
              <figcaption className="mt-3 text-center text-xs font-medium text-muted-foreground">{name}</figcaption>
            </motion.figure>
          ))}
        </div>

        <div className="mx-auto mt-14 grid max-w-4xl gap-3 sm:grid-cols-2">
          {POINTS.map(([emoji, text]) => (
            <div key={text} className="flex items-start gap-3 rounded-2xl border border-white/10 bg-white/[0.03] p-4 text-sm leading-relaxed text-neutral-300">
              <span className="text-lg leading-none">{emoji}</span>
              {text}
            </div>
          ))}
        </div>

        <div className="mx-auto mt-10 flex max-w-4xl flex-wrap justify-center gap-2">
          {FRAMES.map((frame) => (
            <span key={frame} className="rounded-full border border-white/10 px-3 py-1 text-xs text-muted-foreground">
              {frame}
            </span>
          ))}
        </div>
      </div>
    </section>
  )
}
