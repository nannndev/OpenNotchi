mod ai;
mod media;
mod ninerouter;
mod system;

use std::sync::Mutex;
use std::time::Duration;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{Emitter, Manager, State, WebviewWindow};

/// Size of the visible pill in logical pixels. The window itself stays large and transparent so the
/// pill can animate inside it; clicks outside the pill pass through to the desktop.
struct PillSize(Mutex<(f64, f64)>);

/// (x, y, width, height) of Notchi relative to the pill in logical pixels.
struct MascotRect(Mutex<Option<(f64, f64, f64, f64)>>);

#[derive(serde::Serialize, Clone, Debug)]
pub struct MonitorInfo {
    pub name: String,
    pub is_primary: bool,
    pub width: u32,
    pub height: u32,
    pub scale_factor: f64,
}

/// Pins the pill window to the top center of the specified monitor or the primary monitor.
fn place_pill_on_monitor(window: &WebviewWindow, monitor_name: Option<&str>) -> tauri::Result<()> {
    let target = if let Some(name) = monitor_name {
        if let Ok(monitors) = window.available_monitors() {
            monitors.into_iter().find(|m| m.name().map(|n| n == name).unwrap_or(false))
        } else {
            None
        }
    } else {
        None
    };

    let monitor = match target {
        Some(m) => Some(m),
        None => window.primary_monitor()?,
    };

    if let Some(monitor) = monitor {
        let size = window.outer_size()?;
        let area = monitor.size();
        let x = monitor.position().x + (area.width as i32 - size.width as i32) / 2;
        window.set_position(tauri::PhysicalPosition::new(x, monitor.position().y))?;
    }
    Ok(())
}

fn place_pill(window: &WebviewWindow) -> tauri::Result<()> {
    place_pill_on_monitor(window, None)
}

/// The frontend reports the pill's target size whenever it opens, closes or peeks.
#[tauri::command]
fn set_pill_size(size: State<PillSize>, width: f64, height: f64) {
    *size.0.lock().unwrap() = (width, height);
}

/// The frontend reports Notchi's bounding box relative to the pill, so hovering Notchi does not open the pill.
#[tauri::command]
fn set_mascot_rect(
    rect: State<MascotRect>,
    x: Option<f64>,
    y: Option<f64>,
    width: Option<f64>,
    height: Option<f64>,
) {
    let mut lock = rect.0.lock().unwrap();
    if let (Some(x), Some(y), Some(w), Some(h)) = (x, y, width, height) {
        *lock = Some((x, y, w, h));
    } else {
        *lock = None;
    }
}


/// Grows or shrinks the transparent pill window (keeping it top-centered) so a taller pill, like a
/// resized Mirror, isn't clipped.
#[tauri::command]
fn set_pill_window_height(app: tauri::AppHandle, height: f64) -> Result<(), String> {
    let Some(pill) = app.get_webview_window("pill") else { return Ok(()) };
    let size = pill.inner_size().map_err(|e| e.to_string())?;
    let scale = pill.scale_factor().map_err(|e| e.to_string())?;
    let target = (height.clamp(200.0, 600.0) * scale).round() as u32;
    if size.height != target {
        pill.set_size(tauri::PhysicalSize::new(size.width, target)).map_err(|e| e.to_string())?;
    }
    Ok(())
}

/// Whether the cursor is over the visible pill right now; used when a pinned Mirror is unpinned.
#[tauri::command]
fn cursor_over_pill(app: tauri::AppHandle) -> bool {
    let Some(w) = app.get_webview_window("pill") else { return false };
    let (Ok(pos), Ok(size), Ok(scale), Ok(cursor)) = (w.outer_position(), w.outer_size(), w.scale_factor(), w.cursor_position()) else {
        return false;
    };
    let pill = *w.state::<PillSize>().0.lock().unwrap();
    cursor_in_pill((cursor.x, cursor.y), (pos.x as f64, pos.y as f64), size.width as f64, pill, scale)
}

