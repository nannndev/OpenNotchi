use crate::providers::{
    find_oauth_by_alias, find_oauth_by_id, find_provider_by_alias, find_provider_by_id, parse_model_string, Target, OAUTH_PROVIDERS,
    PROVIDERS,
};
use crate::store::{AccountRecord, GatewaySettings, GatewayStore, ProviderRecord, UsageEntry, VirtualKeyRecord};
use crate::translate::{aggregate_sse, openai_to_anthropic, openai_to_commandcode, SseToOpenAi};
use axum::{
    body::{Body, Bytes},
    http::{header, HeaderValue, StatusCode},
    response::{IntoResponse, Json, Response},
};
use futures::{stream::BoxStream, StreamExt};
use reqwest::Client;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::Arc;

#[derive(Clone)]
pub struct GatewayEngine {
    pub store: Arc<GatewayStore>,
    pub http_client: Client,
    pub oauth: crate::oauth::OAuthManager,
    /// Live usage windows per subscription account, cached briefly.
    pub quotas: crate::quota::QuotaCache,
    /// Round-robin cursor per provider.
    rr: Arc<parking_lot::Mutex<HashMap<String, usize>>>,
    /// fill_first: the account that last succeeded, per provider.
    sticky: Arc<parking_lot::Mutex<HashMap<String, String>>>,
}

impl GatewayEngine {
    pub fn new(store: GatewayStore) -> Self {
        Self {
            store: Arc::new(store),
            // Meta (Muse) answers UA-less requests with a 302 to a login page
            http_client: Client::builder().user_agent("OpenNotchiGateway/1.0").build().unwrap_or_default(),
            oauth: crate::oauth::OAuthManager::new(),
            rr: Default::default(),
            sticky: Default::default(),
            quotas: Default::default(),
        }
    }

    /// Expands a requested model into ordered provider/model targets.
    /// `auto` = every connected provider by priority, `<alias>/auto` = one provider,
    /// `auto/<combo>` = a user-defined mix (entries may themselves be `<alias>/auto`).
    pub fn resolve_targets(&self, requested: &str) -> Vec<Target> {
        let s = self.store.get_gateway_settings();
        let req = requested.trim();
        let mut out = Vec::new();
        if let Some(name) = req.strip_prefix("auto/") {
            match self.store.list_combos().get(name) {
                Some(entries) => entries.iter().for_each(|e| extend_unique(&mut out, self.resolve_one(e, &s))),
                None => extend_unique(&mut out, self.provider_auto(name, &s)), // "auto/cx" == "cx/auto"
            }
            return out;
        }
        extend_unique(&mut out, self.resolve_one(req, &s));
        out
    }

    fn resolve_one(&self, req: &str, s: &GatewaySettings) -> Vec<Target> {
        let req = req.trim();
        if req.is_empty() || req == "auto" {
            return self.auto_provider_order(s).iter().flat_map(|id| self.provider_auto(id, s)).collect();
        }
        if let Some(prefix) = req.strip_suffix("/auto") {
            return self.provider_auto(prefix, s);
        }
        let Ok(t) = parse_model_string(req) else { return Vec::new() };
        let mut out = vec![t.clone()];
        // A subscription model falls back to that provider's other plan-appropriate models.
        if t.kind == "oauth" {
            extend_unique(&mut out, self.provider_auto(&t.provider, s));
        }
        out
    }

    fn provider_auto(&self, prefix: &str, s: &GatewaySettings) -> Vec<Target> {
        let target = |provider: &str, model: &str, kind: &str| Target { provider: provider.into(), model: model.into(), kind: kind.into() };
        if let Some(op) = find_oauth_by_alias(prefix).or_else(|| find_oauth_by_id(prefix)) {
            let accounts: Vec<AccountRecord> =
                self.store.list_accounts().into_iter().filter(|a| a.provider == op.id && a.enabled).collect();
            let all_free = accounts.is_empty() || accounts.iter().all(|a| a.is_free());
            let paid: &[&str] = if all_free { &[] } else { op.preferred_auto };
            let mut out = Vec::new();
            extend_unique(&mut out, paid.iter().chain(op.preferred_auto_free).map(|m| target(op.id, m, "oauth")));
            return out;
        }
        if let Some(p) = find_provider_by_alias(prefix).or_else(|| find_provider_by_id(prefix)) {
            // The user's own models first: adding one is the signal they want it used.
            let mut models = self.store.get_provider_custom_models(p.id);
            for m in p.seed_models {
                if !models.iter().any(|x| x == m) {
                    models.push(m.to_string());
                }
            }
            return models.iter().take(s.auto_models_per_provider).map(|m| target(p.id, m, "apikey")).collect();
        }
        Vec::new()
    }

