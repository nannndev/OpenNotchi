use crate::engine::GatewayEngine;
use crate::error::GatewayError;
use crate::providers::{OAUTH_PROVIDERS, PROVIDERS};
use crate::store::KEY_PREFIX;
use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    response::IntoResponse,
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

/// A presented key must be a valid, enabled virtual key; no key means the local app (anonymous).
pub async fn handle_chat_completions(
    State(engine): State<GatewayEngine>,
    headers: HeaderMap,
    Json(payload): Json<Value>,
) -> axum::response::Response {
    let presented = headers
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer ").or(v.strip_prefix("bearer ")))
        .or_else(|| headers.get("x-api-key").and_then(|v| v.to_str().ok()))
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let key = match presented {
        // Agents often send a dummy key; only gateway-issued keys are checked.
        Some(secret) if secret.starts_with(KEY_PREFIX) => match engine.store.find_virtual_key(secret) {
            Some(k) if k.enabled => Some(k),
            Some(_) => return GatewayError::Unauthorized("API key is disabled".into()).into_response(),
            None => return GatewayError::Unauthorized("Invalid API key".into()).into_response(),
        },
        _ => None,
    };
    engine.chat_completions(key, payload).await.into_response()
}

pub async fn handle_health() -> Json<Value> {
    Json(json!({ "status": "ok" }))
}

/// Models of connected providers only (enabled, with an account or key), `auto` modes first.
/// `owned_by` is the provider id so clients can group the list.
pub async fn handle_list_models_v1(State(engine): State<GatewayEngine>) -> Json<Value> {
    let mut data: Vec<Value> =
        engine.auto_model_ids().into_iter().map(|id| json!({ "id": id, "object": "model", "owned_by": "notchi-gateway" })).collect();
    let settings = engine.store.get_gateway_settings();
    for id in engine.auto_provider_order(&settings) {
        let (alias, seeds) = match (OAUTH_PROVIDERS.iter().find(|o| o.id == id), PROVIDERS.iter().find(|p| p.id == id)) {
            (Some(o), _) => (o.alias, o.seed_models),
            (None, Some(p)) => (p.alias, p.seed_models),
            _ => continue,
        };
        for m in engine.store.display_models(&id, seeds) {
            data.push(json!({ "id": format!("{alias}/{m}"), "object": "model", "owned_by": id }));
        }
    }
    Json(json!({ "object": "list", "data": data }))
}

pub async fn handle_admin_models(State(engine): State<GatewayEngine>) -> Json<Value> {
    let mut models = Vec::new();
    for op in OAUTH_PROVIDERS {
        let enabled = engine.store.is_provider_enabled(op.id);
        let custom = engine.store.get_provider_custom_models(op.id);
        for m in engine.store.display_models(op.id, op.seed_models) {
            let is_custom = custom.iter().any(|c| c == &m);
            models.push(json!({
                "id": format!("{}/{}", op.alias, m),
                "model": m,
                "owned_by": op.id,
                "enabled": enabled,
                "custom": is_custom,
            }));
        }
    }
    for p in PROVIDERS {
        let enabled = engine.store.is_provider_enabled(p.id);
        let custom = engine.store.get_provider_custom_models(p.id);
        for m in engine.store.display_models(p.id, p.seed_models) {
            let is_custom = custom.iter().any(|c| c == &m);
            models.push(json!({
                "id": format!("{}/{}", p.alias, m),
                "model": m,
                "owned_by": p.id,
                "enabled": enabled,
                "custom": is_custom,
            }));
        }
    }
    Json(json!({ "models": models }))
}

// ---- Virtual Keys ----------------------------------------------------

pub async fn handle_list_keys(State(engine): State<GatewayEngine>) -> Json<Value> {
    Json(json!({ "keys": engine.store.list_virtual_keys() }))
}

#[derive(Deserialize)]
pub struct CreateKeyPayload {
    name: String,
    allowed_providers: Option<Vec<String>>,
    rate_limit_per_min: Option<i64>,
}

pub async fn handle_create_key(
    State(engine): State<GatewayEngine>,
    Json(payload): Json<CreateKeyPayload>,
) -> Result<Json<Value>, GatewayError> {
    let (record, secret) = engine
        .store
        .create_virtual_key(&payload.name, payload.allowed_providers, payload.rate_limit_per_min)
        .map_err(GatewayError::Internal)?;
    let mut val = serde_json::to_value(&record).map_err(|e| GatewayError::Internal(e.to_string()))?;
    val["key"] = json!(secret);
    Ok(Json(json!({ "key": val })))
}

pub async fn handle_toggle_key(State(engine): State<GatewayEngine>, Path(id): Path<String>) -> Result<Json<Value>, GatewayError> {
    let record = engine.store.toggle_virtual_key(&id).map_err(GatewayError::NotFound)?;
    Ok(Json(json!({ "key": record })))
}

pub async fn handle_delete_key(State(engine): State<GatewayEngine>, Path(id): Path<String>) -> Json<Value> {
    let _ = engine.store.delete_virtual_key(&id);
    Json(json!({ "status": "deleted" }))
}

// ---- Combos ----------------------------------------------------------

pub async fn handle_list_combos(State(engine): State<GatewayEngine>) -> Json<Value> {
    Json(json!({ "combos": engine.store.list_combos() }))
}

