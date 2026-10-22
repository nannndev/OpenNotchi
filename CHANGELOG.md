# Changelog

All notable changes to OpenNotchi are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [0.9.0] - 2026-10-22

### Added
- **Desktop Lyrics Widget**: A floating karaoke widget on every Space, showing the line being sung and the next one. Drag it anywhere, resize it from the corner grip (the text scales with it), set the background from fully clear to solid, or lock it so clicks pass through. Toggle it from the player, lyrics mode, the `⋯` menu or Settings; a reset brings it back if it gets lost.
- **Translated Lyrics**: Lyrics translated on-device with Apple's Translation framework (free, offline, no API key). Translations appear in amber italics under each line in the notch and the desktop widget. The source language is detected automatically, and translation retries on its own once a language pack finishes downloading.
- **Shareable Lyric Cards**: Pick a run of consecutive lines and export a 1080×1350 card in five styles: Aura (blurred artwork), Player (Now Playing screen with a progress bar set to the chosen line), Polaroid, Solid and Paper. Optional translations; copy, save to Pictures › OpenNotchi, or share through AirDrop and Messages.
- **Notes Tab**: A scratchpad that saves as you type, with **Keep Awake** (15 min, 1 h, 2 h or until turned off) and an **Apple Shortcuts** runner.
- **Camera & Microphone Peek**: A pill beside the notch whenever any app starts using the camera or microphone.
- **Download Finished Banner**: Files that finish downloading into ~/Downloads drop out of the notch with an Open button.

### Changed
- Secondary player buttons (favorite, desktop lyrics, translate, share) share one consistent chip style; the lyrics-mode actions sit in their own column beside the lyrics.

## [0.8.0] - 2026-10-14

### Added
- **3D Spatial Show/Hide Animations**: Authentic 3D perspective animations for opening and closing OpenNotchi, anchoring directly to the top camera bezel with physical spring physics and top edge specular highlight sheen:
  - **📦 3D Trapdoor Flip (`flip3D`)**: The entire notch swings downward from the top camera bezel on a 3D hinge axis (`-88°` to `0°` rotation) with wide-angle perspective (`0.55`), realistic mechanical momentum, top specular bevel highlight, and flipping contents.
  - **🔮 3D Holographic Depth (`depth3D`)**: Spatial z-space projection combining `-55°` tilt, deep z-depth scale (`0.38` to `1.0`), and floating spring dampening, materializing like a floating glass HUD.
  - **🎲 3D Cube Roll (`cube3D`)**: High-angle geometric cube roll (`-95°` to `0°`) rotating down like a facet of a 3D spatial cube on compound diagonal axes.
  - Selectable directly in **Settings > Appearance > Open Animation** with live preview buttons, and in the Notch Header quick menu (three-dot button).
- **Smarthome & Climate/Lighting Hub**: Advanced smart device control center directly within the notch with three dedicated operational decks:
  - **❄️ AC & Climate Control Deck**: Interactive thermostat dial with +/- steppers, current vs target room temperature indicator, 1-tap mode switcher (Cool, Eco, Dry, Fan, Off), fan speed presets, and mode-adaptive ambient aura lighting.
  - **💡 Smart Lighting Studio**: Glowing bulb toggles with warm ambient bloom, custom fluid brightness sliders (0–100%), and warmth presets.
  - **🔌 Smart Switches & Plugs**: 1-click toggles for fans, coffee makers, and monitors with live wattage power monitor.
  - **🎬 Instant Quick Scenes**: 1-tap presets for "Focus Work", "Movie Night", "Sleep", and "All Off".
  - **Dynamic Island Heads-Up Peek**: Instant drop-down pill feedback whenever AC temperature or lamps are adjusted.
  - **Home Assistant REST API & Apple Shortcuts**: Connect to local Home Assistant servers via Bearer token with auto-discovery, Apple Shortcuts execution, and built-in interactive offline simulation mode.
- **Multi-Display & External Monitor Support**: Seamlessly displays OpenNotchi across multi-monitor setups with 3 selectable display targets in Settings:
  - **Built-in Screen Only**: Pinned strictly to the physical MacBook camera notch (or primary display).
  - **Follow Active Screen**: Automatically moves to whichever display your mouse cursor is on.
  - **All Connected Screens**: Spawns on every monitor simultaneously, showing full live activities on all screens with single-notch expand coordination.
- **Floating Dynamic Island Pill**: On external monitors or Macs without a physical notch, OpenNotchi renders as an elegant floating Dynamic Island capsule pill with smooth 360° rounded corners, subtle dark glass border, ambient drop shadow, and a top-edge bumper hover trigger.

## [0.7.0] - 2026-10-13

