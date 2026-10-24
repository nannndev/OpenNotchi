# Windows port: prompts

Bring the Windows app up to date with the latest macOS work. Run the prompts **one at a time, in order**: each one is
self-contained, and you review and test before starting the next. Paste the **Shared context** block at the top of every prompt.

---

## Shared context (paste before every prompt)

```
You are working in the OpenNotchi repo. The Windows app is in apps/windows (Tauri 2 + React 19 + TypeScript,
Rust backend in apps/windows/src-tauri). The macOS app in apps/macos (Swift/SwiftUI) is the reference: match its
behavior, labels, defaults and timings unless told otherwise.

Rules:
- Only edit files under apps/windows. Never edit apps/macos, apps/website or docs.
- Keep the Rust side compiling on macOS too (#[cfg(windows)] with a fallback), because the app is also run with
  `npx tauri dev` on a Mac.
- Don't add a dependency for a few lines. Prefer what's already in package.json / Cargo.toml.
- Pure logic gets a small unit test: `node --test` files in src/*.test.ts (import with the .ts extension, like the
  existing tests), Rust #[cfg(test)] tests in the same file.
- Done means, from apps/windows: `npx tsc --noEmit` clean, `npm test` passes, `npm run build` ok; from
  apps/windows/src-tauri: `cargo check` and `cargo test` pass. Report what you verified and how, and what you
  simplified compared with macOS.
- Don't commit; leave changes in the working tree for review.
```

---

## Prompt 1: 9router as the usage source

```
Add 9router support to the AI tab's Usage section, like the macOS app.

Read first:
- apps/macos/Sources/OpenNotchi/Features/NineRouterService.swift (the whole file)
- AIUsageManager.refresh in apps/macos/Sources/OpenNotchi/Features/AIUsage.swift
- The 9router parts of apps/macos/Sources/OpenNotchi/Views/AIView.swift (search isFrom9Router) and
  apps/macos/Sources/OpenNotchi/Views/AISettings.swift (the "9router Multi-Account Sync" section and the
  Quota & Accounts footer)
- On Windows: src-tauri/src/ai.rs, src/ai.ts, src/tabs/AITab.tsx, src/AISettings.tsx

How 9router works:
- Home: ~/.9router (Windows: %USERPROFILE%\.9router). SQLite at db/data.sqlite:
  - providerConnections(id, provider, authType, name, email, priority, isActive, data, …)
  - usageHistory(timestamp, provider, model, connectionId, promptTokens, completionTokens, cost, …)
- Daemon at http://127.0.0.1:20128. Header x-9r-cli-token = first 16 hex chars of
  SHA256(machineId + "9r-cli-auth" + cliSecret), where machineId is the file `machine-id` and cliSecret the file
  `auth/cli-secret` (both trimmed).
- Live quotas: GET /api/usage/<connectionId> → { plan, quotas: { <name>: { used, total, remaining,
  remainingPercentage, resetAt, unlimited } } }.

Behavior to match:
1. If ~/.9router/db/data.sqlite exists, build one usage card per connection: today's tokens and cost and a 7-day
   sparkline from usageHistory, plus live quotas and plan from the daemon (2 s timeout; if the daemon is down, show
   the database numbers without quotas).
2. Quota grouping: if a connection's quotas include any of gemini_session, claude_gpt_session, gemini_weekly,
   claude_gpt_weekly, show ONLY those, in that order, labelled "Gemini (5h)", "Claude & GPT (5h)",
   "Gemini (Weekly)", "Claude & GPT (Weekly)". Otherwise show every quota sorted by name.
   (NineRouterService.displayQuotas on macOS.) This matches the 9router dashboard; without it Antigravity shows 15
   rows of per-model quotas.
3. No double counting: when 9router returned accounts, skip local folder accounts whose tool 9router already covers.
   Those folders still feed the Agents list. Add only folders for tools 9router doesn't cover.
4. Settings footer under the accounts list: when 9router is available, "Usage comes from 9router for every tool it
   routes, so these folders aren't counted twice. They still power the Agents list, and add usage for tools 9router
   doesn't cover." Otherwise "Folders to read sessions and usage from. Add one per account (e.g. a second
   CLAUDE_CONFIG_DIR)."
5. The toggle that turns a connection on or off calls the daemon like setConnectionActive on macOS.

Do the SQLite reads and daemon calls in Rust. For SQLite prefer rusqlite with the "bundled" feature; use the
existing ureq for HTTP; add sha2 only if no hashing crate is present.

Tests: token derivation (fixed inputs → expected 16-char hex), quota grouping (pools present → 4 labelled rows in
order; no pools → all, sorted), and the no-double-count merge.

Verify read-only against the real ~/.9router on this machine (do NOT toggle connections) and report what the Usage
tab shows: accounts, and the Antigravity pools with their percentages.
```

