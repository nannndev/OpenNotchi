//! 9router multi-account and local SQLite / HTTP daemon integration.
//! Reads connection configuration, usage history, and live quotas from ~/.9router.

use rusqlite::{Connection, OpenFlags};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use crate::ai::{Block, CodexLimits, RateWindow, Totals, UsageReport};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct NineRouterQuota {
    pub name: String,
    pub used: f64,
    pub total: f64,
    pub remaining: f64,
    pub remaining_percentage: f64,
    pub reset_at: Option<i64>, // Unix ms
    pub unlimited: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct NineRouterConnection {
    pub id: String,
    pub provider: String,
    pub name: String,
    pub email: Option<String>,
    pub priority: i32,
    pub is_active: bool,
    pub auth_type: String,
    pub test_status: Option<String>,
    pub last_error: Option<String>,
    pub error_code: Option<i32>,
    pub plan: Option<String>,
    pub quotas: Vec<NineRouterQuota>,
    pub today_tokens: u64,
    pub today_cost: f64,
    pub days: Vec<u64>,
}

pub fn router_dir() -> PathBuf {
    let home = std::env::var(if cfg!(windows) { "USERPROFILE" } else { "HOME" }).unwrap_or_default();
    PathBuf::from(home).join(".9router")
}

pub fn db_path() -> PathBuf {
    router_dir().join("db").join("data.sqlite")
}

pub fn machine_id_path() -> PathBuf {
    router_dir().join("machine-id")
}

pub fn cli_secret_path() -> PathBuf {
    router_dir().join("auth").join("cli-secret")
}

pub fn is_available() -> bool {
    db_path().exists()
}

pub fn get_auth_token() -> Option<String> {
    let machine_id = std::fs::read_to_string(machine_id_path()).ok()?.trim().to_string();
    let cli_secret = std::fs::read_to_string(cli_secret_path()).ok()?.trim().to_string();
    if machine_id.is_empty() || cli_secret.is_empty() {
        return None;
    }
    let raw = format!("{machine_id}9r-cli-auth{cli_secret}");
    let mut hasher = Sha256::new();
    hasher.update(raw.as_bytes());
    let hex_str = hex::encode(hasher.finalize());
    Some(hex_str.chars().take(16).collect())
}

pub fn read_connections_from_db() -> Vec<NineRouterConnection> {
    let Ok(conn) = Connection::open_with_flags(db_path(), OpenFlags::SQLITE_OPEN_READ_ONLY) else {
        return vec![];
    };

    let query = "SELECT id, provider, authType, name, email, priority, isActive, data FROM providerConnections ORDER BY priority ASC, id ASC;";
    let Ok(mut stmt) = conn.prepare(query) else {
        return vec![];
    };

    let rows = stmt.query_map([], |row| {
        let id: String = row.get(0)?;
        let provider: String = row.get(1)?;
        let auth_type: String = row.get(2)?;
        let name: Option<String> = row.get(3)?;
        let email: Option<String> = row.get(4)?;
        let priority: i32 = row.get(5)?;
        let is_active_int: i32 = row.get(6)?;
        let data_str: Option<String> = row.get(7)?;

        Ok((
            id,
            provider,
            auth_type,
            name.unwrap_or_default(),
            email,
            priority,
            is_active_int == 1,
            data_str,
        ))
    });

    let Ok(rows) = rows else { return vec![]; };

    let mut list = Vec::new();
    for item in rows.flatten() {
        let (id, provider, auth_type, name, email, priority, is_active, data_str) = item;
        let mut test_status = None;
        let mut last_error = None;
        let mut error_code = None;

        if let Some(s) = data_str {
            if let Ok(v) = serde_json::from_str::<Value>(&s) {
                test_status = v.get("testStatus").and_then(|x| x.as_str()).map(str::to_string);
                last_error = v.get("lastError").and_then(|x| x.as_str()).map(str::to_string);
                error_code = v.get("errorCode").and_then(|x| x.as_i64()).map(|n| n as i32);
            }
        }

        list.push(NineRouterConnection {
            id,
            provider,
            name,
            email,
            priority,
            is_active,
            auth_type,
            test_status,
            last_error,
            error_code,
            plan: None,
            quotas: vec![],
            today_tokens: 0,
            today_cost: 0.0,
            days: vec![0; 7],
        });
    }

    list
}

pub fn enrich_with_usage_history(connections: &mut [NineRouterConnection]) {
    let Ok(conn) = Connection::open_with_flags(db_path(), OpenFlags::SQLITE_OPEN_READ_ONLY) else {
        return;
    };

    // Today's usage
    let today_sql = "SELECT coalesce(sum(promptTokens + completionTokens), 0), coalesce(sum(cost), 0.0) FROM usageHistory WHERE connectionId = ?1 AND date(timestamp, 'localtime') = date('now', 'localtime');";
    if let Ok(mut stmt) = conn.prepare(today_sql) {
        for c in connections.iter_mut() {
            if let Ok(row) = stmt.query_row([&c.id], |r| {
                let tokens: i64 = r.get(0)?;
                let cost: f64 = r.get(1)?;
                Ok((tokens.max(0) as u64, cost))
            }) {
                c.today_tokens = row.0;
                c.today_cost = row.1;
            }
        }
    }

    // 7-day sparkline using recursive CTE for exact 7-day chronologically ordered data
    let days_sql = "WITH RECURSIVE last_seven(d) AS (
        SELECT date('now', 'localtime', '-6 days')
        UNION ALL
        SELECT date(d, '+1 day') FROM last_seven WHERE d < date('now', 'localtime')
    )
    SELECT coalesce(sum(usageHistory.promptTokens + usageHistory.completionTokens), 0)
    FROM last_seven
    LEFT JOIN usageHistory ON date(usageHistory.timestamp, 'localtime') = last_seven.d AND usageHistory.connectionId = ?1
    GROUP BY last_seven.d
    ORDER BY last_seven.d ASC;";

    if let Ok(mut stmt) = conn.prepare(days_sql) {
        for c in connections.iter_mut() {
            if let Ok(rows) = stmt.query_map([&c.id], |r| {
                let tokens: i64 = r.get(0)?;
                Ok(tokens.max(0) as u64)
            }) {
                let days: Vec<u64> = rows.flatten().collect();
                if days.len() == 7 {
                    c.days = days;
                }
            }
        }
    }
}

