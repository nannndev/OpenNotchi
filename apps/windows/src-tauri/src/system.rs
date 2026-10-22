//! Keep awake and camera/microphone-in-use detection.

use serde::Serialize;

#[derive(Serialize, Clone, Default, PartialEq)]
pub struct PrivacyState {
    pub camera: bool,
    pub mic: bool,
}

#[cfg(windows)]
mod imp {
    use super::PrivacyState;
    use windows::Win32::System::Power::{
        SetThreadExecutionState, ES_CONTINUOUS, ES_DISPLAY_REQUIRED, ES_SYSTEM_REQUIRED,
    };
    use winreg::enums::HKEY_CURRENT_USER;
    use winreg::RegKey;

    pub fn keep_awake(on: bool) {
        // Applies to the calling thread, so it's always set from the same (main) thread.
        let flags = if on { ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED } else { ES_CONTINUOUS };
        unsafe { SetThreadExecutionState(flags) };
    }

    /// Windows logs every app that uses the camera or mic under CapabilityAccessManager.
    /// An entry whose LastUsedTimeStop is 0 is in use right now.
    fn in_use(capability: &str) -> bool {
        let base = format!(r"Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\{capability}");
        let Ok(root) = RegKey::predef(HKEY_CURRENT_USER).open_subkey(&base) else { return false };
        let active = |key: &RegKey| key.get_value::<u64, _>("LastUsedTimeStop").map(|t| t == 0).unwrap_or(false);

        root.enum_keys().flatten().any(|name| {
            let Ok(key) = root.open_subkey(&name) else { return false };
            // Desktop (non-Store) apps are nested one level deeper, under "NonPackaged".
            if name == "NonPackaged" {
                key.enum_keys().flatten().any(|app| key.open_subkey(&app).map(|k| active(&k)).unwrap_or(false))
            } else {
                active(&key)
            }
        })
    }

    pub fn privacy() -> PrivacyState {
        PrivacyState { camera: in_use("webcam"), mic: in_use("microphone") }
    }

    pub fn is_autostart() -> bool {
        let Ok(key) = RegKey::predef(HKEY_CURRENT_USER).open_subkey(r"Software\Microsoft\Windows\CurrentVersion\Run") else { return false };
        key.get_value::<String, _>("OpenNotchi").is_ok()
    }

    pub fn set_autostart(enable: bool) -> Result<(), String> {
        let (key, _) = RegKey::predef(HKEY_CURRENT_USER)
            .create_subkey(r"Software\Microsoft\Windows\CurrentVersion\Run")
            .map_err(|e| e.to_string())?;
        if enable {
            let exe = std::env::current_exe().map_err(|e| e.to_string())?;
            key.set_value("OpenNotchi", &exe.to_string_lossy().as_ref()).map_err(|e| e.to_string())?;
        } else {
            let _ = key.delete_value("OpenNotchi");
        }
        Ok(())
    }
}

#[cfg(not(windows))]
mod imp {
    use super::PrivacyState;
    pub fn keep_awake(_on: bool) {}
    pub fn privacy() -> PrivacyState {
        PrivacyState::default()
    }
    pub fn is_autostart() -> bool { false }
    pub fn set_autostart(_enable: bool) -> Result<(), String> { Ok(()) }
}

#[tauri::command]
pub fn set_keep_awake(app: tauri::AppHandle, on: bool) -> Result<(), String> {
    app.run_on_main_thread(move || imp::keep_awake(on)).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn privacy_state() -> PrivacyState {
    imp::privacy()
}

#[tauri::command]
pub fn get_autostart() -> bool {
    imp::is_autostart()
}

#[tauri::command]
pub fn set_autostart(enable: bool) -> Result<(), String> {
    imp::set_autostart(enable)
}