/// Returns all available monitors with their dimensions and primary flag.
#[tauri::command]
fn get_monitors(app: tauri::AppHandle) -> Vec<MonitorInfo> {
    let mut list = Vec::new();
    if let Some(pill) = app.get_webview_window("pill") {
        let primary_name = pill.primary_monitor().ok().flatten().and_then(|m| m.name().cloned());
        if let Ok(monitors) = pill.available_monitors() {
            for m in monitors {
                let name = m.name().cloned().unwrap_or_else(|| "Display".to_string());
                let is_primary = primary_name.as_ref() == Some(&name);
                let size = m.size();
                list.push(MonitorInfo {
                    name,
                    is_primary,
                    width: size.width,
                    height: size.height,
                    scale_factor: m.scale_factor(),
                });
            }
        }
    }
    list
}

/// Moves the pill to a specific monitor.
#[tauri::command]
fn set_pill_monitor(app: tauri::AppHandle, monitor_name: String) -> Result<(), String> {
    if let Some(pill) = app.get_webview_window("pill") {
        let name_opt = if monitor_name.is_empty() || monitor_name == "primary" {
            None
        } else {
            Some(monitor_name.as_str())
        };
        place_pill_on_monitor(&pill, name_opt).map_err(|e| e.to_string())?;
    }
    Ok(())
}

/// Shows the settings window.
#[tauri::command]
fn open_settings(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(w) = app.get_webview_window("settings") {
        let _ = w.show();
        let _ = w.unminimize();
        let _ = w.set_focus();
    }
    Ok(())
}

/// Shows the lyric share card generator window.
#[tauri::command]
fn open_share_lyrics(app: tauri::AppHandle) -> Result<(), String> {
    if let Some(w) = app.get_webview_window("share") {
        let _ = w.show();
        let _ = w.unminimize();
        let _ = w.set_focus();
    }
    Ok(())
}

/// Returns whether the desktop lyrics widget is currently visible.
#[tauri::command]
fn is_lyrics_visible(app: tauri::AppHandle) -> bool {
    app.get_webview_window("lyrics")
        .and_then(|w| w.is_visible().ok())
        .unwrap_or(false)
}

/// Shows or hides the desktop lyrics widget. Showing also unlocks it, since a locked widget can't be clicked.
/// Broadcasts "lyrics-visibility-changed" so the pill button and tray stay in sync.
#[tauri::command]
fn toggle_lyrics(app: tauri::AppHandle) -> Result<bool, String> {
    let w = app.get_webview_window("lyrics").ok_or("No lyrics window")?;
    let will_show = !w.is_visible().unwrap_or(false);
    if will_show {
        w.set_ignore_cursor_events(false).map_err(|e| e.to_string())?;
        w.show().map_err(|e| e.to_string())?;
    } else {
        w.hide().map_err(|e| e.to_string())?;
    }
    let _ = app.emit("lyrics-visibility-changed", will_show);
    Ok(will_show)
}

/// Hides the desktop lyrics widget and notifies all listeners.
#[tauri::command]
fn hide_lyrics(app: tauri::AppHandle) -> Result<(), String> {
    let w = app.get_webview_window("lyrics").ok_or("No lyrics window")?;
    w.hide().map_err(|e| e.to_string())?;
    let _ = app.emit("lyrics-visibility-changed", false);
    Ok(())
}

/// True when the cursor (physical px) is over a pill of `pill` logical size, centered at the top of the window.
fn cursor_in_pill(cursor: (f64, f64), window_pos: (f64, f64), window_width: f64, pill: (f64, f64), scale: f64) -> bool {
    let left = window_pos.0 + (window_width - pill.0 * scale) / 2.0;
    cursor.0 >= left && cursor.0 <= left + pill.0 * scale && cursor.1 >= window_pos.1 && cursor.1 <= window_pos.1 + pill.1 * scale
}

/// True when the cursor (physical px) is over a sub-rect (in logical px relative to the pill) of the pill.
fn cursor_in_pill_subrect(
    cursor: (f64, f64),
    window_pos: (f64, f64),
    window_width: f64,
    pill: (f64, f64),
    subrect: (f64, f64, f64, f64),
    scale: f64,
) -> bool {
    let pill_left = window_pos.0 + (window_width - pill.0 * scale) / 2.0;
    let pill_top = window_pos.1;
    let left = pill_left + subrect.0 * scale;
    let top = pill_top + subrect.1 * scale;
    let right = left + subrect.2 * scale;
    let bottom = top + subrect.3 * scale;
    cursor.0 >= left && cursor.0 <= right && cursor.1 >= top && cursor.1 <= bottom
}