pub async fn handle_save_combo(State(engine): State<GatewayEngine>, Json(payload): Json<Value>) -> Result<Json<Value>, GatewayError> {
    let name = payload.get("name").and_then(|n| n.as_str()).unwrap_or("").trim();
    let targets: Vec<String> = payload.get("targets").and_then(|t| serde_json::from_value(t.clone()).ok()).unwrap_or_default();
    // Combos are addressed as `auto/<name>`, so the name must be one path segment.
    if name.is_empty() || name.contains('/') || name.contains(char::is_whitespace) {
        return Err(GatewayError::BadRequest("Combo name must be one word without '/' or spaces".into()));
    }
    if targets.iter().all(|t| t.trim().is_empty()) {
        return Err(GatewayError::BadRequest("Combo needs at least one model".into()));
    }
    engine.store.save_combo(name, &targets).map_err(GatewayError::BadRequest)?;
    Ok(Json(json!({ "combos": engine.store.list_combos() })))
}

pub async fn handle_put_combo(
    State(engine): State<GatewayEngine>,
    Path(name): Path<String>,
    Json(payload): Json<Value>,
) -> Result<Json<Value>, GatewayError> {
    let targets: Vec<String> = payload.get("targets").and_then(|t| serde_json::from_value(t.clone()).ok()).unwrap_or_default();
    engine.store.save_combo(&name, &targets).map_err(GatewayError::BadRequest)?;
    Ok(Json(json!({ "combos": engine.store.list_combos() })))
}

pub async fn handle_delete_combo(State(engine): State<GatewayEngine>, Path(name): Path<String>) -> Json<Value> {
    let _ = engine.store.delete_combo(&name);
    Json(json!({ "combos": engine.store.list_combos() }))
}

// ---- Usage, Stats & Settings ----------------------------------------

#[derive(Deserialize)]
pub struct UsageQuery {
    limit: Option<i64>,
}

pub async fn handle_list_usage(State(engine): State<GatewayEngine>, Query(query): Query<UsageQuery>) -> Json<Value> {
    let limit = query.limit.unwrap_or(100);
    Json(json!({ "usage": engine.store.list_usage(limit) }))
}

pub async fn handle_clear_usage(State(engine): State<GatewayEngine>) -> Json<Value> {
    let _ = engine.store.clear_usage();
    Json(json!({ "status": "cleared" }))
}

pub async fn handle_get_stats(State(engine): State<GatewayEngine>) -> Json<Value> {
    Json(engine.store.get_stats())
}

#[derive(Deserialize)]
pub struct AnalyticsQuery {
    /// Days of history; omit for all.
    days: Option<u32>,
    /// Caller's offset from UTC in minutes (east positive).
    tz_offset_min: Option<i64>,
}

pub async fn handle_analytics(State(engine): State<GatewayEngine>, Query(q): Query<AnalyticsQuery>) -> Json<Value> {
    Json(engine.store.analytics(q.days, q.tz_offset_min.unwrap_or(0) * 60))
}

pub async fn handle_get_settings(State(engine): State<GatewayEngine>) -> Json<Value> {
    Json(settings_response(&engine))
}

/// Settings plus the effective `auto` provider order, so the UI can show and reorder it.
fn settings_response(engine: &GatewayEngine) -> Value {
    let s = engine.store.get_gateway_settings();
    let order = engine.auto_provider_order(&s);
    json!({ "settings": s, "auto_order": order })
}

#[derive(Deserialize)]
pub struct UpdateSettingsPayload {
    routing_strategy: Option<String>,
    fallback_order: Option<String>,
    provider_priority: Option<Vec<String>>,
    auto_models_per_provider: Option<u32>,
    cooldown_secs: Option<u32>,
    gemini_oauth_client_id: Option<String>,
    gemini_oauth_client_secret: Option<String>,
    clear_gemini_secret: Option<bool>,
}

pub async fn handle_update_settings(
    State(engine): State<GatewayEngine>,
    Json(payload): Json<UpdateSettingsPayload>,
) -> Result<Json<Value>, GatewayError> {
    if let Some(strategy) = payload.routing_strategy {
        if !["priority", "round_robin", "fill_first"].contains(&strategy.as_str()) {
            return Err(GatewayError::BadRequest(format!("unknown routing_strategy: {strategy}")));
        }
        let _ = engine.store.set_setting("routing_strategy", &strategy);
    }
    if let Some(order) = payload.fallback_order {
        if !["model_first", "account_first"].contains(&order.as_str()) {
            return Err(GatewayError::BadRequest(format!("unknown fallback_order: {order}")));
        }
        let _ = engine.store.set_setting("fallback_order", &order);
    }
    if let Some(list) = payload.provider_priority {
        let _ = engine.store.set_setting("provider_priority", &json!(list).to_string());
    }
    if let Some(n) = payload.auto_models_per_provider {
        let _ = engine.store.set_setting("auto_models_per_provider", &n.clamp(1, 10).to_string());
    }
    if let Some(n) = payload.cooldown_secs {
        let _ = engine.store.set_setting("cooldown_secs", &n.min(3600).to_string());
    }
    if let Some(client_id) = payload.gemini_oauth_client_id {
        let _ = engine.store.set_setting("gemini_oauth_client_id", &client_id);
    }
    if payload.clear_gemini_secret == Some(true) {
        let _ = engine.store.set_setting("gemini_oauth_client_secret", "");
    } else if let Some(secret) = payload.gemini_oauth_client_secret {
        if !secret.trim().is_empty() {
            let _ = engine.store.set_setting("gemini_oauth_client_secret", &secret);
        }
    }
    Ok(Json(settings_response(&engine)))
}
