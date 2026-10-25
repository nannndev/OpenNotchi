import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { LyricsShareWindow } from "./LyricsShareWindow"
import { LyricsWidget } from "./LyricsWidget"
import { NowPlayingScreen } from "./NowPlayingScreen"
import { Pill } from "./Pill"
import { SettingsWindow } from "./SettingsWindow"
import "./styles.css"

const hash = location.hash
const isLyrics = hash === "#lyrics"
const isSettings = hash === "#settings"
const isShare = hash === "#share"
const isNowPlaying = hash === "#nowplaying"

document.documentElement.dataset.window = isNowPlaying
  ? "nowplaying"
  : isLyrics
  ? "lyrics"
  : isSettings
  ? "settings"
  : isShare
  ? "share"
  : "pill"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {isNowPlaying ? (
      <NowPlayingScreen />
    ) : isLyrics ? (
      <LyricsWidget />
    ) : isSettings ? (
      <SettingsWindow />
    ) : isShare ? (
      <LyricsShareWindow />
    ) : (
      <Pill />
    )}
  </StrictMode>,
)
