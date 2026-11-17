//! Notchi Gateway: the bundled `notchi-gateway` sidecar (apps/gateway) that routes Ask AI
//! across the user's AI accounts and API keys. This module starts it and talks to its HTTP API.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::path::PathBuf;
use std::process::{Child, Command};
use std::sync::Mutex;
use std::time::Duration;

use crate::ai::{Totals, UsageReport};

pub const PORT: u16 = 20129;
pub const BASE_URL: &str = "http://127.0.0.1:20129";
/// The OpenAI-compatible endpoint (also shown in Settings for external agents).
pub const V1_URL: &str = "http://127.0.0.1:20129/v1";

static CHILD: Mutex<Option<Child>> = Mutex::new(None);

fn agent(timeout_secs: u64) -> ureq::Agent {
    ureq::Agent::config_builder().http_status_as_error(false).timeout_global(Some(Duration::from_secs(timeout_secs))).build().into()
}

const EXE: &str = if cfg!(windows) { "notchi-gateway.exe" } else { "notchi-gateway" };

/// The sidecar next to the app binary (Tauri `externalBin`), or a dev build in apps/gateway.
fn binary() -> Option<PathBuf> {
    let exe_dir = std::env::current_exe().ok()?.parent()?.to_path_buf();
    let mut candidates = vec![exe_dir.join(EXE)];
    // `tauri dev` runs from src-tauri/target/<profile>; the gateway builds into apps/gateway/target.
    for up in exe_dir.ancestors().take(6) {
        for profile in ["release", "debug"] {
            candidates.push(up.join("gateway").join("target").join(profile).join(EXE));
            candidates.push(up.join("apps").join("gateway").join("target").join(profile).join(EXE));
        }
    }
    candidates.into_iter().find(|p| p.is_file())
}

pub fn is_available() -> bool {
    healthy() || binary().is_some()
}

pub fn healthy() -> bool {
    agent(2).get(format!("{BASE_URL}/health")).call().is_ok_and(|r| r.status().is_success())
}

/// Starts the sidecar unless one is already answering on the port (e.g. another instance).
pub fn ensure_running() -> Result<(), String> {
    if healthy() {
        return Ok(());
    }
    let bin = binary().ok_or("notchi-gateway was not found next to OpenNotchi. Reinstall the app.")?;
    {
        let mut child = CHILD.lock().map_err(|e| e.to_string())?;
        let alive = child.as_mut().is_some_and(|c| matches!(c.try_wait(), Ok(None)));
        if !alive {
            let mut cmd = Command::new(&bin);
            cmd.args(["--port", &PORT.to_string()]);
            #[cfg(windows)]
            {
                use std::os::windows::process::CommandExt;
                const CREATE_NO_WINDOW: u32 = 0x0800_0000;
                cmd.creation_flags(CREATE_NO_WINDOW);
            }
            *child = Some(cmd.spawn().map_err(|e| format!("Couldn't start notchi-gateway: {e}"))?);
        }
    }
    for _ in 0..25 {
        if healthy() {
            return Ok(());
        }
        std::thread::sleep(Duration::from_millis(120));
    }
    Err(format!("notchi-gateway didn't answer on port {PORT}"))
}

/// Stops the sidecar this app started (one started by someone else keeps running).
pub fn stop() {
    if let Ok(mut child) = CHILD.lock() {
        if let Some(mut c) = child.take() {
            let _ = c.kill();
            let _ = c.wait();
        }
    }
}

fn get(path: &str) -> Result<Value, String> {
    ensure_running()?;
    let mut r = agent(10).get(format!("{BASE_URL}{path}")).call().map_err(|e| format!("Gateway: {e}"))?;
    let status = r.status();
    let v: Value = r.body_mut().read_json().unwrap_or(Value::Null);
    if status.is_success() { Ok(v) } else { Err(error_text(&v, status.as_u16())) }
}