pub const POOL_LABELS: &[(&str, &str)] = &[
    ("gemini_session", "Gemini (5h)"),
    ("claude_gpt_session", "Claude & GPT (5h)"),
    ("gemini_weekly", "Gemini (Weekly)"),
    ("claude_gpt_weekly", "Claude & GPT (Weekly)"),
];

pub fn display_quotas(quotas: Vec<NineRouterQuota>) -> Vec<NineRouterQuota> {
    let mut pools = Vec::new();
    for &(key, label) in POOL_LABELS {
        if let Some(mut q) = quotas.iter().find(|q| q.name == key).cloned() {
            q.name = label.to_string();
            pools.push(q);
        }
    }
    if !pools.is_empty() {
        pools
    } else {
        let mut sorted = quotas;
        sorted.sort_by(|a, b| a.name.cmp(&b.name));
        sorted
    }
}

pub fn enrich_with_live_quotas(connections: &mut [NineRouterConnection]) {
    let Some(token) = get_auth_token() else { return };
    let agent: ureq::Agent = ureq::Agent::config_builder()
        .http_status_as_error(false)
        .timeout_global(Some(Duration::from_millis(2500)))
        .build()
        .into();

    for conn in connections.iter_mut() {
        let url = format!("http://127.0.0.1:20128/api/usage/{}", conn.id);
        let resp = agent.get(&url).header("x-9r-cli-token", &token).call();
        let Ok(mut resp) = resp else { continue };
        if !resp.status().is_success() {
            continue;
        }
        let Ok(val) = resp.body_mut().read_json::<Value>() else { continue };

        if let Some(plan) = val.get("plan").and_then(|p| p.as_str()) {
            conn.plan = Some(plan.to_string());
        }

        if let Some(quotas_obj) = val.get("quotas").and_then(|q| q.as_object()) {
            let mut parsed = Vec::new();
            for (q_name, q_val) in quotas_obj {
                let used = q_val.get("used").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let total = q_val.get("total").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let remaining = q_val.get("remaining").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let remaining_pct = q_val
                    .get("remainingPercentage")
                    .and_then(|v| v.as_f64())
                    .unwrap_or_else(|| {
                        if total > 0.0 {
                            (100.0 - (used / total * 100.0)).max(0.0)
                        } else {
                            100.0
                        }
                    });
                let unlimited = q_val.get("unlimited").and_then(|v| v.as_bool()).unwrap_or(false);
                let reset_at = q_val
                    .get("resetAt")
                    .and_then(|v| v.as_str())
                    .and_then(crate::ai::parse_iso_ms);

                parsed.push(NineRouterQuota {
                    name: q_name.clone(),
                    used,
                    total,
                    remaining,
                    remaining_percentage: remaining_pct,
                    reset_at,
                    unlimited,
                });
            }
            conn.quotas = display_quotas(parsed);
        }
    }
}

