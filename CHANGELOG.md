# Changelog

All notable changes to OpenNotchi are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/nannndev/OpenNotchi/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/nannndev/OpenNotchi/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/nannndev/OpenNotchi/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/nannndev/OpenNotchi/releases/tag/v0.1.0