    /// Providers `auto` uses, in order: the saved priority first, then any other connected
    /// subscription providers, then connected API-key providers.
    pub fn auto_provider_order(&self, s: &GatewaySettings) -> Vec<String> {
        let accounts = self.store.list_accounts();
        let records: std::collections::HashMap<String, ProviderRecord> =
            self.store.list_providers().into_iter().map(|r| (r.id.clone(), r)).collect();
        let usable = |id: &str| -> bool {
            if !self.store.is_provider_enabled(id) {
                return false;
            }
            if find_oauth_by_id(id).is_some() {
                return accounts.iter().any(|a| a.provider == id && a.enabled);
            }
            let extra_key = accounts.iter().any(|a| a.provider == id && a.enabled);
            match (find_provider_by_id(id), records.get(id)) {
                (Some(p), Some(r)) => r.has_key || !p.needs_key || extra_key,
                (Some(_), None) => extra_key,
                _ => false,
            }
        };
        let mut order: Vec<String> = Vec::new();
        let candidates = s
            .provider_priority
            .iter()
            .cloned()
            .chain(OAUTH_PROVIDERS.iter().map(|o| o.id.to_string()))
            .chain(PROVIDERS.iter().map(|p| p.id.to_string()));
        for id in candidates {
            if !order.contains(&id) && usable(&id) {
                order.push(id);
            }
        }
        order
    }

    /// Model ids worth showing in pickers for the auto modes.
    pub fn auto_model_ids(&self) -> Vec<String> {
        let s = self.store.get_gateway_settings();
        let mut ids = vec!["auto".to_string()];
        let mut combos: Vec<String> = self.store.list_combos().into_keys().collect();
        combos.sort();
        ids.extend(combos.into_iter().map(|c| format!("auto/{c}")));
        for id in self.auto_provider_order(&s) {
            let alias = find_oauth_by_id(&id).map(|o| o.alias).or_else(|| find_provider_by_id(&id).map(|p| p.alias)).unwrap_or(&id);
            ids.push(format!("{alias}/auto"));
        }
        ids
    }

    /// Turns targets into concrete (target, account) attempts following the routing settings.
    /// Attempts on cooling accounts/providers move to the end, so they're only a last resort.
    fn plan_attempts(&self, targets: &[Target], s: &GatewaySettings) -> Vec<(Target, Option<AccountRecord>)> {
        let all_accounts = self.store.list_accounts();
        let mut ordered: std::collections::HashMap<String, Vec<AccountRecord>> = Default::default();
        let mut out = Vec::new();
        // Consecutive targets of one provider form a group, so combos keep their interleaving.
        for group in targets.chunk_by(|a, b| a.provider == b.provider) {
            let prov = &group[0].provider;
            let accs = ordered.entry(prov.clone()).or_insert_with(|| self.ordered_accounts(prov, &all_accounts, s)).clone();
            if group[0].kind != "oauth" {
                // API-key providers: the main key (None) first, then any extra keys, in routing order.
                let keys: Vec<Option<AccountRecord>> = std::iter::once(None).chain(accs.into_iter().map(Some)).collect();
                if s.fallback_order == "account_first" {
                    for k in &keys {
                        out.extend(group.iter().map(|t| (t.clone(), k.clone())));
                    }
                } else {
                    for t in group {
                        out.extend(keys.iter().map(|k| (t.clone(), k.clone())));
                    }
                }
                continue;
            }
            if s.fallback_order == "account_first" {
                for a in &accs {
                    out.extend(group.iter().map(|t| (t.clone(), Some(a.clone()))));
                }
            } else {
                for t in group {
                    out.extend(accs.iter().map(|a| (t.clone(), Some(a.clone()))));
                }
            }
        }
        out.sort_by_key(|(t, a)| self.store.cooling_until(&cool_key(t, a.as_ref())).is_some());
        out
    }

    fn ordered_accounts(&self, provider: &str, all: &[AccountRecord], s: &GatewaySettings) -> Vec<AccountRecord> {
        // `all` is already in the user's per-provider sort order.
        let mut accs: Vec<AccountRecord> = all.iter().filter(|a| a.provider == provider && a.enabled).cloned().collect();
        if accs.len() < 2 {
            return accs;
        }
        match s.routing_strategy.as_str() {
            "round_robin" => {
                let mut rr = self.rr.lock();
                let n = rr.entry(provider.to_string()).or_insert(0);
                let len = accs.len();
                accs.rotate_left(*n % len);
                *n = n.wrapping_add(1);
            }
            "fill_first" => {
                if let Some(id) = self.sticky.lock().get(provider) {
                    if let Some(pos) = accs.iter().position(|a| &a.id == id) {
                        let a = accs.remove(pos);
                        accs.insert(0, a);
                    }
                }
            }
            _ => {}
        }
        accs
    }