### Added
- **Webcam Eye-Contact Teleprompter Tab**: Smooth auto-scrolling presentation script directly beneath the camera notch for natural 100% eye contact during Zoom, Google Meet, and Teams video calls. Features adjustable scroll speed presets (Slow, Normal, Fast, Turbo), live camera preview guide, spacebar pause/resume, font scaling, and transparent HUD background.
- **Dual Analog VU Meter & 9-Band Spectrum Deck**: 112×112pt hi-fi audio deck with dual ballistic stylus needles, overload redline scale, responsive peak LED indicators, and 9-band digital equalizer with falling peak caps. One-tap interactive toggle between Analog VU Meter and Graphic Spectrum Analyzer.
- **Symmetrical Apple Desk Calendar Glass Card**: Symmetrical 112×112pt desk calendar companion card matching the left vinyl turntable with clean day number, weekday accent banner, upcoming event status, and video meeting join button.
- **Keyless Ad-Hoc Keychain Safety**: Suppressed unwanted Keychain authorization alerts when Spotify Remote is disabled for a smoother first-launch experience.

## [0.6.0] - 2026-10-13

### Added
- **Interactive Turntable Deck & Vinyl Stylus**: Realistic tonearm with ruby stylus cartridge that drops onto the record when playing and lifts when paused.
- **4 Selectable Artwork & Vinyl Styles**: Vinyl Only (Turntable), Center Cover with Vinyl Platter (Halo), Slide-out Vinyl Sleeve, and Standard Square artwork.
- **Interactive DJ Scratching**: Drag circularly on the vinyl record to scratch with haptic feedback ticks on every groove and real-time audio scrub seeking.
- **Closed Notch Live Vinyl Activity**: Matching mini spinning vinyl disc in the closed notch pill with real grooves, center label, spindle hole, tap-to-toggle play/pause, and right-click style switcher.
- **6 Notch Open Animation Styles**: Choose your notch opening personality: Fluid Classic (Apple balanced), Bouncy Island (jelly spring), Waterfall Drop (-65pt cascade from bezel), Snappy Pro (160ms instant), Elastic Pop (0.58 scale 3D pop), and Gentle Float (0.68s slow-motion).
- **Dynamic Island Update Notification Banner**: Real-time drop-down update notification banner directly from the notch when a new release is available, with one-click update and header pill indicator.
- **Device Access Control & Audio Routing**: Microphone input selection, input gain calibration, and output device routing directly in DevTools and Settings.

### Added
- **Spinning Vinyl Record Deck & Sleeve**: Interactive album jacket where a grooved vinyl disc slides out and spins continuously while playing, featuring concentric microgrooves, specular sheen, and circular center artwork label
- **Ambient Backdrop Aura**: Dynamic blurred ambient lighting behind the player matching the dominant colors extracted from the album artwork palette, with gentle breathing animation
- **Full Transport & Volume Controls**: Integrated volume slider with instant click-to-mute, shuffle toggle, repeat toggle, loved/favorite track button, and glowing play/pause button
- **Interactive Karaoke Lyrics**: Hover preview with play cue, click-to-seek timestamp jumping, depth-of-field distance blur, and rounded glowing karaoke typography for the active lyric line
- **Closed Notch Dynamic Island Live Activity**: Interactive tap-to-toggle play/pause directly on the mini artwork and dancing waveform when the notch is closed
- **Developer Tools Tab**: Active local port inspector with process killer, screen eyedropper color picker with 1-click HEX/RGB copy, audio output device manager with L/R channel balance, and real-time CPU/RAM/Network gauges
- **Photobox Sticker & Deco Studio**: Korean photobooth-style sticker editor with custom doodle frames, cute stars, ribbons, stamps, pins, tape, drag/rotate/scale placement, and instant export to the Tray
- **AirPods & Device Battery Drop-Down Banner**: Detailed Left earbud, Right earbud, and Charging Case battery levels with native Apple SF symbols, plus fluid spring HUD capsule for system volume, brightness, and mic mute status

## [0.4.0] - 2026-10-12

### Added
- Meeting reminders: a banner drops out of the notch before calendar events
  (1 to 15 minutes, or off), with a Join button for Zoom, Google Meet, Teams,
  Webex and FaceTime links. Optionally only for events with a call link
- Join buttons on today's events next to the player
- Prayer times: the next prayer rotates in the header, with a banner at each
  prayer and an optional heads-up before it. Calculated on your Mac (no data
  sent) with Kemenag, MWL, ISNA, Egypt, Umm al-Qura, JAKIM and Diyanet methods
  and Hanafi Asr. Imsak and an iftar message during Ramadan
