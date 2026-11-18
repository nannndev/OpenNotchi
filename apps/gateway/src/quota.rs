//! Live usage windows (remaining %, reset time, plan) for subscription accounts, read from
//! each provider's own usage endpoint. Several of these are private client APIs and may change.

use crate::oauth::{cline_bearer, grok_headers, kimi_headers, kiro_profile_arn, AG_USER_AGENT, GROK_API};
use crate::store::{AccountRecord, GatewayStore};
use parking_lot::Mutex;
use reqwest::Client;
use serde::Serialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

/// One usage window, e.g. "session (5h)" at 62% left, resetting at `reset_at` (unix seconds).
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Quota {
    pub name: String,
    pub used: f64,
    pub total: f64,
    pub remaining_percentage: f64,
    pub reset_at: Option<f64>,
    pub unlimited: bool,
}

impl Quota {
    /// A window reported as "percent used" (0-100).
    fn used_percent(name: impl Into<String>, used_pct: f64, reset_at: Option<f64>) -> Self {
        let p = used_pct.clamp(0.0, 100.0);
        Quota { name: name.into(), used: p, total: 100.0, remaining_percentage: 100.0 - p, reset_at, unlimited: false }
    }

    /// A window reported as used / total counts.
    fn counts(name: impl Into<String>, used: f64, total: f64, reset_at: Option<f64>) -> Self {
        let pct = if total > 0.0 { ((total - used) / total * 100.0).clamp(0.0, 100.0) } else { 100.0 };
        Quota { name: name.into(), used, total, remaining_percentage: pct, reset_at, unlimited: false }
    }

