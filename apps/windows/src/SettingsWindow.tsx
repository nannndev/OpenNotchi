import { invoke } from "@tauri-apps/api/core"
import {
  Check,
  ChevronRight,
  ClipboardList,
  Coffee,
  Download,
  ExternalLink,
  HelpCircle,
  Info,
  Monitor,
  Music,
  Palette,
  Play,
  RotateCcw,
  RotateCw,
  Sliders,
  Sparkles,
  ScrollText,
  Timer,
  Video,
  Wand2,
  Bot,
  Search,
  X,
} from "lucide-react"
import { useEffect, useMemo, useState } from "react"
import { CURRENT_VERSION, openExternalUrl, useUpdateChecker } from "./updater"
import { AISettings } from "./AISettings"
import { MirrorSettings } from "./MirrorSettings"
import { filterSettingItems, SETTING_ITEMS, type SettingsSection } from "./settingsSearch"
import {
  ACCENT_PRESETS,
  ANIMATION_OPTIONS,
  BORDER_OPTIONS,
  DEFAULT_SETTINGS,
  NOW_PLAYING_BACKGROUNDS,
  THEME_OPTIONS,
  resolveAccentColor,
  useSettings,
  type AccentChoice,
  type BorderStyle,
  type NotchAnimationStyle,
  type NotchTheme,
} from "./settings"

interface MonitorInfo {
  name: string
  is_primary: boolean
  width: number
  height: number
}

type TabKey = "appearance" | "animations" | "tabs" | "mirror" | "ai" | "general" | "about"