- Optional sound with reminders
- Mirror: drag the bottom edge to make it taller (double-click to toggle),
  seven looks (Natural, Vivid, Warm, Cool, Film, Mono, Dreamy), a ring light
  that brightens your face, and a camera picker
- Mirror photos: a shutter button with a 3-2-1 countdown and flash; photos
  are saved to Pictures › OpenNotchi and dropped into the Tray
- Mirror hand gestures, recognized on your Mac: ✌️ takes a photo, 👍 throws
  confetti, ✋ toggles the ring light
- Mirror backgrounds: portrait blur, or the album art of the song that's
  playing behind you, gently pulsing while music plays
- Photobox: four shots with a countdown, laid out as a strip in one of twelve
  styles (Classic, Midnight, Film, Polaroid, Y2K, Sakura, Retro, Newspaper,
  Neon, Pastel Grid, Love and Now Playing), saved and dropped into the Tray.
  Write your own text on the strip, or keep each style's title
- Mirror pane in Settings with live previews of every photobox style
- The photobox button opens a style picker right in the mirror, with live
  previews, your strip text and a Start button
- Six trending photobox styles: Receipt, Social Post, Player (with the song
  that's playing), Scrapbook, Coquette and Retro PC
- Photobox takes 1, 2, 3, 4 or 6 photos, and makes a classic strip or a
  picture sized for a Story (9:16), a Post (4:5) or a Square (1:1); the photos
  are arranged in the grid that fits best
- The Mirror tab stays open when the pointer leaves it (click elsewhere to
  close), and never closes in the middle of a countdown

- AirDrop progress: the AirDrop zone shows "Pick a device", a progress ring
  while sending and a check when done, also beside the closed notch
- Tray items show real thumbnails (photos, PDFs, videos) instead of file icons

### Fixed
- Dragging a Tray item onto the AirDrop zone did nothing
- The strip text prompt opened behind the tall Mirror and couldn't be closed;
  the text is now typed right in the style picker
- AirDrop window closing by itself or never finishing, because the sharing
  service was released right after it opened

### Changed
- The location in Settings is shared by weather and prayer times
- Reminders that arrive while the notch is open show once it closes
- Mirror runs at the camera's best resolution (up to 1080p) and renders at
  full Retina sharpness

## [0.3.0] - 2026-10-12

### Added
- YouTube and YouTube Music in Chrome, Brave, Edge, Arc and Safari: title,
  channel, thumbnail, progress and playback controls
- Live video preview: a muted copy of the YouTube video plays in the notch,
  in sync with the browser, while the notch is open
- Spotify on other devices: connect your Spotify account to see (and with
  Premium, control) what's playing on your iPhone, speaker or TV, with lyrics
- Markets tab: a watchlist of Indonesian and global stocks, indices, crypto and
  currencies with intraday sparklines; tickers also rotate in the header.
  Search and reorder tickers in Settings. Delayed quotes from Yahoo Finance.

## [0.2.0] - 2026-10-12

### Added
- Auto-update with Sparkle: "Check for Updates…" in the menu bar and Settings,
  plus automatic background checks
- Live activities beside the notch when a charger or AirPods / Bluetooth
  device connects, with battery level when the device reports it
- Optional volume and brightness HUD in the notch (needs Accessibility access)
- Weather in the notch header from Open-Meteo: search a city or use your
  location, Celsius or Fahrenheit
- Customizable global shortcut (default ⌥⌘N)

### Changed
- Lyrics moved from their own tab into Home: tap the button on the artwork to
  switch between the player and synced lyrics

## [0.1.0] - 2026-10-12

First public release.

### Added
- Notch that expands on hover, matching the MacBook camera housing
- Now Playing for Spotify and Apple Music with artwork, seekable progress and controls
- Synced lyrics from LRCLIB, in a Lyrics tab and under the song title
- Live activity beside the closed notch for music and timers
- Tray: park files in the notch, drag them back out, AirDrop them
- Clipboard history with search (skips password-manager copies)
- Today's calendar events, Pomodoro timer, camera mirror
- Battery status
- Themes: Liquid Glass, Liquid Glass Clear, Frosted, Music Adaptive, Album Art,
  Midnight, Aurora, Classic Black; accent colors including "From music"
- Adjustable border style, border width and corner radius
- Global shortcut ⌥⌘N, launch at login, sidebar Settings window
- Monochrome brand: app icon, logo, wordmark and menu bar icon

[Unreleased]: https://github.com/nannndev/OpenNotchi/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/nannndev/OpenNotchi/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/nannndev/OpenNotchi/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/nannndev/OpenNotchi/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/nannndev/OpenNotchi/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/nannndev/OpenNotchi/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/nannndev/OpenNotchi/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/nannndev/OpenNotchi/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nannndev/OpenNotchi/releases/tag/v0.1.0