    /// Routes one OpenAI-style chat request across the resolved targets, failing over on errors.
    /// `key` is the caller's virtual key, if it presented one.
    pub async fn chat_completions(&self, key: Option<VirtualKeyRecord>, mut body: Value) -> Result<Response, (StatusCode, Json<Value>)> {
        let req_model = body.get("model").and_then(|m| m.as_str()).unwrap_or("auto").to_string();
        let wants_stream = body.get("stream").and_then(|s| s.as_bool()).unwrap_or(false);
        let key_name = key.as_ref().map(|k| k.name.clone()).unwrap_or_else(|| "AI Copilot".to_string());

        if let Some(k) = &key {
            if let Some(limit) = k.rate_limit_per_min.filter(|l| *l > 0) {
                if self.store.key_requests_since(&k.id, crate::store::now() - 60.0) >= limit {
                    return Err(gateway_err(
                        StatusCode::TOO_MANY_REQUESTS,
                        format!("Rate limit of {limit} requests/min reached for key '{}'", k.name),
                    ));
                }
            }
        }

        let mut targets = self.resolve_targets(&req_model);
        if let Some(allowed) = key.as_ref().and_then(|k| k.allowed_providers.clone()).filter(|a| !a.is_empty()) {
            // Entries may be provider ids ("codex") or aliases ("cx").
            targets.retain(|t| allowed.iter().any(|a| *a == t.provider || t.public().starts_with(&format!("{a}/"))));
            if targets.is_empty() {
                return Err(gateway_err(StatusCode::FORBIDDEN, format!("Key '{}' is not allowed to use {req_model}", key_name)));
            }
        }
        let settings = self.store.get_gateway_settings();
        let mut last_error = format!("no connected provider can serve '{req_model}'");

        for (target, acc) in self.plan_attempts(&targets, &settings) {
            if !self.store.is_provider_enabled(&target.provider) {
                continue;
            }
            let cool = cool_key(&target, acc.as_ref());
            let t0 = std::time::Instant::now();
            let mut resp = None;
            if let Some(acc) = acc.as_ref().filter(|_| target.kind == "oauth") {
                // One forced refresh + retry when the upstream rejects the token.
                for force in [false, true] {
                    let cred = match crate::oauth::fresh_credential(&self.http_client, &self.store, acc, force).await {
                        Ok(c) => c,
                        Err(e) => {
                            last_error = e;
                            break;
                        }
                    };
                    let Some((req, kind)) =
                        crate::oauth::subscription_request(&self.http_client, &target.provider, &cred, &target.model, &body)
                    else {
                        break;
                    };
                    match req.send().await {
                        Ok(r) if r.status().as_u16() == 401 && !force => {
                            last_error = format!("{}: 401", target.provider);
                            continue;
                        }
                        Ok(r) => {
                            resp = Some((r, kind));
                            break;
                        }
                        Err(e) => {
                            last_error = format!("{}: {e}", target.provider);
                            break;
                        }
                    }
                }
            } else {
                let rec = self.store.get_provider_record(&target.provider);
                if rec.as_ref().map(|r| !r.enabled).unwrap_or(false) {
                    continue;
                }
                let Some(p) = find_provider_by_id(&target.provider) else { continue };
                // An extra key (stored as an account) overrides the provider's main key.
                let key = match &acc {
                    Some(a) => a.cred["api_key"].as_str().map(String::from),
                    None => self.store.get_provider_key(&target.provider),
                };
                if p.needs_key && key.is_none() {
                    continue;
                }
                let base = rec.and_then(|r| r.base_url).filter(|s| !s.trim().is_empty()).unwrap_or_else(|| p.base_url.to_string());
                let base = base.trim_end_matches('/');
                let (req, kind) = if p.family == "commandcode" {
                    // Same conversation -> same thread, keyed on the first user message.
                    let seed = body["messages"]
                        .as_array()
                        .and_then(|m| m.iter().find(|m| m["role"] == "user"))
                        .map(|m| m["content"].to_string())
                        .unwrap_or_default();
                    let thread = commandcode_thread_id(&seed);
                    let r = crate::oauth::commandcode_headers(
                        self.http_client.post(format!("{base}/alpha/generate")),
                        key.as_deref().unwrap_or(""),
                        &thread,
                    )
                    .json(&openai_to_commandcode(&body, &target.model, &thread));
                    (r, "commandcode")
                } else if p.family == "openai-responses" {
                    // Same wire format as Codex, minus the ChatGPT-specific fields.
                    let mut b = crate::translate::openai_to_codex(&body, &target.model);
                    if let Some(o) = b.as_object_mut() {
                        o.remove("store");
                        o.remove("include");
                    }
                    let r = self.http_client.post(format!("{base}/responses")).bearer_auth(key.unwrap_or_default()).json(&b);
                    (r, "codex")
                } else if p.family == "anthropic" {
                    let mut b = openai_to_anthropic(&body, &target.model);
                    b["stream"] = json!(true);
                    let r = self
                        .http_client
                        .post(format!("{base}/messages"))
                        .header("x-api-key", key.unwrap_or_default())
                        .header("anthropic-version", "2023-06-01")
                        .json(&b);
                    (r, "claude")
                } else {
                    body["model"] = json!(target.model);
                    body["stream"] = json!(true);
                    body["stream_options"] = json!({ "include_usage": true });
                    let mut r = self.http_client.post(format!("{base}/chat/completions")).json(&body);
                    if let Some(k) = key {
                        // Azure's v1 API takes the key in `api-key`, not a bearer token.
                        r = if p.id == "azure-openai" { r.header("api-key", k) } else { r.bearer_auth(k) };
                    }
                    (r, "openai")
                };
                match req.header("Accept", "text/event-stream").send().await {
                    Ok(r) => resp = Some((r, kind)),
                    Err(e) => last_error = format!("{}: {e}", target.public()),
                }
            }

            let Some((upstream, kind)) = resp else {
                if let Some(a) = &acc {
                    let _ = self.store.record_account_error(&a.id, Some(&last_error));
                }
                continue;
            };
            let status = upstream.status();
            if !status.is_success() {
                let retry_after = upstream.headers().get("retry-after").and_then(|v| v.to_str().ok()).and_then(|v| v.trim().parse().ok());
                let err_text = upstream.text().await.unwrap_or_default();
                self.store.record_usage(&UsageEntry {
                    key_id: key.as_ref().map(|k| k.id.as_str()),
                    key_name: Some(&key_name),
                    provider: Some(&target.provider),
                    model: Some(&target.model),
                    input_tokens: 0,
                    output_tokens: 0,
                    cached_tokens: 0,
                    duration_ms: t0.elapsed().as_millis() as i64,
                    status: "error",
                    status_code: i64::from(status.as_u16()),
                    error: Some(&err_text),
                    streaming: wants_stream,
                });
                last_error = format!("{} HTTP {}: {}", target.public(), status, err_text.chars().take(300).collect::<String>());
                if let Some(secs) = cooldown_for(status.as_u16(), retry_after, &err_text, settings.cooldown_secs) {
                    self.store.cool_down(&cool, secs);
                    last_error.push_str(&format!(" (cooling {secs}s)"));
                }
                if let Some(a) = &acc {
                    let _ = self.store.record_account_error(&a.id, Some(&last_error));
                }
                eprintln!("[GATEWAY CHAT] {last_error}");
                continue;
            }
            self.store.clear_cooldown(&cool);
            if let Some(a) = &acc {
                let _ = self.store.record_account_error(&a.id, None);
                self.sticky.lock().insert(target.provider.clone(), a.id.clone());
            }

            let tr = Arc::new(parking_lot::Mutex::new(SseToOpenAi::new(kind, target.public())));
            let guard = UsageGuard {
                store: self.store.clone(),
                tr: tr.clone(),
                key_id: key.as_ref().map(|k| k.id.clone()),
                key_name: key_name.clone(),
                provider: target.provider.clone(),
                model: target.model.clone(),
                t0,
                streaming: wants_stream,
            };
            let frames = sse_frames(upstream, tr.clone(), guard);

            if wants_stream {
                let mut resp = Response::new(Body::from_stream(frames));
                let h = resp.headers_mut();
                h.insert(header::CONTENT_TYPE, HeaderValue::from_static("text/event-stream"));
                h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-cache"));
                return Ok(resp);
            }
            let mut sse = String::new();
            let mut frames = frames;
            while let Some(chunk) = frames.next().await {
                match chunk {
                    Ok(b) => sse.push_str(&String::from_utf8_lossy(&b)),
                    Err(e) => return Err(gateway_err(StatusCode::BAD_GATEWAY, e.to_string())),
                }
            }
            drop(frames); // records usage before we read it below
            let usage = tr.lock().usage;
            if let Some(msg) = sse_error(&sse) {
                return Err(gateway_err(StatusCode::BAD_GATEWAY, msg));
            }
            return Ok(Json(aggregate_sse(&sse, usage)).into_response());
        }

        Err(gateway_err(StatusCode::BAD_GATEWAY, format!("No connected AI provider could respond: {last_error}")))
    }
}

