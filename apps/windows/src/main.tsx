import { StrictMode } from "react"
import { createRoot } from "react-dom/client"
import { LyricsWidget } from "./LyricsWidget"
import { Pill } from "./Pill"
import { SettingsWindow } from "./SettingsWindow"
import "./styles.css"

const hash = location.hash
const isLyrics = hash === "#lyrics"
const isSettings = hash === "#settings"

document.documentElement.dataset.window = isLyrics ? "lyrics" : isSettings ? "settings" : "pill"

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    {isLyrics ? <LyricsWidget /> : isSettings ? <SettingsWindow /> : <Pill />}
  </StrictMode>,
)