---

## Prompt 2: Notchi, the mascot

```
Add Notchi, the mascot, to the closed pill, like the macOS app.

Read first: apps/macos/Sources/OpenNotchi/Views/NotchiMascot.swift (all of it), and in
apps/macos/Sources/OpenNotchi/Views/NotchRootView.swift: isMascotVisible, where NotchiIdleRow and NotchiLive are
used (idle slot, music row, AI meter row), and the bodySize "notchiOnly" width rule. On Windows: src/Pill.tsx and
src/settings.ts.

What Notchi is:
- The logo's 5-bar waveform come alive, no face. Rest heights 0.42, 0.68, 1, 0.68, 0.42.
- Port NotchiMascot.level(i, mood, t, gaze) exactly as a pure TS function and unit-test it (every mood, values stay
  within 0.12…1 after clamping, idle crest moves toward the gaze).
- Moods and their priority (port notchiMood): alert (an agent needs you) > loved (petted in the last 4 s) >
  busy (agent working) > tired (battery ≤ 15% and not charging, if Windows exposes it, else skip) > vibing (music
  playing) > happy (agent finished in the last 8 s) > sleepy (idle > 10 min, or hour ≥ 23 or < 5) > idle.
- A finished agent only counts as "done" for 8 seconds (recentAgentStates on macOS); after that Notchi stops
  cheering.
- Look: bar gradient white → accent, double glow whose strength depends on the mood (strong for alert/loved/vibing,
  faint for tired/sleepy), orange for alert and pink for loved. Accent = the pill's accent (the artwork color while
  music plays); a plain white accent becomes silver #D1D1D6.
- Extras: a drifting "z" (sleepy), a blinking orange "!" (alert), rising ♪/♫ (vibing), hearts after a pet, and a
  squash-and-spring on pet.

Right side of the row (port NotchiStatus):
- busy: a spinning ring with a sparkle in the middle; happy: green check with a bounce; alert: orange raised hand
  that wiggles; loved: pink heart (heart in a circle after 3 pets in a row); tired: red low battery, pulsing;
  vibing: music note, pulsing; sleepy: moon with zz, pulsing. Use lucide icons and CSS animations.
- idle: rotate every 6 s through the next prayer (only if the Windows app has prayer times, otherwise skip), the
  weather (skip if there is none) and the clock. Icon on top, tiny label under it, in the same square as Notchi.

Layout (this was a user complaint on macOS, get it exact):
- Both sides use the same square (pill height − 10), centered in equal-width slots, with the same vertical center.
- When only Notchi is showing, the closed pill is narrower (macOS: each side = notch height + 12), not as wide as for
  network-speed text.
- While music plays, Notchi (vibing) replaces the waveform/equalizer on the right of the music row; the artwork on
  the left stays.
- Notchi shows only when nothing else claims the slot (music, timer, peeks, network speed, AI meter), except the
  two places above.

Setting showMascot, default true, label "Notchi, the mascot, when the notch is idle", next to the other closed-pill
toggles.

Visual check: a throwaway harness HTML with mocked invoke, served with `npx vite --port 4793`, screenshots of every
mood on a white accent and on a colored accent. Fix what looks off, then delete the harness and stop vite.
```

---

## Prompt 3: Hovering and petting Notchi

```
On Windows, hovering anywhere on the closed pill opens it, so Notchi can never be played with. Fix that like macOS.

Read first: src-tauri/src/lib.rs (cursor_in_pill, watch_hover, set_pill_size), the hover listener in src/Pill.tsx,
and on macOS: isOverMascot in apps/macos/Sources/OpenNotchi/Notch/NotchViewModel.swift and hoverStrip /
isNotchiInteractive in apps/macos/Sources/OpenNotchi/Views/NotchRootView.swift.

Behavior:
- Pointer over Notchi: the pill does NOT open. Notchi scales to 1.15 and goes "loved". The pointer must still reach
  the webview there, so Notchi gets hover and clicks (don't let set_ignore_cursor_events swallow it).
- Moving from Notchi onto the rest of the pill opens it as usual (after the normal delay).
- Click Notchi to pet it: a short pop sound (WebAudio), floating hearts, a squash. Pets in a row add up (a pause of
  more than 6 s resets the count) and the right-side status changes: ♥ → heart in a circle at 3 pets.
- When idle, Notchi's tallest bar leans toward the pointer horizontally (gaze −1…1: the pointer's x relative to the
  pill center, divided by 400 px, clamped).

Suggested approach: the frontend reports Notchi's rect (relative to the pill, in logical px) with a new command
whenever it shows, moves or hides; watch_hover keeps the window clickable inside the pill but emits a separate
"pill-hover-mascot" state instead of "pill-hover" while the cursor is inside that rect. Keep cursor_in_pill pure and
add a Rust unit test for the "inside pill but inside the no-open rect" case.

Check with `npx tauri dev` on the Mac: hover Notchi for 2 s (pill stays closed), then move to the center of the pill
(it opens).
```