/// Stable UUID-shaped id from a seed (Command Code groups requests by thread).
fn commandcode_thread_id(seed: &str) -> String {
    use sha2::{Digest, Sha256};
    let h = hex::encode(Sha256::digest(seed.as_bytes()));
    format!("{}-{}-4{}-a{}-{}", &h[0..8], &h[8..12], &h[13..16], &h[17..20], &h[20..32])
}

fn extend_unique(out: &mut Vec<Target>, items: impl IntoIterator<Item = Target>) {
    for t in items {
        if !out.contains(&t) {
            out.push(t);
        }
    }
}

/// Cooldown bucket: a subscription account, or a whole API-key provider.
fn cool_key(t: &Target, acc: Option<&AccountRecord>) -> String {
    acc.map(|a| a.id.clone()).unwrap_or_else(|| format!("apikey:{}", t.provider))
}

/// Seconds to bench a rate-limited / out-of-quota upstream, or None for other errors.
/// `default` 0 disables cooldown unless the upstream names its own reset time.
fn cooldown_for(status: u16, retry_after: Option<u64>, body: &str, default: u64) -> Option<u64> {
    let b = body.to_lowercase();
    let limited = status == 429
        || ["rate limit", "rate_limit", "quota", "usage limit", "usage_limit", "too many requests"].iter().any(|k| b.contains(k));
    if !limited {
        return None;
    }
    let hinted = retry_after.or_else(|| {
        let j: Value = serde_json::from_str(body).ok()?;
        j["error"]["resets_in_seconds"].as_u64().or(j["resets_in_seconds"].as_u64())
    });
    let secs = hinted.unwrap_or(default);
    (secs > 0).then(|| secs.min(6 * 3600))
}