    /// A window reported as the fraction left (0-1).
    fn fraction_left(name: impl Into<String>, left: f64, reset_at: Option<f64>) -> Self {
        Self::used_percent(name, (1.0 - left.clamp(0.0, 1.0)) * 100.0, reset_at)
    }
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct AccountQuota {
    pub plan: Option<String>,
    pub quotas: Vec<Quota>,
    /// Set when the provider answered but quotas aren't available (chat may still work).
    pub message: Option<String>,
    pub fetched_at: f64,
}

/// Seconds, milliseconds, numeric strings or ISO dates -> unix seconds.
pub fn to_unix_secs(v: &Value) -> Option<f64> {
    let n = v.as_f64().or_else(|| v.as_str().and_then(|s| s.trim().parse::<f64>().ok()));
    if let Some(n) = n {
        return (n > 0.0).then(|| if n >= 1e12 { n / 1000.0 } else { n });
    }
    let s = v.as_str()?;
    chrono::DateTime::parse_from_rfc3339(s).map(|d| d.timestamp() as f64).ok().or_else(|| {
        chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d").ok().and_then(|d| d.and_hms_opt(0, 0, 0)).map(|d| d.and_utc().timestamp() as f64)
    })
}

/// Per-account cache so the 30-60 s UI polls don't hammer provider usage APIs.
#[derive(Clone, Default)]
pub struct QuotaCache {
    entries: Arc<Mutex<HashMap<String, (Instant, AccountQuota)>>>,
}

const TTL: Duration = Duration::from_secs(120);

impl QuotaCache {
    /// Cached quota for the account, refetched when older than two minutes or when `force`.
    pub async fn get(&self, client: &Client, store: &GatewayStore, acc: &AccountRecord, force: bool) -> Option<AccountQuota> {
        if !force {
            if let Some((at, q)) = self.entries.lock().get(&acc.id) {
                if at.elapsed() < TTL {
                    return Some(q.clone());
                }
            }
        }
        let fresh = fetch(client, store, acc).await?;
        let mut entries = self.entries.lock();
        let (shown, cache) = keep_last_good(entries.get(&acc.id).map(|(_, q)| q), fresh);
        if cache {
            entries.insert(acc.id.clone(), (Instant::now(), shown.clone()));
        }
        Some(shown)
    }
}

/// A failed read (no windows, an error message) must not hide windows we already had:
/// show the last good windows with the new message, and don't cache the failure so the
/// next poll retries. Returns (what to show, whether to cache it).
fn keep_last_good(prev: Option<&AccountQuota>, fresh: AccountQuota) -> (AccountQuota, bool) {
    let failed = fresh.quotas.is_empty() && fresh.message.is_some();
    match prev {
        Some(p) if failed && !p.quotas.is_empty() => (AccountQuota { message: fresh.message, ..p.clone() }, false),
        _ => (fresh, !failed),
    }
}

/// Live quota for one subscription account; None for providers without a usage API.
pub async fn fetch(client: &Client, store: &GatewayStore, acc: &AccountRecord) -> Option<AccountQuota> {
    if !supports(&acc.provider) {
        return None;
    }
    let cred = match crate::oauth::fresh_credential(client, store, acc, false).await {
        Ok(c) => c,
        Err(e) => return Some(AccountQuota { message: Some(e), fetched_at: crate::store::now(), ..Default::default() }),
    };
    let mut result = fetch_with(client, &acc.provider, &cred).await;
    // An expired token is the common failure; refresh once and retry.
    if matches!(&result, Err(e) if e.contains("401")) {
        if let Ok(c) = crate::oauth::fresh_credential(client, store, acc, true).await {
            result = fetch_with(client, &acc.provider, &c).await;
        }
    }
    let mut q = result.unwrap_or_else(|e| AccountQuota { message: Some(e), ..Default::default() });
    q.fetched_at = crate::store::now();
    Some(q)
}

pub fn supports(provider: &str) -> bool {
    matches!(provider, "claude" | "codex" | "copilot" | "gemini-cli" | "antigravity" | "kimi" | "kiro" | "cline" | "grok-cli")
}

async fn get_json(req: reqwest::RequestBuilder) -> Result<Value, String> {
    let r = req.timeout(Duration::from_secs(12)).send().await.map_err(|e| e.to_string())?;
    let status = r.status();
    if !status.is_success() {
        return Err(format!("usage API HTTP {}", status.as_u16()));
    }
    r.json().await.map_err(|e| e.to_string())
}

async fn fetch_with(client: &Client, provider: &str, cred: &Value) -> Result<AccountQuota, String> {
    let tok = cred["access_token"].as_str().unwrap_or("");
    let body = match provider {
        "claude" => {
            get_json(
                client
                    .get("https://api.anthropic.com/api/oauth/usage")
                    .bearer_auth(tok)
                    .header("anthropic-beta", "oauth-2025-04-20")
                    .header("anthropic-version", "2023-06-01")
                    .header("User-Agent", "claude-cli/2.1.322 (external, cli)"),
            )
            .await?
        }
        "codex" => {
            let mut r = client.get("https://chatgpt.com/backend-api/wham/usage").bearer_auth(tok).header("Accept", "application/json");
            // Team/multi-workspace logins answer 401 unless told which account to report on.
            if let Some(aid) = cred["account_id"].as_str() {
                r = r.header("chatgpt-account-id", aid);
            }
            get_json(r).await?
        }
        "copilot" => {
            let gh = cred["github_token"].as_str().unwrap_or(tok);
            get_json(
                client
                    .get("https://api.github.com/copilot_internal/user")
                    .header("Authorization", format!("token {gh}"))
                    .header("Accept", "application/json")
                    .header("X-GitHub-Api-Version", "2022-11-28")
                    .header("User-Agent", "GitHubCopilotChat/0.26.7")
                    .header("Editor-Version", "vscode/1.100.0")
                    .header("Editor-Plugin-Version", "copilot-chat/0.26.7"),
            )
            .await?
        }
        "gemini-cli" => {
            let project = cred["project_id"].as_str().ok_or("Gemini CLI has no project yet; send one chat first")?;
            get_json(
                client
                    .post("https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")
                    .bearer_auth(tok)
                    .json(&json!({ "project": project })),
            )
            .await?
        }
        "antigravity" => {
            let project = cred["project_id"].as_str().ok_or("Antigravity has no project yet; send one chat first")?;
            get_json(
                client
                    .post(format!("{}/v1internal:retrieveUserQuotaSummary", crate::oauth::AG_CHAT_BASE))
                    .bearer_auth(tok)
                    .header("User-Agent", AG_USER_AGENT)
                    .header("X-Client-Name", "antigravity")
                    .header("X-Client-Version", "2.24.0")
                    .json(&json!({ "project": project })),
            )
            .await?
        }
        "kimi" => {
            let mut r = client.get("https://api.kimi.com/coding/v1/usages").bearer_auth(tok).header("Accept", "application/json");
            for (k, v) in kimi_headers(cred["device_id"].as_str().unwrap_or("")) {
                r = r.header(k, v);
            }
            get_json(r).await?
        }
        "kiro" => {
            let mut r = client
                .get("https://codewhisperer.us-east-1.amazonaws.com/getUsageLimits")
                .query(&[("isEmailRequired", "true"), ("origin", "AI_EDITOR"), ("resourceType", "AGENTIC_REQUEST")])
                .bearer_auth(tok)
                .header("x-amz-user-agent", "aws-sdk-js/1.0.0 KiroIDE")
                .header("user-agent", "aws-sdk-js/1.0.0 KiroIDE");
            if let Some(arn) = kiro_profile_arn(cred) {
                r = r.query(&[("profileArn", arn)]);
            }
            get_json(r).await?
        }
        "cline" => {
            get_json(
                client
                    .get("https://api.cline.bot/api/v1/users/me/plan/usage-limits")
                    .bearer_auth(cline_bearer(tok))
                    .header("HTTP-Referer", "https://cline.bot")
                    .header("X-Title", "Cline"),
            )
            .await?
        }
        "grok-cli" => get_json(grok_headers(client.get(format!("{GROK_API}/billing?format=credits")), cred, "usage", 0, "")).await?,
        _ => return Err("no usage API".into()),
    };
    let mut q = parse(provider, &body);
    if provider == "grok-cli" && q.plan.is_none() {
        q.plan = grok_plan(tok);
    }
    Ok(q)
}

/// Maps a provider's usage response onto quota windows. Pure, so it can be unit tested.
pub fn parse(provider: &str, b: &Value) -> AccountQuota {
    let mut q = AccountQuota::default();
    match provider {
        "claude" => {
            for (key, v) in b.as_object().into_iter().flatten() {
                let Some(u) = v["utilization"].as_f64() else { continue };
                let name = match key.as_str() {
                    "five_hour" => "session (5h)".to_string(),
                    "seven_day" => "weekly (7d)".to_string(),
                    k => match k.strip_prefix("seven_day_") {
                        Some(x) => format!("weekly {x} (7d)"),
                        None => continue,
                    },
                };
                q.quotas.push(Quota::used_percent(name, u, to_unix_secs(&v["resets_at"])));
            }
            q.quotas.sort_by(|a, b| a.name.cmp(&b.name));
            q.plan = Some("Claude Code".into());
        }
        "codex" => {
            let base = b.get("rate_limit").or(b.get("rate_limits")).unwrap_or(b);
            let base = base.get("rate_limit").unwrap_or(base);
            let window = |name: &str, w: &Value, out: &mut Vec<Quota>| {
                if let Some(p) = w["used_percent"].as_f64().or(w["percent_used"].as_f64()) {
                    out.push(Quota::used_percent(name, p, to_unix_secs(w.get("reset_at").or(w.get("resets_at")).unwrap_or(&Value::Null))));
                }
            };
            window("session", base.get("primary_window").or(base.get("primary")).unwrap_or(&Value::Null), &mut q.quotas);
            window("weekly", base.get("secondary_window").or(base.get("secondary")).unwrap_or(&Value::Null), &mut q.quotas);
            q.plan = b["plan_type"].as_str().map(String::from);
        }
        "copilot" => {
            let reset = to_unix_secs(b.get("quota_reset_date").or(b.get("limited_user_reset_date")).unwrap_or(&Value::Null));
            if let Some(snap) = b["quota_snapshots"].as_object() {
                for (name, s) in snap {
                    if s["unlimited"] == true {
                        q.quotas.push(Quota {
                            name: name.clone(),
                            used: 0.0,
                            total: 0.0,
                            remaining_percentage: 100.0,
                            reset_at: reset,
                            unlimited: true,
                        });
                    } else if let (Some(total), Some(left)) = (s["entitlement"].as_f64(), s["remaining"].as_f64()) {
                        q.quotas.push(Quota::counts(name.clone(), total - left, total, reset));
                    }
                }
            } else if let Some(monthly) = b["monthly_quotas"].as_object() {
                for (name, total) in monthly {
                    let total = total.as_f64().unwrap_or(0.0);
                    let left = b["limited_user_quotas"][name].as_f64().unwrap_or(total);
                    q.quotas.push(Quota::counts(name.clone(), total - left, total, reset));
                }
            }
            q.plan = b["copilot_plan"].as_str().or(b["access_type_sku"].as_str()).map(String::from);
        }
        "gemini-cli" => {
            for bucket in b["buckets"].as_array().into_iter().flatten() {
                if let (Some(model), Some(f)) = (bucket["modelId"].as_str(), bucket["remainingFraction"].as_f64()) {
                    q.quotas.push(Quota::fraction_left(model, f, to_unix_secs(&bucket["resetTime"])));
                }
            }
        }
        "antigravity" => {
            let groups = b["groups"].as_array().or(b["quotaSummary"]["groups"].as_array());
            for g in groups.into_iter().flatten() {
                let family = g["displayName"].as_str().unwrap_or("").to_lowercase();
                let label = if family.contains("argon") {
                    "Gemini 4 Argon"
                } else if family.contains("gemini") {
                    "Gemini"
                } else if family.contains("claude") || family.contains("gpt") {
                    "Claude & GPT"
                } else {
                    continue;
                };
                for bucket in g["buckets"].as_array().into_iter().flatten() {
                    let w = format!("{} {}", bucket["window"].as_str().unwrap_or(""), bucket["displayName"].as_str().unwrap_or(""))
                        .to_lowercase();
                    let span = if w.contains("week") {
                        "Weekly"
                    } else if w.contains("5h") || w.contains("five hour") || w.contains("daily") {
                        "5h"
                    } else {
                        continue;
                    };
                    let disabled = bucket["disabled"] == true;
                    if disabled && span == "Weekly" {
                        continue;
                    }
                    let left = if disabled { 0.0 } else { bucket["remainingFraction"].as_f64().unwrap_or(1.0) };
                    q.quotas.push(Quota::fraction_left(format!("{label} ({span})"), left, to_unix_secs(&bucket["resetTime"])));
                }
            }
        }
        "kimi" => {
            let u = &b["usage"];
            if let Some(limit) = u["limit"].as_f64() {
                let used = u["used"].as_f64().unwrap_or_else(|| limit - u["remaining"].as_f64().unwrap_or(limit));
                let reset = u.get("resetTime").or(u.get("reset_at")).or(u.get("resetAt")).unwrap_or(&Value::Null);
                q.quotas.push(Quota::counts("Weekly", used, limit, to_unix_secs(reset)));
            }
            if let Some(d) = b["limits"].as_array().and_then(|l| l.last()).map(|l| &l["detail"]) {
                if let (Some(limit), Some(left)) = (d["limit"].as_f64(), d["remaining"].as_f64()) {
                    q.quotas.push(Quota::counts("Rate limit", limit - left, limit, to_unix_secs(&d["resetTime"])));
                }
            }
            q.plan = b["user"]["membership"]["level"].as_str().map(|l| {
                match l {
                    "LEVEL_BASIC" => "Moderato",
                    "LEVEL_INTERMEDIATE" => "Allegretto",
                    "LEVEL_ADVANCED" => "Allegro",
                    "LEVEL_STANDARD" => "Vivace",
                    other => other.trim_start_matches("LEVEL_"),
                }
                .to_string()
            });
        }
        "kiro" => {
            for item in b["usageBreakdownList"].as_array().into_iter().flatten() {
                let kind = item["resourceType"].as_str().unwrap_or("usage").to_lowercase();
                if let (Some(used), Some(total)) = (item["currentUsageWithPrecision"].as_f64(), item["usageLimitWithPrecision"].as_f64()) {
                    let reset = item.get("nextDateReset").or(item.get("resetDate")).unwrap_or(&Value::Null);
                    q.quotas.push(Quota::counts(kind.replace('_', " "), used, total, to_unix_secs(reset)));
                }
            }
            q.plan = b["subscriptionInfo"]["subscriptionTitle"].as_str().map(String::from);
        }
        "cline" => {
            let limits = b["data"]["limits"].as_array().or(b["limits"].as_array());
            for l in limits.into_iter().flatten() {
                let Some(p) = l["percentUsed"].as_f64() else { continue };
                let name = match l["type"].as_str().unwrap_or("") {
                    "five_hour" => "Session (5h)".to_string(),
                    "weekly" => "Weekly (7d)".to_string(),
                    "monthly" => "Monthly".to_string(),
                    other => other.to_string(),
                };
                q.quotas.push(Quota::used_percent(name, p, to_unix_secs(&l["resetsAt"])));
            }
            q.plan = Some("ClinePass".into());
        }
        "grok-cli" => {
            let c = b.get("config").unwrap_or(b);
            let num = |v: &Value| v.as_f64().or(v["val"].as_f64());
            let reset = to_unix_secs(
                c.get("billingPeriodEnd")
                    .or(c.get("periodEnd"))
                    .or(c.get("resetAt"))
                    .or(c["currentPeriod"].get("end"))
                    .unwrap_or(&Value::Null),
            );
            if let Some(limit) = num(&c["monthlyLimit"]).filter(|l| *l > 0.0) {
                let used = num(&c["includedUsed"]).or(num(&c["totalUsed"])).unwrap_or(0.0);
                q.quotas.push(Quota::counts("Monthly included", used, limit, reset));
            }
            if let Some(p) = num(&c["creditUsagePercent"]) {
                q.quotas.push(Quota::used_percent("Weekly SuperGrok", p, reset));
            }
            q.plan = c["subscriptionTier"].as_str().map(String::from);
        }
        _ => {}
    }
    q
}

/// The Grok plan is encoded in the access token's `tier` claim.
fn grok_plan(token: &str) -> Option<String> {
    let tier = crate::oauth::extract_jwt_claims(token)?["tier"].as_i64()?;
    Some(
        match tier {
            0 => "Free",
            1 => "SuperGrok",
            2 => "X Basic",
            3 => "X Premium",
            4 => "X Premium+",
            5 => "SuperGrok Heavy",
            6 => "SuperGrok Lite",
            _ => return None,
        }
        .into(),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    mod to_unix_secs {
        use super::*;

        #[test]
        fn keeps_seconds() {
            assert_eq!(to_unix_secs(&json!(1_800_000_000)), Some(1_800_000_000.0));
        }

        #[test]
        fn converts_milliseconds() {
            assert_eq!(to_unix_secs(&json!(1_800_000_000_000_i64)), Some(1_800_000_000.0));
        }

        #[test]
        fn parses_iso_dates() {
            assert_eq!(to_unix_secs(&json!("1970-01-02T00:00:00Z")), Some(86_400.0));
        }

        #[test]
        fn parses_bare_dates_as_utc_midnight() {
            assert_eq!(to_unix_secs(&json!("1970-01-02")), Some(86_400.0));
        }

        #[test]
        fn ignores_nulls() {
            assert_eq!(to_unix_secs(&Value::Null), None);
        }
    }

    mod keep_last_good {
        use super::*;

        fn good() -> AccountQuota {
            AccountQuota { quotas: vec![Quota::used_percent("weekly", 10.0, None)], ..Default::default() }
        }

        fn failed() -> AccountQuota {
            AccountQuota { message: Some("usage API HTTP 503".into()), ..Default::default() }
        }

        #[test]
        fn a_failure_keeps_the_previous_windows() {
            assert_eq!(keep_last_good(Some(&good()), failed()).0.quotas.len(), 1);
        }

        #[test]
        fn a_failure_is_not_cached() {
            assert!(!keep_last_good(Some(&good()), failed()).1);
        }

        #[test]
        fn a_success_replaces_and_is_cached() {
            let (shown, cache) = keep_last_good(Some(&failed()), good());
            assert_eq!((shown.quotas.len(), cache), (1, true));
        }
    }

    #[test]
    fn claude_maps_five_hour_and_weekly_windows() {
        let q = parse(
            "claude",
            &json!({"five_hour":{"utilization":40,"resets_at":"1970-01-02T00:00:00Z"},"seven_day":{"utilization":10},"extra":{}}),
        );
        assert_eq!(
            q.quotas.iter().map(|x| (x.name.as_str(), x.remaining_percentage)).collect::<Vec<_>>(),
            vec![("session (5h)", 60.0), ("weekly (7d)", 90.0)]
        );
    }

    #[test]
    fn codex_maps_primary_and_secondary_windows() {
        let q = parse(
            "codex",
            &json!({"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":25,"reset_at":100},"secondary_window":{"used_percent":5}}}),
        );
        assert_eq!((q.quotas[0].remaining_percentage, q.quotas[1].name.as_str(), q.plan.as_deref()), (75.0, "weekly", Some("plus")));
    }