---

## Prompt 4: Notification banners with sounds

```
Make the Windows notification peeks match the new macOS banners.

Read first: Banner and BannerKind in apps/macos/Sources/OpenNotchi/Notch/Peek.swift, BannerView in
apps/macos/Sources/OpenNotchi/Views/NotchRootView.swift, the sound in NotchScreenManager.showPeek
(apps/macos/Sources/OpenNotchi/Notch/NotchScreenManager.swift), and where banners are created with a kind
(AgentMonitor.publish, ReminderCenter, the downloads banner in AppDelegate). On Windows: the peeks in src/Pill.tsx
(agentPeek, the camera/mic peek) and their CSS.

Kinds:
- success (agent finished, download finished): soft "glass" chime, stays 5 s
- attention (agent needs you, meeting starting now): brighter two-note "hero" chime, stays 10 s, pulsing dot
- reminder (prayer time, meeting soon): single "ping", stays 12 s
- info (update available): silent, 12 s
Synthesize the sounds with WebAudio (a few oscillator notes with a quick envelope), no audio files. Play the sound
once per banner even with several monitors.

Look (all tinted with the banner's color):
- beside the notch: a small glowing dot on the left (pulsing for attention) and the badge text in a tinted capsule
  on the right
- below: the icon in a radial-gradient circle with a glow that pops in with a spring, title and subtitle sliding in
  from the left, a tinted action button when there is one, a close button
- a thin countdown bar under the content that shrinks over the banner's duration
- a soft tinted glow from the bottom edge
- hovering the banner pauses auto-dismiss, like now

Setting notificationSounds, default true, label "Play sounds for important notifications".

Apply this to every banner-like peek on Windows (agent finished / needs you at minimum). Leave the small HUD-style
peeks (camera/mic in use) as they are.

Visual check: harness screenshots of a success and an attention banner; then delete the harness and stop vite.
```

---

## Prompt 5: Settings search

```
Add search to the Windows Settings window, like the macOS one, and make sure it finds every setting.

Read first: SettingItem, SettingItem.all and SettingsView in
apps/macos/Sources/OpenNotchi/Views/SettingsView.swift. On Windows: src/SettingsWindow.tsx, src/AISettings.tsx,
src/MirrorSettings.tsx and any other settings section files.

Behavior:
- A search field at the top of the sidebar.
- Index EVERY Windows setting control: go through the settings files and add one entry per toggle, select, slider
  and button that changes a setting, using the label it has on screen. Each entry: title, subtitle, section (the
  sidebar tab), keywords. Include Indonesian synonyms where people would search in Indonesian: jaringan, trafik,
  maskot, lirik, terjemah, cuaca, sholat, adzan, saham, bunyi, suara, notif.
- Matching: split the query on whitespace; every word must appear (case-insensitive) somewhere in title, subtitle,
  section or keywords, in any order. So "speed network" finds "Network speed…".
- While searching: the sidebar shows only sections with matches, each with a match count; a "Matches:" chip row
  above the content jumps to a section; no matches shows "No settings found for "<query>"" with a Clear button.

Tests:
- the matcher (word order, case, Indonesian keyword, no match)
- coverage: a test that reads the settings .tsx files, extracts the visible labels of toggles/selects with a simple
  regex, and fails if any label is missing from the index, so new settings can't be forgotten.

Visual check: harness screenshots of the sidebar with queries "network" and "lirik"; then delete the harness and
stop vite.
```

---

## After all five

```
Bump the Windows version for a release: set the same new version in apps/windows/package.json,
apps/windows/src-tauri/tauri.conf.json, apps/windows/src-tauri/Cargo.toml and the opennotchi entry in
apps/windows/src-tauri/Cargo.lock (src/updater.test.ts fails if they differ). Don't touch apps/macos; its version is
bumped by apps/macos/scripts/release.sh. Run the full Done-means checks and summarize every change since the last
release for CHANGELOG.md, but don't edit the changelog.
```