fn gateway_err(status: StatusCode, message: String) -> (StatusCode, Json<Value>) {
    (status, Json(json!({ "error": { "message": message, "type": "gateway_error" } })))
}

/// First in-band error frame of a translated stream, if any.
fn sse_error(sse: &str) -> Option<String> {
    sse.lines()
        .filter_map(|l| l.trim().strip_prefix("data:"))
        .filter_map(|d| serde_json::from_str::<Value>(d.trim()).ok())
        .find_map(|v| v["error"]["message"].as_str().map(String::from))
}

/// Records the request's usage once its response stream is finished or dropped (client disconnect).
struct UsageGuard {
    store: Arc<GatewayStore>,
    tr: Arc<parking_lot::Mutex<SseToOpenAi>>,
    key_id: Option<String>,
    key_name: String,
    provider: String,
    model: String,
    t0: std::time::Instant,
    streaming: bool,
}

impl Drop for UsageGuard {
    fn drop(&mut self) {
        let (inp, out, cached) = {
            let t = self.tr.lock();
            (t.usage.0, t.usage.1, t.cached)
        };
        self.store.record_usage(&UsageEntry {
            key_id: self.key_id.as_deref(),
            key_name: Some(&self.key_name),
            provider: Some(&self.provider),
            model: Some(&self.model),
            input_tokens: inp,
            output_tokens: out,
            cached_tokens: cached,
            duration_ms: self.t0.elapsed().as_millis() as i64,
            status: "success",
            status_code: 200,
            error: None,
            streaming: self.streaming,
        });
        if let Some(id) = &self.key_id {
            self.store.touch_virtual_key(id, inp, out);
        }
    }
}

/// Kiro replies with a binary AWS event stream instead of SSE.
fn kiro_frames(
    upstream: reqwest::Response,
    tr: Arc<parking_lot::Mutex<SseToOpenAi>>,
    guard: UsageGuard,
    start: String,
) -> BoxStream<'static, Result<Bytes, std::io::Error>> {
    let state = Arc::new(parking_lot::Mutex::new(crate::kiro::KiroStream::default()));
    let (tr_end, state_end) = (tr.clone(), state.clone());
    let events = upstream.bytes_stream().map(move |item| {
        let bytes = item.map_err(std::io::Error::other)?;
        let mut t = tr.lock();
        let out = match state.lock().push(&mut t, &bytes) {
            Ok(frames) => frames.concat(),
            Err(e) => format!("data: {}\n\n", json!({ "error": { "message": e } })),
        };
        Ok(Bytes::from(out))
    });
    let tail = futures::stream::once(async move {
        let frames = state_end.lock().finish(&mut tr_end.lock()).concat();
        drop(guard);
        Ok(Bytes::from(frames))
    });
    futures::stream::once(async move { Ok(Bytes::from(start)) }).chain(events).chain(tail).boxed()
}

