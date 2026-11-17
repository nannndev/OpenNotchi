//! Drives the gateway router in-process (no network, no real providers).

// Test-only file: a failed unwrap is a failed test, which is what we want.
#![allow(clippy::unwrap_used)]

use axum::{
    body::Body,
    http::{Request, StatusCode},
    Router,
};
use http_body_util::BodyExt;
use notchi_gateway::{gateway_router, GatewayEngine, GatewayStore};
use serde_json::{json, Value};
use tower::ServiceExt;

/// A router over a fresh store; keep the dir alive for the test's duration.
fn app() -> (Router, tempfile::TempDir) {
    let dir = tempfile::tempdir().unwrap();
    let engine = GatewayEngine::new(GatewayStore::new(dir.path()).unwrap());
    (gateway_router(engine), dir)
}

async fn call(app: &Router, method: &str, uri: &str, body: Option<Value>, auth: Option<&str>) -> (StatusCode, Value) {
    let mut req = Request::builder().method(method).uri(uri).header("content-type", "application/json");
    if let Some(a) = auth {
        req = req.header("authorization", format!("Bearer {a}"));
    }
    let req = req.body(body.map_or_else(Body::empty, |b| Body::from(b.to_string()))).unwrap();
    let resp = app.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

mod health {
    use super::*;

    #[tokio::test]
    async fn reports_ok() {
        let (app, _d) = app();
        assert_eq!(call(&app, "GET", "/gateway/health", None, None).await.1["status"], "ok");
    }
}

mod chat_completions {
    use super::*;

    const CHAT: &str = "/v1/chat/completions";

    fn hi() -> Option<Value> {
        Some(json!({ "model": "auto", "messages": [{ "role": "user", "content": "hi" }] }))
    }

    #[tokio::test]
    async fn rejects_an_unknown_gateway_key() {
        let (app, _d) = app();
        assert_eq!(call(&app, "POST", CHAT, hi(), Some("gw-sk-nope")).await.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn rejects_a_disabled_gateway_key() {
        let (app, _d) = app();
        let (_, created) = call(&app, "POST", "/gateway/admin/keys", Some(json!({ "name": "ci" })), None).await;
        let id = created["key"]["id"].as_str().unwrap().to_string();
        let secret = created["key"]["key"].as_str().unwrap().to_string();
        call(&app, "PATCH", &format!("/gateway/admin/keys/{id}/toggle"), None, None).await;
        assert_eq!(call(&app, "POST", CHAT, hi(), Some(&secret)).await.0, StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn ignores_non_gateway_keys_from_agents() {
        let (app, _d) = app();
        // No provider is connected, so an accepted request fails upstream, not on auth.
        assert_eq!(call(&app, "POST", CHAT, hi(), Some("sk-dummy")).await.0, StatusCode::BAD_GATEWAY);
    }

    #[tokio::test]
    async fn fails_with_bad_gateway_when_nothing_is_connected() {
        let (app, _d) = app();
        assert_eq!(call(&app, "POST", CHAT, hi(), None).await.0, StatusCode::BAD_GATEWAY);
    }

    #[tokio::test]
    async fn enforces_a_keys_allowed_providers() {
        let (app, _d) = app();
        let body = json!({ "name": "ci", "allowed_providers": ["deepseek"] });
        let (_, created) = call(&app, "POST", "/gateway/admin/keys", Some(body), None).await;
        let secret = created["key"]["key"].as_str().unwrap().to_string();
        let req = Some(json!({ "model": "oa/gpt-4o", "messages": [{ "role": "user", "content": "hi" }] }));
        assert_eq!(call(&app, "POST", CHAT, req, Some(&secret)).await.0, StatusCode::FORBIDDEN);
    }
}

mod settings {
    use super::*;

    #[tokio::test]
    async fn rejects_an_unknown_routing_strategy() {
        let (app, _d) = app();
        let (status, _) = call(&app, "POST", "/gateway/admin/settings", Some(json!({ "routing_strategy": "yolo" })), None).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn saves_the_provider_priority() {
        let (app, _d) = app();
        let body = json!({ "provider_priority": ["deepseek", "openai"] });
        let (_, saved) = call(&app, "POST", "/gateway/admin/settings", Some(body), None).await;
        assert_eq!(saved["settings"]["provider_priority"], json!(["deepseek", "openai"]));
    }
}

mod combos {
    use super::*;

    #[tokio::test]
    async fn rejects_a_name_with_a_slash() {
        let (app, _d) = app();
        let (status, _) = call(&app, "POST", "/gateway/admin/combos", Some(json!({ "name": "a/b", "targets": ["x"] })), None).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn a_saved_combo_shows_up_as_an_auto_model() {
        let (app, _d) = app();
        call(&app, "POST", "/gateway/admin/combos", Some(json!({ "name": "mix", "targets": ["oa/gpt-4o"] })), None).await;
        let (_, models) = call(&app, "GET", "/v1/models", None, None).await;
        let ids: Vec<&str> = models["data"].as_array().unwrap().iter().filter_map(|m| m["id"].as_str()).collect();
        assert!(ids.contains(&"auto/mix"), "{ids:?}");
    }
}

mod providers {
    use super::*;

    #[tokio::test]
    async fn connecting_azure_without_a_base_url_is_refused() {
        let (app, _d) = app();
        let (status, _) = call(&app, "POST", "/gateway/admin/providers/azure-openai/connect", Some(json!({ "api_key": "k" })), None).await;
        assert_eq!(status, StatusCode::BAD_REQUEST);
    }

    #[tokio::test]
    async fn importing_for_a_provider_without_a_local_login_is_refused() {
        let (app, _d) = app();
        assert_eq!(call(&app, "POST", "/gateway/admin/providers/openai/import", None, None).await.0, StatusCode::BAD_REQUEST);
    }
}