fn tool_display_name(tool: &str) -> String {
    match tool {
        "codex" => "Codex".to_string(),
        "antigravity" => "Antigravity".to_string(),
        "commandcode" => "Command Code".to_string(),
        _ => "Claude Code".to_string(),
    }
}

pub fn fetch_reports() -> Vec<UsageReport> {
    if !is_available() {
        return vec![];
    }

    let mut connections = read_connections_from_db();
    if connections.is_empty() {
        return vec![];
    }

    enrich_with_usage_history(&mut connections);
    enrich_with_live_quotas(&mut connections);

    let now_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    connections
        .into_iter()
        .map(|conn| {
            let tool = match conn.provider.to_lowercase().as_str() {
                "codex" => "codex",
                "antigravity" => "antigravity",
                "commandcode" => "commandcode",
                _ => "claude",
            }
            .to_string();

            let display_name = if !conn.name.is_empty() && conn.name != "-" {
                conn.name.clone()
            } else if let Some(ref email) = conn.email {
                if !email.is_empty() {
                    email.clone()
                } else {
                    tool_display_name(&tool)
                }
            } else {
                tool_display_name(&tool)
            };

            // Set running 5h block if active
            let mut block = None;
            if let Some(session_quota) = conn
                .quotas
                .iter()
                .find(|q| q.name.to_lowercase().contains("session") || q.name.contains("5h"))
            {
                if let Some(reset_at) = session_quota.reset_at {
                    if reset_at > now_ms {
                        let start = reset_at - 5 * 3600 * 1000;
                        block = Some(Block {
                            start,
                            end: reset_at,
                            tokens: conn.today_tokens,
                            cost: conn.today_cost,
                        });
                    }
                }
            }

            // Set Codex rate limits if tool is Codex
            let limits = if tool == "codex" {
                let mut primary = None;
                let mut secondary = None;
                for q in &conn.quotas {
                    let resets_at = q.reset_at.unwrap_or(now_ms) / 1000;
                    let w = RateWindow {
                        used_percent: 100.0 - q.remaining_percentage,
                        window_minutes: if q.name.contains("weekly") { 10080 } else { 300 },
                        resets_at,
                    };
                    if q.name.contains("session") || q.name.contains("5h") || primary.is_none() {
                        primary = Some(w);
                    } else {
                        secondary = Some(w);
                    }
                }
                Some(CodexLimits {
                    plan_type: conn.plan.clone(),
                    primary,
                    secondary,
                })
            } else {
                None
            };

            UsageReport {
                id: Some(conn.id.clone()),
                name: display_name,
                tool,
                dir: "~/.9router".to_string(),
                connection_id: Some(conn.id),
                email: conn.email,
                priority: Some(conn.priority),
                is_active: conn.is_active,
                found: true,
                today: Totals {
                    tokens: conn.today_tokens,
                    cost: conn.today_cost,
                },
                block,
                days: conn.days,
                limits,
                quotas: conn.quotas,
                plan_name: conn.plan,
                test_status: conn.test_status,
                last_error: conn.last_error,
                is_from_9router: true,
            }
        })
        .collect()
}