#[derive(PartialEq, Eq, Clone, Copy, Debug)]
enum HoverState {
    Outside,
    Pill,
    Mascot,
}

/// Polls the cursor so the pill reacts to hover without needing focus (like the macOS notch),
/// lets clicks through everywhere outside the pill, and treats hovering over Notchi separately
/// so the pill stays closed while Notchi is petted.
fn watch_hover(window: WebviewWindow) {
    std::thread::spawn(move || {
        // Allow WebView2 and native window 500ms to mount and stabilize before polling
        std::thread::sleep(Duration::from_millis(500));

        let mut current_state: Option<HoverState> = None;
        let mut cached_geom: Option<((f64, f64), f64, f64)> = None; // (pos, width, scale)
        let mut last_geom_refresh = std::time::Instant::now();

        loop {
            std::thread::sleep(Duration::from_millis(40));

            // Refresh window geometry once per second or on the very first cycle
            if cached_geom.is_none() || last_geom_refresh.elapsed() >= Duration::from_secs(1) {
                if let (Ok(pos), Ok(size), Ok(scale)) = (
                    window.outer_position(),
                    window.outer_size(),
                    window.scale_factor(),
                ) {
                    cached_geom = Some(((pos.x as f64, pos.y as f64), size.width as f64, scale));
                    last_geom_refresh = std::time::Instant::now();
                }
            }

            let Some((win_pos, win_width, scale)) = cached_geom else {
                continue;
            };

            let Ok(cursor) = window.cursor_position() else {
                continue;
            };

            let pill = *window.state::<PillSize>().0.lock().unwrap();
            let mascot = *window.state::<MascotRect>().0.lock().unwrap();

            let in_pill = cursor_in_pill((cursor.x, cursor.y), win_pos, win_width, pill, scale);
            let state = if !in_pill {
                HoverState::Outside
            } else if let Some(m) = mascot {
                if cursor_in_pill_subrect((cursor.x, cursor.y), win_pos, win_width, pill, m, scale) {
                    HoverState::Mascot
                } else {
                    HoverState::Pill
                }
            } else {
                HoverState::Pill
            };

            if current_state != Some(state) {
                current_state = Some(state);
                let ignore_events = state == HoverState::Outside;
                let _ = window.set_ignore_cursor_events(ignore_events);
                let _ = window.emit_to("pill", "pill-hover", state == HoverState::Pill);
                let _ = window.emit_to("pill", "pill-hover-mascot", state == HoverState::Mascot);
            }
        }
    });
}