    #[test]
    fn copilot_marks_unlimited_snapshots() {
        let q = parse(
            "copilot",
            &json!({"quota_snapshots":{"chat":{"unlimited":true},"premium_interactions":{"entitlement":300,"remaining":30}}}),
        );
        let premium = q.quotas.iter().find(|x| x.name == "premium_interactions").unwrap();
        assert_eq!((q.quotas.iter().any(|x| x.unlimited), premium.remaining_percentage), (true, 10.0));
    }

    #[test]
    fn gemini_uses_the_fraction_left() {
        let q = parse("gemini-cli", &json!({"buckets":[{"modelId":"gemini-2.5-pro","remainingFraction":0.8}]}));
        assert!((q.quotas[0].remaining_percentage - 80.0).abs() < 1e-9);
    }

    #[test]
    fn antigravity_groups_become_family_windows() {
        let q = parse(
            "antigravity",
            &json!({"groups":[{"displayName":"Gemini models","buckets":[{"window":"weekly","remainingFraction":0.5},{"window":"5h","remainingFraction":0.9}]}]}),
        );
        assert_eq!(q.quotas.iter().map(|x| x.name.as_str()).collect::<Vec<_>>(), vec!["Gemini (Weekly)", "Gemini (5h)"]);
    }

    #[test]
    fn kimi_maps_the_membership_level() {
        assert_eq!(parse("kimi", &json!({"user":{"membership":{"level":"LEVEL_ADVANCED"}}})).plan.as_deref(), Some("Allegro"));
    }

    #[test]
    fn kiro_maps_usage_breakdowns() {
        let q = parse(
            "kiro",
            &json!({"usageBreakdownList":[{"resourceType":"AGENTIC_REQUEST","currentUsageWithPrecision":25,"usageLimitWithPrecision":50}]}),
        );
        assert_eq!((q.quotas[0].name.as_str(), q.quotas[0].remaining_percentage), ("agentic request", 50.0));
    }

    #[test]
    fn cline_maps_named_limits() {
        let q = parse("cline", &json!({"data":{"limits":[{"type":"five_hour","percentUsed":30}]}}));
        assert_eq!((q.quotas[0].name.as_str(), q.quotas[0].remaining_percentage), ("Session (5h)", 70.0));
    }

    #[test]
    fn grok_reads_wrapped_values() {
        let q = parse("grok-cli", &json!({"config":{"monthlyLimit":{"val":100},"includedUsed":{"val":25}}}));
        assert_eq!(q.quotas[0].remaining_percentage, 75.0);
    }
}
