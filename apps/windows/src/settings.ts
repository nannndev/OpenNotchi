import { emit, listen } from "@tauri-apps/api/event"
import type { MirrorEffect, StripStyle } from "./photobox"
import { useEffect, useState } from "react"

export type NotchTheme =
  | "classic"
  | "liquidGlass"
  | "liquidGlassClear"
  | "frosted"
  | "adaptive"
  | "albumArt"
  | "midnight"
  | "aurora"

export type AccentChoice =
  | "artwork"
  | "white"
  | "system"
  | "blue"
  | "purple"
  | "pink"
  | "orange"
  | "green"
  | "custom"

export type BorderStyle = "none" | "subtle" | "accent" | "gradient" | "rainbow"

export type NotchAnimationStyle =
  | "fluid"
  | "bouncy"
  | "waterfall"
  | "snappy"
  | "pop"
  | "gentle"
  | "flip3D"
  | "depth3D"
  | "cube3D"

export type NotchMode = "pinned" | "floating" | "autoHide"

export interface AppSettings {
  theme: NotchTheme
  accentChoice: AccentChoice
  customAccent: string
  borderStyle: BorderStyle
  auraGlow: "off" | "subtle" | "vibrant"
  openAnimation: NotchAnimationStyle
  closeDelayMs: number
  autostart: boolean
  selectedMonitor: string
  /** pinned: attached to the top edge; floating: a detached pill; autoHide: hidden until the top edge is hovered. */
  notchMode: NotchMode
  // Enabled tabs in the open pill
  tabMusic: boolean
  tabClipboard: boolean
  tabTimer: boolean
  tabNotes: boolean
  tabPrompter: boolean
  tabMirror: boolean
  // Teleprompter
  prompterScript: string
  /** Scroll speed in px/s. */
  prompterSpeed: number
  prompterFontSize: number
  prompterMirror: boolean
  // Mirror & photobox
  mirrorEffect: MirrorEffect
  photoboxStyle: StripStyle
  // Notes content persistence
  notesText: string
}

export const THEME_OPTIONS: { id: NotchTheme; name: string; desc: string; previewClass: string }[] = [
  { id: "classic", name: "Classic Black", desc: "Solid deep black, sleek & minimalist", previewClass: "theme-classic" },
  { id: "liquidGlass", name: "Liquid Glass", desc: "Translucent glass with specular reflections", previewClass: "theme-liquidGlass" },
  { id: "liquidGlassClear", name: "Liquid Glass (Clear)", desc: "Ultra-clear crystal acrylic refraction", previewClass: "theme-liquidGlassClear" },
  { id: "frosted", name: "Frosted", desc: "Mica acrylic blur with subtle depth", previewClass: "theme-frosted" },
  { id: "adaptive", name: "Music Adaptive", desc: "Smooth dynamic gradient from album art", previewClass: "theme-adaptive" },
  { id: "albumArt", name: "Album Art", desc: "Blurred full artwork backdrop with soft vignette", previewClass: "theme-albumArt" },
  { id: "midnight", name: "Midnight", desc: "Deep cosmic indigo & violet nebula", previewClass: "theme-midnight" },
  { id: "aurora", name: "Aurora", desc: "Northern lights teal, purple & emerald mesh", previewClass: "theme-aurora" },
]

export const ACCENT_PRESETS: { id: AccentChoice; name: string; color: string }[] = [
  { id: "artwork", name: "From music", color: "var(--accent)" },
  { id: "white", name: "White", color: "#ffffff" },
  { id: "system", name: "Windows Blue", color: "#0078d4" },
  { id: "blue", name: "Azure Blue", color: "#3b82f6" },
  { id: "purple", name: "Purple", color: "#a855f7" },
  { id: "pink", name: "Hot Pink", color: "#ec4899" },
  { id: "orange", name: "Warm Orange", color: "#f97316" },
  { id: "green", name: "Mint Green", color: "#22c55e" },
]

export const ANIMATION_OPTIONS: {
  id: NotchAnimationStyle
  name: string
  subtitle: string
  icon: string
  is3D: boolean
}[] = [
  { id: "fluid", name: "Fluid Classic", subtitle: "Halus, natural & seimbang (standar macOS)", icon: "🌊", is3D: false },
  { id: "bouncy", name: "Bouncy Island", subtitle: "Elastis & membal seperti Dynamic Island", icon: "✨", is3D: false },
  { id: "waterfall", name: "Waterfall Drop", subtitle: "Meluncur turun dari balik tepi atas layar", icon: "💧", is3D: false },
  { id: "snappy", name: "Snappy Pro", subtitle: "Sangat responsif tanpa jeda untuk produktivitas", icon: "⚡", is3D: false },
  { id: "pop", name: "Elastic Pop", subtitle: "Penuh energi dengan hentakan skala magnetik", icon: "🎯", is3D: false },
  { id: "gentle", name: "Gentle Float", subtitle: "Gerakan mengambang lembut & sinematik", icon: "🍃", is3D: false },
  { id: "flip3D", name: "3D Trapdoor Flip", subtitle: "Ayunan engsel 3D berputar dari tepi atas", icon: "🚪", is3D: true },
  { id: "depth3D", name: "3D Holographic Depth", subtitle: "Proyeksi spasial melayang keluar dari kedalaman z-space", icon: "🔮", is3D: true },
  { id: "cube3D", name: "3D Cube Roll", subtitle: "Rotasi sisi kubus 3D geometris berperspektif tajam", icon: "🎲", is3D: true },
]

