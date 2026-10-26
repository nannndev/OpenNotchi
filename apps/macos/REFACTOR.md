# Refactor checklist (macOS)

Goal: no file over ~500 lines, no function over ~80 lines. Behavior must not change.
Each item = 1 commit, then `make debug` to verify.

Rules
- One type per file, grouped in a folder per feature (`Views/AI/UsageCard.swift`).
- Moving a `private struct` to its own file: drop `private` (it becomes module-internal).
- Run `make format FILES="..."` on every touched file.

## Phase 1: split files (move only, no logic change, low risk)

- [x] `Views/AIView.swift` (1916): 18 types → `Views/AI/` (AgentsSection, UsageSection, UsageCard, AnalyticsSection, AskSection, ...)
- [x] `Views/LyricsShare.swift` (1928): 16 types → `Views/LyricsShare/` (LyricsShareView, LyricCard, decorations like VinylDisc/Grain/BarcodePattern, CameraCaptureSheet, enums)
- [x] `Views/DevToolsView.swift` (1403): 11 types → `Views/DevTools/` (one file per card + Full*View)
- [x] `Views/SettingsView.swift` (1215): 14 types → `Views/Settings/` (one file per pane; move the SettingItem search list to `SettingsSearchIndex.swift`)
- [x] `Views/HomeView.swift` (1041): 17 types → `Views/Home/` (player controls, artwork/vinyl/turntable, volume bar)
- [x] `Views/NotchRootView.swift` (998): 10 types → `Views/Notch/`
- [x] `Views/MirrorView.swift` (780): 10 types → `Views/Mirror/`
- [x] `Settings/AppSettings.swift` (880): move the style enums + 3D animation modifiers out (lines 1-360); keep the `AppSettings` class alone
- [x] `Features/AgentMonitor.swift` (659), `Features/SmarthomeManager.swift` (544), `Features/AIUsage.swift` (463): move model types out of the manager files

## Phase 2: break up giant functions (real refactor, medium risk)

- [x] `Features/PhotoStrip.swift` (2301): the same `switch style` repeats in drawPhoto (353 lines), drawFooter (323), drawTrendFooter (263), drawBackground (169).
      Target: `Features/PhotoStrip/` with Composer + DrawingHelpers + `Styles/<Style>.swift` (one style per file holding its background/photo/footer).
      Verified with `OpenNotchi --strip-snapshot <dir>`: 380 renders pixel-identical before/after.
- [x] `Views/PrompterView.swift` (704): `controlToolbar` is 215 lines → subviews (`Views/Prompter/`)
- [x] `Views/PhotoboxStudioView.swift` (748): `canvasSection` and `controlsSection` → subviews (`Views/Photobox/`)
- [x] `Views/NotchiMascot.swift` (666): `drawRobot` 174 lines → antenna/headphones/ear pads/helmet/cheeks/eyes
- [x] `Views/Mirror/MirrorView.swift`: `body` 214 → 87 lines (`cameraSource`, overlays as properties, `CameraAccessPrompt`)
- [x] `Views/AI/AskSection.swift` (545): `+Header`, `+Conversation`, `+Composer`, `+Actions` extensions
- [x] `Views/LyricsShare/LyricsShareView.swift` (880): split into `+Controls`, `+LinePicker`, `+Media`, `+Export` extensions
- [x] `Views/LyricsShare/LyricCard.swift` (724): one `LyricCard+<Style>.swift` extension per style
- [x] `Features/NineRouterService.swift` (551): one NULL-safe `query()` helper replaces 7 copies of open/prepare/step/finalize; models → `NineRouterModels.swift`
- [ ] `Settings/AppSettings.swift` (524): 111 settings in one class; fine for now, split by feature group only if it keeps growing
- [ ] Any `var body` over ~100 lines found while doing phase 1 → extract subviews

## Phase 3: later (only when needed)

- [ ] Add a `Tests/` target; first tests for pure logic (PhotoStrip grid math, AIUsage parsing, ColorFormat)
- [ ] Reduce `.shared` singletons (15, used in 39 files) only where testing needs it