fn send(method: &str, path: &str, body: &Value) -> Result<Value, String> {
    ensure_running()?;
    let a = agent(60);
    let url = format!("{BASE_URL}{path}");
    let req = match method {
        "PATCH" => a.patch(&url),
        "DELETE" => a.delete(&url).force_send_body(),
        "PUT" => a.put(&url),
        _ => a.post(&url),
    };
    let mut r = req.send_json(body).map_err(|e| format!("Gateway: {e}"))?;
    let status = r.status();
    let v: Value = r.body_mut().read_json().unwrap_or(Value::Null);
    if status.is_success() { Ok(v) } else { Err(error_text(&v, status.as_u16())) }
}

fn error_text(v: &Value, status: u16) -> String {
    v["detail"].as_str().or(v["error"]["message"].as_str()).or(v["error"].as_str()).map(String::from).unwrap_or_else(|| format!("Gateway HTTP {status}"))
}

// ---------------------------------------------------------------------
// Models and usage for the AI tab
// ---------------------------------------------------------------------

/// Model ids the gateway can route to, `auto` modes first.
pub fn models() -> Vec<String> {
    get("/v1/models").map(|v| v["data"].as_array().into_iter().flatten().filter_map(|m| m["id"].as_str().map(String::from)).collect()).unwrap_or_default()
}

/// Maps a gateway provider id onto the AI tab's tool families (for icons and limits).
fn tool_for(provider: &str) -> String {
    match provider {
        "codex" => "codex",
        "antigravity" => "antigravity",
        "claude" => "claude",
        other => other,
    }
    .to_string()
}

/// One usage report per connected subscription account.
pub fn reports(tz_offset_min: i64) -> Vec<UsageReport> {
    // JS getTimezoneOffset() is minutes *behind* UTC; the gateway wants minutes east.
    let Ok(v) = get(&format!("/gateway/admin/accounts/usage?days=7&tz_offset_min={}", -tz_offset_min)) else { return vec![] };
    let now_s = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0);
    v["usage"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|a| {
            let provider = a["provider"].as_str().unwrap_or("").to_string();
            let id = a["account_id"].as_str().unwrap_or("").to_string();
            let name = a["label"].as_str().filter(|s| !s.is_empty()).or(a["email"].as_str().filter(|s| !s.is_empty())).unwrap_or(&provider).to_string();
            let cooling = a["cooling_until"].as_f64().filter(|t| *t > now_s);
            let last_error = a["last_error"].as_str().map(String::from);
            let enabled = a["enabled"].as_bool().unwrap_or(true);
            let test_status = if !enabled {
                "paused"
            } else if cooling.is_some() {
                "cooling"
            } else if last_error.is_some() {
                "error"
            } else {
                "active"
            };
            UsageReport {
                id: Some(id.clone()),
                name,
                tool: tool_for(&provider),
                dir: provider.clone(),
                connection_id: Some(id),
                email: a["email"].as_str().map(String::from),
                priority: a["sort_order"].as_i64().map(|n| n as i32 + 1),
                is_active: enabled,
                found: true,
                today: Totals { tokens: a["today_tokens"].as_u64().unwrap_or(0), cost: 0.0 },
                block: None,
                days: a["days"].as_array().into_iter().flatten().map(|d| d.as_u64().unwrap_or(0)).collect(),
                limits: None,
                quotas: Vec::new(),
                plan_name: a["plan"].as_str().map(String::from),
                test_status: Some(test_status.into()),
                last_error,
                is_from_gateway: true,
                provider: Some(provider),
            }
        })
        .collect()
}

