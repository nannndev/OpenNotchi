import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { LyricsShareWindow } from "./LyricsShareWindow"
import { LyricsWidget } from "./LyricsWidget"
import { Pill } from "./Pill"
import { SettingsWindow } from "./SettingsWindow"
import "./styles.css"

const hash = location.hash
const isLyrics = hash === "#lyrics"
const isSettings = hash === "#settings"
const isShare = hash === "#share"

document.documentElement.dataset.window = isLyrics
  ? "lyrics"
  : isSettings
  ? "settings"
  : isShare
  ? "share"
  : "pill"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {isLyrics ? (
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
