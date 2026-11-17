use crate::engine::{build_gateway_providers, GatewayEngine};
use crate::error::GatewayError;
use crate::providers::{find_oauth_by_id, find_provider_by_id};
use crate::store::GatewayStore;
use axum::{
    extract::{Path, State},
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub async fn handle_list_providers(State(engine): State<GatewayEngine>) -> Json<Value> {
    Json(json!({
        "providers": build_gateway_providers(&engine.store)
    }))
}

#[derive(Deserialize)]
pub struct ConnectPayload {
    api_key: String,
    base_url: Option<String>,
}

/// Checks the key and returns (latency, model ids if the provider listed them).
async fn verify_upstream_provider(
    client: &reqwest::Client,
    provider_id: &str,
    api_key: &str,
    base_url: &str,
) -> Result<(i64, Vec<String>), String> {
    let t0 = std::time::Instant::now();
    let trimmed_key = api_key.trim();
    let trimmed_base = base_url.trim_end_matches('/');

    let res = if provider_id == "commandcode" {
        client
            .get(format!("{trimmed_base}/alpha/whoami?limits=1"))
            .bearer_auth(trimmed_key)
            .timeout(std::time::Duration::from_secs(8))
            .send()
            .await
    } else if provider_id == "ollama" {
        let url = format!("{}/api/tags", trimmed_base);
        client.get(&url).timeout(std::time::Duration::from_secs(5)).send().await
    } else if provider_id == "anthropic" {
        let url =
            if trimmed_base.ends_with("/v1") { format!("{}/messages", trimmed_base) } else { format!("{}/v1/messages", trimmed_base) };
        client
            .post(&url)
            .header("x-api-key", trimmed_key)
            .header("anthropic-version", "2023-06-01")
            .header("content-type", "application/json")
            .json(&json!({
                "model": "claude-3-5-haiku-20241022",
                "max_tokens": 1,
                "messages": [{"role": "user", "content": "ping"}]
            }))
            .timeout(std::time::Duration::from_secs(8))
            .send()
            .await
    } else {
        models_request(client, provider_id, trimmed_key, trimmed_base).send().await
    };

    match res {
        Ok(resp) => {
            let latency_ms = t0.elapsed().as_millis() as i64;
            let status = resp.status();
            if status.is_success() {
                let body: Value = resp.json().await.unwrap_or(Value::Null);
                Ok((latency_ms, parse_model_ids(&body)))
            } else if status == reqwest::StatusCode::UNAUTHORIZED || status == reqwest::StatusCode::FORBIDDEN {
                let err_text = resp.text().await.unwrap_or_default();
                let detail = serde_json::from_str::<Value>(&err_text)
                    .ok()
                    .and_then(|v| v.get("error").and_then(|e| e.get("message")).and_then(|m| m.as_str()).map(String::from))
                    .unwrap_or_else(|| format!("HTTP {} - invalid credentials", status));
                Err(format!("Authentication failed: {}", detail))
            } else {
                let err_text = resp.text().await.unwrap_or_default();
                let detail = serde_json::from_str::<Value>(&err_text)
                    .ok()
                    .and_then(|v| v.get("error").and_then(|e| e.get("message")).and_then(|m| m.as_str()).map(String::from))
                    .unwrap_or_else(|| format!("HTTP {}", status));
                if status.as_u16() >= 400 && status.as_u16() < 500 && status != reqwest::StatusCode::NOT_FOUND {
                    Err(format!("Provider rejected key: {}", detail))
                } else {
                    Ok((latency_ms, Vec::new()))
                }
            }
        }
        Err(e) => Err(format!("Connection check failed: {}", e)),
    }
}

/// GET {base}/models with the provider's auth style.
fn models_request(client: &reqwest::Client, provider_id: &str, key: &str, base: &str) -> reqwest::RequestBuilder {
    let mut req = client.get(format!("{base}/models")).timeout(std::time::Duration::from_secs(10));
    if provider_id == "xiaomi-mimo" {
        req = req.header("X-Mimo-Source", "mimocode-cli");
    }
    if provider_id == "azure-openai" {
        req = req.header("api-key", key);
    } else if !key.is_empty() {
        req = req.bearer_auth(key);
    }
    req
}

/// Model ids from an OpenAI-style `{data:[{id}]}`, a `{models:[{id|name}]}` list, or Ollama tags.
pub(crate) fn parse_model_ids(body: &Value) -> Vec<String> {
    let list = body["data"].as_array().or(body["models"].as_array()).or(body.as_array());
    let mut out: Vec<String> = list
        .into_iter()
        .flatten()
        .filter(|m| m["hidden"] != true)
        .filter_map(|m| m["id"].as_str().or(m["name"].as_str()).or(m["model"].as_str()).or(m.as_str()))
        .map(|id| id.trim_start_matches("models/").to_string()) // Gemini prefixes ids
        .filter(|id| !id.is_empty())
        .collect();
    out.sort();
    out.dedup();
    out
}

/// Re-fetches one provider's model list (API key or subscription) and stores it.
pub(crate) async fn sync_provider_models(engine: &GatewayEngine, id: &str) -> Result<Vec<String>, String> {
    let req = if let Some(p) = find_provider_by_id(id) {
        let rec = engine.store.get_provider_record(id);
        let base = rec.and_then(|r| r.base_url).filter(|s| !s.trim().is_empty()).unwrap_or_else(|| p.base_url.to_string());
        if base.is_empty() {
            return Err(format!("{} needs a base URL", p.name));
        }
        let key = engine.store.get_provider_key(id).unwrap_or_default();
        if p.needs_key && key.is_empty() {
            return Err(format!("{} is not connected", p.name));
        }
        let base = base.trim_end_matches('/');
        if id == "commandcode" {
            crate::oauth::commandcode_headers(engine.http_client.get(format!("{base}/provider/v1/models?view=client")), &key, "models")
        } else if id == "ollama" {
            engine.http_client.get(format!("{}/api/tags", base.trim_end_matches("/v1")))
        } else if p.family == "anthropic" {
            engine.http_client.get(format!("{base}/models?limit=1000")).header("x-api-key", key).header("anthropic-version", "2023-06-01")
        } else {
            models_request(&engine.http_client, id, &key, base)
        }
    } else if find_oauth_by_id(id).is_some() {
        let acc = engine
            .store
            .list_accounts()
            .into_iter()
            .find(|a| a.provider == id && a.enabled)
            .ok_or_else(|| format!("No enabled {id} account"))?;
        let cred = crate::oauth::fresh_credential(&engine.http_client, &engine.store, &acc, false).await?;
        crate::oauth::subscription_models_request(&engine.http_client, id, &cred)
            .ok_or_else(|| format!("{id} has no model list; using built-in models"))?
    } else {
        return Err(format!("Unknown provider {id}"));
    };
    let resp = req.timeout(std::time::Duration::from_secs(15)).send().await.map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("HTTP {}", resp.status()));
    }
    let models = parse_model_ids(&resp.json::<Value>().await.map_err(|e| e.to_string())?);
    if models.is_empty() {
        return Err("Provider returned no models".into());
    }
    engine.store.set_synced_models(id, &models)?;
    Ok(models)
}

