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

Every asset comes from `Brand/generate.swift`:

```bash
make brand
```

This rewrites the PNG/SVG files here and `Resources/AppIcon.icns`.
