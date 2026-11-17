use crate::engine::{get_oauth_accounts_state, GatewayEngine};
use crate::error::GatewayError;
use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub async fn handle_list_accounts(State(engine): State<GatewayEngine>) -> Json<Value> {
    Json(get_oauth_accounts_state(&engine.store))
}

pub async fn handle_save_account(State(engine): State<GatewayEngine>, Json(payload): Json<Value>) -> Result<Json<Value>, GatewayError> {
    let provider = payload.get("provider").and_then(|p| p.as_str()).unwrap_or("");
    let cred = payload.get("cred").cloned().unwrap_or(json!({}));
    let label = payload.get("label").and_then(|l| l.as_str());
    let email = payload.get("email").and_then(|e| e.as_str());

    let id = engine.store.save_account(provider, &cred, label, email).map_err(GatewayError::Internal)?;
    Ok(Json(json!({ "status": "saved", "id": id })))
}

pub async fn handle_remove_account(State(engine): State<GatewayEngine>, Path((provider, id)): Path<(String, String)>) -> Json<Value> {
    let _ = engine.store.remove_account(&provider, Some(&id));
    Json(get_oauth_accounts_state(&engine.store))
}

#[derive(Deserialize)]
pub struct AccountDeleteQuery {
    account_id: Option<String>,
}

pub async fn handle_delete_account_by_query(
    State(engine): State<GatewayEngine>,
    Path(provider): Path<String>,
    Query(query): Query<AccountDeleteQuery>,
) -> Json<Value> {
    let _ = engine.store.remove_account(&provider, query.account_id.as_deref());
    Json(get_oauth_accounts_state(&engine.store))
}

#[derive(Deserialize, Default)]
pub struct TogglePayload {
    enabled: Option<bool>,
}

pub async fn handle_toggle_account(
    State(engine): State<GatewayEngine>,
    Path((provider, id)): Path<(String, String)>,
    payload: Option<Json<TogglePayload>>,
) -> Result<Json<Value>, GatewayError> {
    let desired = payload.and_then(|Json(p)| p.enabled);
    let enabled = engine.store.set_account_enabled(&provider, &id, desired).map_err(GatewayError::NotFound)?;
    let mut state = get_oauth_accounts_state(&engine.store);
    state["toggled"] = json!({ "provider": provider, "id": id, "enabled": enabled });
    Ok(Json(state))
}

#[derive(Deserialize)]
pub struct ReorderPayload {
    account_ids: Vec<String>,
}

pub async fn handle_reorder_accounts(
    State(engine): State<GatewayEngine>,
    Path(provider): Path<String>,
    Json(payload): Json<ReorderPayload>,
) -> Json<Value> {
    let _ = engine.store.reorder_accounts(&provider, &payload.account_ids);
    Json(get_oauth_accounts_state(&engine.store))
}

pub async fn handle_accounts_usage(State(engine): State<GatewayEngine>) -> Json<Value> {
    let accounts = engine.store.list_accounts();
    let usage: Vec<Value> = accounts
        .iter()
        .map(|a| {
            json!({
                "provider": a.provider,
                "account_id": a.id,
                "email": a.email,
                "last_error": a.last_error,
                "plan": a.display_plan(),
                "windows": [],
                "limit_reached": false,
                "fetched_at": crate::store::now(),
            })
        })
        .collect();
    Json(json!({ "usage": usage, "summary": {} }))
}

#[derive(Deserialize)]
pub struct OAuthStartPayload {
    account_id: Option<String>,
    #[allow(dead_code)]
    label: Option<String>,
    gemini_oauth_client_id: Option<String>,
    gemini_oauth_client_secret: Option<String>,
}

pub async fn handle_oauth_start(
    State(engine): State<GatewayEngine>,
    Path(provider): Path<String>,
    Json(payload): Json<OAuthStartPayload>,
) -> (StatusCode, Json<Value>) {
    if let Some(ref cid) = payload.gemini_oauth_client_id {
        let _ = engine.store.set_setting("gemini_oauth_client_id", cid);
    }
    if let Some(ref sec) = payload.gemini_oauth_client_secret {
        let _ = engine.store.set_setting("gemini_oauth_client_secret", sec);
    }

    match provider.as_str() {
        "copilot" => match crate::oauth::start_copilot_device_flow(&engine.http_client, &engine.oauth, payload.account_id).await {
            Ok(val) => (StatusCode::OK, Json(val)),
            Err(e) => (StatusCode::BAD_REQUEST, Json(json!({ "error": e, "message": e }))),
        },
        "claude" => {
            let val = crate::oauth::start_claude_pkce_flow(&engine.http_client, &engine.oauth, &engine.store, payload.account_id).await;
            (StatusCode::OK, Json(val))
        }
        "codex" => {
            let val = crate::oauth::start_codex_pkce_flow(&engine.http_client, &engine.oauth, &engine.store, payload.account_id).await;
            (StatusCode::OK, Json(val))
        }
        "antigravity" => {
            let val = crate::oauth::start_antigravity_flow(&engine.http_client, &engine.oauth, &engine.store, payload.account_id).await;
            (StatusCode::OK, Json(val))
        }
        "cline" => {
            let val = crate::oauth::start_cline_flow(&engine.http_client, &engine.oauth, &engine.store, payload.account_id).await;
            (StatusCode::OK, Json(val))
        }
        "gemini-cli" => {
            match crate::oauth::start_gemini_cli_flow(&engine.http_client, &engine.oauth, &engine.store, payload.account_id).await {
                Ok(val) => (StatusCode::OK, Json(val)),
                Err(e) => (StatusCode::BAD_REQUEST, Json(json!({ "error": e, "message": e }))),
            }
        }
        _ => match crate::oauth::start_device_flow(&engine.http_client, &engine.oauth, &provider, payload.account_id).await {
            Ok(val) => (StatusCode::OK, Json(val)),
            Err(e) => (StatusCode::BAD_REQUEST, Json(json!({ "error": e, "message": e }))),
        },
    }
}