pub fn set_connection_active(id: &str, active: bool) -> Result<(), String> {
    // 1. Direct SQLite update
    if let Ok(conn) = Connection::open_with_flags(db_path(), OpenFlags::SQLITE_OPEN_READ_WRITE) {
        let sql = "UPDATE providerConnections SET isActive = ?1, updatedAt = datetime('now') WHERE id = ?2;";
        let _ = conn.execute(sql, rusqlite::params![if active { 1 } else { 0 }, id]);
    }

    // 2. Notify 9router daemon via HTTP PUT
    if let Some(token) = get_auth_token() {
        let url = format!("http://127.0.0.1:20128/api/providers/{}", id);
        let agent: ureq::Agent = ureq::Agent::config_builder()
            .http_status_as_error(false)
            .timeout_global(Some(Duration::from_secs(3)))
            .build()
            .into();
        let body = json!({ "isActive": active });
        let _ = agent
            .put(&url)
            .header("x-9r-cli-token", &token)
            .header("Content-Type", "application/json")
            .send_json(&body);
    }

    Ok(())
}

/// The local OpenAI-compatible endpoint 9router serves.
pub const BASE_URL: &str = "http://127.0.0.1:20128/v1";

/// First active 9router API key, so Ask AI can call the local endpoint without the user pasting it.
pub fn api_key() -> Option<String> {
    let conn = Connection::open_with_flags(db_path(), OpenFlags::SQLITE_OPEN_READ_ONLY).ok()?;
    conn.query_row("SELECT key FROM apiKeys WHERE isActive = 1 ORDER BY createdAt ASC LIMIT 1;", [], |r| r.get(0)).ok()
}

/// Model ids 9router can route to right now (e.g. "cc/claude-sonnet-5-5"); empty when the daemon is down.
pub fn models() -> Vec<String> {
    let agent: ureq::Agent = ureq::Agent::config_builder().http_status_as_error(false).timeout_global(Some(Duration::from_secs(3))).build().into();
    let Ok(mut resp) = agent.get(format!("{BASE_URL}/models")).call() else { return vec![] };
    let v: Value = resp.body_mut().read_json().unwrap_or_default();
    v["data"].as_array().into_iter().flatten().filter_map(|m| m["id"].as_str().map(String::from)).collect()
}

#[derive(Serialize, Clone, Debug)]
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