/// Refreshes every connected provider whose list is older than a day.
pub async fn sync_stale_models(engine: &GatewayEngine) {
    let now = crate::store::now();
    let mut ids: Vec<String> = engine
        .store
        .list_providers()
        .into_iter()
        .filter(|r| {
            r.enabled
                && (r.has_key
                    || find_provider_by_id(&r.id).map(|p| !p.needs_key && !p.base_url.is_empty() && p.id != "ollama").unwrap_or(false))
        })
        .map(|r| r.id)
        .collect();
    for a in engine.store.list_accounts() {
        if a.enabled && !ids.contains(&a.provider) {
            ids.push(a.provider);
        }
    }
    for id in ids {
        let (_, at) = engine.store.get_synced_models(&id);
        if at.map(|t| now - t < 86_400.0).unwrap_or(false) {
            continue;
        }
        if let Err(e) = sync_provider_models(engine, &id).await {
            eprintln!("[GATEWAY MODELS] {id}: {e}");
        }
    }
}

pub async fn handle_sync_provider_models(State(engine): State<GatewayEngine>, Path(id): Path<String>) -> Result<Json<Value>, GatewayError> {
    sync_provider_models(&engine, &id).await.map_err(GatewayError::BadGateway)?;
    Ok(Json(provider_models_response(&engine.store, &id)))
}