/// Turns an upstream SSE body into OpenAI chat.completion.chunk frames, ending with [DONE].
fn sse_frames(
    upstream: reqwest::Response,
    tr: Arc<parking_lot::Mutex<SseToOpenAi>>,
    guard: UsageGuard,
) -> BoxStream<'static, Result<Bytes, std::io::Error>> {
    let start = {
        let t = tr.lock();
        if t.kind_passthrough() {
            String::new()
        } else {
            t.base.start_chunk()
        }
    };
    let tr_end = tr.clone();
    if tr.lock().is_kiro() {
        return kiro_frames(upstream, tr, guard, start);
    }
    let mut buf = String::new();
    let events = upstream.bytes_stream().map(move |item| {
        let bytes = item.map_err(std::io::Error::other)?;
        buf.push_str(&String::from_utf8_lossy(&bytes));
        let mut out = String::new();
        let mut t = tr.lock();
        // SSE events can span network chunks: only consume complete lines.
        while let Some(i) = buf.find('\n') {
            let line: String = buf.drain(..=i).collect();
            if let Some(data) = line.trim().strip_prefix("data:") {
                if let Ok(ev) = serde_json::from_str::<Value>(data.trim()) {
                    match t.feed(&ev) {
                        Ok(frames) => out.extend(frames),
                        Err(e) => out.push_str(&format!("data: {}\n\n", json!({ "error": { "message": e } }))),
                    }
                }
            }
        }
        Ok(Bytes::from(out))
    });
    let tail = futures::stream::once(async move {
        let frames = tr_end.lock().end().concat();
        drop(guard);
        Ok(Bytes::from(frames))
    });
    futures::stream::once(async move { Ok(Bytes::from(start)) }).chain(events).chain(tail).boxed()
}

// ---------------------------------------------------------------------
// Helper builders for Client-compatible responses
// ---------------------------------------------------------------------
pub fn get_oauth_accounts_state(store: &GatewayStore) -> Value {
    let accounts = store.list_accounts();
    let client_accounts: Vec<Value> = accounts
        .into_iter()
        // Extra API keys are stored as accounts but belong to their provider, not this list.
        .filter(|a| find_oauth_by_id(&a.provider).is_some())
        .map(|a| {
            let expires_at = a.cred.get("expires_at").and_then(|v| v.as_f64());
            let plan = a.display_plan();
            let is_free = a.is_free();
            json!({
                "id": a.id,
                "provider": a.provider,
                "label": a.label,
                "email": a.email,
                "enabled": a.enabled,
                "connected_at": a.connected_at,
                "refreshed_at": a.refreshed_at,
                "expires_at": expires_at,
                "last_error": a.last_error,
                "plan": plan,
                "is_free": is_free,
                "cooling_until": store.cooling_until(&a.id),
            })
        })
        .collect();

    let mut models_map = serde_json::Map::new();
    let mut aliases_map = serde_json::Map::new();
    let mut enabled_map = serde_json::Map::new();
    for op in OAUTH_PROVIDERS {
        models_map.insert(op.id.to_string(), json!(store.display_models(op.id, op.seed_models)));
        aliases_map.insert(op.id.to_string(), json!(op.alias));
        enabled_map.insert(op.id.to_string(), json!(store.is_provider_enabled(op.id)));
    }

    let settings = store.get_gateway_settings();

    json!({
        "accounts": client_accounts,
        "models": models_map,
        "aliases": aliases_map,
        "provider_enabled": enabled_map,
        "providers": OAUTH_PROVIDERS,
        "settings": settings,
    })
}