#[derive(Deserialize)]
pub struct OAuthPollPayload {
    session_id: String,
    #[allow(dead_code)]
    account_id: Option<String>,
    #[allow(dead_code)]
    label: Option<String>,
}

pub async fn handle_oauth_poll(
    State(engine): State<GatewayEngine>,
    Path(provider): Path<String>,
    Json(payload): Json<OAuthPollPayload>,
) -> (StatusCode, Json<Value>) {
    let polled = if provider == "copilot" {
        crate::oauth::poll_copilot_device_flow(&engine.http_client, &engine.oauth, &engine.store, &payload.session_id).await
    } else {
        crate::oauth::poll_device_flow(&engine.http_client, &engine.oauth, &engine.store, &payload.session_id).await
    };
    match polled {
        Ok(res) => {
            if res.get("status").and_then(|v| v.as_str()) == Some("done") {
                let mut state = get_oauth_accounts_state(&engine.store);
                state["status"] = json!("done");
                let accounts = engine.store.list_accounts();
                if let Some(acc) = accounts.iter().rev().find(|a| a.provider == provider) {
                    state["account"] = json!({
                        "id": acc.id,
                        "provider": acc.provider,
                        "label": acc.label,
                        "email": acc.email,
                        "connected_at": acc.connected_at,
                        "refreshed_at": acc.refreshed_at,
                        "expires_at": null,
                        "last_error": acc.last_error,
                    });
                }
                (StatusCode::OK, Json(state))
            } else {
                (StatusCode::OK, Json(res))
            }
        }
        Err(e) => (StatusCode::BAD_REQUEST, Json(json!({ "status": "error", "error": e, "message": e }))),
    }
}

#[derive(Deserialize)]
pub struct OAuthCompletePayload {
    session_id: String,
    callback: String,
    account_id: Option<String>,
    #[allow(dead_code)]
    label: Option<String>,
}

pub async fn handle_oauth_complete(
    State(engine): State<GatewayEngine>,
    Path(provider): Path<String>,
    Json(payload): Json<OAuthCompletePayload>,
) -> (StatusCode, Json<Value>) {
    let target_id = payload.account_id.as_deref();
    let res = match provider.as_str() {
        "claude" => {
            crate::oauth::complete_claude_pkce_flow(
                &engine.http_client,
                &engine.oauth,
                &engine.store,
                &payload.session_id,
                &payload.callback,
                target_id,
            )
            .await
        }
        "codex" => {
            crate::oauth::complete_codex_pkce_flow(
                &engine.http_client,
                &engine.oauth,
                &engine.store,
                &payload.session_id,
                &payload.callback,
                target_id,
            )
            .await
        }
        "gemini-cli" => {
            crate::oauth::complete_gemini_cli_flow(
                &engine.http_client,
                &engine.oauth,
                &engine.store,
                &payload.session_id,
                &payload.callback,
                target_id,
            )
            .await
        }
        _ => crate::oauth::complete_generic_token_flow(&engine.store, &provider, &payload.callback, target_id).await,
    };

    match res {
        Ok(_) => {
            let mut state = get_oauth_accounts_state(&engine.store);
            let accounts = engine.store.list_accounts();
            if let Some(acc) = accounts.iter().rev().find(|a| a.provider == provider) {
                state["account"] = json!({
                    "id": acc.id,
                    "provider": acc.provider,
                    "label": acc.label,
                    "email": acc.email,
                    "connected_at": acc.connected_at,
                    "refreshed_at": acc.refreshed_at,
                    "expires_at": null,
                    "last_error": acc.last_error,
                });
            }
            (StatusCode::OK, Json(state))
        }
        Err(err) => (StatusCode::BAD_REQUEST, Json(json!({ "error": err, "message": err }))),
    }
}

#[derive(Deserialize)]
pub struct OAuthTestPayload {
    account_id: Option<String>,
}

pub async fn handle_oauth_test(
    State(engine): State<GatewayEngine>,
    Path(provider): Path<String>,
    Json(payload): Json<OAuthTestPayload>,
) -> Json<Value> {
    let accounts = engine.store.list_accounts();
    let target_account = if let Some(ref aid) = payload.account_id {
        accounts.into_iter().find(|a| a.provider == provider && a.id == *aid)
    } else {
        accounts.into_iter().find(|a| a.provider == provider)
    };

    if let Some(account) = target_account {
        Json(crate::oauth::test_oauth_account(&engine.http_client, &account).await)
    } else {
        Json(json!({
            "valid": false,
            "error": format!("No connected account found for provider '{}'", provider)
        }))
    }
}
