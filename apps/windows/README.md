# OpenNotchi for Windows

A port of OpenNotchi to Windows, built with [Tauri v2](https://tauri.app) (Rust + React + TypeScript).
Windows laptops have no notch, so it lives in a sleek pill at the top center of the screen that expands smoothly with spring physics and 3D animations.

## What works

- **Themes & Customization**:
  - 8 visual themes: Classic Black, Liquid Glass, Liquid Glass (Clear), Frosted, Music Adaptive, Album Art, Midnight, and Aurora.
  - Dynamic album art accent colors, Windows system accent, or custom preset palettes.
  - Border styles (Subtle, Accent, Gradient, Rainbow) and ambient aura glow effects.
- **9 Signature Open Animations** (macOS Parity):
  - Fluid Classic, Bouncy Island, Waterfall Drop, Snappy Pro, Elastic Pop, Gentle Float, 3D Trapdoor Flip, 3D Holographic Depth, and 3D Cube Roll.
- **Header & Tabs**:
  - **Music**: Now playing vinyl turntable, transport controls (play/pause, seek, skip), and synced scrolling lyrics with mini-player.
  - **Clipboard**: Searchable clipboard history with instant copy and delete.
  - **Timer**: Focus / Pomodoro countdown timer with SVG ring, presets (1m, 5m, 10m, 15m, 25m, 50m), and audio chime.
  - **Notes**: Persistent scratchpad notes and timed keep-awake screen triggers (15m, 1h, 2h, Indefinite).
- **Floating Desktop Lyrics**:
  - Drag, resize, adjust background transparency, lock clicks-through, and hide/toggle with synchronized tray and pill status.
- **Settings Window**:
  - Dedicated modern settings window accessible from the tray icon or the pill header.
  - Real-time live pill preview, startup at login (autostart), and multi-monitor positioning.
- **Privacy & System**:
  - Camera & Microphone "IN USE" hardware peeks.
  - Keep-awake coffee chip.
  - System tray with lyrics toggle, settings, and quit options.

## Run it

Needs Node 22+, Rust, and the [Tauri prerequisites for Windows](https://tauri.app/start/prerequisites/) (WebView2 ships with Windows 10/11).

```powershell
cd apps/windows
npm install
npm run tauri dev      # run with hot reload
npm run tauri build    # installer in src-tauri/target/release/bundle/
npm test               # unit tests
```

On macOS, `npm run tauri dev` also works for UI development: it shows a demo song when Windows media session is unavailable.