pub fn build_gateway_providers(store: &GatewayStore) -> Vec<Value> {
    let stored_records = store.list_providers();
    let record_map: std::collections::HashMap<String, ProviderRecord> = stored_records.into_iter().map(|r| (r.id.clone(), r)).collect();

    let accounts = store.list_accounts();
    let mut out = Vec::new();
    for p in PROVIDERS {
        let rec = record_map.get(p.id);
        let enabled = rec.map(|r| r.enabled).unwrap_or(true);
        let extra_keys: Vec<Value> = accounts
            .iter()
            .filter(|a| a.provider == p.id)
            .map(|a| {
                json!({
                    "id": a.id, "label": a.label, "enabled": a.enabled, "last_error": a.last_error,
                    "cooling_until": store.cooling_until(&a.id),
                })
            })
            .collect();
        let connected = rec.map(|r| r.has_key).unwrap_or(false) || !p.needs_key || !extra_keys.is_empty();
        let base_url = rec.and_then(|r| r.base_url.clone());
        let verified_at = rec.and_then(|r| r.verified_at);
        let latency_ms = rec.and_then(|r| r.latency_ms);
        let error = rec.and_then(|r| r.error.clone());
        let custom_models: Vec<String> = rec.map(|r| r.models.clone()).unwrap_or_default();
        let models = store.display_models(p.id, p.seed_models);
        let (synced, synced_at) = store.get_synced_models(p.id);

        out.push(json!({
            "id": p.id,
            "alias": p.alias,
            "name": p.name,
            "family": p.family,
            "default_base_url": p.base_url,
            "needs_key": p.needs_key,
            "enabled": enabled,
            "connected": connected,
            "extra_keys": extra_keys,
            "base_url": base_url,
            "api_key": if connected && p.needs_key { Some("••••••••") } else { None },
            "models": models,
            "custom_models": custom_models,
            "seed_models": p.seed_models,
            "synced_count": synced.len(),
            "models_synced_at": synced_at,
            "verified_at": verified_at,
            "latency_ms": latency_ms,
            "cooling": store.cooling_until(&format!("apikey:{}", p.id)).is_some(),
            "error": error,
        }));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn engine() -> (GatewayEngine, tempfile::TempDir) {
        let dir = tempfile::tempdir().unwrap();
        (GatewayEngine::new(GatewayStore::new(dir.path()).unwrap()), dir)
    }

    fn ids(ts: &[Target]) -> Vec<String> {
        ts.iter().map(Target::public).collect()
    }

    /// OpenAI (with one custom model) and DeepSeek connected by API key.
    fn two_apikey_providers() -> (GatewayEngine, tempfile::TempDir) {
        let (e, d) = engine();
        e.store.save_provider_key("openai", "sk-1").unwrap();
        e.store.save_provider_key("deepseek", "sk-2").unwrap();
        e.store.add_provider_model("openai", "my-model").unwrap();
        (e, d)
    }

    mod resolve_targets {
        use super::*;

        #[test]
        fn auto_tries_two_models_per_apikey_provider_by_default() {
            let (e, _d) = two_apikey_providers();
            assert_eq!(e.resolve_targets("auto").len(), 4);
        }

        #[test]
        fn auto_puts_a_providers_custom_models_first() {
            let (e, _d) = two_apikey_providers();
            assert_eq!(ids(&e.resolve_targets("auto"))[0], "oa/my-model");
        }

        #[test]
        fn auto_follows_the_saved_provider_priority() {
            let (e, _d) = two_apikey_providers();
            e.store.set_setting("provider_priority", r#"["deepseek","openai"]"#).unwrap();
            let order = ids(&e.resolve_targets("auto"));
            assert!(order[0].starts_with("ds/") && order[2].starts_with("oa/"), "{order:?}");
        }

        #[test]
        fn provider_auto_and_auto_provider_are_the_same() {
            let (e, _d) = two_apikey_providers();
            assert_eq!(ids(&e.resolve_targets("oa/auto")), ids(&e.resolve_targets("auto/oa")));
        }

        #[test]
        fn provider_auto_stays_within_that_provider() {
            let (e, _d) = two_apikey_providers();
            let t = ids(&e.resolve_targets("ds/auto"));
            assert!(t.iter().all(|m| m.starts_with("ds/")), "{t:?}");
        }

        #[test]
        fn an_unknown_combo_resolves_to_nothing() {
            let (e, _d) = engine();
            assert!(e.resolve_targets("auto/missing-combo").is_empty());
        }

        #[test]
        fn a_combo_keeps_its_explicit_models_first() {
            let (e, _d) = engine();
            e.store.save_provider_key("deepseek", "sk").unwrap();
            e.store.save_combo("mix", &["oa/gpt-4o".into(), "ds/auto".into()]).unwrap();
            assert_eq!(ids(&e.resolve_targets("auto/mix"))[0], "oa/gpt-4o");
        }

        #[test]
        fn a_combo_drops_duplicate_targets() {
            let (e, _d) = engine();
            e.store.save_provider_key("deepseek", "sk").unwrap();
            e.store.save_combo("mix", &["oa/gpt-4o".into(), "ds/auto".into(), "oa/gpt-4o".into()]).unwrap();
            let t = ids(&e.resolve_targets("auto/mix"));
            assert!(t[1..].iter().all(|m| m.starts_with("ds/")), "{t:?}");
        }
    }

    mod auto_model_ids {
        use super::*;

        #[test]
        fn lists_saved_combos() {
            let (e, _d) = engine();
            e.store.save_combo("mix", &["oa/gpt-4o".into()]).unwrap();
            assert!(e.auto_model_ids().contains(&"auto/mix".to_string()));
        }
    }

    mod plan_attempts {
        use super::*;

        /// Two Codex accounts, reordered so B comes before A. Returns (engine, dir, a, b).
        fn two_accounts() -> (GatewayEngine, tempfile::TempDir, String, String) {
            let (e, d) = engine();
            let a = e.store.save_account("codex", &json!({"access_token":"a","plan":"plus"}), Some("A"), None).unwrap();
            let b = e.store.save_account("codex", &json!({"access_token":"b","plan":"plus"}), Some("B"), None).unwrap();
            e.store.reorder_accounts("codex", &[b.clone(), a.clone()]).unwrap();
            (e, d, a, b)
        }

        /// (model, account id) for each planned attempt over models m1, m2.
        fn plan(e: &GatewayEngine) -> Vec<(String, String)> {
            let t = |m: &str| Target { provider: "codex".into(), model: m.into(), kind: "oauth".into() };
            let s = e.store.get_gateway_settings();
            e.plan_attempts(&[t("m1"), t("m2")], &s).into_iter().map(|(t, a)| (t.model, a.unwrap().id)).collect()
        }

        fn pair(m: &str, id: &str) -> (String, String) {
            (m.to_string(), id.to_string())
        }

        #[test]
        fn model_first_tries_every_account_in_user_order_before_the_next_model() {
            let (e, _d, a, b) = two_accounts();
            assert_eq!(plan(&e), vec![pair("m1", &b), pair("m1", &a), pair("m2", &b), pair("m2", &a)]);
        }

        #[test]
        fn account_first_tries_every_model_before_the_next_account() {
            let (e, _d, a, b) = two_accounts();
            e.store.set_setting("fallback_order", "account_first").unwrap();
            assert_eq!(plan(&e), vec![pair("m1", &b), pair("m2", &b), pair("m1", &a), pair("m2", &a)]);
        }

        #[test]
        fn a_cooling_account_is_tried_last() {
            let (e, _d, a, b) = two_accounts();
            e.store.cool_down(&b, 60);
            assert_eq!(plan(&e)[0].1, a);
        }

        #[test]
        fn round_robin_starts_consecutive_requests_on_different_accounts() {
            let (e, _d, _a, _b) = two_accounts();
            e.store.set_setting("routing_strategy", "round_robin").unwrap();
            assert_ne!(plan(&e)[0].1, plan(&e)[0].1);
        }

        #[test]
        fn an_apikey_provider_tries_its_main_key_then_extra_keys() {
            let (e, _d) = engine();
            e.store.save_provider_key("deepseek", "sk-main").unwrap();
            let extra = e.store.save_account("deepseek", &json!({"api_key":"sk-2"}), Some("Key …sk-2"), None).unwrap();
            let t = Target { provider: "deepseek".into(), model: "m".into(), kind: "apikey".into() };
            let s = e.store.get_gateway_settings();
            let plan: Vec<Option<String>> = e.plan_attempts(&[t], &s).into_iter().map(|(_, a)| a.map(|a| a.id)).collect();
            assert_eq!(plan, vec![None, Some(extra)]);
        }

        #[test]
        fn fill_first_sticks_to_the_last_account_that_worked() {
            let (e, _d, a, _b) = two_accounts();
            e.store.set_setting("routing_strategy", "fill_first").unwrap();
            e.sticky.lock().insert("codex".into(), a.clone());
            assert_eq!(plan(&e)[0].1, a);
        }
    }

    mod cooldown_for {
        use super::*;

        #[test]
        fn a_429_cools_for_the_default_time() {
            assert_eq!(cooldown_for(429, None, "", 60), Some(60));
        }

        #[test]
        fn retry_after_overrides_the_default() {
            assert_eq!(cooldown_for(429, Some(5), "", 60), Some(5));
        }

        #[test]
        fn a_usage_limit_body_uses_its_reset_time() {
            assert_eq!(cooldown_for(400, None, r#"{"error":{"type":"usage_limit_reached","resets_in_seconds":900}}"#, 60), Some(900));
        }

        #[test]
        fn server_errors_do_not_cool_down() {
            assert_eq!(cooldown_for(500, None, "internal", 60), None);
        }

        #[test]
        fn unsupported_model_errors_do_not_cool_down() {
            assert_eq!(cooldown_for(404, None, "model not supported", 60), None);
        }

        #[test]
        fn a_zero_default_disables_cooldown_without_a_hint() {
            assert_eq!(cooldown_for(429, None, "", 0), None);
        }
    }
}
