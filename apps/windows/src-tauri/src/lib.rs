mod media;
mod system;

use std::sync::Mutex;
use std::time::Duration;
use tauri::menu::{Menu, MenuItem};
use tauri::tray::TrayIconBuilder;
use tauri::{Emitter, Manager, State, WebviewWindow};

/// Size of the visible pill in logical pixels. The window itself stays large and transparent so the
/// pill can animate inside it; clicks outside the pill pass through to the desktop.
struct PillSize(Mutex<(f64, f64)>);

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

/// Polls the cursor so the pill reacts to hover without needing focus (like the macOS notch),
/// and lets clicks through everywhere outside the pill.
fn watch_hover(window: WebviewWindow) {
    std::thread::spawn(move || {
        let mut inside = None;
        loop {
            std::thread::sleep(Duration::from_millis(30));
            let (Ok(cursor), Ok(pos), Ok(size), Ok(scale)) =
                (window.cursor_position(), window.outer_position(), window.outer_size(), window.scale_factor())
            else {
                continue;
            };
            let pill = *window.state::<PillSize>().0.lock().unwrap();
            let now = cursor_in_pill((cursor.x, cursor.y), (pos.x as f64, pos.y as f64), size.width as f64, pill, scale);
            if inside != Some(now) {
                inside = Some(now);
                let _ = window.set_ignore_cursor_events(!now);
                let _ = window.emit_to("pill", "pill-hover", now);
            }
        }
    });
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .manage(PillSize(Mutex::new((360.0, 44.0))))
        // Remembers where the desktop lyrics widget was dragged; the pill is always re-centered.
        .plugin(
            tauri_plugin_window_state::Builder::default()
                .with_denylist(&["pill"])
                .build(),
        )
        .on_window_event(|window, event| {
            if window.label() == "settings" {
                if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                    api.prevent_close();
                    let _ = window.hide();
                }
            }
        })
        .invoke_handler(tauri::generate_handler![
            set_pill_size,
            toggle_lyrics,
            hide_lyrics,
            is_lyrics_visible,
            open_settings,
            get_monitors,
            set_pill_monitor,
            media::now_playing,
            media::media_control,
            system::set_keep_awake,
            system::privacy_state,
            system::get_autostart,
            system::set_autostart,
        ])
        .setup(|app| {
            if cfg!(debug_assertions) {
                app.handle().plugin(tauri_plugin_log::Builder::default().level(log::LevelFilter::Info).build())?;
            }
            if let Some(pill) = app.get_webview_window("pill") {
                place_pill(&pill)?;
                watch_hover(pill);
            }

            let lyrics = MenuItem::with_id(app, "lyrics", "Toggle Desktop Lyrics", true, None::<&str>)?;
            let settings = MenuItem::with_id(app, "settings", "Settings…", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "Quit OpenNotchi", true, None::<&str>)?;
            TrayIconBuilder::new()
                .icon(app.default_window_icon().cloned().expect("bundle icon"))
                .tooltip("OpenNotchi")
                .menu(&Menu::with_items(app, &[&lyrics, &settings, &quit])?)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "lyrics" => {
                        let _ = toggle_lyrics(app.clone());
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
    use super::cursor_in_pill;

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
}