/// Daily totals (from 9router's `usageDaily` rollup), latest requests and today's top models.
/// `days` None means all history.
pub fn analytics(days: Option<u32>) -> Analytics {
    let Ok(conn) = Connection::open_with_flags(db_path(), OpenFlags::SQLITE_OPEN_READ_ONLY) else {
        return Analytics::default();
    };
    let offset = format!("-{} days", days.unwrap_or(100_000).saturating_sub(1));

    let days = conn
        .prepare(
            "SELECT dateKey,
                    coalesce(json_extract(data, '$.requests'), 0),
                    coalesce(json_extract(data, '$.promptTokens'), 0),
                    coalesce((SELECT sum(json_extract(value, '$.cachedTokens')) FROM json_each(data, '$.byProvider')), 0),
                    coalesce(json_extract(data, '$.completionTokens'), 0),
                    coalesce(json_extract(data, '$.cost'), 0.0)
             FROM usageDaily WHERE dateKey >= date('now', 'localtime', ?1) ORDER BY dateKey ASC;",
        )
        .and_then(|mut st| {
            st.query_map([&offset], |r| {
                Ok(DayStat {
                    date: r.get(0)?,
                    requests: r.get::<_, i64>(1)?.max(0) as u64,
                    input: r.get::<_, i64>(2)?.max(0) as u64,
                    cached: r.get::<_, i64>(3)?.max(0) as u64,
                    output: r.get::<_, i64>(4)?.max(0) as u64,
                    cost: r.get(5)?,
                })
            })
            .map(|rows| rows.flatten().collect())
        })
        .unwrap_or_default();

    let recent = conn
        .prepare("SELECT id, timestamp, coalesce(model, '?'), coalesce(provider, ''), promptTokens, completionTokens, coalesce(status, '') FROM usageHistory ORDER BY id DESC LIMIT 20;")
        .and_then(|mut st| {
            st.query_map([], |r| {
                Ok(RecentRequest {
                    id: r.get(0)?,
                    timestamp: r.get(1)?,
                    model: r.get(2)?,
                    provider: r.get(3)?,
                    input: r.get::<_, i64>(4)?.max(0) as u64,
                    output: r.get::<_, i64>(5)?.max(0) as u64,
                    ok: r.get::<_, String>(6)? == "ok",
                })
            })
            .map(|rows| rows.flatten().collect())
        })
        .unwrap_or_default();

    let top_models = conn
        .prepare(
            "SELECT coalesce(model, '?'), coalesce(sum(promptTokens + completionTokens), 0), coalesce(sum(cost), 0.0)
             FROM usageHistory WHERE date(timestamp, 'localtime') = date('now', 'localtime')
             GROUP BY model ORDER BY 2 DESC LIMIT 5;",
        )
        .and_then(|mut st| {
            st.query_map([], |r| Ok(ModelUsage { model: r.get(0)?, tokens: r.get::<_, i64>(1)?.max(0) as u64, cost: r.get(2)? }))
                .map(|rows| rows.flatten().collect())
        })
        .unwrap_or_default();

    Analytics { days, recent, top_models }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_quotas_extracts_pools_when_present() {
        let raw = vec![
            NineRouterQuota {
                name: "gemini_session".into(),
                used: 50.0,
                total: 1000.0,
                remaining: 950.0,
                remaining_percentage: 95.0,
                reset_at: None,
                unlimited: false,
            },
            NineRouterQuota {
                name: "gemini-3.8-flash-high".into(),
                used: 50.0,
                total: 1000.0,
                remaining: 950.0,
                remaining_percentage: 95.0,
                reset_at: None,
                unlimited: false,
            },
            NineRouterQuota {
                name: "gemini_weekly".into(),
                used: 200.0,
                total: 1000.0,
                remaining: 800.0,
                remaining_percentage: 80.0,
                reset_at: None,
                unlimited: false,
            },
        ];

        let displayed = display_quotas(raw);
        assert_eq!(displayed.len(), 2);
        assert_eq!(displayed[0].name, "Gemini (5h)");
        assert_eq!(displayed[1].name, "Gemini (Weekly)");
    }

    #[test]
    fn display_quotas_falls_back_to_sorted_quotas_when_no_pools() {
        let raw = vec![
            NineRouterQuota {
                name: "claude-3-5-sonnet".into(),
                used: 10.0,
                total: 100.0,
                remaining: 90.0,
                remaining_percentage: 90.0,
                reset_at: None,
                unlimited: false,
            },
            NineRouterQuota {
                name: "claude-3-opus".into(),
                used: 20.0,
                total: 100.0,
                remaining: 80.0,
                remaining_percentage: 80.0,
                reset_at: None,
                unlimited: false,
            },
        ];

        let displayed = display_quotas(raw);
        assert_eq!(displayed.len(), 2);
        assert_eq!(displayed[0].name, "claude-3-5-sonnet");
        assert_eq!(displayed[1].name, "claude-3-opus");
    }

    #[test]
    fn real_9router_db_integration() {
        if !is_available() {
            return;
        }
        let reports = fetch_reports();
        assert!(!reports.is_empty(), "Should load at least 1 account from 9router");
        for r in &reports {
            assert!(r.is_from_9router);
            assert!(r.found);
            assert_eq!(r.days.len(), 7);
        }
    }

    #[test]
    fn real_9router_analytics() {
        if !is_available() {
            return;
        }
        let week = analytics(Some(7));
        assert!(week.days.len() <= 7);
        assert!(week.days.windows(2).all(|w| w[0].date < w[1].date), "days oldest first");
        assert!(week.recent.len() <= 20);
        let all = analytics(None);
        assert!(all.days.len() >= week.days.len());
    }
}
