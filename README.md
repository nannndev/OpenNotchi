<p align="center"><img src="brand/logo/lockup-light.png" alt="OpenNotchi" width="420"></p>

# OpenNotchi

**Website:** [opennotchi.vercel.app](https://opennotchi.vercel.app) ·
**Download:** [latest release](https://github.com/nannndev/OpenNotchi/releases/latest)

A free, open-source "dynamic notch" for macOS: hover the MacBook notch to get
now-playing controls, battery status, and a file tray with AirDrop. An
alternative to paid apps like NotchNook and Alcove.

## Features

- **Notch that expands on hover**, matching the physical camera housing (falls
  back to a pill on displays without a notch)
- **Now Playing with Spinning Vinyl Deck**: Interactive album jacket where a grooved vinyl record slides out and rotates continuously during playback, with an ambient color aura backdrop matching the album art palette
- **Complete Transport & Audio Controls**: Integrated system volume slider with 1-click mute/unmute, shuffle, repeat, and favorite heart buttons
- **Interactive Karaoke Lyrics**: Synced lyrics with depth blur, hover play cues, and 1-click seeking by tapping any lyric line
- **Closed Notch Dynamic Island**: Interactive tap on mini artwork or animated waveform to play/pause directly from the closed notch
- **Developer Tools**: Built-in **Port Inspector** for active localhost servers with 1-click process termination, screen **Color Eyedropper** (HEX, RGB, Swift), **Audio Device Switcher** with L/R channels, and **System Performance Monitor** (CPU, RAM, Network I/O)
- **Photobox & Deco Studio**: Photobooth camera with 18 trending styles and Korean Deco Studio (custom doodle frames, stars, ribbons, stamps, pins, tape) with instant export to Tray
- **Live Video Preview** of YouTube videos right in the notch
- **Spotify on other devices** (Spotify Connect): see and control playback on other devices
- **AirPods & Device Battery Drop-Down**: Detailed Left, Right, and Charging Case battery percentages with native Apple SF symbols, plus fluid spring HUD for volume and brightness
- **Tray**: drag files onto the notch to park them, drag them back out later, double-click to open, right-click for Finder/AirDrop/OCR/Format conversion
- **AirDrop & Instant OCR**: drop files on the AirDrop zone to send immediately, or drop any image / PDF onto the **Instant OCR** zone to copy recognized text to clipboard (Apple Vision offline, 0 latency)
- **Image Converter**: 1-click convert parked images to WebP, PNG, or JPEG with compression
- **Clipboard history**: text and images, searchable, click to copy again. Skips items password managers mark as concealed
- **Calendar & Meeting Reminders**: today's upcoming events next to the player, with a Join button for Zoom, Meet, Teams, Webex, and drop-down reminder banners
- **Prayer times**: the next prayer in the header and a banner at each prayer, calculated offline
- **Timer**: Pomodoro-style presets, countdown shown beside the notch while closed
- **Mirror**: camera preview up to 1080p with looks, ring light, portrait blur, and hand gestures (✌️ 👍 ✋)
- **Markets**: your own watchlist of IDX (`.JK`) and global stocks, crypto and currencies
- **Weather** in the notch header (Open-Meteo, no API key)
- **Weather** in the notch header (Open-Meteo, no API key): search a city or
  use your location
- **Auto-update** via Sparkle, from GitHub Releases
- **Global shortcut** (⌥⌘N by default, customizable) to toggle the notch;
  clicking elsewhere closes it
- **Themes**: Liquid Glass (macOS 26+), Liquid Glass Clear, Frosted, Music
  Adaptive (colors from the current cover), Album Art (blurred cover), Midnight,
  Aurora, Classic Black
- **Accent color** from the music, your Mac's accent, or a fixed color
- **Border & shape**: none / subtle / accent / music gradient / rainbow border,
  adjustable width and corner radius
- **Battery** level and charging state
- Settings: launch at login, hover delay, haptics, per-feature toggles, media sources

## Download

Grab the latest `.dmg` from the [Releases page](https://github.com/nannndev/OpenNotchi/releases/latest),
open it and drag OpenNotchi into Applications. The app isn't notarized yet, so
on first launch go to **System Settings → Privacy & Security** and click
**Open Anyway**.

## Requirements

- macOS 14 Sonoma or later (works best on a MacBook with a notch)
- Xcode 16+ / Swift 5.10+ toolchain

## Build & run

All commands run from the repo root (`make help` lists them):

```bash
make run        # debug build of the app, then launch it
make app        # release build
make install    # release build, copied to /Applications
make dist       # universal .dmg + .zip in apps/macos/dist
make web        # landing page at http://localhost:5173
make brand      # regenerate icon, logo and web assets
```

You can also open `apps/macos/Package.swift` in Xcode to edit the code. Run through
`make run` rather than Xcode, though: the app needs its `Info.plist` (from the
`.app` bundle) for the Automation permission prompt.

On first use macOS asks to let OpenNotchi control Spotify / Music (and your
browser, for YouTube). For YouTube, also turn on **Allow JavaScript from Apple
Events** in the browser (Chrome: View → Developer; Safari: Develop menu). If you said
no, re-enable it in **System Settings → Privacy & Security → Automation**.
Ad-hoc signed debug builds may ask again after a rebuild.

### Scripting

Other tools can drive the notch with a distributed notification named
`io.github.opennotchi.command` whose object is `open`, `close`, `toggle`, or a
tab name (`home`, `lyrics`, `tray`, `clipboard`, `timer`, `mirror`), or
`settings`. `peek-charging`, `peek-airpods`, `peek-volume`,
`peek-brightness`, `peek-meeting` and `peek-prayer` preview the live activities.

## Project layout

This is a small monorepo:

```
OpenNotchi/
├── apps/
│   ├── macos/          the app (Swift Package)
│   │   ├── Sources/OpenNotchi/
│   │   │   ├── App/       entry point, AppDelegate, menu bar, brand mark
│   │   │   ├── Notch/     floating panel, notch shape, hover/open state
│   │   │   ├── Views/     SwiftUI: home, lyrics, tray, clipboard, timer, settings
│   │   │   ├── Media/     Spotify / Apple Music, artwork colors, lyrics
│   │   │   ├── Theme/     themes, accents, borders
│   │   │   ├── Features/  clipboard, timer, calendar, camera
│   │   │   ├── System/    battery (IOKit), global hotkey (Carbon)
│   │   │   ├── Tray/      tray storage, AirDrop
│   │   │   └── Settings/  persisted preferences
│   │   ├── Resources/     Info.plist, AppIcon.icns
│   │   └── scripts/       build, package, release
│   └── website/        landing page (React, Vite, Tailwind, shadcn/ui)
├── brand/              brand guide and asset generator
├── .github/workflows/  CI and release
└── CHANGELOG.md
```

### Adding a media source

Implement `MediaProvider` (see `apps/macos/Sources/OpenNotchi/Media/SpotifyProvider.swift`)
and add it to `MediaManager.providers`.

## Roadmap

- [ ] Multi-display support
- [ ] Signed & notarized releases, Homebrew cask

## Releases & versioning

OpenNotchi uses [Semantic Versioning](https://semver.org/); changes are listed
in [CHANGELOG.md](CHANGELOG.md). To cut a release:

1. Add a `## [X.Y.Z] - YYYY-MM-DD` section to `CHANGELOG.md` and commit it.
2. Run `make release VERSION=X.Y.Z`.

This bumps the version in `apps/macos/Resources/Info.plist`, tags `vX.Y.Z` and pushes.
Releases are signed for Sparkle auto-update with the EdDSA key stored in the
`SPARKLE_PRIVATE_KEY` repository secret (public key: `SUPublicEDKey` in
Info.plist).
GitHub Actions then builds a universal (Apple Silicon + Intel) app and publishes
`OpenNotchi.dmg` / `.zip` on the release. `make dist` builds the same files
locally into `apps/macos/dist/`.

## Website

The landing page lives in [apps/website/](apps/website/) (React, Tailwind,
shadcn/ui) and is live at [opennotchi.vercel.app](https://opennotchi.vercel.app).

## Brand

Logo, colors and usage rules are in [brand/BRAND.md](brand/BRAND.md). Run
`make brand` to regenerate every asset.

## License

MIT. See [LICENSE](LICENSE).
# OpenNotchi
