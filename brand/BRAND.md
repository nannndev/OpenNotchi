# OpenNotchi Brand

Clean, monochrome and quietly playful: a notch that comes alive with music.

## Logo

| Asset | File | Use |
|---|---|---|
| App icon | `icon/AppIcon-1024.png`, `icon/AppIcon.svg` | Dock, Finder, website hero, App Store-style listings |
| Mark | `logo/mark.svg`, `logo/mark.png` | Favicon, avatars, small spaces |
| Mark (mono) | `logo/mark-mono.svg` | Menu bar, single-color print. Uses `currentColor` |
| Lockup, light bg | `logo/lockup-light.svg/.png` | README, docs, light websites |
| Lockup, dark bg | `logo/lockup-dark.svg/.png` | Dark websites, social banners |

Icon options (light/dark tone × center artwork) live in `icon/options/`, see
`overview.png`. The app ships the combination set by `selectedTone` and
`selectedVariant` in `generate.swift`.

**The mark**: the OpenNotchi notch (flat top, outward ears, soft rounded
bottom) with a five-bar waveform inside. The waveform is always five bars,
tallest in the middle.

**Clear space**: keep at least the height of the waveform's tallest bar empty
around the mark and lockup.

**Don't**: rotate the mark, change the bar count, add color, put the mark on
busy photos, or stretch the lockup.

## Colors

Monochrome only. Contrast and depth come from greys, light and shadow, not hue.

| Name | Hex | Role |
|---|---|---|
| **Black** | `#000000` | Primary: the notch, text on light backgrounds |
| **White** | `#FFFFFF` | Primary: waveform, text on dark backgrounds |
| Snow | `#F5F5F7` | Light backgrounds |
| Mist | `#E5E5EA` | Waveform mid-tone, subtle fills |
| Silver | `#D1D1D6` | Waveform tip, light-tile shading |
| Ash | `#8E8E93` | "Notchi" in the wordmark, secondary text |
| Graphite | `#3A3A3C` | Dark tile top, notch highlight |
| Charcoal | `#1C1C1E` | Dark surfaces |

**Gradients**
- Light tile: White → `#D6D6DB`, with a soft white sheen under the notch
- Dark tile: Graphite → `#0E0E10`
- Notch: Graphite/Charcoal → Black, top to bottom
- Waveform: White → Mist → Silver

**Wordmark**: "Open" in Black (or White on dark), "Notchi" in Ash.

## Typography

- **Wordmark & headings**: SF Pro Rounded, Bold. On the web, fall back to
  `ui-rounded`, then Nunito.
- **Body**: SF Pro Text / `system-ui`.
- The name is written **OpenNotchi**: one word, capital O and N.

## Regenerating

Every asset comes from `brand/generate.swift`. From the repo root:

```bash
make brand
```

This rewrites the PNG/SVG files here, `apps/macos/Resources/AppIcon.icns` and the
icons and social card in `apps/website/public/`.

## Marketing

`marketing/showcase.png` (2400×1350) shows the app with demo content only: no
real album art, videos or personal data. To refresh it:

1. Run the app and post `demo-on` to `io.github.opennotchi.command` (see the
   README's Scripting section), then open each view with `player`, `lyrics`,
   `markets`, `timer` and the `peek-*` commands.
2. Capture the notch panel window with `screencapture -o -l <window id>` into a
   folder as `home.png`, `lyrics.png`, `markets.png`, `timer.png`,
   `closed-music.png`, `peek-charging.png`, `peek-airpods.png`, `peek-volume.png`.
3. `swift brand/marketing/showcase.swift <folder> brand/marketing/showcase.png`
4. For the link preview, add `og`:
   `swift brand/marketing/showcase.swift <folder> og2x.png og`, then
   `sips -z 630 1200 og2x.png --out apps/website/public/og.png` and copy it to
   `brand/social/og.png`. Bump `?v=` on the `og:image` URL in
   `apps/website/index.html` so feeds fetch the new image.
5. Post `demo-off` when done.

### Showcase video

`marketing/showcase.mp4` (1920×1080, 60 fps, 40 s, not committed) is rendered
from captures of the real app:

1. Post `demo-on` and `pin` (keeps the notch open), then capture the notch window
   for `closed-music`, `home` (`player`), `lyrics`, `markets`, `mirror` and
   `picker` (`photobox`, wait for the previews), then `unpin` and capture
   `meeting`, `prayer` (`peek-meeting`, `peek-prayer`) and the `peek-*` live
   activities. Capture `theme-<name>.png` for albumArt, adaptive, aurora,
   midnight and classic with the `theme-<name>` command. Set the weather place
   to a plain city name first; it shows on the prayer banner.
2. `swiftc -O -o render brand/marketing/video.swift` (copy it to `main.swift`
   first), then `./render <shots> apps/website/public/photobox brand/marketing/showcase.mp4`.
3. Post `demo-off` and restore any settings you changed.