#[tauri::command]
fn open_external_url(url: String) -> Result<(), String> {
    #[cfg(windows)]
    {
        std::process::Command::new("rundll32")
            .args(["url.dll,FileProtocolHandler", &url])
            .spawn()
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
    #[cfg(not(windows))]
    {
        std::process::Command::new("open")
            .arg(&url)
            .spawn()
            .map(|_| ())
            .map_err(|e| e.to_string())
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(PillSize(Mutex::new((360.0, 44.0))))
        .manage(MascotRect(Mutex::new(None)))
        // Only remember the position and size where the desktop lyrics widget was dragged;
        // Never restore window visibility so the lyrics widget does not open at launch.
        .plugin(
            tauri_plugin_window_state::Builder::default()
                .with_state_flags(
                    tauri_plugin_window_state::StateFlags::POSITION
                        | tauri_plugin_window_state::StateFlags::SIZE,
                )
                .with_denylist(&["pill", "settings", "share"])
                .build(),
        )
        .on_window_event(|window, event| {
            if window.label() == "settings" || window.label() == "share" {
                if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            set_pill_size,
            set_mascot_rect,
            set_pill_window_height,
            cursor_over_pill,
            toggle_lyrics,
            hide_lyrics,
            is_lyrics_visible,
            open_settings,
            open_share_lyrics,
            open_external_url,
            get_monitors,
            set_pill_monitor,
            media::now_playing,
            media::media_control,
            system::set_keep_awake,
            system::privacy_state,
            system::get_autostart,
            system::set_autostart,
            ai::agent_sessions,
            ai::ai_usage,
            ai::ai_default_accounts,
            ai::set_hook_server,
            ai::claude_hooks,
            ai::claude_hooks_installed,
            ai::ai_key_set,
            ai::ai_key_exists,
            ai::ask_ai,
            ai::set_9router_connection_active,
            ai::ninerouter_analytics,
        ])
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(tauri_plugin_log::Builder::default().level(log::LevelFilter::Info).build())?;
            }

            // Start dedicated SMTC background thread
            media::init();

            if let Some(pill) = app.get_webview_window("pill") {
                place_pill(&pill)?;
                watch_hover(pill);
            }

            // Explicitly ensure auxiliary windows are hidden on startup
            if let Some(lyrics) = app.get_webview_window("lyrics") {
                let _ = lyrics.hide();
            }
            if let Some(settings) = app.get_webview_window("settings") {
                let _ = settings.hide();
            }
            if let Some(share) = app.get_webview_window("share") {
                let _ = share.hide();
            }

            let lyrics = MenuItem::with_id(app, "lyrics", "Toggle Desktop Lyrics", true, None::<&str>)?;
            let share = MenuItem::with_id(app, "share", "Share Lyric Card…", true, None::<&str>)?;
            let settings = MenuItem::with_id(app, "settings", "Settings…", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit OpenNotchi", true, None::<&str>)?;
            TrayIconBuilder::new()
                .icon(app.default_window_icon().cloned().expect("bundle icon"))
                .tooltip("OpenNotchi")
                .menu(&Menu::with_items(app, &[&lyrics, &share, &settings, &quit])?)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "lyrics" => {
                        let _ = toggle_lyrics(app.clone());
                    }
                    "share" => {
                        let _ = open_share_lyrics(app.clone());
                    }
                    "settings" => {
                        let _ = open_settings(app.clone());
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .build(app)?;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running OpenNotchi");
}

#[cfg(test)]
mod tests {
    use super::{cursor_in_pill, cursor_in_pill_subrect};

    #[test]
    fn hover_zone_is_the_centered_pill_scaled_to_physical_pixels() {
        // 600-wide window at x=100 on a 2x screen; a 360x44 pill spans x 340..1060, y 0..88.
        let hit = |x, y| cursor_in_pill((x, y), (100.0, 0.0), 1200.0, (360.0, 44.0), 2.0);
        assert!(hit(700.0, 10.0));
        assert!(hit(340.0, 88.0));
        assert!(!hit(339.0, 10.0));
        assert!(!hit(1061.0, 10.0));
        assert!(!hit(700.0, 89.0));
    }

    #[test]
    fn mascot_subrect_detects_cursor_inside_mascot_vs_rest_of_pill() {
        // Pill is 340x38, at window x=100, scale=2.0, window_width=1200.
        // Pill left = 100 + (1200 - 340*2)/2 = 100 + 260 = 360.
        // Pill spans physical x 360..1040, y 0..76.
        // Mascot is at (x=10, y=5, w=30, h=28) relative to pill.
        // In physical px: mascot spans x (360 + 10*2)..(360 + 40*2) = 380..440, y 10..66.
        let hit_pill = |x, y| cursor_in_pill((x, y), (100.0, 0.0), 1200.0, (340.0, 38.0), 2.0);
        let hit_mascot = |x, y| {
            cursor_in_pill_subrect(
                (x, y),
                (100.0, 0.0),
                1200.0,
                (340.0, 38.0),
                (10.0, 5.0, 30.0, 28.0),
                2.0,
            )
        };

        // (400, 30) is inside both the pill AND the mascot
        assert!(hit_pill(400.0, 30.0));
        assert!(hit_mascot(400.0, 30.0));

        // (600, 30) is inside the pill, but NOT inside the mascot (rest of the pill)
        assert!(hit_pill(600.0, 30.0));
        assert!(!hit_mascot(600.0, 30.0));

        // (100, 30) is outside the pill entirely
        assert!(!hit_pill(100.0, 30.0));
        assert!(!hit_mascot(100.0, 30.0));
    }
}