export const BORDER_OPTIONS: { id: BorderStyle; name: string }[] = [
  { id: "none", name: "None" },
  { id: "subtle", name: "Subtle (White 15%)" },
  { id: "accent", name: "Accent Color" },
  { id: "gradient", name: "Music Gradient" },
  { id: "rainbow", name: "Animated Rainbow" },
]

const SETTINGS_KEY = "opennotchi_settings_v1"

export const DEFAULT_SETTINGS: AppSettings = {
  theme: "liquidGlass",
  accentChoice: "artwork",
  customAccent: "#6366f1",
  borderStyle: "subtle",
  auraGlow: "vibrant",
  openAnimation: "fluid",
  closeDelayMs: 300,
  autostart: false,
  selectedMonitor: "primary",
  notchMode: "pinned",
  tabMusic: true,
  tabClipboard: true,
  tabTimer: true,
  tabNotes: true,
  tabPrompter: true,
  tabMirror: true,
  prompterScript:
    "Hi everyone, thanks for joining today.\n\nKeep your eyes on this line, right under the camera, and your gaze looks natural.\n\nPress Edit to paste your own script. Scroll with the mouse wheel to jump around, and change the speed with the plus and minus buttons.",
  prompterSpeed: 28,
  prompterFontSize: 18,
  prompterMirror: false,
  mirrorEffect: "natural",
  photoboxStyle: "classic",
  notesText: "",
}

export function loadSettings(): AppSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY)
    if (!raw) return DEFAULT_SETTINGS
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) }
  } catch {
    return DEFAULT_SETTINGS
  }
}

export function saveSettings(settings: AppSettings): void {
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings))
    // Dispatch local custom event for current window
    window.dispatchEvent(new CustomEvent("opennotchi-settings-updated", { detail: settings }))
    // Broadcast to all Tauri windows (pill, settings, lyrics, share)
    emit("opennotchi-settings-changed", settings).catch(() => {})
  } catch (e) {
    console.error("Failed to save settings", e)
  }
}

export function updateSettings(partial: Partial<AppSettings>): AppSettings {
  const current = loadSettings()
  const updated = { ...current, ...partial }
  saveSettings(updated)
  return updated
}

/** Hook that subscribes to settings changes across tabs and windows */
export function useSettings(): [AppSettings, (partial: Partial<AppSettings>) => void] {
  const [settings, setSettings] = useState<AppSettings>(loadSettings)

  useEffect(() => {
    const onCustomUpdate = (e: Event) => {
      const customEvent = e as CustomEvent<AppSettings>
      if (customEvent.detail) setSettings(customEvent.detail)
    }

    const onStorage = (e: StorageEvent) => {
      if (e.key === SETTINGS_KEY && e.newValue) {
        try {
          setSettings({ ...DEFAULT_SETTINGS, ...JSON.parse(e.newValue) })
        } catch {}
      }
    }

    window.addEventListener("opennotchi-settings-updated", onCustomUpdate)
    window.addEventListener("storage", onStorage)

    // Listen for settings broadcast from other windows via Tauri event bus
    const unlisten = listen<AppSettings>("opennotchi-settings-changed", ({ payload }) => {
      setSettings(payload)
    })

    return () => {
      window.removeEventListener("opennotchi-settings-updated", onCustomUpdate)
      window.removeEventListener("storage", onStorage)
      unlisten.then((f) => f()).catch(() => {})
    }
  }, [])

  const setPartial = (partial: Partial<AppSettings>) => {
    const next = updateSettings(partial)
    setSettings(next)
  }

  return [settings, setPartial]
}

/** Resolves accent color given the chosen setting and artwork accent */
export function resolveAccentColor(choice: AccentChoice, artworkAccent: string | null, customHex: string): string {
  switch (choice) {
    case "artwork":
      return artworkAccent || "#ffffff"
    case "white":
      return "#ffffff"
    case "system":
      return "#0078d4"
    case "blue":
      return "#3b82f6"
    case "purple":
      return "#a855f7"
    case "pink":
      return "#ec4899"
    case "orange":
      return "#f97316"
    case "green":
      return "#22c55e"
    case "custom":
      return customHex || "#6366f1"
    default:
      return artworkAccent || "#ffffff"
  }
}