/// Connects a provider with the key its own CLI/desktop app already saved locally.
pub async fn handle_import_local_key(State(engine): State<GatewayEngine>, Path(id): Path<String>) -> Result<Json<Value>, GatewayError> {
    let home = std::path::PathBuf::from(std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")).unwrap_or_default());
    let appdata = std::env::var("APPDATA").map(std::path::PathBuf::from).unwrap_or_else(|_| home.clone());
    // (candidate files, JSON pointer to the key, optional pointer to a base URL, login hint)
    if id == "kiro" || id == "codex" {
        let imported = if id == "kiro" {
            crate::oauth::import_kiro_from_ide(&engine.store)
        } else {
            crate::oauth::import_codex_from_cli(&engine.store)
        };
        let acc_id = imported.map_err(GatewayError::NotFound)?;
        return Ok(Json(json!({ "status": "imported", "id": acc_id })));
    }
    let (files, key_ptr, base_ptr, hint) = match id.as_str() {
        "commandcode" => (vec![home.join(".commandcode/auth.json")], "/apiKey", None, "run `cmd login` in Command Code"),
        "xiaomi-mimo" => (
            vec![
                home.join("Library/Application Support/mimocode/auth.json"),
                home.join(".local/share/mimocode/auth.json"),
                appdata.join("Xiaomi MiMo/auth.json"),
            ],
            "/xiaomi/key",
            Some("/xiaomi/metadata/base_url"),
            "sign in to MiMo Desktop",
        ),
        _ => return Err(GatewayError::BadRequest(format!("{id} has no local login to import"))),
    };
    let saved = files
        .iter()
        .find_map(|f| std::fs::read_to_string(f).ok().and_then(|raw| serde_json::from_str::<Value>(&raw).ok()))
        .ok_or_else(|| GatewayError::NotFound(format!("No saved login found; {hint} first.")))?;
    let key = saved
        .pointer(key_ptr)
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|k| !k.is_empty())
        .ok_or_else(|| GatewayError::BadRequest(format!("The saved login has no API key; {hint} again.")))?
        .to_string();
    let base_url = base_ptr.and_then(|p| saved.pointer(p)).and_then(|v| v.as_str()).map(String::from);
    handle_connect_provider(State(engine), Path(id), Json(ConnectPayload { api_key: key, base_url })).await
}

pub async fn handle_connect_provider(
    State(engine): State<GatewayEngine>,
    Path(id): Path<String>,
    Json(payload): Json<ConnectPayload>,
) -> Result<Json<Value>, GatewayError> {
    let prov = find_provider_by_id(&id);
    let default_base = prov.map(|p| p.base_url).unwrap_or("");
    let custom_base = payload.base_url.as_deref().filter(|s| !s.trim().is_empty());
    let base_url = custom_base.unwrap_or(default_base);
    let api_key = payload.api_key.trim();

    if prov.map(|p| p.needs_key).unwrap_or(true) && api_key.is_empty() {
        return Err(GatewayError::BadRequest(format!("API key is required for {}", prov.map(|p| p.name).unwrap_or(&id))));
    }

    if base_url.trim().is_empty() {
        return Err(GatewayError::BadRequest(match id.as_str() {
            "azure-openai" => "Azure needs a base URL like https://<resource>.openai.azure.com/openai/v1".to_string(),
            "cloudflare-ai" => {
                "Cloudflare needs a base URL like https://api.cloudflare.com/client/v4/accounts/<account-id>/ai/v1".to_string()
            }
            _ => format!("{} needs a base URL", prov.map(|p| p.name).unwrap_or(&id)),
        }));
    }

    let mut latency_ms: Option<i64> = None;
    let mut listed = Vec::new();
    if !base_url.is_empty() {
        let (ms, models) = verify_upstream_provider(&engine.http_client, &id, api_key, base_url).await.map_err(GatewayError::BadRequest)?;
        latency_ms = Some(ms);
        listed = models;
    }

    engine.store.connect_provider(&id, api_key, custom_base).map_err(GatewayError::BadRequest)?;
    let _ = engine.store.set_provider_verification(&id, latency_ms, None);
    // The key check already listed the models; Anthropic/Ollama need their own call.
    if !listed.is_empty() {
        let _ = engine.store.set_synced_models(&id, &listed);
    } else {
        let _ = sync_provider_models(&engine, &id).await;
    }

    let providers = build_gateway_providers(&engine.store);
    if let Some(p) = providers.into_iter().find(|p| p["id"] == id) {
        Ok(Json(p))
    } else {
        Ok(Json(json!({ "id": id, "connected": true, "latency_ms": latency_ms })))
    }
}

pub async fn handle_disconnect_provider(State(engine): State<GatewayEngine>, Path(id): Path<String>) -> Json<Value> {
    let _ = engine.store.disconnect_provider(&id);
    let providers = build_gateway_providers(&engine.store);
    providers.into_iter().find(|p| p["id"] == id).map(Json).unwrap_or_else(|| Json(json!({ "id": id, "connected": false })))
}

#[derive(Deserialize, Default)]
pub struct TogglePayload {
    enabled: Option<bool>,
}

pub async fn handle_toggle_provider(
    State(engine): State<GatewayEngine>,
    Path(id): Path<String>,
    payload: Option<Json<TogglePayload>>,
) -> Result<Json<Value>, GatewayError> {
    let desired = payload.and_then(|Json(p)| p.enabled);
    let enabled = engine.store.set_provider_enabled(&id, desired).map_err(GatewayError::Internal)?;
    let providers = build_gateway_providers(&engine.store);
    if let Some(p) = providers.into_iter().find(|p| p["id"] == id) {
        Ok(Json(p))
    } else {
        Ok(Json(json!({ "id": id, "enabled": enabled })))
    }
}

