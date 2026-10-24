export type SettingsSection = "appearance" | "animations" | "tabs" | "mirror" | "ai" | "general" | "about"

export interface SettingItem {
  id: string
  title: string
  subtitle: string
  section: SettingsSection
  keywords: string[]
  icon?: string
}

export const SETTING_ITEMS: SettingItem[] = [
  // --- Appearance ---
  {
    id: "theme",
    title: "Theme",
    subtitle: "Visual styling: Liquid Glass, Frosted Dark, Deep Black Opaque, Pure Crystal Clear, Turntable Vinyl",
    section: "appearance",
    keywords: ["theme", "style", "glass", "frosted", "opaque", "clear", "vinyl", "liquid", "tema", "tampilan"],
  },
  {
    id: "aura-glow",
    title: "Aura Glow",
    subtitle: "Dynamic ambient aura projecting behind the pill from album artwork",
    section: "appearance",
    keywords: ["aura", "glow", "ambient", "vibrant", "subtle", "artwork", "cahaya", "pendaran", "sinar"],
  },
  {
    id: "border-style",
    title: "Border Style & Width",
    subtitle: "Outline styling: None, Subtle Highlight, Neon Glow, Rainbow Prism, and thickness slider",
    section: "appearance",
    keywords: ["border", "stroke", "width", "neon", "prism", "outline", "highlight", "garis tepi", "lebar", "ketebalan"],
  },
  {
    id: "color-palette",
    title: "Color Palette & Tint",
    subtitle: "Accent color preset or auto-matched from currently playing album artwork",
    section: "appearance",
    keywords: ["accent", "color", "tint", "artwork", "palette", "emerald", "blue", "warna", "aksen"],
  },
  {
    id: "open-animation",
    title: "Open Animation",
    subtitle: "Spring opening dynamics: Fluid Classic, Bouncy Island, Waterfall Drop, Snappy Fold, Elastic Pop, 3D Spatial Flip, 3D Spatial Swing",
    section: "animations",
    keywords: ["animation", "3d", "spring", "fluid", "bouncy", "waterfall", "snappy", "spatial", "physics", "animasi", "buka"],
  },

  // --- Pill Tabs & Features ---
  {
    id: "tab-music",
    title: "Music Player & Synced Lyrics",
    subtitle: "Turntable vinyl, transport controls, and synced lyrics mode",
    section: "tabs",
    keywords: ["music", "player", "lyrics", "synced", "vinyl", "playback", "song", "lirik", "musik", "lagu", "karaoke", "terjemah"],
  },
  {
    id: "tab-clipboard",
    title: "Clipboard History",
    subtitle: "Searchable clipboard history with one-click copy",
    section: "tabs",
    keywords: ["clipboard", "history", "copy", "paste", "searchable", "papan klip", "salin", "tempel"],
  },
  {
    id: "tab-timer",
    title: "Focus & Pomodoro Timer",
    subtitle: "Quick countdown timers and interval productivity sessions",
    section: "tabs",
    keywords: ["timer", "pomodoro", "stopwatch", "focus", "countdown", "breaks", "waktu", "fokus", "hitung mundur"],
  },
  {
    id: "tab-notes",
    title: "Quick Notes & Keep Awake",
    subtitle: "Persistent scratchpad and timed screen keep-awake triggers",
    section: "tabs",
    keywords: ["notes", "keep awake", "caffeine", "scratchpad", "stay awake", "catatan", "bangun", "tidur"],
  },
  {
    id: "tab-prompter",
    title: "Teleprompter",
    subtitle: "Your script scrolls right under the camera, so you keep eye contact on calls",
    section: "tabs",
    keywords: ["teleprompter", "prompter", "script", "scroll", "speech", "camera", "naskah", "rekam", "bicara"],
  },
  {
    id: "tab-mirror",
    title: "Mirror & Photobox",
    subtitle: "Camera mirror with filters, single photos and 4-shot photobox strips",
    section: "tabs",
    keywords: ["mirror", "photobox", "camera", "selfie", "filters", "strip", "cermin", "kamera", "foto"],
  },

  // Cross-feature keywords for search (features parity with macOS)
  {
    id: "network-speed",
    title: "Network speed and traffic",
    subtitle: "Download and upload speed monitoring in the notch header",
    section: "tabs",
    keywords: ["network", "speed", "traffic", "bandwidth", "download", "upload", "jaringan", "trafik", "kecepatan", "internet"],
  },
  {
    id: "weather-forecast",
    title: "Weather and forecast",
    subtitle: "Real-time weather temperature, forecast, and location",
    section: "tabs",
    keywords: ["weather", "temperature", "forecast", "location", "cuaca", "suhu", "hujan"],
  },
  {
    id: "prayer-times",
    title: "Prayer times & Adhan",
    subtitle: "Prayer schedule, Adhan countdowns, and prayer time notifications",
    section: "tabs",
    keywords: ["prayer", "adhan", "sholat", "adzan", "waktu", "ibadah", "jadwal"],
  },
  {
    id: "markets-ticker",
    title: "Markets & Stock ticker",
    subtitle: "Stock and crypto watchlist ticker in the notch",
    section: "tabs",
    keywords: ["markets", "stocks", "crypto", "ticker", "watchlist", "saham", "kripto", "bursa"],
  },

  // --- Mirror & Photobox ---
  {
    id: "mirror-photobox",
    title: "Photobox",
    subtitle: "Pick the frame for photobox strips. Previews use sample photos",
    section: "mirror",
    keywords: ["photobox", "strip", "frame", "styles", "samples", "bingkai", "cetak", "foto"],
  },
  {
    id: "mirror-format",
    title: "Format",
    subtitle: "Strip aspect ratio: Classic, Story, Post, Square for Instagram",
    section: "mirror",
    keywords: ["format", "aspect ratio", "instagram", "story", "post", "square", "ukuran", "proporsi"],
  },
  {
    id: "mirror-photos",
    title: "Photos",
    subtitle: "Number of shots in a photobox strip (1, 2, 3, 4, or 6 photos)",
    section: "mirror",
    keywords: ["photos", "shots", "count", "strip", "number", "jumlah", "foto", "bidikan"],
  },
  {
    id: "mirror-text",
    title: "Text on the strip",
    subtitle: "Custom caption or watermark printed at the bottom of the strip",
    section: "mirror",
    keywords: ["caption", "text", "strip", "title", "watermark", "teks", "tulisan", "judul", "keterangan"],
  },
  {
    id: "mirror-camera",
    title: "Camera Device",
    subtitle: "Select the webcam device for video mirror and photobox",
    section: "mirror",
    keywords: ["camera", "device", "webcam", "videoinput", "hardware", "kamera", "perangkat"],
  },
  {
    id: "mirror-look",
    title: "Look",
    subtitle: "Camera filter look: Natural, Vintage, Noir B&W, Golden Hour, Emerald",
    section: "mirror",
    keywords: ["look", "filter", "effect", "vintage", "bw", "color", "efek", "tampilan", "filter"],
  },
  {
    id: "mirror-pinned",
    title: "Keep the notch open while using the Mirror",
    subtitle: "Prevents the notch from closing when the cursor leaves the window",
    section: "mirror",
    keywords: ["keep", "open", "pin", "pinned", "stay", "mirror", "tetap buka", "tahan"],
  },
  {
    id: "mirror-ringlight",
    title: "Ring light",
    subtitle: "Illuminate your face with a bright border around the mirror view",
    section: "mirror",
    keywords: ["ring light", "light", "lamp", "lighting", "brightness", "lampu", "terang", "pencahayaan"],
  },

  // --- AI ---
  {
    id: "ai-enabled",
    title: "Enable AI features",
    subtitle: "Master toggle: Agent status and usage are read from files on this computer. Ask AI sends text to your provider",
    section: "ai",
    keywords: ["ai", "enable", "master", "artificial intelligence", "antigravity", "claude", "codex", "aktifkan", "fitur"],
  },
  {
    id: "ai-agents",
    title: "Show Claude Code and Codex sessions",
    subtitle: "Working, needs you and done, read from their session logs every 2 seconds",
    section: "ai",
    keywords: ["claude", "codex", "antigravity", "agents", "sessions", "working", "needs you", "done", "sesi", "agen"],
  },
  {
    id: "ai-hooks",
    title: "Claude Code hooks",
    subtitle: "Instant updates and 'needs you' via curl call to 127.0.0.1:47823 in settings.json",
    section: "ai",
    keywords: ["hooks", "webhook", "curl", "port", "realtime", "instant", "cepat", "otomatis"],
  },
  {
    id: "ai-notify",
    title: "Notify when an agent finishes",
    subtitle: "Banner notification when an agent finishes or needs your input",
    section: "ai",
    keywords: ["notify", "notification", "agent", "finished", "needs you", "banner", "notifikasi", "selesai", "bunyi", "suara", "notif"],
  },
  {
    id: "ai-quota",
    title: "Quota & Accounts",
    subtitle: "Multi-account token monitoring, rate limit gauges, and reset countdowns (9router style)",
    section: "ai",
    keywords: ["quota", "accounts", "tokens", "usage", "limits", "reset", "9router", "kuota", "akun", "penggunaan", "saldo"],
  },
  {
    id: "ai-meter",
    title: "Show usage in the closed notch",
    subtitle: "Show usage in the closed notch: rate limit meter displayed on the closed pill",
    section: "ai",
    keywords: ["meter", "gauge", "closed", "notch", "pill", "rate limit", "usage", "indikator", "tutup"],
  },
  {
    id: "ai-provider",
    title: "Provider",
    subtitle: "Ask AI connection: Anthropic Claude, OpenAI, OpenRouter, Google Gemini, Ollama",
    section: "ai",
    keywords: ["provider", "anthropic", "openai", "openrouter", "ollama", "gemini", "penyedia", "layanan"],
  },
  {
    id: "ai-base-url",
    title: "Base URL",
    subtitle: "Custom API endpoint address for local models or proxy routers",
    section: "ai",
    keywords: ["base url", "url", "endpoint", "api", "host", "proxy", "alamat"],
  },
  {
    id: "ai-model",
    title: "Model",
    subtitle: "Specific LLM model to query (e.g. claude-3-7-sonnet, gpt-4o, gemini-2.5)",
    section: "ai",
    keywords: ["model", "llm", "claude", "gpt", "gemini", "sonnet", "haiku", "model"],
  },
  {
    id: "ai-key",
    title: "API key",
    subtitle: "Secret token for authenticating queries with your chosen AI provider",
    section: "ai",
    keywords: ["api key", "key", "token", "secret", "auth", "kunci", "sandi"],
  },

  // --- General & System ---
  {
    id: "general-startup",
    title: "Launch at Windows startup",
    subtitle: "Automatically launch OpenNotchi when logging in to Windows",
    section: "general",
    keywords: ["startup", "boot", "login", "auto", "launch", "windows", "mulai", "otomatis"],
  },
  {
    id: "general-mascot",
    title: "Notchi Mascot",
    subtitle: "Notchi, the mascot, when the notch is idle",
    section: "general",
    keywords: ["mascot", "notchi", "character", "idle", "pet", "waves", "maskot", "karakter", "lucu", "animasi"],
  },
  {
    id: "general-sounds",
    title: "Play sounds for important notifications",
    subtitle: "Chimes for agent status, reminders, and alerts",
    section: "general",
    keywords: ["sound", "notification", "notif", "bunyi", "suara", "alert", "chime", "hero", "glass", "ping", "nada"],
  },
  {
    id: "general-style",
    title: "Notch Style",
    subtitle: "Pin it to the top edge, float it as a pill, or hide it until you hover the top of the screen",
    section: "general",
    keywords: ["style", "pinned", "floating", "autoHide", "mode", "position", "gaya", "posisi", "sembunyi"],
  },
  {
    id: "general-monitor",
    title: "Target Monitor",
    subtitle: "Select which display should host the top-center notch pill",
    section: "general",
    keywords: ["screen", "monitor", "display", "target", "primary", "layar", "tampilan"],
  },
  {
    id: "general-reset",
    title: "Reset Preferences",
    subtitle: "Restore OpenNotchi to factory default settings",
    section: "general",
    keywords: ["reset", "default", "restore", "factory", "resetel", "ulang", "pabrik"],
  },

  // --- About ---
  {
    id: "about-version",
    title: "OpenNotchi version",
    subtitle: "Check for updates and release information",
    section: "about",
    keywords: ["version", "update", "github", "release", "tentang", "versi", "pembaruan", "info"],
  },
]

/**
 * Multi-word case-insensitive matcher:
 * Splits query on whitespace. Every word must appear somewhere in title, subtitle, section or keywords.
 */
export function matchSettingItem(item: SettingItem, query: string): boolean {
  const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean)
  if (words.length === 0) return true

  const haystack = [
    item.title,
    item.subtitle,
    item.section,
    ...item.keywords,
  ].join(" ").toLowerCase()

  return words.every((word) => haystack.includes(word))
}

/** Filters all settings by query */
export function filterSettingItems(items: SettingItem[], query: string): SettingItem[] {
  if (!query.trim()) return items
  return items.filter((item) => matchSettingItem(item, query))
}

/** Section display names and icons */
export const SECTION_METADATA: Record<SettingsSection, { label: string; icon: string }> = {
  appearance: { label: "Appearance & Themes", icon: "palette" },
  animations: { label: "Open Animations", icon: "sparkles" },
  tabs: { label: "Pill Tabs & Features", icon: "sliders" },
  mirror: { label: "Mirror & Photobox", icon: "video" },
  ai: { label: "AI", icon: "bot" },
  general: { label: "General & System", icon: "monitor" },
  about: { label: "About OpenNotchi", icon: "info" },
}