export function SettingsWindow() {
  const [settings, setSettings] = useSettings()
  const [activeTab, setActiveTab] = useState<TabKey>("appearance")
  const [monitors, setMonitors] = useState<MonitorInfo[]>([])
  const [autostartEnabled, setAutostartEnabled] = useState(false)
  const [previewOpen, setPreviewOpen] = useState(false)
  const [searchQuery, setSearchQuery] = useState("")
  const { updateInfo, isChecking, error, checkNow } = useUpdateChecker()

  const filteredItems = useMemo(
    () => filterSettingItems(SETTING_ITEMS, searchQuery),
    [searchQuery]
  )
  const hasSearch = searchQuery.trim().length > 0
  const matchingSections = useMemo(() => {
    if (!hasSearch) return null
    return new Set(filteredItems.map((i) => i.section))
  }, [hasSearch, filteredItems])

  const sectionCounts = useMemo(() => {
    const counts: Record<string, number> = {}
    for (const item of filteredItems) {
      counts[item.section] = (counts[item.section] || 0) + 1
    }
    return counts
  }, [filteredItems])

  // Automatically switch tab if active tab has no matches during search
  useEffect(() => {
    if (hasSearch && matchingSections && !matchingSections.has(activeTab)) {
      const order: TabKey[] = ["appearance", "animations", "tabs", "mirror", "ai", "general", "about"]
      const first = order.find((s) => matchingSections.has(s))
      if (first) setActiveTab(first)
    }
  }, [hasSearch, matchingSections, activeTab])

  // Query monitors and autostart on mount
  useEffect(() => {
    invoke<MonitorInfo[]>("get_monitors").then(setMonitors).catch(() => {})
    invoke<boolean>("get_autostart").then(setAutostartEnabled).catch(() => {})
  }, [])

  const toggleAutostart = async () => {
    const next = !autostartEnabled
    try {
      await invoke("set_autostart", { enable: next })
      setAutostartEnabled(next)
      setSettings({ autostart: next })
    } catch (e) {
      console.error(e)
    }
  }

  const handleMonitorChange = async (name: string) => {
    setSettings({ selectedMonitor: name })
    await invoke("set_pill_monitor", { monitorName: name }).catch(() => {})
  }

  const activeAccentColor = resolveAccentColor(
    settings.accentChoice,
    "#ec4899", // sample demo album accent
    settings.customAccent,
  )

  return (
    <div className="settings-window">
      {/* Sidebar */}
      <aside className="settings-sidebar">
        <div className="sidebar-brand">
          <div className="brand-icon">
            <span className="brand-dot" />
          </div>
          <div className="brand-meta">
            <span className="brand-title">OpenNotchi</span>
            <span className="brand-version">v{CURRENT_VERSION} (Windows)</span>
          </div>
        </div>

        {/* Sidebar Search Bar */}
        <div className="sidebar-search">
          <Search size={13} className="search-icon" />
          <input
            type="text"
            className="search-input"
            placeholder="Search settings…"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
          {searchQuery && (
            <button
              className="search-clear-btn"
              onClick={() => setSearchQuery("")}
              title="Clear search"
              aria-label="Clear search"
            >
              <X size={12} />
            </button>
          )}
        </div>

        <nav className="sidebar-nav">
          {(!hasSearch || matchingSections?.has("appearance")) && (
            <button
              className={`nav-item ${activeTab === "appearance" ? "active" : ""}`}
              onClick={() => setActiveTab("appearance")}
            >
              <Palette size={16} />
              <span>Appearance & Themes</span>
              {hasSearch && sectionCounts["appearance"] && (
                <span className="nav-match-count">{sectionCounts["appearance"]}</span>
              )}
            </button>
          )}

          {(!hasSearch || matchingSections?.has("animations")) && (
            <button
              className={`nav-item ${activeTab === "animations" ? "active" : ""}`}
              onClick={() => setActiveTab("animations")}
            >
              <Sparkles size={16} />
              <span>Open Animations</span>
              {hasSearch && sectionCounts["animations"] && (
                <span className="nav-match-count">{sectionCounts["animations"]}</span>
              )}
            </button>
          )}

          {(!hasSearch || matchingSections?.has("tabs")) && (
            <button
              className={`nav-item ${activeTab === "tabs" ? "active" : ""}`}
              onClick={() => setActiveTab("tabs")}
            >
              <Sliders size={16} />
              <span>Pill Tabs & Features</span>
              {hasSearch && sectionCounts["tabs"] && (
                <span className="nav-match-count">{sectionCounts["tabs"]}</span>
              )}
            </button>
          )}

          {(!hasSearch || matchingSections?.has("mirror")) && (
            <button
              className={`nav-item ${activeTab === "mirror" ? "active" : ""}`}
              onClick={() => setActiveTab("mirror")}
            >
              <Video size={16} />
              <span>Mirror & Photobox</span>
              {hasSearch && sectionCounts["mirror"] && (
                <span className="nav-match-count">{sectionCounts["mirror"]}</span>
              )}
            </button>
          )}

          {(!hasSearch || matchingSections?.has("ai")) && (
            <button
              className={`nav-item ${activeTab === "ai" ? "active" : ""}`}
              onClick={() => setActiveTab("ai")}
            >
              <Bot size={16} />
              <span>AI</span>
              {hasSearch && sectionCounts["ai"] && (
                <span className="nav-match-count">{sectionCounts["ai"]}</span>
              )}
            </button>
          )}

          {(!hasSearch || matchingSections?.has("general")) && (
            <button
              className={`nav-item ${activeTab === "general" ? "active" : ""}`}
              onClick={() => setActiveTab("general")}
            >
              <Monitor size={16} />
              <span>General & System</span>
              {hasSearch && sectionCounts["general"] && (
                <span className="nav-match-count">{sectionCounts["general"]}</span>
              )}
            </button>
          )}

          {(!hasSearch || matchingSections?.has("about")) && (
            <button
              className={`nav-item ${activeTab === "about" ? "active" : ""}`}
              onClick={() => setActiveTab("about")}
            >
              <Info size={16} />
              <span>About OpenNotchi</span>
              {hasSearch && sectionCounts["about"] ? (
                <span className="nav-match-count">{sectionCounts["about"]}</span>
              ) : (
                updateInfo?.available && <span className="nav-update-badge">NEW</span>
              )}
            </button>
          )}
        </nav>
      </aside>

      {/* Main Content Area */}
      <main className="settings-main">
        {hasSearch && filteredItems.length === 0 ? (
          <div className="search-empty-state">
            <Search size={36} className="empty-search-icon" />
            <div className="empty-search-title">No settings found for "{searchQuery}"</div>
            <div className="empty-search-subtitle">
              Try searching for other keywords, feature names, or Indonesian synonyms.
            </div>
            <button className="clear-search-btn" onClick={() => setSearchQuery("")}>
              Clear Search
            </button>
          </div>
        ) : (
          <>
            {/* Matches Chip Row */}
            {hasSearch && filteredItems.length > 0 && (
              <div className="search-matches-row">
                <span className="matches-label">Matches:</span>
                <div className="matches-chips">
                  {filteredItems.map((item) => (
                    <button
                      key={item.id}
                      className={`match-chip ${activeTab === item.section ? "active" : ""}`}
                      onClick={() => setActiveTab(item.section)}
                      title={item.subtitle}
                    >
                      <span>{item.title}</span>
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Live Pill Preview Header */}
        <section className="settings-preview-banner">
          <div className="preview-top">
            <span className="preview-label">Live Pill Preview</span>
            <button
              className="preview-toggle-btn"
              onClick={() => setPreviewOpen(!previewOpen)}
            >
              <Play size={11} fill="currentColor" />
              <span>{previewOpen ? "Close Preview" : "Trigger Open Animation"}</span>
            </button>
          </div>

          <div className="preview-canvas" style={{ position: "relative" }}>
            {previewOpen && settings.auraGlow !== "off" && activeAccentColor !== "#ffffff" && (
              <div
                className={`preview-aura-backdrop ${settings.auraGlow === "vibrant" ? "vibrant" : "subtle"}`}
                style={{ background: activeAccentColor }}
              />
            )}
            <div
              className={`pill-preview-item theme-${settings.theme} border-${settings.borderStyle} anim-${settings.openAnimation} ${previewOpen ? "open" : ""}`}
              style={{ ["--accent" as string]: activeAccentColor, zIndex: 1 }}
            >

              <div className="preview-closed-content" aria-hidden={previewOpen}>
                <div className="preview-vinyl" />
                <span className="preview-text">Blinding Lights · The Weeknd</span>
                <span className="preview-bars">
                  <i />
                  <i />
                  <i />
                </span>
              </div>

              <div className="preview-open-content" aria-hidden={!previewOpen}>
                <div className="preview-open-top">
                  <span className="preview-tab active">🎵 Music</span>
                  <span className="preview-tab">📋 Clipboard</span>
                  <span className="preview-tab">⏱️ Timer</span>
                </div>
                <div className="preview-open-body">
                  <div className="preview-open-vinyl" />
                  <div className="preview-open-info">
                    <strong>Blinding Lights</strong>
                    <small>I'm blinded by the lights ♪</small>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Tab 1: Appearance & Themes */}
        {activeTab === "appearance" && (
          <div className="settings-section">
            <h2 className="section-title">Themes</h2>
            <p className="section-desc">Select how the pill blends with your desktop or music.</p>

            <div className="theme-grid">
              {THEME_OPTIONS.map((t) => (
                <div
                  key={t.id}
                  className={`theme-card ${settings.theme === t.id ? "selected" : ""}`}
                  onClick={() => setSettings({ theme: t.id })}
                >
                  <div className={`theme-card-preview ${t.previewClass}`}>
                    <div className="theme-mini-pill" />
                  </div>
                  <div className="theme-card-info">
                    <div className="theme-card-name">
                      {t.name}
                      {settings.theme === t.id && <Check size={14} className="check-icon" />}
                    </div>
                    <div className="theme-card-desc">{t.desc}</div>
                  </div>
                </div>
              ))}
            </div>

            <h2 className="section-title" style={{ marginTop: 28 }}>Accent Color</h2>
            <p className="section-desc">Color used for highlights, play buttons, progress rings, and lyrics.</p>

            <div className="accent-grid">
              {ACCENT_PRESETS.map((a) => {
                const isSelected = settings.accentChoice === a.id
                return (
                  <button
                    key={a.id}
                    className={`accent-chip ${isSelected ? "selected" : ""}`}
                    onClick={() => setSettings({ accentChoice: a.id })}
                  >
                    <span
                      className="accent-swatch"
                      style={{
                        background: a.id === "artwork" ? "linear-gradient(135deg, #ec4899, #8b5cf6)" : a.color,
                      }}
                    />
                    <span className="accent-name">{a.name}</span>
                    {isSelected && <Check size={12} className="chip-check" />}
                  </button>
                )
              })}
            </div>

            <h2 className="section-title" style={{ marginTop: 28 }}>Border Style</h2>
            <p className="section-desc">Stroke around the open pill boundary.</p>

            <div className="segment-group">
              {BORDER_OPTIONS.map((b) => (
                <button
                  key={b.id}
                  className={`segment-btn ${settings.borderStyle === b.id ? "active" : ""}`}
                  onClick={() => setSettings({ borderStyle: b.id })}
                >
                  {b.name}
                </button>
              ))}
            </div>

            <h2 className="section-title" style={{ marginTop: 28 }}>Aura Blur & Glow</h2>
            <p className="section-desc">Ambient lighting around the pill while open.</p>

            <div className="segment-group">
              <button
                className={`segment-btn ${settings.auraGlow === "off" ? "active" : ""}`}
                onClick={() => setSettings({ auraGlow: "off" })}
              >
                Off
              </button>
              <button
                className={`segment-btn ${settings.auraGlow === "subtle" ? "active" : ""}`}
                onClick={() => setSettings({ auraGlow: "subtle" })}
              >
                Subtle (30%)
              </button>
              <button
                className={`segment-btn ${settings.auraGlow === "vibrant" ? "active" : ""}`}
                onClick={() => setSettings({ auraGlow: "vibrant" })}
              >
                Vibrant (Full Aura)
              </button>
            </div>
          </div>
        )}

        {/* Tab 2: Open Animations */}
        {activeTab === "animations" && (
          <div className="settings-section">
            <h2 className="section-title">Open & Expand Animations</h2>
            <p className="section-desc">
              All 9 signature animation curves from OpenNotchi macOS, adapted with GPU acceleration for Windows.
            </p>

            <div className="anim-list">
              {ANIMATION_OPTIONS.map((anim) => {
                const isSelected = settings.openAnimation === anim.id
                return (
                  <div
                    key={anim.id}
                    className={`anim-row ${isSelected ? "selected" : ""}`}
                    onClick={() => {
                      setSettings({ openAnimation: anim.id })
                      setPreviewOpen(false)
                      setTimeout(() => setPreviewOpen(true), 60)
                    }}
                  >
                    <div className="anim-icon">{anim.icon}</div>
                    <div className="anim-meta">
                      <div className="anim-name">
                        <span>{anim.name}</span>
                        {anim.is3D && <span className="badge-3d">3D SPATIAL</span>}
                      </div>
                      <div className="anim-sub">{anim.subtitle}</div>
                    </div>
                    <div className="anim-action">
                      {isSelected ? (
                        <span className="selected-tag">
                          <Check size={14} /> Active
                        </span>
                      ) : (
                        <button className="preview-action-btn">Test</button>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        )}

        {/* Tab 3: Pill Tabs & Features */}
        {activeTab === "tabs" && (
          <div className="settings-section">
            <h2 className="section-title">Enabled Pill Tabs</h2>
            <p className="section-desc">Choose which views appear in the header when the pill is open.</p>

            <div className="toggle-list">
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">
                    <Music size={16} /> Music Player & Synced Lyrics
                  </div>
                  <div className="toggle-desc">Turntable vinyl, transport controls, and synced lyrics mode.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.tabMusic}
                  onChange={(e) => setSettings({ tabMusic: e.target.checked })}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">
                    <ClipboardList size={16} /> Clipboard History
                  </div>
                  <div className="toggle-desc">Searchable clipboard history with one-click copy.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.tabClipboard}
                  onChange={(e) => setSettings({ tabClipboard: e.target.checked })}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">
                    <Timer size={16} /> Focus & Pomodoro Timer
                  </div>
                  <div className="toggle-desc">Circular SVG countdown timer with quick preset chips and audio chime.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.tabTimer}
                  onChange={(e) => setSettings({ tabTimer: e.target.checked })}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">
                    <Coffee size={16} /> Quick Notes & Keep Awake
                  </div>
                  <div className="toggle-desc">Persistent scratchpad and timed screen keep-awake triggers.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.tabNotes}
                  onChange={(e) => setSettings({ tabNotes: e.target.checked })}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">
                    <ScrollText size={16} /> Teleprompter
                  </div>
                  <div className="toggle-desc">Your script scrolls right under the camera, so you keep eye contact on calls.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.tabPrompter}
                  onChange={(e) => setSettings({ tabPrompter: e.target.checked })}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">
                    <Video size={16} /> Mirror & Photobox
                  </div>
                  <div className="toggle-desc">Camera mirror with filters, single photos and 4-shot photobox strips.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.tabMirror}
                  onChange={(e) => setSettings({ tabMirror: e.target.checked })}
                />
              </div>
            </div>

            <h2 className="section-title" style={{ marginTop: 28 }}>Full-screen Player</h2>
            <p className="section-desc">
              Big cover, an album-colored background and synced lyrics. Space plays or pauses, ← → skip, T translates, L shows lyrics,
              B switches the background, Esc closes. It also opens from the ⤢ button in the pill header.
            </p>
            <div className="toggle-list">
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Full-screen player when the PC sits idle</div>
                  <div className="toggle-desc">Keep it shorter than your screen saver and display sleep.</div>
                </div>
                <input type="checkbox" className="switch" checked={settings.nowPlayingEnabled} onChange={(e) => setSettings({ nowPlayingEnabled: e.target.checked })} />
              </div>
              {settings.nowPlayingEnabled && (
                <div className="toggle-row">
                  <div className="toggle-info">
                    <div className="toggle-title">Full-screen player delay</div>
                  </div>
                  <select className="settings-select" value={settings.nowPlayingIdleMinutes} onChange={(e) => setSettings({ nowPlayingIdleMinutes: Number(e.target.value) })}>
                    {[0.5, 1, 2, 5, 10, 15].map((m) => (
                      <option key={m} value={m}>
                        {m < 1 ? "30 seconds" : `${m} minute${m === 1 ? "" : "s"}`}
                      </option>
                    ))}
                  </select>
                </div>
              )}
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Full-screen player background</div>
                </div>
                <select className="settings-select" value={settings.nowPlayingBackground} onChange={(e) => setSettings({ nowPlayingBackground: e.target.value as typeof settings.nowPlayingBackground })}>
                  {NOW_PLAYING_BACKGROUNDS.map((b) => (
                    <option key={b.id} value={b.id}>
                      {b.name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Full-screen player lyrics</div>
                </div>
                <input type="checkbox" className="switch" checked={settings.nowPlayingLyrics} onChange={(e) => setSettings({ nowPlayingLyrics: e.target.checked })} />
              </div>
              {settings.nowPlayingLyrics && (
                <>
                  <div className="toggle-row">
                    <div className="toggle-info">
                      <div className="toggle-title">Full-screen lyrics size</div>
                    </div>
                    <select className="settings-select" value={settings.nowPlayingTextScale} onChange={(e) => setSettings({ nowPlayingTextScale: Number(e.target.value) })}>
                      <option value={0.8}>Small</option>
                      <option value={1}>Medium</option>
                      <option value={1.3}>Large</option>
                    </select>
                  </div>
                  <div className="toggle-row">
                    <div className="toggle-info">
                      <div className="toggle-title">Translate lyrics into</div>
                      <div className="toggle-desc">Uses your Ask AI provider (Settings › AI), once per song.</div>
                    </div>
                    <select className="settings-select" value={settings.lyricsTranslateTarget} onChange={(e) => setSettings({ lyricsTranslateTarget: e.target.value })}>
                      <option value="">Off</option>
                      {["id", "en", "ja", "ko", "zh", "es", "fr", "de", "ar", "pt", "it", "th", "vi"].map((c) => (
                        <option key={c} value={c}>
                          {new Intl.DisplayNames([navigator.language], { type: "language" }).of(c) ?? c}
                        </option>
                      ))}
                    </select>
                  </div>
                </>
              )}
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Full-screen player clock</div>
                </div>
                <input type="checkbox" className="switch" checked={settings.nowPlayingClock} onChange={(e) => setSettings({ nowPlayingClock: e.target.checked })} />
              </div>
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Preview full-screen player</div>
                </div>
                <button className="ai-settings-btn" onClick={() => invoke("open_now_playing").catch(() => {})}>
                  Open
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Tab 4: General & System */}
        {activeTab === "general" && (
          <div className="settings-section">
            <h2 className="section-title">Startup & Display</h2>
            <p className="section-desc">Configure system integration and multi-monitor positioning.</p>

            <div className="toggle-list">
              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Launch at Windows startup</div>
                  <div className="toggle-desc">Automatically launch OpenNotchi when logging in to Windows.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={autostartEnabled}
                  onChange={toggleAutostart}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Notchi Mascot</div>
                  <div className="toggle-desc">Notchi, the mascot, when the notch is idle.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.showMascot}
                  onChange={(e) => setSettings({ showMascot: e.target.checked })}
                />
              </div>

              <div className="toggle-row">
                <div className="toggle-info">
                  <div className="toggle-title">Play sounds for important notifications</div>
                  <div className="toggle-desc">Chimes for agent status, reminders, and alerts.</div>
                </div>
                <input
                  type="checkbox"
                  className="switch"
                  checked={settings.notificationSounds}
                  onChange={(e) => setSettings({ notificationSounds: e.target.checked })}
                />
              </div>


              <div className="toggle-row" style={{ flexDirection: "column", alignItems: "flex-start", gap: 10 }}>
                <div className="toggle-info">
                  <div className="toggle-title">Notch Style</div>
                  <div className="toggle-desc">Pin it to the top edge, float it as a pill, or hide it until you hover the top of the screen.</div>
                </div>

                <div className="monitor-select-group">
                  {([
                    ["pinned", "Pinned to top"],
                    ["floating", "Floating pill"],
                    ["autoHide", "Auto-hide"],
                  ] as const).map(([id, label]) => (
                    <button
                      key={id}
                      className={`monitor-btn ${(settings.notchMode ?? "pinned") === id ? "active" : ""}`}
                      onClick={() => setSettings({ notchMode: id })}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </div>

              <div className="toggle-row" style={{ flexDirection: "column", alignItems: "flex-start", gap: 10 }}>
                <div className="toggle-info">
                  <div className="toggle-title">Target Monitor</div>
                  <div className="toggle-desc">Select which display should host the top-center notch pill.</div>
                </div>

                <div className="monitor-select-group">
                  <button
                    className={`monitor-btn ${settings.selectedMonitor === "primary" ? "active" : ""}`}
                    onClick={() => handleMonitorChange("primary")}
                  >
                    Primary Monitor (Default)
                  </button>
                  {monitors.map((m) => (
                    <button
                      key={m.name}
                      className={`monitor-btn ${settings.selectedMonitor === m.name ? "active" : ""}`}
                      onClick={() => handleMonitorChange(m.name)}
                    >
                      {m.name} ({m.width}×{m.height}) {m.is_primary ? "★" : ""}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <h2 className="section-title" style={{ marginTop: 28 }}>Reset Preferences</h2>
            <p className="section-desc">Restore OpenNotchi to factory default settings.</p>

            <button
              className="reset-btn"
              onClick={() => {
                if (confirm("Reset all settings to default?")) {
                  setSettings(DEFAULT_SETTINGS)
                }
              }}
            >
              <RotateCcw size={14} />
              <span>Reset all settings to default</span>
            </button>
          </div>
        )}

        {activeTab === "mirror" && <MirrorSettings />}

        {activeTab === "ai" && <AISettings />}

        {/* Tab 5: About */}
        {activeTab === "about" && (
          <div className="settings-section about-section">
            <div className="about-hero">
              <div className="about-logo">
                <span className="about-glow" />
                <span className="about-pill-graphic" />
              </div>
              <h2 className="about-name">OpenNotchi for Windows</h2>
              <p className="about-tagline">
                Now playing, synced lyrics, clipboard, focus timer and live activities in a smooth notch pill.
              </p>
              <span className="about-chip">Version {CURRENT_VERSION} • Built with Tauri & React</span>
            </div>

            {/* Software Update Card */}
            <div className="update-card">
              <div className="update-card-header">
                <div className="update-card-title">
                  <Sparkles size={16} color="var(--accent)" />
                  <strong>Software Updates</strong>
                </div>
                <button
                  className="check-update-btn"
                  onClick={() => checkNow()}
                  disabled={isChecking}
                >
                  <RotateCw size={12} className={isChecking ? "spin-icon" : ""} />
                  <span>{isChecking ? "Checking…" : "Check for Updates"}</span>
                </button>
              </div>

              {updateInfo?.available ? (
                <div className="update-banner">
                  <div className="update-meta">
                    <span className="update-tag">v{updateInfo.latestVersion} Available</span>
                    <h4 className="update-headline">{updateInfo.releaseName || `OpenNotchi v${updateInfo.latestVersion}`}</h4>
                    {updateInfo.releaseNotes && (
                      <p className="update-notes">
                        {updateInfo.releaseNotes.slice(0, 180)}...
                      </p>
                    )}
                  </div>
                  <div className="update-actions">
                    <button
                      className="update-action-btn primary"
                      onClick={() => openExternalUrl(updateInfo.downloadUrl)}
                    >
                      <Download size={13} />
                      <span>Download Installer (.exe)</span>
                    </button>
                    <button
                      className="update-action-btn secondary"
                      onClick={() => openExternalUrl(updateInfo.releaseUrl)}
                    >
                      <ExternalLink size={13} />
                      <span>Release Notes</span>
                    </button>
                  </div>
                </div>
              ) : (
                <div className="update-status-row">
                  <Check size={14} color="var(--green)" />
                  <span>
                    OpenNotchi is up to date (version {CURRENT_VERSION}).
                  </span>
                </div>
              )}

              {error && <div className="update-error-text">⚠️ {error}</div>}
            </div>

            <div className="about-details">
              <div className="about-card">
                <strong>Parity with macOS</strong>
                <p>
                  Includes all 8 notch visual themes (Liquid Glass, Frosted, Adaptive, Album Art, Midnight, Aurora),
                  all 9 opening animation physics, floating desktop lyrics, and privacy peeks.
                </p>
              </div>
              <div className="about-card">
                <strong>Keyboard & Mouse</strong>
                <p>
                  Hover near the top center to reveal the pill. Outside clicks pass straight through to background
                  applications.
                </p>
              </div>
            </div>
          </div>
        )}
          </>
        )}
      </main>
    </div>
  )
}