pub async fn handle_save_provider_key(
    State(engine): State<GatewayEngine>,
    Path(id): Path<String>,
    Json(payload): Json<Value>,
) -> Result<Json<Value>, GatewayError> {
    let key = payload.get("key").or_else(|| payload.get("api_key")).and_then(|k| k.as_str()).unwrap_or("");
    engine.store.save_provider_key(&id, key).map_err(GatewayError::BadRequest)?;
    Ok(Json(json!({ "status": "saved" })))
}

// ---- Custom Models per Provider -------------------------------------

#[derive(Deserialize)]
pub struct ModelPayload {
    model: String,
}

#[derive(Deserialize)]
pub struct ModelsListPayload {
    models: Vec<String>,
}

fn provider_models_response(store: &GatewayStore, provider_id: &str) -> Value {
    let custom = store.get_provider_custom_models(provider_id);
    let seed: Vec<String> = find_oauth_by_id(provider_id)
        .map(|op| op.seed_models.iter().map(|s| s.to_string()).collect())
        .or_else(|| find_provider_by_id(provider_id).map(|p| p.seed_models.iter().map(|s| s.to_string()).collect()))
        .unwrap_or_default();
    let seed_refs: Vec<&str> = seed.iter().map(String::as_str).collect();
    let (synced, synced_at) = store.get_synced_models(provider_id);
    json!({
        "provider": provider_id,
        "models": store.display_models(provider_id, &seed_refs),
        "custom_models": custom,
        "seed_models": seed,
        "synced_models": synced,
        "models_synced_at": synced_at,
    })
}

pub async fn handle_get_provider_models(State(engine): State<GatewayEngine>, Path(id): Path<String>) -> Json<Value> {
    Json(provider_models_response(&engine.store, &id))
}

pub async fn handle_add_provider_model(
    State(engine): State<GatewayEngine>,
    Path(id): Path<String>,
    Json(payload): Json<ModelPayload>,
) -> Result<Json<Value>, GatewayError> {
    engine.store.add_provider_model(&id, &payload.model).map_err(GatewayError::BadRequest)?;
    Ok(Json(provider_models_response(&engine.store, &id)))
}

pub async fn handle_set_provider_models(
    State(engine): State<GatewayEngine>,
    Path(id): Path<String>,
    Json(payload): Json<ModelsListPayload>,
) -> Result<Json<Value>, GatewayError> {
    engine.store.set_provider_models(&id, &payload.models).map_err(GatewayError::BadRequest)?;
    Ok(Json(provider_models_response(&engine.store, &id)))
}

pub async fn handle_delete_provider_model(
    State(engine): State<GatewayEngine>,
    Path((id, model)): Path<(String, String)>,
) -> Result<Json<Value>, GatewayError> {
    engine.store.remove_provider_model(&id, &model).map_err(GatewayError::BadRequest)?;
    Ok(Json(provider_models_response(&engine.store, &id)))
}

pub async fn handle_delete_provider_model_body(
    State(engine): State<GatewayEngine>,
    Path(id): Path<String>,
    Json(payload): Json<ModelPayload>,
) -> Result<Json<Value>, GatewayError> {
    engine.store.remove_provider_model(&id, &payload.model).map_err(GatewayError::BadRequest)?;
    Ok(Json(provider_models_response(&engine.store, &id)))
}

#[cfg(test)]
mod tests {
    mod parse_model_ids {
        use super::super::parse_model_ids;
        use serde_json::json;

        #[test]
        fn reads_an_openai_data_list_sorted_and_deduplicated() {
            assert_eq!(parse_model_ids(&json!({"data":[{"id":"b"},{"id":"a"},{"id":"a"}]})), vec!["a", "b"]);
        }

        #[test]
        fn strips_the_gemini_models_prefix() {
            assert_eq!(parse_model_ids(&json!({"models":[{"name":"models/gemini-2.5-pro"}]})), vec!["gemini-2.5-pro"]);
        }

        #[test]
        fn reads_ollama_tags() {
            assert_eq!(parse_model_ids(&json!({"models":[{"name":"llama3.2:latest","model":"llama3.2:latest"}]})), vec!["llama3.2:latest"]);
        }

        #[test]
        fn returns_nothing_for_an_error_body() {
            assert!(parse_model_ids(&json!({"error":"nope"})).is_empty());
        }

        #[test]
        fn skips_hidden_models() {
            assert_eq!(parse_model_ids(&json!({"data":[{"id":"a"},{"id":"b","hidden":true}]})), vec!["a"]);
        }
    }
}