pub fn set_account_enabled(provider: &str, id: &str, enabled: bool) -> Result<(), String> {
    send("PATCH", &format!("/gateway/admin/accounts/{provider}/{}/toggle", urlencode(id)), &json!({ "enabled": enabled })).map(|_| ())
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase")]
pub struct DayStat {
    pub date: String,
    pub requests: u64,
    pub input: u64,
    pub cached: u64,
    pub output: u64,
    pub cost: f64,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct RecentRequest {
    pub id: i64,
    pub timestamp: String,
    pub model: String,
    pub provider: String,
    pub input: u64,
    pub output: u64,
    pub ok: bool,
}

#[derive(Serialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct ModelUsage {
    pub model: String,
    pub tokens: u64,
    pub cost: f64,
}

#[derive(Serialize, Clone, Debug, Default)]
#[serde(rename_all = "camelCase")]
pub struct Analytics {
    pub days: Vec<DayStat>,
    pub recent: Vec<RecentRequest>,
    pub top_models: Vec<ModelUsage>,
}

/// Request history for the Analytics panel; `days` None covers all of it.
pub fn analytics(days: Option<u32>, tz_offset_min: i64) -> Analytics {
    let mut q = format!("/gateway/admin/analytics?tz_offset_min={}", -tz_offset_min);
    if let Some(d) = days {
        q.push_str(&format!("&days={d}"));
    }
    let Ok(v) = get(&q) else { return Analytics::default() };
    let days = serde_json::from_value(v["days"].clone()).unwrap_or_default();
    let recent = v["recent"]
        .as_array()
        .into_iter()
        .flatten()
        .enumerate()
        .map(|(i, r)| RecentRequest {
            id: i as i64,
            timestamp: r["ts"]
                .as_f64()
                .and_then(|t| chrono_like_iso(t as i64))
                .unwrap_or_default(),
            model: r["model"].as_str().unwrap_or("auto").into(),
            provider: r["provider"].as_str().unwrap_or("").into(),
            input: r["input"].as_u64().unwrap_or(0),
            output: r["output"].as_u64().unwrap_or(0),
            ok: r["ok"].as_bool().unwrap_or(true),
        })
        .collect();
    let top_models = v["top_models"]
        .as_array()
        .into_iter()
        .flatten()
        .map(|m| ModelUsage { model: m["model"].as_str().unwrap_or("auto").into(), tokens: m["tokens"].as_u64().unwrap_or(0), cost: 0.0 })
        .collect();
    Analytics { days, recent, top_models }
}

/// Unix seconds -> RFC 3339 UTC (the frontend parses it with `new Date`).
fn chrono_like_iso(secs: i64) -> Option<String> {
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    // Civil-from-days (Howard Hinnant), valid for the proleptic Gregorian calendar.
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };
    Some(format!("{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z", rem / 3600, (rem % 3600) / 60, rem % 60))
}

fn urlencode(s: &str) -> String {
    s.bytes()
        .map(|b| if b.is_ascii_alphanumeric() || b"-_.~".contains(&b) { (b as char).to_string() } else { format!("%{b:02X}") })
        .collect()
}

// ---------------------------------------------------------------------
// Admin API passthrough for the Settings › Gateway screen
// ---------------------------------------------------------------------

/// Calls a gateway admin endpoint; the path must stay under /gateway/admin or /v1.
pub fn admin(method: &str, path: &str, body: Option<Value>) -> Result<Value, String> {
    if !(path.starts_with("/gateway/admin/") || path == "/v1/models") || path.contains("..") {
        return Err("Not a gateway admin path".into());
    }
    match method {
        "GET" => get(path),
        "POST" | "PATCH" | "PUT" | "DELETE" => send(method, path, &body.unwrap_or_else(|| json!({}))),
        _ => Err(format!("Unsupported method {method}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn iso_formats_the_unix_epoch() {
        assert_eq!(chrono_like_iso(0).as_deref(), Some("1970-01-01T00:00:00Z"));
    }

    #[test]
    fn iso_formats_a_leap_day() {
        assert_eq!(chrono_like_iso(951_782_400 + 3661).as_deref(), Some("2000-02-29T01:01:01Z"));
    }

    #[test]
    fn urlencode_escapes_separators_in_account_ids() {
        assert_eq!(urlencode("codex:ab/c d"), "codex%3Aab%2Fc%20d");
    }

    #[test]
    fn admin_refuses_paths_outside_the_admin_api() {
        assert!(admin("GET", "/health", None).is_err());
    }

    #[test]
    fn admin_refuses_path_traversal() {
        assert!(admin("GET", "/gateway/admin/../../etc", None).is_err());
    }
}
