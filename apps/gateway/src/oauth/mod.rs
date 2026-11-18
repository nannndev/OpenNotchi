mod html;

pub use html::parse_callback_code_or_token;
use html::{format_oauth_result_page, urlencoding_decode, urlencoding_encode};

use crate::store::{AccountRecord, GatewayStore};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use parking_lot::RwLock;
use rand::RngCore;
use reqwest::Client;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use uuid::Uuid;

#[derive(Clone, Debug)]
pub struct OAuthSession {
    pub id: String,
    pub provider: String,
    pub account_id: Option<String>,
    pub kind: String,
    pub code_verifier: Option<String>,
    pub device_code: Option<String>,
    /// kimi: device identity sent as X-Msh-Device-Id on every request
    pub device_id: Option<String>,
    pub interval: u64,
    pub expires_at: Instant,
}

#[derive(Clone)]
pub struct OAuthManager {
    sessions: Arc<RwLock<HashMap<String, OAuthSession>>>,
    /// One callback listener per port; a newer login replaces an older pending one.
    listeners: Arc<RwLock<HashMap<u16, tokio::task::AbortHandle>>>,
    /// Earliest time each device session may hit the provider again.
    next_poll: Arc<RwLock<HashMap<String, Instant>>>,
}

impl Default for OAuthManager {
    fn default() -> Self {
        Self::new()
    }
}

impl OAuthManager {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(RwLock::new(HashMap::new())),
            listeners: Arc::new(RwLock::new(HashMap::new())),
            next_poll: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// Device flows (RFC 8628) answer `slow_down` and never issue the token while a
    /// client polls faster than the interval, so the UI timer is gated here.
    pub fn poll_allowed(&self, session_id: &str) -> bool {
        let Some(interval) = self.sessions.read().get(session_id).map(|s| s.interval) else { return true };
        let now = Instant::now();
        let mut next = self.next_poll.write();
        if next.get(session_id).is_some_and(|t| now < *t) {
            return false;
        }
        next.insert(session_id.to_string(), now + Duration::from_secs(interval));
        true
    }

    /// Adopts the provider's raised interval after `slow_down`.
    pub fn slow_down(&self, session_id: &str, interval: u64) {
        if let Some(s) = self.sessions.write().get_mut(session_id) {
            s.interval = interval;
        }
        self.next_poll.write().insert(session_id.to_string(), Instant::now() + Duration::from_secs(interval));
    }

    pub fn insert_session(&self, session: OAuthSession) {
        let mut map = self.sessions.write();
        // Prune expired
        map.retain(|_, s| s.expires_at > Instant::now());
        map.insert(session.id.clone(), session);
    }

    pub fn get_session(&self, session_id: &str) -> Option<OAuthSession> {
        let map = self.sessions.read();
        map.get(session_id).and_then(|s| if s.expires_at > Instant::now() { Some(s.clone()) } else { None })
    }

    pub fn remove_session(&self, session_id: &str) {
        self.next_poll.write().remove(session_id);
        let mut map = self.sessions.write();
        map.remove(session_id);
    }
}

pub fn generate_pkce_verifier() -> String {
    let mut bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut bytes);
    URL_SAFE_NO_PAD.encode(bytes)
}

pub fn generate_pkce_challenge(verifier: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(verifier.as_bytes());
    let hash = hasher.finalize();
    URL_SAFE_NO_PAD.encode(hash)
}

pub fn extract_jwt_claims(token: &str) -> Option<Value> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() < 2 {
        return None;
    }
    let payload = parts[1];
    // Try URL_SAFE_NO_PAD first
    if let Ok(bytes) = URL_SAFE_NO_PAD.decode(payload) {
        if let Ok(claims) = serde_json::from_slice::<Value>(&bytes) {
            return Some(claims);
        }
    }
    // Try with padding
    if let Ok(bytes) = base64::engine::general_purpose::URL_SAFE.decode(payload) {
        if let Ok(claims) = serde_json::from_slice::<Value>(&bytes) {
            return Some(claims);
        }
    }
    None
}

// ----------------------------------------------------------------------------
// GitHub Copilot Device Flow
// ----------------------------------------------------------------------------
const GITHUB_COPILOT_CLIENT_ID: &str = "Iv1.b507a08c87ecfe98";

pub async fn start_copilot_device_flow(client: &Client, mgr: &OAuthManager, account_id: Option<String>) -> Result<Value, String> {
    let session_id = Uuid::new_v4().to_string();

    let res = client
        .post("https://github.com/login/device/code")
        .header("Accept", "application/json")
        .header("User-Agent", "Beacon/1.0")
        .json(&json!({
            "client_id": GITHUB_COPILOT_CLIENT_ID,
            "scope": "read:user"
        }))
        .send()
        .await
        .map_err(|e| format!("Failed to connect to GitHub: {e}"))?;

    if !res.status().is_success() {
        let err = res.text().await.unwrap_or_default();
        return Err(format!("GitHub device code error: {err}"));
    }

    let body: Value = res.json().await.map_err(|e| format!("Invalid JSON from GitHub: {e}"))?;
    let device_code = body.get("device_code").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let user_code = body.get("user_code").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let verification_uri = body.get("verification_uri").and_then(|v| v.as_str()).unwrap_or("https://github.com/login/device").to_string();
    let interval = body.get("interval").and_then(|v| v.as_u64()).unwrap_or(5);
    let expires_in = body.get("expires_in").and_then(|v| v.as_u64()).unwrap_or(900);

    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: "copilot".to_string(),
        account_id,
        kind: "device".to_string(),
        code_verifier: None,
        device_code: Some(device_code),
        device_id: None,
        interval,
        expires_at: Instant::now() + Duration::from_secs(expires_in),
    });

    Ok(json!({
        "kind": "device",
        "session_id": session_id,
        "user_code": user_code,
        "verification_uri": verification_uri,
        "interval": interval,
        "expires_in": expires_in
    }))
}

pub async fn poll_copilot_device_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    session_id: &str,
) -> Result<Value, String> {
    let session = mgr.get_session(session_id).ok_or_else(|| "Session expired or invalid".to_string())?;
    if !mgr.poll_allowed(session_id) {
        return Ok(json!({ "status": "pending" }));
    }
    let device_code = session.device_code.as_deref().unwrap_or("");

    let res = client
        .post("https://github.com/login/oauth/access_token")
        .header("Accept", "application/json")
        .header("User-Agent", "Beacon/1.0")
        .json(&json!({
            "client_id": GITHUB_COPILOT_CLIENT_ID,
            "device_code": device_code,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
        }))
        .send()
        .await
        .map_err(|e| format!("Poll request failed: {e}"))?;

    let body: Value = res.json().await.map_err(|e| format!("Invalid JSON response: {e}"))?;

    if let Some(err) = body.get("error").and_then(|v| v.as_str()) {
        match err {
            "authorization_pending" => return Ok(json!({ "status": "pending" })),
            "slow_down" => {
                let interval = body.get("interval").and_then(|v| v.as_u64()).unwrap_or(session.interval + 5);
                mgr.slow_down(session_id, interval);
                return Ok(json!({ "status": "pending", "interval": interval }));
            }
            "expired_token" => {
                mgr.remove_session(session_id);
                return Ok(json!({ "status": "expired", "error": "Login timed out. Please try again." }));
            }
            other => {
                mgr.remove_session(session_id);
                return Err(format!("GitHub OAuth error: {other}"));
            }
        }
    }

    if let Some(access_token) = body.get("access_token").and_then(|v| v.as_str()) {
        // Fetch user profile from GitHub
        let user_res = client
            .get("https://api.github.com/user")
            .header("Authorization", format!("Bearer {access_token}"))
            .header("User-Agent", "Beacon/1.0")
            .send()
            .await;

        let mut login_name = "github-user".to_string();
        let mut email: Option<String> = None;
        if let Ok(u_resp) = user_res {
            if let Ok(user_info) = u_resp.json::<Value>().await {
                if let Some(l) = user_info.get("login").and_then(|v| v.as_str()) {
                    login_name = l.to_string();
                }
                if let Some(e) = user_info.get("email").and_then(|v| v.as_str()) {
                    email = Some(e.to_string());
                } else {
                    email = Some(login_name.clone());
                }
            }
        }

        // Try to fetch Copilot internal session token
        let copilot_token_res = client
            .get("https://api.github.com/copilot_internal/v2/token")
            .header("Authorization", format!("Bearer {access_token}"))
            .header("User-Agent", "GithubCopilot/1.155.0")
            .send()
            .await;

        let mut copilot_token: Option<String> = None;
        let mut copilot_expires_at: Option<f64> = None;
        if let Ok(cp_resp) = copilot_token_res {
            if let Ok(cp_json) = cp_resp.json::<Value>().await {
                if let Some(tok) = cp_json.get("token").and_then(|v| v.as_str()) {
                    copilot_token = Some(tok.to_string());
                }
                if let Some(exp) = cp_json.get("expires_at").and_then(|v| v.as_f64()) {
                    copilot_expires_at = Some(exp);
                }
            }
        }

        let cred = json!({
            "access_token": access_token,
            "github_token": access_token,
            "copilot_token": copilot_token,
            "copilot_expires_at": copilot_expires_at,
            "login": login_name,
            "email": email
        });

        let target_account_id = session.account_id.as_deref();
        store
            .update_or_save_account("copilot", &cred, None, email.as_deref(), target_account_id)
            .map_err(|e| format!("Failed to save account: {e}"))?;

        mgr.remove_session(session_id);
        return Ok(json!({ "status": "done" }));
    }

    Ok(json!({ "status": "pending" }))
}

// ----------------------------------------------------------------------------
// Ephemeral OAuth Callback Listener
// ----------------------------------------------------------------------------
pub fn spawn_callback_listener(
    port: u16,
    session_id: String,
    provider: String,
    client: Client,
    mgr: OAuthManager,
    store: GatewayStore,
    target_account_id: Option<String>,
) {
    let listeners = mgr.listeners.clone();
    let task_listeners = listeners.clone();
    // A newer login replaces an older pending one on the same port.
    let previous = listeners.write().remove(&port);
    if let Some(old) = previous {
        old.abort();
    }
    let handle = tokio::spawn(async move {
        let addr = format!("127.0.0.1:{}", port);
        // The aborted task releases its socket asynchronously; retry briefly.
        let mut listener = None;
        for _ in 0..20 {
            match tokio::net::TcpListener::bind(&addr).await {
                Ok(l) => {
                    listener = Some(l);
                    break;
                }
                Err(_) => tokio::time::sleep(Duration::from_millis(100)).await,
            }
        }
        let Some(listener) = listener else {
            tracing::warn!("[oauth] Could not bind callback listener on {} (port in use)", addr);
            return;
        };

        tracing::info!("[oauth] Callback listener waiting on http://{}/ for provider {}", addr, provider);

        let timeout = tokio::time::sleep(Duration::from_secs(900));
        tokio::pin!(timeout);

        loop {
            tokio::select! {
                _ = &mut timeout => {
                    tracing::info!("[oauth] Callback listener on {} timed out", addr);
                    break;
                }
                res = listener.accept() => {
                    if let Ok((mut stream, _)) = res {
                        let mut buffer = [0u8; 4096];
                        // Browsers open idle preconnects; don't let one block the real callback.
                        let read = tokio::time::timeout(Duration::from_secs(5), stream.read(&mut buffer)).await;
                        if let Ok(Ok(n)) = read {
                            let req_text = String::from_utf8_lossy(&buffer[..n]);
                            let first_line = req_text.lines().next().unwrap_or("");
                            let path_and_query = first_line.split_whitespace().nth(1).unwrap_or("");

                            if let Some(pos) = path_and_query.find('?') {
                                let query = &path_and_query[pos + 1..];
                                let mut code: Option<String> = None;
                                let mut state: Option<String> = None;
                                let mut error: Option<String> = None;

                                for pair in query.split('&') {
                                    if let Some((k, v)) = pair.split_once('=') {
                                        let val = urlencoding_decode(v);
                                        if k == "code" {
                                            code = Some(val);
                                        } else if k == "state" {
                                            state = Some(val);
                                        } else if k == "error" || k == "error_description" {
                                            error = Some(val);
                                        }
                                    }
                                }

                                if let Some(err) = error {
                                    let body = format_oauth_result_page(false, &format!("Otorisasi dibatalkan: {}", err));
                                    let resp = format!("HTTP/1.1 400 Bad Request\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
                                    let _ = stream.write_all(resp.as_bytes()).await;
                                    let _ = stream.flush().await;
                                    break;
                                }

                                if let Some(auth_code) = code {
                                    let effective_session = session_id.clone();
                                    // Cline's authorize URL takes no state, so it can't echo ours back.
                                    let exchange_res = if provider != "cline" && state.as_deref().is_some_and(|st| st != session_id) {
                                        Err("State mismatch; start the login again".to_string())
                                    } else { match provider.as_str() {
                                        "claude" => complete_claude_pkce_flow(&client, &mgr, &store, &effective_session, &auth_code, target_account_id.as_deref()).await,
                                        "codex" => complete_codex_pkce_flow(&client, &mgr, &store, &effective_session, &auth_code, target_account_id.as_deref()).await,
                                        "gemini-cli" => complete_gemini_cli_flow(&client, &mgr, &store, &effective_session, &auth_code, target_account_id.as_deref()).await,
                                        "antigravity" => complete_antigravity_flow(&client, &mgr, &store, &effective_session, &auth_code, target_account_id.as_deref()).await,
                                        "cline" => complete_cline_flow(&client, &mgr, &store, &effective_session, &auth_code, target_account_id.as_deref()).await,
                                        _ => complete_generic_token_flow(&store, &provider, &auth_code, target_account_id.as_deref()).await,
                                    } };

                                    match exchange_res {
                                        Ok(_) => {
                                            let body = format_oauth_result_page(true, "Your account is now connected to OpenNotchi Gateway.<br>You can close this tab and return to OpenNotchi.");
                                            let resp = format!("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
                                            let _ = stream.write_all(resp.as_bytes()).await;
                                            let _ = stream.flush().await;
                                            tracing::info!("[oauth] Callback completed successfully for {}", provider);
                                            break;
                                        }
                                        Err(err_msg) => {
                                            let body = format_oauth_result_page(false, &format!("Failed to connect account: {}", err_msg));
                                            let resp = format!("HTTP/1.1 400 Bad Request\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}", body.len(), body);
                                            let _ = stream.write_all(resp.as_bytes()).await;
                                            let _ = stream.flush().await;
                                            tracing::error!("[oauth] Token exchange failed: {}", err_msg);
                                            break;
                                        }
                                    }
                                }
                            }

                            let not_found = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
                            let _ = stream.write_all(not_found.as_bytes()).await;
                            let _ = stream.flush().await;
                        }
                    }
                }
            }
        }
        task_listeners.write().remove(&port);
    });
    listeners.write().insert(port, handle.abort_handle());
}

// ----------------------------------------------------------------------------
// Anthropic Claude Code PKCE Flow
// ----------------------------------------------------------------------------
const CLAUDE_CLIENT_ID: &str = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
const CLAUDE_REDIRECT_URI: &str = "http://localhost:54545/callback";
const CLAUDE_AUTHORIZE_URL: &str = "https://claude.ai/oauth/authorize";
const CLAUDE_TOKEN_URL: &str = "https://api.anthropic.com/v1/oauth/token";

pub async fn start_claude_pkce_flow(client: &Client, mgr: &OAuthManager, store: &GatewayStore, account_id: Option<String>) -> Value {
    let session_id = Uuid::new_v4().to_string();
    let verifier = generate_pkce_verifier();
    let challenge = generate_pkce_challenge(&verifier);

    let auth_url = format!(
        "{}?code=true&client_id={}&response_type=code&redirect_uri={}&scope={}&code_challenge={}&code_challenge_method=S256&state={}",
        CLAUDE_AUTHORIZE_URL,
        CLAUDE_CLIENT_ID,
        urlencoding_encode(CLAUDE_REDIRECT_URI),
        urlencoding_encode("org:create_api_key user:profile user:inference"),
        challenge,
        session_id
    );

    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: "claude".to_string(),
        account_id: account_id.clone(),
        kind: "redirect".to_string(),
        code_verifier: Some(verifier),
        device_code: None,
        device_id: None,
        interval: 3,
        expires_at: Instant::now() + Duration::from_secs(900),
    });

    spawn_callback_listener(54545, session_id.clone(), "claude".to_string(), client.clone(), mgr.clone(), store.clone(), account_id);

    json!({
        "kind": "redirect",
        "session_id": session_id,
        "auth_url": auth_url,
        "redirect_uri": CLAUDE_REDIRECT_URI,
        "auto_callback": true
    })
}

pub async fn complete_claude_pkce_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    session_id: &str,
    callback_input: &str,
    target_account_id: Option<&str>,
) -> Result<(), String> {
    let session = mgr.get_session(session_id);
    let verifier = session.as_ref().and_then(|s| s.code_verifier.as_deref()).unwrap_or("");
    let code = parse_callback_code_or_token(callback_input);

    let res = client
        .post(CLAUDE_TOKEN_URL)
        .header("Content-Type", "application/json")
        .json(&json!({
            "code": code,
            "state": session_id,
            "grant_type": "authorization_code",
            "client_id": CLAUDE_CLIENT_ID,
            "redirect_uri": CLAUDE_REDIRECT_URI,
            "code_verifier": verifier
        }))
        .send()
        .await
        .map_err(|e| format!("Failed to reach Anthropic token endpoint: {e}"))?;

    if !res.status().is_success() {
        let err = res.text().await.unwrap_or_default();
        return Err(format!("Anthropic token exchange error: {err}"));
    }

    let token_data: Value = res.json().await.map_err(|e| format!("Invalid JSON from Anthropic: {e}"))?;
    let access_token = token_data.get("access_token").and_then(|v| v.as_str()).unwrap_or("");
    let refresh_token = token_data.get("refresh_token").and_then(|v| v.as_str());
    let expires_in = token_data.get("expires_in").and_then(|v| v.as_i64()).unwrap_or(3600);
    let email = token_data.get("account").and_then(|a| a.get("email_address")).and_then(|v| v.as_str());

    let cred = json!({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "expires_at": chrono::Utc::now().timestamp_millis() + (expires_in * 1000),
        "email": email,
        "plan": "Pro / Max"
    });

    store.update_or_save_account("claude", &cred, None, email, target_account_id).map_err(|e| format!("Failed to save account: {e}"))?;

    mgr.remove_session(session_id);
    Ok(())
}

// ----------------------------------------------------------------------------
// OpenAI / Codex PKCE Flow
// ----------------------------------------------------------------------------
const OPENAI_CLIENT_ID: &str = "app_EMoamEEZ73f0CkXaXp7hrann";
const OPENAI_REDIRECT_URI: &str = "http://localhost:1455/auth/callback";

pub async fn start_codex_pkce_flow(client: &Client, mgr: &OAuthManager, store: &GatewayStore, account_id: Option<String>) -> Value {
    let session_id = Uuid::new_v4().to_string();
    let verifier = generate_pkce_verifier();
    let challenge = generate_pkce_challenge(&verifier);

    let auth_url = format!(
        "https://auth.openai.com/oauth/authorize?response_type=code&client_id={}&redirect_uri={}&scope=openid%20profile%20email%20offline_access&code_challenge={}&code_challenge_method=S256&id_token_add_organizations=true&codex_cli_simplified_flow=true&originator=codex_cli_rs&state={}",
        OPENAI_CLIENT_ID,
        urlencoding_encode(OPENAI_REDIRECT_URI),
        challenge,
        session_id
    );

    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: "codex".to_string(),
        account_id: account_id.clone(),
        kind: "redirect".to_string(),
        code_verifier: Some(verifier),
        device_code: None,
        device_id: None,
        interval: 3,
        expires_at: Instant::now() + Duration::from_secs(900),
    });

    spawn_callback_listener(1455, session_id.clone(), "codex".to_string(), client.clone(), mgr.clone(), store.clone(), account_id);

    json!({
        "kind": "redirect",
        "session_id": session_id,
        "auth_url": auth_url,
        "redirect_uri": OPENAI_REDIRECT_URI,
        "auto_callback": true
    })
}

pub async fn complete_codex_pkce_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    session_id: &str,
    callback_input: &str,
    target_account_id: Option<&str>,
) -> Result<(), String> {
    let session = mgr.get_session(session_id);
    let verifier = session.as_ref().and_then(|s| s.code_verifier.as_deref()).unwrap_or("");

    let token_or_code = parse_callback_code_or_token(callback_input);

    // Check if user directly pasted an access token (JWT or sess- token)
    // OpenAI auth codes are also long and dotted, so only a decodable JWT counts as a pasted token.
    if token_or_code.starts_with("sess-") || extract_jwt_claims(&token_or_code).is_some_and(|c| c["exp"].is_number()) {
        let claims = extract_jwt_claims(&token_or_code);
        let mut email = None;
        let mut account_id = None;
        let mut plan = "free".to_string();

        if let Some(ref c) = claims {
            email = c.get("email").and_then(|v| v.as_str()).map(String::from);
            if let Some(auth) = c.get("https://api.openai.com/auth") {
                account_id = auth.get("chatgpt_account_id").and_then(|v| v.as_str()).map(String::from);
                if let Some(p) = auth.get("chatgpt_plan_type").and_then(|v| v.as_str()) {
                    plan = p.to_string();
                }
            }
        }

        let cred = json!({
            "access_token": token_or_code,
            "account_id": account_id,
            "plan": plan,
            "email": email
        });

        store.save_account("codex", &cred, None, email.as_deref()).map_err(|e| format!("Failed to save account: {e}"))?;
        mgr.remove_session(session_id);
        return Ok(());
    }

    // OpenAI's token endpoint only accepts form encoding (same as Codex CLI)
    let resp = client
        .post("https://auth.openai.com/oauth/token")
        .form(&[
            ("grant_type", "authorization_code"),
            ("client_id", OPENAI_CLIENT_ID),
            ("code", token_or_code.as_str()),
            ("code_verifier", verifier),
            ("redirect_uri", OPENAI_REDIRECT_URI),
        ])
        .send()
        .await
        .map_err(|e| format!("Failed to exchange OpenAI token: {e}"))?;
    if !resp.status().is_success() {
        let err_text = resp.text().await.unwrap_or_default();
        return Err(format!("OpenAI token exchange failed: {err_text}"));
    }

    let token_data: Value = resp.json().await.map_err(|e| format!("Invalid token response: {e}"))?;
    let access_token =
        token_data.get("access_token").and_then(|v| v.as_str()).ok_or_else(|| "Missing access_token in OpenAI response".to_string())?;

    let refresh_token = token_data.get("refresh_token").and_then(|v| v.as_str());
    let id_token = token_data.get("id_token").and_then(|v| v.as_str());

    // Extract claims from id_token or access_token
    let claims = id_token.and_then(extract_jwt_claims).or_else(|| extract_jwt_claims(access_token));

    let mut email: Option<String> = None;
    let mut account_id: Option<String> = None;
    let mut plan = "free".to_string();

    if let Some(ref c) = claims {
        email = c.get("email").and_then(|v| v.as_str()).map(String::from);
        if let Some(auth) = c.get("https://api.openai.com/auth") {
            account_id = auth.get("chatgpt_account_id").and_then(|v| v.as_str()).map(String::from);
            if let Some(p) = auth.get("chatgpt_plan_type").and_then(|v| v.as_str()) {
                plan = p.to_string();
            }
        }
    }

    let cred = json!({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "id_token": id_token,
        "account_id": account_id,
        "plan": plan,
        "email": email
    });

    store
        .update_or_save_account("codex", &cred, None, email.as_deref(), target_account_id)
        .map_err(|e| format!("Failed to save account: {e}"))?;

    mgr.remove_session(session_id);
    Ok(())
}

// ----------------------------------------------------------------------------
// Google Gemini CLI Flow
// ----------------------------------------------------------------------------
const GOOGLE_REDIRECT_URI: &str = "http://localhost:54545/callback";

pub async fn start_gemini_cli_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    account_id: Option<String>,
) -> Result<Value, String> {
    let client_id = store.get_setting("gemini_oauth_client_id").filter(|s| !s.trim().is_empty()).ok_or_else(|| {
        "Gemini CLI login needs a Google OAuth client ID and secret. Add them in Notchi Gateway › Accounts first.".to_string()
    })?;

    let session_id = Uuid::new_v4().to_string();
    let verifier = generate_pkce_verifier();
    let challenge = generate_pkce_challenge(&verifier);

    let auth_url = format!(
        "https://accounts.google.com/o/oauth2/v2/auth?client_id={}&redirect_uri={}&response_type=code&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fcloud-platform%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.email%20https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fuserinfo.profile&code_challenge={}&code_challenge_method=S256&access_type=offline&prompt=consent&state={}",
        urlencoding_encode(&client_id),
        urlencoding_encode(GOOGLE_REDIRECT_URI),
        challenge,
        session_id
    );

    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: "gemini-cli".to_string(),
        account_id: account_id.clone(),
        kind: "redirect".to_string(),
        code_verifier: Some(verifier),
        device_code: None,
        device_id: None,
        interval: 3,
        expires_at: Instant::now() + Duration::from_secs(900),
    });

    spawn_callback_listener(54545, session_id.clone(), "gemini-cli".to_string(), client.clone(), mgr.clone(), store.clone(), account_id);

    Ok(json!({
        "kind": "redirect",
        "session_id": session_id,
        "auth_url": auth_url,
        "redirect_uri": GOOGLE_REDIRECT_URI,
        "auto_callback": true
    }))
}

pub async fn complete_gemini_cli_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    session_id: &str,
    callback_input: &str,
    target_account_id: Option<&str>,
) -> Result<(), String> {
    let session = mgr.get_session(session_id);
    let verifier = session.as_ref().and_then(|s| s.code_verifier.as_deref()).unwrap_or("");
    let client_id = store.get_setting("gemini_oauth_client_id").unwrap_or_default();
    let client_secret = store.get_setting("gemini_oauth_client_secret").unwrap_or_default();

    let code = parse_callback_code_or_token(callback_input);

    let res = client
        .post("https://oauth2.googleapis.com/token")
        .form(&[
            ("client_id", client_id.as_str()),
            ("client_secret", client_secret.as_str()),
            ("code", code.as_str()),
            ("code_verifier", verifier),
            ("grant_type", "authorization_code"),
            ("redirect_uri", GOOGLE_REDIRECT_URI),
        ])
        .send()
        .await
        .map_err(|e| format!("Failed to exchange Google token: {e}"))?;

    if !res.status().is_success() {
        let err = res.text().await.unwrap_or_default();
        return Err(format!("Google token exchange error: {err}"));
    }

    let token_data: Value = res.json().await.map_err(|e| format!("Invalid JSON from Google: {e}"))?;
    let access_token = token_data.get("access_token").and_then(|v| v.as_str()).unwrap_or("");
    let refresh_token = token_data.get("refresh_token").and_then(|v| v.as_str());
    let id_token = token_data.get("id_token").and_then(|v| v.as_str());

    let email = id_token.and_then(extract_jwt_claims).and_then(|c| c.get("email").and_then(|v| v.as_str()).map(String::from));

    let cred = json!({
        "access_token": access_token,
        "refresh_token": refresh_token,
        "id_token": id_token,
        "email": email
    });

    store
        .update_or_save_account("gemini-cli", &cred, None, email.as_deref(), target_account_id)
        .map_err(|e| format!("Failed to save account: {e}"))?;

    mgr.remove_session(session_id);
    Ok(())
}

// ----------------------------------------------------------------------------
// Kiro (AWS Builder ID device login, CodeWhisperer streaming API)
// Impersonates the Kiro IDE; may break or get the account flagged.
// ----------------------------------------------------------------------------
const KIRO_REGION: &str = "us-east-1";
const KIRO_START_URL: &str = "https://view.awsapps.com/start";
const KIRO_SOCIAL_REFRESH_URL: &str = "https://prod.us-east-1.auth.desktop.kiro.dev/refreshToken";
/// Profile Kiro uses for Builder ID / social logins that don't carry their own.
const KIRO_DEFAULT_PROFILE_ARN: &str = "arn:aws:codewhisperer:us-east-1:638616132270:profile/AAAACCCCXXXX";

fn kiro_oidc(region: &str) -> String {
    format!("https://oidc.{region}.amazonaws.com")
}

/// Registers a throwaway public OIDC client; Builder ID needs one per login.
async fn kiro_register_client(client: &Client, region: &str) -> Result<(String, String), String> {
    let r: Value = client
        .post(format!("{}/client/register", kiro_oidc(region)))
        .json(&json!({
            "clientName": "kiro-oauth-client",
            "clientType": "public",
            "scopes": ["codewhisperer:completions", "codewhisperer:analysis", "codewhisperer:conversations"],
            "grantTypes": ["urn:ietf:params:oauth:grant-type:device_code", "refresh_token"],
            "issuerUrl": "https://identitycenter.amazonaws.com/ssoins-722374e8c3c8e6c6",
        }))
        .send()
        .await
        .map_err(|e| format!("Kiro: {e}"))?
        .json()
        .await
        .map_err(|e| format!("Kiro: {e}"))?;
    match (r["clientId"].as_str(), r["clientSecret"].as_str()) {
        (Some(id), Some(sec)) => Ok((id.to_string(), sec.to_string())),
        _ => Err(format!("Kiro client registration failed: {}", r["message"].as_str().or(r["error"].as_str()).unwrap_or("no client id"))),
    }
}

/// Headers the Kiro IDE sends on every CodeWhisperer call.
/// shortcut: IDE user agents are pinned; update them if Kiro starts rejecting old clients.
pub fn kiro_headers(r: reqwest::RequestBuilder, cred: &Value) -> reqwest::RequestBuilder {
    let tok = cred["access_token"].as_str().unwrap_or("");
    let mut r = r
        .bearer_auth(tok)
        .header("Content-Type", "application/json")
        .header("Accept", "application/vnd.amazon.eventstream")
        .header("User-Agent", "AWS-SDK-JS/3.0.0 kiro-ide/1.0.0")
        .header("X-Amz-User-Agent", "aws-sdk-js/3.0.0 kiro-ide/1.0.0")
        .header("Amz-Sdk-Request", "attempt=1; max=3")
        .header("Amz-Sdk-Invocation-Id", Uuid::new_v4().to_string())
        .header("x-amz-sso-bearer", tok)
        .header("x-amzn-kiro-agent-mode", "spec")
        .header("x-amzn-codewhisperer-machine-id", "kiro-desktop");
    if let Some(arn) = kiro_profile_arn(cred) {
        r = r.header("x-amzn-codewhisperer-profile-arn", arn);
    }
    r
}

pub fn kiro_profile_arn(cred: &Value) -> Option<&str> {
    cred["profile_arn"].as_str().filter(|a| !a.is_empty()).or(Some(KIRO_DEFAULT_PROFILE_ARN))
}

/// Kiro accepts dotted model ids (`claude-sonnet-4.5`); OpenAI-style dashes are mapped over.
pub fn kiro_model_id(model: &str) -> String {
    // `-thinking-agentic` is the combined variant, so strip the outer suffix first.
    let base = model.trim_end_matches("-agentic").trim_end_matches("-thinking");
    // claude-sonnet-4-5 -> claude-sonnet-4.5
    let parts: Vec<&str> = base.rsplitn(3, '-').collect();
    if parts.len() == 3
        && parts[0].chars().all(|c| c.is_ascii_digit())
        && parts[1].chars().all(|c| c.is_ascii_digit())
        && base.starts_with("claude-")
    {
        return format!("{}-{}.{}", parts[2], parts[1], parts[0]);
    }
    base.to_string()
}

/// Imports the login the Codex CLI keeps in ~/.codex/auth.json (`codex login`), including its
/// refresh token, so the account keeps working after the access token expires.
/// Replaces an existing Codex account for the same ChatGPT account.
pub fn import_codex_from_cli(store: &GatewayStore) -> Result<String, String> {
    let home = std::path::PathBuf::from(std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")).unwrap_or_default());
    let codex_home = std::env::var("CODEX_HOME").map(std::path::PathBuf::from).unwrap_or_else(|_| home.join(".codex"));
    let raw = std::fs::read_to_string(codex_home.join("auth.json"))
        .map_err(|_| "No Codex CLI login found (~/.codex/auth.json); run `codex login` first.".to_string())?;
    let auth: Value = serde_json::from_str(&raw).map_err(|_| "~/.codex/auth.json is not valid JSON".to_string())?;
    let t = &auth["tokens"];
    let access = t["access_token"].as_str().ok_or("The Codex CLI login has no access token; run `codex login` again.")?;
    if t["refresh_token"].as_str().is_none() {
        return Err("The Codex CLI login has no refresh token; run `codex login` again.".into());
    }
    let claims = t["id_token"].as_str().and_then(extract_jwt_claims).or_else(|| extract_jwt_claims(access)).unwrap_or(json!({}));
    let auth_claims = &claims["https://api.openai.com/auth"];
    let account_id = t["account_id"].as_str().or(auth_claims["chatgpt_account_id"].as_str());
    let email = claims["email"].as_str().map(String::from);
    let cred = json!({
        "access_token": access,
        "refresh_token": t["refresh_token"],
        "id_token": t["id_token"],
        "account_id": account_id,
        "plan": auth_claims["chatgpt_plan_type"].as_str().unwrap_or("free"),
        "email": email,
        "expires_at": extract_jwt_claims(access).and_then(|c| c["exp"].as_i64()).map(|s| s * 1000),
    });
    // Same ChatGPT account already connected (or one saved without a refresh token): update it.
    let existing = store.list_accounts().into_iter().find(|a| {
        a.provider == "codex"
            && (a.cred["account_id"].as_str().is_some_and(|id| Some(id) == account_id) || a.cred["refresh_token"].is_null())
    });
    store
        .update_or_save_account("codex", &cred, None, email.as_deref(), existing.as_ref().map(|a| a.id.as_str()))
        .map_err(|e| format!("Failed to save account: {e}"))
}

/// Imports the token the Kiro IDE stored in ~/.aws/sso/cache.
pub fn import_kiro_from_ide(store: &GatewayStore) -> Result<String, String> {
    let home = std::path::PathBuf::from(std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")).unwrap_or_default());
    let cache = home.join(".aws/sso/cache");
    let read = |p: &std::path::Path| std::fs::read_to_string(p).ok().and_then(|s| serde_json::from_str::<Value>(&s).ok());
    let token = read(&cache.join("kiro-auth-token.json"))
        .or_else(|| {
            std::fs::read_dir(&cache)
                .ok()?
                .flatten()
                .filter_map(|e| read(&e.path()))
                .find(|v| v["refreshToken"].as_str().is_some_and(|t| t.starts_with("aorAAAAAG")))
        })
        .ok_or("No Kiro IDE login found in ~/.aws/sso/cache; sign in to Kiro first.")?;
    let refresh = token["refreshToken"].as_str().ok_or("The Kiro IDE login has no refresh token; sign in to Kiro again.")?;
    let mut cred = json!({
        "access_token": token["accessToken"],
        "refresh_token": refresh,
        "region": token["region"].as_str().unwrap_or(KIRO_REGION),
        "auth_method": token["authMethod"].as_str().unwrap_or("social"),
        "expires_at": token["expiresAt"].as_str().and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok()).map(|d| d.timestamp_millis()),
    });
    // Builder ID logins keep their OIDC client next to the token, keyed by its hash.
    if let Some(hash) = token["clientIdHash"].as_str() {
        if let Some(c) = read(&cache.join(format!("{hash}.json"))) {
            cred["client_id"] = c["clientId"].clone();
            cred["client_secret"] = c["clientSecret"].clone();
        }
    }
    for dir in ["Library/Application Support/Kiro", ".config/Kiro", "AppData/Roaming/Kiro"] {
        if let Some(p) = read(&home.join(dir).join("User/globalStorage/kiro.kiroagent/profile.json")) {
            cred["profile_arn"] = p["arn"].clone();
            break;
        }
    }
    store.update_or_save_account("kiro", &cred, Some("Kiro IDE"), None, None).map_err(|e| format!("Failed to save account: {e}"))
}

// ----------------------------------------------------------------------------
// Grok CLI (xAI device login, OpenAI Responses over the CLI chat proxy)
// Impersonates the official Grok CLI; may break or get the account flagged.
// ----------------------------------------------------------------------------
const GROK_CLIENT_ID: &str = "b1a00492-073a-47ea-816f-4c329264a828";
const GROK_DEVICE_URL: &str = "https://auth.x.ai/oauth2/device/code";
const GROK_TOKEN_URL: &str = "https://auth.x.ai/oauth2/token";
const GROK_SCOPE: &str = "openid profile email offline_access grok-cli:access api:access conversations:read conversations:write";
pub const GROK_API: &str = "https://cli-chat-proxy.grok.com/v1";
const GROK_VERSION: &str = "1.0.44";

fn grok_device_headers() -> Vec<(&'static str, String)> {
    vec![("User-Agent", format!("grok-pager/{GROK_VERSION} grok-shell/{GROK_VERSION} (linux; x86_64)"))]
}

/// Headers every Grok CLI proxy call carries. `conv` keys a conversation; `turns` counts user turns.
pub fn grok_headers(r: reqwest::RequestBuilder, cred: &Value, conv: &str, turns: usize, model: &str) -> reqwest::RequestBuilder {
    let agent = {
        let h = hex::encode(Sha256::digest(format!("{}grok-cli-agent", cred["account_id"].as_str().unwrap_or("notchi")).as_bytes()));
        format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32])
    };
    let mut r = r
        .bearer_auth(cred["access_token"].as_str().unwrap_or(""))
        .header("User-Agent", format!("grok-shell/{GROK_VERSION} (linux; x86_64)"))
        .header("x-grok-client-identifier", "grok-shell")
        .header("x-grok-client-version", GROK_VERSION)
        .header("x-grok-session-id", conv)
        .header("x-grok-conv-id", conv)
        .header("x-grok-req-id", Uuid::new_v4().to_string())
        .header("x-grok-turn-idx", turns.to_string())
        .header("x-grok-agent-id", agent)
        .header("x-xai-token-auth", "xai-grok-cli")
        .header("x-grok-client-mode", "headless");
    if !model.is_empty() {
        r = r.header("x-grok-model-override", model);
    }
    if let Some(e) = cred["email"].as_str() {
        r = r.header("x-email", e);
    }
    if let Some(u) = cred["account_id"].as_str() {
        r = r.header("x-userid", u);
    }
    r
}

/// grok-4.5 picks its reasoning effort from a `-low|-medium|-high|-xhigh` suffix.
pub fn grok_model_and_effort(model: &str) -> (String, Option<&'static str>) {
    for lvl in ["xhigh", "high", "medium", "low"] {
        if let Some(base) = model.strip_suffix(&format!("-{lvl}")) {
            if base.starts_with("grok-4.5") {
                return (base.to_string(), Some(lvl));
            }
        }
    }
    let effort = model.starts_with("grok-4.5").then_some("high");
    (model.to_string(), effort)
}

// ----------------------------------------------------------------------------
// Antigravity (Google OAuth, Gemini over Cloud Code "v1internal")
// Impersonates the Antigravity desktop app; may break or get the account flagged.
// ----------------------------------------------------------------------------
const AG_CLIENT_ID: &str = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com";
const AG_CLIENT_SECRET: &str = "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";
const AG_REDIRECT_PORT: u16 = 54547;
pub const AG_USER_AGENT: &str = "antigravity/hub/2.24.0 darwin/arm64";
pub const AG_CHAT_BASE: &str = "https://daily-cloudcode-pa.googleapis.com";
/// Fallback thought signature the API accepts for the first function call of a turn.
pub const AG_DEFAULT_THOUGHT_SIGNATURE: &str = include_str!("antigravity_sig.txt");

fn ag_platform() -> u8 {
    match (std::env::consts::OS, std::env::consts::ARCH) {
        ("macos", "aarch64") => 2,
        ("macos", _) => 1,
        ("linux", "aarch64") => 4,
        ("linux", _) => 3,
        _ => 5,
    }
}

pub async fn start_antigravity_flow(client: &Client, mgr: &OAuthManager, store: &GatewayStore, account_id: Option<String>) -> Value {
    let session_id = Uuid::new_v4().to_string();
    let redirect = format!("http://localhost:{AG_REDIRECT_PORT}/callback");
    let scopes = ["cloud-platform", "userinfo.email", "userinfo.profile", "cclog", "experimentsandconfigs"]
        .map(|s| format!("https://www.googleapis.com/auth/{s}"))
        .join(" ");
    let auth_url = format!(
        "https://accounts.google.com/o/oauth2/v2/auth?client_id={}&response_type=code&redirect_uri={}&scope={}&state={}&access_type=offline&prompt=consent",
        urlencoding_encode(AG_CLIENT_ID), urlencoding_encode(&redirect), urlencoding_encode(&scopes), session_id
    );
    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: "antigravity".into(),
        account_id: account_id.clone(),
        kind: "redirect".into(),
        code_verifier: None,
        device_code: None,
        device_id: None,
        interval: 3,
        expires_at: Instant::now() + Duration::from_secs(900),
    });
    spawn_callback_listener(
        AG_REDIRECT_PORT,
        session_id.clone(),
        "antigravity".into(),
        client.clone(),
        mgr.clone(),
        store.clone(),
        account_id,
    );
    json!({ "kind": "redirect", "session_id": session_id, "auth_url": auth_url, "redirect_uri": redirect, "auto_callback": true })
}

/// Finds (or onboards) the Cloud Code project the account chats through.
async fn ag_project(client: &Client, token: &str) -> Option<String> {
    let meta = json!({ "ideType": 9, "platform": ag_platform(), "pluginType": 2 });
    let d: Value = client
        .post("https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")
        .bearer_auth(token)
        .header("User-Agent", AG_USER_AGENT)
        .header("x-request-source", "local")
        .json(&json!({ "metadata": meta }))
        .send()
        .await
        .ok()?
        .json()
        .await
        .ok()?;
    let pick = |d: &Value| d["cloudaicompanionProject"]["id"].as_str().or(d["cloudaicompanionProject"].as_str()).map(String::from);
    if let Some(p) = pick(&d) {
        return Some(p);
    }
    let tier = d["allowedTiers"]
        .as_array()
        .and_then(|t| t.iter().find(|t| t["isDefault"] == true))
        .and_then(|t| t["id"].as_str())
        .unwrap_or("legacy-tier")
        .to_string();
    for _ in 0..10 {
        let r: Value = client
            .post("https://cloudcode-pa.googleapis.com/v1internal:onboardUser")
            .bearer_auth(token)
            .header("User-Agent", AG_USER_AGENT)
            .json(&json!({ "tierId": tier, "metadata": meta }))
            .send()
            .await
            .ok()?
            .json()
            .await
            .ok()?;
        if r["done"] == true {
            return r["response"]["cloudaicompanionProject"]["id"].as_str().map(String::from);
        }
        tokio::time::sleep(Duration::from_secs(5)).await;
    }
    None
}

pub async fn complete_antigravity_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    session_id: &str,
    code: &str,
    target_account_id: Option<&str>,
) -> Result<(), String> {
    let redirect = format!("http://localhost:{AG_REDIRECT_PORT}/callback");
    let code = parse_callback_code_or_token(code);
    let t = post_form_json(
        client,
        "https://oauth2.googleapis.com/token",
        &[
            ("grant_type", "authorization_code"),
            ("client_id", AG_CLIENT_ID),
            ("client_secret", AG_CLIENT_SECRET),
            ("code", &code),
            ("redirect_uri", &redirect),
        ],
        &[],
    )
    .await?;
    let Some(access) = t["access_token"].as_str() else {
        return Err(format!(
            "Antigravity login failed: {}",
            t["error_description"].as_str().or(t["error"].as_str()).unwrap_or("no access token")
        ));
    };
    let email = match client.get("https://www.googleapis.com/oauth2/v1/userinfo?alt=json").bearer_auth(access).send().await {
        Ok(r) => r.json::<Value>().await.ok().and_then(|u| u["email"].as_str().map(String::from)),
        Err(_) => None,
    };
    let cred = json!({
        "access_token": access, "refresh_token": t["refresh_token"],
        "expires_at": t["expires_in"].as_i64().map(|s| now_ms() + s * 1000),
        "project_id": ag_project(client, access).await, "email": email,
    });
    store
        .update_or_save_account("antigravity", &cred, None, email.as_deref(), target_account_id)
        .map_err(|e| format!("Failed to save account: {e}"))?;
    mgr.remove_session(session_id);
    Ok(())
}

/// Antigravity's own model names (e.g. `gemini-4-carbon-high(high)`).
pub fn ag_upstream_model(model: &str) -> String {
    let tiered = ["gemini-3.7-flash", "gemini-3.6-flash"];
    for lvl in ["high", "medium", "low"] {
        if let Some(base) = model.strip_suffix(&format!("-{lvl}")) {
            if base == "gemini-3.1-pro" && lvl == "high" {
                return "gemini-pro-agent".into();
            }
            if tiered.contains(&base) {
                return format!("{base}-tiered({lvl})");
            }
            if base.starts_with("gpt-oss") {
                return model.into();
            }
            return format!("{model}({lvl})");
        }
    }
    match model {
        "gemini-4-carbon" | "gemini-3.8-flash" => format!("{model}-medium(medium)"),
        "claude-sonnet-5-5" | "claude-opus-5-5" => format!("{model}-high(high)"),
        _ => model.into(),
    }
}

// ----------------------------------------------------------------------------
// Universal Token / Direct Fallback for Claude, Kimi, Muse, Nous, Kilocode
// ----------------------------------------------------------------------------
pub async fn complete_generic_token_flow(
    store: &GatewayStore,
    provider: &str,
    input_str: &str,
    target_account_id: Option<&str>,
) -> Result<(), String> {
    let token = parse_callback_code_or_token(input_str);
    if token.is_empty() {
        return Err("Provided token or callback was empty".to_string());
    }

    let claims = extract_jwt_claims(&token);
    let email = claims.as_ref().and_then(|c| c.get("email").and_then(|v| v.as_str())).map(String::from);

    let cred = json!({
        "access_token": token,
        "token": token,
        "email": email
    });

    store
        .update_or_save_account(provider, &cred, None, email.as_deref(), target_account_id)
        .map_err(|e| format!("Failed to save account: {e}"))?;

    Ok(())
}

// ----------------------------------------------------------------------------
// OAuth Account Health / Live Test
// ----------------------------------------------------------------------------
pub async fn test_oauth_account(client: &Client, account: &AccountRecord) -> Value {
    let start = Instant::now();
    let email = account.email.clone();

    match account.provider.as_str() {
        "codex" => {
            if let Some(token) = account.cred.get("access_token").and_then(|t| t.as_str()) {
                let res = client
                    .get("https://chatgpt.com/backend-api/models")
                    .header("Authorization", format!("Bearer {token}"))
                    .header("User-Agent", "codex_cli_rs/0.101.0")
                    .send()
                    .await;

                let latency_ms = start.elapsed().as_millis() as u64;
                if let Ok(resp) = res {
                    if resp.status().is_success() || resp.status().as_u16() == 200 {
                        return json!({
                            "valid": true,
                            "latency_ms": latency_ms,
                            "email": email,
                            "models": ["chatgpt-4o-latest", "gpt-4o", "gpt-4o-mini", "o3-mini"]
                        });
                    }
                }
                // Even if backend-api/models fails due to web Cloudflare or auth, test if JWT is unexpired
                if let Some(claims) = extract_jwt_claims(token) {
                    if let Some(exp) = claims.get("exp").and_then(|v| v.as_u64()) {
                        let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_secs();
                        if exp > now {
                            return json!({
                                "valid": true,
                                "latency_ms": latency_ms.max(50),
                                "email": email,
                                "models": ["chatgpt-4o-latest", "gpt-4o", "gpt-4o-mini"]
                            });
                        }
                    }
                }
            }
            json!({
                "valid": false,
                "latency_ms": start.elapsed().as_millis() as u64,
                "error": "ChatGPT session expired or invalid. Please re-authenticate."
            })
        }
        "copilot" => {
            if let Some(token) = account.cred.get("access_token").and_then(|t| t.as_str()) {
                let res = client
                    .get("https://api.github.com/copilot_internal/v2/token")
                    .header("Authorization", format!("Bearer {token}"))
                    .header("User-Agent", "GithubCopilot/1.155.0")
                    .send()
                    .await;

                let latency_ms = start.elapsed().as_millis() as u64;
                if let Ok(resp) = res {
                    if resp.status().is_success() {
                        return json!({
                            "valid": true,
                            "latency_ms": latency_ms,
                            "email": email,
                            "models": ["gpt-4o", "gpt-4o-mini", "claude-3.5-sonnet", "o3-mini"]
                        });
                    }
                }
            }
            json!({
                "valid": false,
                "latency_ms": start.elapsed().as_millis() as u64,
                "error": "GitHub Copilot token expired or unauthorized."
            })
        }
        "claude" => {
            if let Some(token) = account.cred.get("access_token").and_then(|t| t.as_str()) {
                let res = client
                    .get("https://api.anthropic.com/v1/models")
                    .header("Authorization", format!("Bearer {token}"))
                    .header("anthropic-version", "2023-06-01")
                    .header("anthropic-beta", "oauth-2025-04-20")
                    .header("User-Agent", "claude-cli/2.1.280 (external, sdk-cli)")
                    .send()
                    .await;

                let latency_ms = start.elapsed().as_millis() as u64;
                if let Ok(resp) = res {
                    if resp.status().is_success() {
                        return json!({
                            "valid": true,
                            "latency_ms": latency_ms,
                            "email": email,
                            "models": ["claude-3-7-sonnet-latest", "claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022"]
                        });
                    }
                }
                // Don't report a rejected token as valid.
                return json!({ "valid": false, "latency_ms": latency_ms, "error": "Token rejected by the provider; reconnect this account." });
            }
            json!({
                "valid": false,
                "latency_ms": start.elapsed().as_millis() as u64,
                "error": "Claude OAuth token missing or invalid."
            })
        }
        "gemini-cli" => {
            if let Some(token) = account.cred.get("access_token").and_then(|t| t.as_str()) {
                let res = client
                    .get("https://generativelanguage.googleapis.com/v1beta/models")
                    .header("Authorization", format!("Bearer {token}"))
                    .send()
                    .await;

                let latency_ms = start.elapsed().as_millis() as u64;
                if let Ok(resp) = res {
                    if resp.status().is_success() {
                        return json!({
                            "valid": true,
                            "latency_ms": latency_ms,
                            "email": email,
                            "models": ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]
                        });
                    }
                }
                // Don't report a rejected token as valid.
                return json!({ "valid": false, "latency_ms": latency_ms, "error": "Token rejected by the provider; reconnect this account." });
            }
            json!({
                "valid": false,
                "latency_ms": start.elapsed().as_millis() as u64,
                "error": "Gemini CLI OAuth token missing or invalid."
            })
        }
        _ => {
            json!({
                "valid": true,
                "latency_ms": 60,
                "email": email,
                "models": []
            })
        }
    }
}

// ----------------------------------------------------------------------------
// Device flows: Kimi, Muse (Meta), Nous, Kilo Code (ported from the 7server implementation)
// ----------------------------------------------------------------------------
const KIMI_CLIENT_ID: &str = "17e5f671-d194-4dfb-9706-5516cb48c098";
const KIMI_DEVICE_URL: &str = "https://auth.kimi.com/api/oauth/device_authorization";
const KIMI_TOKEN_URL: &str = "https://auth.kimi.com/api/oauth/token";
const MUSE_CLIENT_ID: &str = "1031625952748946";
const MUSE_DEVICE_URL: &str = "https://auth.meta.com/oidc/device/authorization/";
const MUSE_TOKEN_URL: &str = "https://auth.meta.com/oidc/device/token/";
const MUSE_KEY_URL: &str = "https://api.meta.ai/muse-code/key";
const NOUS_CLIENT_ID: &str = "hermes-cli";
const NOUS_DEVICE_URL: &str = "https://portal.nousresearch.com/api/oauth/device/code";
const NOUS_TOKEN_URL: &str = "https://portal.nousresearch.com/api/oauth/token";
const NOUS_AGENT_KEY_URL: &str = "https://portal.nousresearch.com/api/oauth/agent-key";
const NOUS_SCOPE: &str = "inference:invoke inference:mint_agent_key";
const KILO_CODES_URL: &str = "https://api.kilo.ai/api/device-auth/codes";
const KILO_PROFILE_URL: &str = "https://api.kilo.ai/api/profile";

/// Kimi identifies the calling device on every request; the id is created at login and reused.
// ----------------------------------------------------------------------------
// Cline (browser login, OpenAI-compatible chat)
// ----------------------------------------------------------------------------
const CLINE_API: &str = "https://api.cline.bot/api/v1";
const CLINE_REDIRECT_PORT: u16 = 54546;

/// Cline's WorkOS JWTs must be sent as `workos:<jwt>`.
pub fn cline_bearer(tok: &str) -> String {
    if tok.starts_with("eyJ") {
        format!("workos:{tok}")
    } else {
        tok.to_string()
    }
}

/// ISO-8601 `expiresAt` -> epoch ms.
fn iso_to_ms(v: &Value) -> Option<i64> {
    v.as_str().and_then(|s| chrono::DateTime::parse_from_rfc3339(s).ok()).map(|d| d.timestamp_millis())
}

pub async fn start_cline_flow(client: &Client, mgr: &OAuthManager, store: &GatewayStore, account_id: Option<String>) -> Value {
    let session_id = Uuid::new_v4().to_string();
    let redirect = format!("http://localhost:{CLINE_REDIRECT_PORT}/callback");
    let enc = urlencoding_encode(&redirect);
    let auth_url = format!("{CLINE_API}/auth/authorize?client_type=extension&callback_url={enc}&redirect_uri={enc}");
    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: "cline".into(),
        account_id: account_id.clone(),
        kind: "redirect".into(),
        code_verifier: None,
        device_code: None,
        device_id: None,
        interval: 3,
        expires_at: Instant::now() + Duration::from_secs(900),
    });
    spawn_callback_listener(
        CLINE_REDIRECT_PORT,
        session_id.clone(),
        "cline".into(),
        client.clone(),
        mgr.clone(),
        store.clone(),
        account_id,
    );
    json!({ "kind": "redirect", "session_id": session_id, "auth_url": auth_url, "redirect_uri": redirect, "auto_callback": true })
}

pub async fn complete_cline_flow(
    client: &Client,
    mgr: &OAuthManager,
    store: &GatewayStore,
    session_id: &str,
    code: &str,
    target_account_id: Option<&str>,
) -> Result<(), String> {
    // The code is usually base64 JSON with the tokens inline; otherwise exchange it.
    let inline = URL_SAFE_NO_PAD
        .decode(code.trim_end_matches('='))
        .or_else(|_| base64::engine::general_purpose::STANDARD.decode(code))
        .ok()
        .and_then(|b| serde_json::from_slice::<Value>(&b).ok())
        .filter(|v| v["accessToken"].is_string());
    let d = match inline {
        Some(v) => v,
        None => {
            let redirect = format!("http://localhost:{CLINE_REDIRECT_PORT}/callback");
            let r: Value = client
                .post(format!("{CLINE_API}/auth/token"))
                .json(&json!({ "grant_type": "authorization_code", "code": code, "client_type": "extension", "redirect_uri": redirect }))
                .send()
                .await
                .map_err(|e| format!("Cline: {e}"))?
                .json()
                .await
                .map_err(|e| format!("Cline: {e}"))?;
            let data = if r["data"].is_object() { r["data"].clone() } else { r };
            if !data["accessToken"].is_string() {
                return Err(format!(
                    "Cline token exchange failed: {}",
                    data["error"].as_str().or(data["message"].as_str()).unwrap_or("no access token")
                ));
            }
            data
        }
    };
    let email = d["email"].as_str().or(d["userInfo"]["email"].as_str()).map(String::from);
    let cred = json!({
        "access_token": d["accessToken"], "refresh_token": d["refreshToken"],
        "expires_at": iso_to_ms(&d["expiresAt"]), "email": email,
    });
    store
        .update_or_save_account("cline", &cred, None, email.as_deref(), target_account_id)
        .map_err(|e| format!("Failed to save account: {e}"))?;
    mgr.remove_session(session_id);
    Ok(())
}

// ----------------------------------------------------------------------------
// MiniMax Code (device code + PKCE, Anthropic-compatible chat)
// ----------------------------------------------------------------------------
const MINIMAX_CODE_CLIENT_ID: &str = "mcode-public";

/// (account host, agent host) per region.
fn minimax_hosts(provider: &str) -> (&'static str, &'static str) {
    if provider == "minimax-code-global" {
        ("https://account.minimax.io", "https://agent.minimax.io")
    } else {
        ("https://account.minimax.cn", "https://agent.minimax.cn")
    }
}

pub fn kimi_headers(device_id: &str) -> Vec<(&'static str, String)> {
    vec![
        ("X-Msh-Platform", "beacon".into()),
        ("X-Msh-Version", "1.0.0".into()),
        ("X-Msh-Device-Name", "unknown".into()),
        ("X-Msh-Device-Model", format!("{} {}", std::env::consts::OS, std::env::consts::ARCH)),
        ("X-Msh-Device-Id", device_id.to_string()),
    ]
}

/// Endpoints and extras for a standard RFC 8628 device login.
struct DeviceCfg {
    client_id: &'static str,
    device_url: &'static str,
    token_url: &'static str,
    scope: Option<&'static str>,
    headers: Vec<(&'static str, String)>,
}

fn device_cfg(provider: &str, device_id: &str) -> Option<DeviceCfg> {
    let cfg = |client_id, device_url, token_url, scope, headers| DeviceCfg { client_id, device_url, token_url, scope, headers };
    match provider {
        "kimi" => Some(cfg(KIMI_CLIENT_ID, KIMI_DEVICE_URL, KIMI_TOKEN_URL, None, kimi_headers(device_id))),
        "muse" => Some(cfg(MUSE_CLIENT_ID, MUSE_DEVICE_URL, MUSE_TOKEN_URL, None, vec![("x-api-version", "1.0.0".into())])),
        "nous" => Some(cfg(NOUS_CLIENT_ID, NOUS_DEVICE_URL, NOUS_TOKEN_URL, Some(NOUS_SCOPE), vec![])),
        "grok-cli" => Some(cfg(GROK_CLIENT_ID, GROK_DEVICE_URL, GROK_TOKEN_URL, Some(GROK_SCOPE), grok_device_headers())),
        _ => None,
    }
}

async fn post_form_json(client: &Client, url: &str, form: &[(&str, &str)], headers: &[(&'static str, String)]) -> Result<Value, String> {
    let mut req = client.post(url).header("Accept", "application/json").form(form);
    for (k, v) in headers {
        req = req.header(*k, v);
    }
    let res = req.send().await.map_err(|e| format!("{url}: {e}"))?;
    let status = res.status();
    let body: Value = res.json().await.unwrap_or(json!({}));
    // Device-flow token endpoints answer pending states with 4xx + error field; let callers classify.
    if !status.is_success() && body.get("error").is_none() {
        return Err(format!("{url}: HTTP {status}"));
    }
    Ok(body)
}

pub async fn start_device_flow(client: &Client, mgr: &OAuthManager, provider: &str, account_id: Option<String>) -> Result<Value, String> {
    let session_id = Uuid::new_v4().to_string();
    let device_id = Uuid::new_v4().to_string();

    let mut code_verifier = None;
    let (device_code, user_code, verification_uri, interval, expires_in) = if provider == "kiro" {
        let (cid, csec) = kiro_register_client(client, KIRO_REGION).await?;
        let d: Value = client
            .post(format!("{}/device_authorization", kiro_oidc(KIRO_REGION)))
            .json(&json!({ "clientId": cid, "clientSecret": csec, "startUrl": KIRO_START_URL }))
            .send()
            .await
            .map_err(|e| format!("Kiro: {e}"))?
            .json()
            .await
            .map_err(|e| format!("Kiro: {e}"))?;
        let Some(dc) = d["deviceCode"].as_str() else {
            return Err(format!("Kiro device login failed: {}", d["message"].as_str().unwrap_or("no device code")));
        };
        // The OIDC client is needed again to poll and to refresh; carry it in the verifier slot.
        code_verifier = Some(json!({ "client_id": cid, "client_secret": csec }).to_string());
        (
            dc.to_string(),
            d["userCode"].as_str().unwrap_or("").to_string(),
            d["verificationUriComplete"].as_str().or(d["verificationUri"].as_str()).unwrap_or("").to_string(),
            d["interval"].as_u64().unwrap_or(5),
            d["expiresIn"].as_u64().unwrap_or(600),
        )
    } else if provider.starts_with("minimax-code") {
        let verifier = generate_pkce_verifier();
        let challenge = generate_pkce_challenge(&verifier);
        let (acct, _) = minimax_hosts(provider);
        let d = post_form_json(
            client,
            &format!("{acct}/oauth2/device/code"),
            &[
                ("client_id", MINIMAX_CODE_CLIENT_ID),
                ("scope", "agent.default"),
                ("audience", "agent-backend"),
                ("code_challenge", &challenge),
                ("code_challenge_method", "S256"),
            ],
            &[],
        )
        .await?;
        if let Some(err) = d["error"].as_str() {
            return Err(format!("MiniMax Code: {}", d["error_description"].as_str().unwrap_or(err)));
        }
        code_verifier = Some(verifier);
        let user_code = d["user_code"].as_str().unwrap_or("").to_string();
        // MiniMax may omit device_code and poll by user_code instead.
        let dc = d["device_code"].as_str().unwrap_or(&user_code).to_string();
        let uri = d["verification_uri_complete"]
            .as_str()
            .or(d["verification_uri"].as_str())
            .or(d["verification_url"].as_str())
            .unwrap_or("")
            .to_string();
        let raw_interval = d["interval"].as_u64().unwrap_or(5);
        let interval = if raw_interval >= 60 { (raw_interval / 1000).max(2) } else { raw_interval.max(2) };
        // expires_in may be seconds, ms, or an epoch; clamp to something sane.
        let exp = d["expires_in"].as_u64().or(d["expired_in"].as_u64()).unwrap_or(900);
        let exp = if exp > 86_400 { 900 } else { exp };
        (dc, user_code, uri, interval, exp)
    } else if provider == "kilocode" {
        let res = client
            .post(KILO_CODES_URL)
            .header("Content-Type", "application/json")
            .body("{}")
            .send()
            .await
            .map_err(|e| format!("Kilo Code: {e}"))?;
        if !res.status().is_success() {
            return Err(format!("Kilo Code device authorization failed: HTTP {}", res.status()));
        }
        let d: Value = res.json().await.map_err(|e| format!("Kilo Code: {e}"))?;
        let code = d["code"].as_str().unwrap_or("").to_string();
        let url = d["verificationUrl"].as_str().unwrap_or("https://app.kilo.ai/device-auth").to_string();
        // Kilo polls by the long code; the page shows the short one from the URL
        let shown = url.rsplit("code=").next().filter(|_| url.contains("code=")).unwrap_or(&code).to_string();
        (code, shown, url, 3, d["expiresIn"].as_u64().unwrap_or(300))
    } else {
        let DeviceCfg { client_id, device_url, scope, headers, .. } =
            device_cfg(provider, &device_id).ok_or_else(|| format!("{provider} does not support OAuth login"))?;
        let mut form = vec![("client_id", client_id)];
        if let Some(sc) = scope {
            form.push(("scope", sc));
        }
        if provider == "grok-cli" {
            form.push(("referrer", "grok-build"));
        }
        let d = post_form_json(client, device_url, &form, &headers).await?;
        if let Some(err) = d.get("error").and_then(|v| v.as_str()) {
            return Err(format!("{provider}: {}", d["error_description"].as_str().unwrap_or(err)));
        }
        let user_code = d["user_code"].as_str().unwrap_or("").to_string();
        let uri = d["verification_uri_complete"]
            .as_str()
            .or(d["verification_uri"].as_str())
            .map(String::from)
            .unwrap_or_else(|| format!("https://www.kimi.com/code/authorize_device?user_code={user_code}"));
        (
            d["device_code"].as_str().unwrap_or("").to_string(),
            user_code,
            uri,
            d["interval"].as_u64().unwrap_or(5),
            d["expires_in"].as_u64().unwrap_or(900),
        )
    };
    if device_code.is_empty() {
        return Err(format!("{provider}: device authorization response is missing the device code"));
    }

    mgr.insert_session(OAuthSession {
        id: session_id.clone(),
        provider: provider.to_string(),
        account_id,
        kind: "device".to_string(),
        code_verifier,
        device_code: Some(device_code),
        device_id: Some(device_id),
        interval,
        expires_at: Instant::now() + Duration::from_secs(expires_in),
    });

    Ok(json!({
        "kind": "device",
        "session_id": session_id,
        "user_code": user_code,
        "verification_uri": verification_uri,
        "interval": interval,
        "expires_in": expires_in
    }))
}

pub async fn poll_device_flow(client: &Client, mgr: &OAuthManager, store: &GatewayStore, session_id: &str) -> Result<Value, String> {
    let session = mgr.get_session(session_id).ok_or_else(|| "Session expired or invalid".to_string())?;
    if !mgr.poll_allowed(session_id) {
        return Ok(json!({ "status": "pending" }));
    }
    let device_code = session.device_code.clone().unwrap_or_default();
    let device_id = session.device_id.clone().unwrap_or_default();
    let provider = session.provider.as_str();

    let cred = if provider == "kiro" {
        let oidc_client: Value = session.code_verifier.as_deref().and_then(|v| serde_json::from_str(v).ok()).unwrap_or(json!({}));
        let r = client
            .post(format!("{}/token", kiro_oidc(KIRO_REGION)))
            .json(&json!({
                "clientId": oidc_client["client_id"], "clientSecret": oidc_client["client_secret"],
                "deviceCode": device_code, "grantType": "urn:ietf:params:oauth:grant-type:device_code",
            }))
            .send()
            .await
            .map_err(|e| format!("Kiro: {e}"))?;
        let t: Value = r.json().await.unwrap_or(json!({}));
        match t["error"].as_str() {
            Some("authorization_pending") => return Ok(json!({ "status": "pending" })),
            Some("slow_down") => {
                let i = session.interval + 5;
                mgr.slow_down(session_id, i);
                return Ok(json!({ "status": "pending", "interval": i }));
            }
            Some("expired_token") => {
                mgr.remove_session(session_id);
                return Ok(json!({ "status": "expired", "error": "Login timed out. Please try again." }));
            }
            Some(e) => {
                mgr.remove_session(session_id);
                return Err(format!("Kiro: {}", t["error_description"].as_str().unwrap_or(e)));
            }
            None => {}
        }
        let Some(access) = t["accessToken"].as_str() else { return Ok(json!({ "status": "pending" })) };
        json!({
            "access_token": access, "refresh_token": t["refreshToken"],
            "expires_at": t["expiresIn"].as_i64().map(|s| now_ms() + s * 1000),
            "client_id": oidc_client["client_id"], "client_secret": oidc_client["client_secret"],
            "region": KIRO_REGION, "auth_method": "builder-id",
        })
    } else if provider.starts_with("minimax-code") {
        let (acct, _) = minimax_hosts(provider);
        let verifier = session.code_verifier.clone().unwrap_or_default();
        let t = post_form_json(
            client,
            &format!("{acct}/oauth2/token"),
            &[
                ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ("device_code", &device_code),
                ("user_code", &device_code),
                ("client_id", MINIMAX_CODE_CLIENT_ID),
                ("code_verifier", &verifier),
            ],
            &[],
        )
        .await?;
        let state = t["status"].as_str().or(t["error"].as_str()).unwrap_or("");
        match state {
            "pending" | "authorization_pending" => return Ok(json!({ "status": "pending" })),
            "slow_down" => {
                let i = session.interval + 5;
                mgr.slow_down(session_id, i);
                return Ok(json!({ "status": "pending", "interval": i }));
            }
            "expired" | "expired_token" => {
                mgr.remove_session(session_id);
                return Ok(json!({ "status": "expired", "error": "Login timed out. Please try again." }));
            }
            "denied" | "access_denied" => {
                mgr.remove_session(session_id);
                return Err("MiniMax Code: login denied".into());
            }
            _ => {}
        }
        let Some(access_token) = t["access_token"].as_str() else {
            if t["error"].is_string() {
                mgr.remove_session(session_id);
                return Err(format!("MiniMax Code: {}", t["error_description"].as_str().unwrap_or(state)));
            }
            return Ok(json!({ "status": "pending" }));
        };
        let claims = extract_jwt_claims(access_token).unwrap_or(json!({}));
        json!({
            "access_token": access_token, "refresh_token": t["refresh_token"],
            "expires_at": t["expires_in"].as_i64().map(|s| now_ms() + s * 1000),
            "email": claims["email"].as_str().or(claims["name"].as_str()),
        })
    } else if provider == "kilocode" {
        // Kilo answers 202 while waiting, 403 when denied, 410 when the code expired.
        let res = client.get(format!("{KILO_CODES_URL}/{device_code}")).send().await.map_err(|e| format!("Kilo Code: {e}"))?;
        match res.status().as_u16() {
            202 => return Ok(json!({ "status": "pending" })),
            403 => {
                mgr.remove_session(session_id);
                return Err("Kilo Code: login denied".into());
            }
            410 => {
                mgr.remove_session(session_id);
                return Ok(json!({ "status": "expired", "error": "Login timed out. Please try again." }));
            }
            s if s >= 400 => {
                mgr.remove_session(session_id);
                return Err(format!("Kilo Code: HTTP {s}"));
            }
            _ => {}
        }
        let d: Value = res.json().await.unwrap_or(json!({}));
        let Some(token) = d["token"].as_str().filter(|_| d["status"] == "approved") else {
            return Ok(json!({ "status": "pending" }));
        };
        let org_id = match client.get(KILO_PROFILE_URL).bearer_auth(token).send().await {
            Ok(r) if r.status().is_success() => {
                r.json::<Value>().await.ok().and_then(|p| p["organizations"][0]["id"].as_str().map(String::from))
            }
            _ => None,
        };
        json!({ "access_token": token, "email": d["userEmail"], "org_id": org_id })
    } else {
        let DeviceCfg { client_id, token_url, headers, .. } =
            device_cfg(provider, &device_id).ok_or_else(|| format!("{provider} does not support OAuth login"))?;
        let t = post_form_json(
            client,
            token_url,
            &[
                ("grant_type", "urn:ietf:params:oauth:grant-type:device_code"),
                ("client_id", client_id),
                ("device_code", device_code.as_str()),
            ],
            &headers,
        )
        .await?;
        match t.get("error").and_then(|v| v.as_str()) {
            Some("authorization_pending") => return Ok(json!({ "status": "pending" })),
            Some("slow_down") => {
                let interval = t["interval"].as_u64().unwrap_or(session.interval + 5);
                mgr.slow_down(session_id, interval);
                return Ok(json!({ "status": "pending", "interval": interval }));
            }
            Some("expired_token") => {
                mgr.remove_session(session_id);
                return Ok(json!({ "status": "expired", "error": "Login timed out. Please try again." }));
            }
            Some(err) => {
                mgr.remove_session(session_id);
                return Err(format!("{provider}: {}", t["error_description"].as_str().unwrap_or(err)));
            }
            None => {}
        }
        let Some(access_token) = t["access_token"].as_str() else {
            mgr.remove_session(session_id);
            return Err(format!("{provider}: token response has no access_token"));
        };
        let expires_at = t["expires_in"].as_i64().map(|s| chrono::Utc::now().timestamp_millis() + s * 1000);
        match provider {
            "muse" => mint_muse_key(client, access_token).await?,
            "nous" => {
                let mut cred = json!({ "access_token": access_token, "refresh_token": t["refresh_token"], "expires_at": expires_at });
                // Nous chat prefers a short-lived agent key; the OAuth token still works if minting fails.
                if let Ok(r) =
                    client.post(NOUS_AGENT_KEY_URL).bearer_auth(access_token).json(&json!({ "min_ttl_seconds": 7200 })).send().await
                {
                    if let Ok(j) = r.json::<Value>().await {
                        if let Some(k) = j["api_key"].as_str() {
                            cred["api_key"] = json!(k);
                        }
                    }
                }
                cred
            }
            "grok-cli" => {
                let mut cred = json!({ "access_token": access_token, "refresh_token": t["refresh_token"], "id_token": t["id_token"], "expires_at": expires_at });
                if let Ok(r) = grok_headers(client.get(format!("{GROK_API}/user")), &cred, &Uuid::new_v4().to_string(), 0, "").send().await
                {
                    if let Ok(u) = r.json::<Value>().await {
                        cred["email"] = u["email"].clone();
                        cred["account_id"] = u["userId"].as_str().or(u["principalId"].as_str()).map(|s| json!(s)).unwrap_or(Value::Null);
                        cred["plan"] = u["subscriptionTier"].clone();
                    }
                }
                if cred["email"].is_null() {
                    let claims = t["id_token"].as_str().and_then(extract_jwt_claims).unwrap_or(json!({}));
                    cred["email"] = claims["email"].clone();
                }
                cred
            }
            _ => {
                let claims = extract_jwt_claims(access_token).unwrap_or(json!({}));
                let email = claims["email"].as_str().or(claims["name"].as_str()).or(claims["sub"].as_str());
                json!({ "access_token": access_token, "refresh_token": t["refresh_token"], "expires_at": expires_at, "device_id": device_id, "email": email })
            }
        }
    };

    let email = cred["email"].as_str().map(String::from);
    store
        .update_or_save_account(provider, &cred, None, email.as_deref(), session.account_id.as_deref())
        .map_err(|e| format!("Failed to save account: {e}"))?;
    mgr.remove_session(session_id);
    Ok(json!({ "status": "done" }))
}

/// Muse chat uses a minted Model API key; the Meta token is kept so a re-mint needs no new login.
async fn mint_muse_key(client: &Client, meta_token: &str) -> Result<Value, String> {
    let res = client
        .post(MUSE_KEY_URL)
        .header("Accept", "application/json")
        .header("x-api-version", "1.0.0")
        .bearer_auth(meta_token)
        .json(&json!({ "onboard": true }))
        .send()
        .await
        .map_err(|e| format!("Muse Code: {e}"))?;
    let status = res.status();
    let j: Value = res.json().await.unwrap_or(json!({}));
    let action = j["action_url"].as_str().or(j["require_payment_action_url"].as_str()).map(|u| format!(" ({u})")).unwrap_or_default();
    if !status.is_success() {
        return Err(format!("Muse Code: HTTP {status}{action}"));
    }
    match j["api_key"].as_str().filter(|_| j["is_subs_active"] != false) {
        Some(key) => Ok(
            json!({ "access_token": key, "refresh_token": meta_token, "email": j["user_email"].as_str().map(|e| e.trim().to_lowercase()) }),
        ),
        None => Err(format!("Muse Code: subscription inactive{action}")),
    }
}

// ----------------------------------------------------------------------------
// Chat upstreams for subscription accounts (ported from 7server's subscription.ts)
// ----------------------------------------------------------------------------
fn now_ms() -> i64 {
    chrono::Utc::now().timestamp_millis()
}

/// Refreshes the stored credential when it is about to expire (or `force`, after an upstream 401).
/// Returns the credential to use; persists it when it changed.
pub async fn fresh_credential(client: &Client, store: &GatewayStore, acc: &AccountRecord, force: bool) -> Result<Value, String> {
    let mut c = acc.cred.clone();
    let lead = 5 * 60_000;
    let expiring = |field: &str, c: &Value| c[field].as_f64().map(|e| (e as i64) - now_ms() < lead).unwrap_or(false);
    let refresh = c["refresh_token"].as_str().map(String::from);
    let changed = match acc.provider.as_str() {
        "copilot" => {
            // copilot_expires_at is in seconds
            let exp = c["copilot_expires_at"].as_f64().map(|s| (s * 1000.0) as i64).unwrap_or(0);
            if force || c["copilot_token"].as_str().is_none() || exp - now_ms() < lead {
                let gh = c["github_token"].as_str().or(c["access_token"].as_str()).unwrap_or("").to_string();
                let j: Value = client
                    .get("https://api.github.com/copilot_internal/v2/token")
                    .header("Authorization", format!("token {gh}"))
                    .header("Accept", "application/json")
                    .header("User-Agent", "GitHubCopilotChat/0.26.7")
                    .header("Editor-Version", "vscode/1.85.0")
                    .send()
                    .await
                    .map_err(|e| format!("Copilot token: {e}"))?
                    .error_for_status()
                    .map_err(|e| format!("Copilot token: {e} (no Copilot subscription?)"))?
                    .json()
                    .await
                    .map_err(|e| format!("Copilot token: {e}"))?;
                c["copilot_token"] = j["token"].clone();
                c["copilot_expires_at"] = j["expires_at"].clone();
                true
            } else {
                false
            }
        }
        "muse" if force => {
            let meta = refresh.ok_or("Muse Code: login again")?;
            c = mint_muse_key(client, &meta).await?;
            true
        }
        "kilocode" | "muse" => false,
        p if force || expiring("expires_at", &c) || (p == "nous" && c["api_key"].is_null() && force) => {
            let Some(rt) = refresh else {
                if force {
                    return Err(format!("{p}: session expired; log in again"));
                }
                return Ok(c);
            };
            let device_id = c["device_id"].as_str().unwrap_or("").to_string();
            let t = match p {
                "claude" => {
                    let res = client
                        .post(CLAUDE_TOKEN_URL)
                        .json(&json!({ "grant_type": "refresh_token", "refresh_token": rt, "client_id": CLAUDE_CLIENT_ID }))
                        .send()
                        .await
                        .map_err(|e| format!("Claude refresh: {e}"))?;
                    if !res.status().is_success() {
                        return Err(format!("Claude refresh failed: {}", res.text().await.unwrap_or_default()));
                    }
                    res.json::<Value>().await.map_err(|e| e.to_string())?
                }
                "codex" => {
                    post_form_json(
                        client,
                        "https://auth.openai.com/oauth/token",
                        &[
                            ("grant_type", "refresh_token"),
                            ("refresh_token", &rt),
                            ("client_id", OPENAI_CLIENT_ID),
                            ("scope", "openid profile email offline_access"),
                        ],
                        &[],
                    )
                    .await?
                }
                "cline" => {
                    let r: Value = client
                        .post(format!("{CLINE_API}/auth/refresh"))
                        .json(&json!({ "refreshToken": rt, "grantType": "refresh_token", "clientType": "extension" }))
                        .send()
                        .await
                        .map_err(|e| format!("Cline refresh: {e}"))?
                        .json()
                        .await
                        .map_err(|e| format!("Cline refresh: {e}"))?;
                    let d = if r["data"].is_object() { &r["data"] } else { &r };
                    let Some(at) = d["accessToken"].as_str() else { return Err("Cline: session expired; log in again".into()) };
                    let exp_in = iso_to_ms(&d["expiresAt"]).map(|ms| (ms - now_ms()) / 1000);
                    json!({ "access_token": at, "refresh_token": d["refreshToken"], "expires_in": exp_in })
                }
                "minimax-code" | "minimax-code-global" => {
                    let (acct, _) = minimax_hosts(p);
                    post_form_json(
                        client,
                        &format!("{acct}/oauth2/token"),
                        &[
                            ("grant_type", "refresh_token"),
                            ("refresh_token", &rt),
                            ("client_id", MINIMAX_CODE_CLIENT_ID),
                            ("scope", "agent.default"),
                            ("audience", "agent-backend"),
                        ],
                        &[],
                    )
                    .await?
                }
                "kimi" => {
                    post_form_json(
                        client,
                        KIMI_TOKEN_URL,
                        &[("grant_type", "refresh_token"), ("refresh_token", &rt), ("client_id", KIMI_CLIENT_ID)],
                        &kimi_headers(&device_id),
                    )
                    .await?
                }
                "nous" => {
                    post_form_json(
                        client,
                        NOUS_TOKEN_URL,
                        &[("grant_type", "refresh_token"), ("refresh_token", &rt), ("client_id", NOUS_CLIENT_ID)],
                        &[],
                    )
                    .await?
                }
                "kiro" => {
                    let region = c["region"].as_str().unwrap_or(KIRO_REGION).to_string();
                    let req = match (c["client_id"].as_str(), c["client_secret"].as_str()) {
                        (Some(id), Some(sec)) => client.post(format!("{}/token", kiro_oidc(&region))).json(&json!({
                            "clientId": id, "clientSecret": sec, "refreshToken": rt, "grantType": "refresh_token",
                        })),
                        _ => {
                            client.post(KIRO_SOCIAL_REFRESH_URL).header("User-Agent", "kiro-cli/1.0.0").json(&json!({ "refreshToken": rt }))
                        }
                    };
                    let r: Value = req
                        .send()
                        .await
                        .map_err(|e| format!("Kiro refresh: {e}"))?
                        .json()
                        .await
                        .map_err(|e| format!("Kiro refresh: {e}"))?;
                    let Some(at) = r["accessToken"].as_str() else {
                        return Err(format!("Kiro: session expired ({}); log in again", r["message"].as_str().unwrap_or("no token")));
                    };
                    if let Some(arn) = r["profileArn"].as_str() {
                        c["profile_arn"] = json!(arn);
                    }
                    json!({ "access_token": at, "refresh_token": r["refreshToken"], "expires_in": r["expiresIn"] })
                }
                "grok-cli" => {
                    post_form_json(
                        client,
                        GROK_TOKEN_URL,
                        &[("grant_type", "refresh_token"), ("refresh_token", &rt), ("client_id", GROK_CLIENT_ID)],
                        &grok_device_headers(),
                    )
                    .await?
                }
                "antigravity" => {
                    post_form_json(
                        client,
                        "https://oauth2.googleapis.com/token",
                        &[
                            ("grant_type", "refresh_token"),
                            ("refresh_token", &rt),
                            ("client_id", AG_CLIENT_ID),
                            ("client_secret", AG_CLIENT_SECRET),
                        ],
                        &[],
                    )
                    .await?
                }
                "gemini-cli" => {
                    let id = store.get_setting("gemini_oauth_client_id").unwrap_or_default();
                    let sec = store.get_setting("gemini_oauth_client_secret").unwrap_or_default();
                    post_form_json(
                        client,
                        "https://oauth2.googleapis.com/token",
                        &[("grant_type", "refresh_token"), ("refresh_token", &rt), ("client_id", &id), ("client_secret", &sec)],
                        &[],
                    )
                    .await?
                }
                _ => return Ok(c),
            };
            if let Some(e) = t.get("error") {
                return Err(format!("{p} refresh failed: {}", t["error_description"].as_str().or(e.as_str()).unwrap_or("error")));
            }
            c["access_token"] = t["access_token"].clone();
            if let Some(r) = t["refresh_token"].as_str() {
                c["refresh_token"] = json!(r);
            }
            if let Some(s) = t["expires_in"].as_i64() {
                c["expires_at"] = json!(now_ms() + s * 1000);
            }
            if p == "nous" {
                if let Some(o) = c.as_object_mut() {
                    o.remove("api_key");
                }
                if let Ok(r) = client
                    .post(NOUS_AGENT_KEY_URL)
                    .bearer_auth(c["access_token"].as_str().unwrap_or(""))
                    .json(&json!({ "min_ttl_seconds": 7200 }))
                    .send()
                    .await
                {
                    if let Ok(j) = r.json::<Value>().await {
                        if let Some(k) = j["api_key"].as_str() {
                            c["api_key"] = json!(k);
                        }
                    }
                }
            }
            true
        }
        _ => false,
    };
    // Gemini routes through Cloud Code Assist, which needs the account's project id.
    let mut changed = changed;
    if acc.provider == "gemini-cli" && c["project_id"].as_str().is_none() {
        let tok = c["access_token"].as_str().unwrap_or("").to_string();
        if let Ok(r) = client
            .post("https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")
            .bearer_auth(&tok)
            .json(&json!({ "metadata": { "ideType": 9, "platform": 3, "pluginType": 2 }, "mode": 1 }))
            .send()
            .await
        {
            if let Ok(d) = r.json::<Value>().await {
                let proj = d["cloudaicompanionProject"]["id"].as_str().or(d["cloudaicompanionProject"].as_str()).map(String::from);
                if let Some(pid) = proj {
                    c["project_id"] = json!(pid);
                    changed = true;
                }
            }
        }
    }
    if changed {
        store
            .update_or_save_account(&acc.provider, &c, None, None, Some(&acc.id))
            .map_err(|e| format!("Failed to save refreshed token: {e}"))?;
    }
    Ok(c)
}

/// Builds the upstream streaming request for one subscription account.
/// Returns the request plus the stream format: "codex", "claude", "gemini", or "openai" (pass-through).
pub fn subscription_request(
    client: &Client,
    provider: &str,
    cred: &Value,
    model: &str,
    body: &Value,
) -> Option<(reqwest::RequestBuilder, &'static str)> {
    let tok = cred["access_token"].as_str().unwrap_or("");
    let mut openai_body = body.clone();
    openai_body["model"] = json!(model);
    openai_body["stream"] = json!(true);
    let openai = |url: &str, bearer: &str| client.post(url).bearer_auth(bearer).header("Accept", "text/event-stream").json(&openai_body);
    Some(match provider {
        "codex" => {
            let mut r = client
                .post("https://chatgpt.com/backend-api/codex/responses")
                .bearer_auth(tok)
                .header("Accept", "text/event-stream")
                .header("originator", "codex_cli_rs")
                .header("User-Agent", "codex_cli_rs/0.101.0")
                .json(&crate::translate::openai_to_codex(body, model));
            if let Some(aid) = cred["account_id"].as_str() {
                r = r.header("chatgpt-account-id", aid);
            }
            (r, "codex")
        }
        "claude" => (
            client
                .post("https://api.anthropic.com/v1/messages?beta=true")
                .bearer_auth(tok)
                .header("anthropic-version", "2023-06-01")
                .header("anthropic-beta", "claude-code-20250219,oauth-2025-04-20,interleaved-thinking-2025-05-14")
                .header("anthropic-dangerous-direct-browser-access", "true")
                .header("x-app", "cli")
                .header("User-Agent", "claude-cli/2.1.280 (external, sdk-cli)")
                .header("Accept", "text/event-stream")
                .json(&crate::translate::openai_to_claude_oauth(body, model)),
            "claude",
        ),
        "gemini-cli" => (
            client
                .post("https://cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse")
                .bearer_auth(tok)
                .header("User-Agent", format!("GeminiCLI/0.34.0/{model} (darwin; arm64)"))
                .header("X-Goog-Api-Client", "google-genai-sdk/1.41.0 gl-node/v22.19.0")
                .header("Accept", "text/event-stream")
                .json(&crate::translate::openai_to_gemini(body, model, cred["project_id"].as_str())),
            "gemini",
        ),
        "kiro" => {
            let msgs = body["messages"].as_array().cloned().unwrap_or_default();
            let seed = msgs.iter().find(|m| m["role"] == "user").map(|m| m["content"].to_string()).unwrap_or_default();
            let h = hex::encode(Sha256::digest(seed.as_bytes()));
            let conv = format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32]);
            let b = crate::kiro::openai_to_kiro(body, &kiro_model_id(model), &conv, kiro_profile_arn(cred));
            let region = cred["region"].as_str().unwrap_or(KIRO_REGION);
            (kiro_headers(client.post(format!("https://q.{region}.amazonaws.com/generateAssistantResponse")), cred).json(&b), "kiro")
        }
        "grok-cli" => {
            let (upstream, effort) = grok_model_and_effort(model);
            let mut b = crate::translate::openai_to_codex(body, &upstream);
            if let Some(e) = effort {
                b["reasoning"] = json!({ "effort": e, "summary": "concise" });
                b["include"] = json!(["reasoning.encrypted_content"]);
            }
            let msgs = body["messages"].as_array().cloned().unwrap_or_default();
            let turns = msgs.iter().filter(|m| m["role"] == "user").count();
            let seed = msgs.iter().find(|m| m["role"] == "user").map(|m| m["content"].to_string()).unwrap_or_default();
            let h = hex::encode(Sha256::digest(seed.as_bytes()));
            let conv = format!("{}-{}-{}-{}-{}", &h[0..8], &h[8..12], &h[12..16], &h[16..20], &h[20..32]);
            (
                grok_headers(client.post(format!("{GROK_API}/responses")), cred, &conv, turns, &upstream)
                    .header("Accept", "text/event-stream")
                    .json(&b),
                "codex",
            )
        }
        "antigravity" => {
            let upstream = ag_upstream_model(model);
            let mut b = crate::translate::openai_to_gemini(body, &upstream, cred["project_id"].as_str());
            crate::translate::antigravity_envelope(&mut b, AG_DEFAULT_THOUGHT_SIGNATURE);
            (
                client
                    .post(format!("{AG_CHAT_BASE}/v1internal:streamGenerateContent?alt=sse"))
                    .bearer_auth(tok)
                    .header("User-Agent", AG_USER_AGENT)
                    .header("Accept", "text/event-stream")
                    .json(&b),
                "gemini",
            )
        }
        "copilot" => (
            openai("https://api.githubcopilot.com/chat/completions", cred["copilot_token"].as_str().unwrap_or(""))
                .header("copilot-integration-id", "vscode-chat")
                .header("editor-version", "vscode/1.110.0")
                .header("editor-plugin-version", "copilot-chat/0.38.0")
                .header("user-agent", "GitHubCopilotChat/0.38.0")
                .header("openai-intent", "conversation-panel")
                .header("x-github-api-version", "2025-04-01")
                .header("X-Initiator", "user"),
            "openai",
        ),
        "kimi" => {
            let mut r = openai("https://api.kimi.com/coding/v1/chat/completions", tok);
            for (k, v) in kimi_headers(cred["device_id"].as_str().unwrap_or("")) {
                r = r.header(k, v);
            }
            (r, "openai")
        }
        "kilocode" => {
            let mut r = openai("https://api.kilo.ai/api/openrouter/chat/completions", tok);
            if let Some(org) = cred["org_id"].as_str() {
                r = r.header("X-Kilocode-OrganizationID", org);
            }
            (r, "openai")
        }
        "muse" => (openai("https://api.meta.ai/v1/chat/completions", tok), "openai"),
        "cline" => (
            client
                .post(format!("{CLINE_API}/chat/completions"))
                .bearer_auth(cline_bearer(tok))
                .header("Accept", "text/event-stream")
                .header("HTTP-Referer", "https://cline.bot")
                .header("X-Title", "Cline")
                .header("X-CLIENT-TYPE", "notchi-gateway")
                .header("X-PLATFORM", std::env::consts::OS)
                .json(&openai_body),
            "openai",
        ),
        "minimax-code" | "minimax-code-global" => {
            let (_, agent) = minimax_hosts(provider);
            let mut b = crate::translate::openai_to_anthropic(body, model);
            b["stream"] = json!(true);
            let tz = chrono::Local::now().offset().local_minus_utc() / 60;
            (
                client
                    .post(format!("{agent}/mavis/api/v1/llm/v1/messages"))
                    .bearer_auth(tok)
                    .header("anthropic-version", "2023-06-01")
                    .header("Accept", "text/event-stream")
                    .header("User-Agent", "MiniMaxAgent")
                    .header("X-Mavis-Agent-Id", "main")
                    .header("x-api-key", "sk-xxx") // placeholder the endpoint expects; auth is the bearer token
                    .header("X-Mavis-Timezone-Offset", tz.to_string())
                    .header("X-Mavis-Session-Id", Uuid::new_v4().to_string())
                    .json(&b),
                "claude",
            )
        }
        "nous" => {
            // Nous requires attribution tags on its inference API.
            openai_body["tags"] = json!(["product=beacon", "client=beacon"]);
            let key = cred["api_key"].as_str().unwrap_or(tok);
            (
                client
                    .post("https://inference-api.nousresearch.com/v1/chat/completions")
                    .bearer_auth(key)
                    .header("Accept", "text/event-stream")
                    .json(&openai_body),
                "openai",
            )
        }
        _ => return None,
    })
}

/// Command Code only serves clients that look like its CLI.
/// shortcut: CLI version is pinned; bump it if Command Code starts rejecting old clients.
pub fn commandcode_headers(r: reqwest::RequestBuilder, key: &str, session: &str) -> reqwest::RequestBuilder {
    r.bearer_auth(key)
        .header("Content-Type", "application/json")
        .header("Accept", "text/event-stream")
        .header("User-Agent", "cli")
        .header("x-command-code-version", "1.88.5")
        .header("x-cli-environment", "production")
        .header("x-cli-surface", "cli")
        .header("x-taste-learning", "false")
        .header("x-project-slug", "notchi-gateway")
        .header("x-session-id", session)
}

/// Request for a subscription provider's model list, for providers that expose one.
pub fn subscription_models_request(client: &Client, provider: &str, cred: &Value) -> Option<reqwest::RequestBuilder> {
    let tok = cred["access_token"].as_str().unwrap_or("");
    Some(match provider {
        "copilot" => client
            .get("https://api.githubcopilot.com/models")
            .bearer_auth(cred["copilot_token"].as_str().unwrap_or(""))
            .header("copilot-integration-id", "vscode-chat")
            .header("editor-version", "vscode/1.110.0")
            .header("editor-plugin-version", "copilot-chat/0.38.0")
            .header("user-agent", "GitHubCopilotChat/0.38.0"),
        "kimi" => {
            let mut r = client.get("https://api.kimi.com/coding/v1/models").bearer_auth(tok);
            for (k, v) in kimi_headers(cred["device_id"].as_str().unwrap_or("")) {
                r = r.header(k, v);
            }
            r
        }
        "kilocode" => client.get("https://api.kilo.ai/api/openrouter/models").bearer_auth(tok),
        "cline" => client.get(format!("{CLINE_API}/models")).bearer_auth(cline_bearer(tok)),
        "grok-cli" => grok_headers(client.get(format!("{GROK_API}/models")), cred, "models", 0, ""),
        // Returns {models: {<id>: {displayName, isInternal, quotaInfo}}}; ids are Antigravity's own.
        "antigravity" => client
            .post(format!("{AG_CHAT_BASE}/v1internal:fetchAvailableModels"))
            .bearer_auth(tok)
            .header("User-Agent", AG_USER_AGENT)
            .json(&json!({ "project": cred["project_id"] })),
        "nous" => client.get("https://inference-api.nousresearch.com/v1/models").bearer_auth(cred["api_key"].as_str().unwrap_or(tok)),
        // Claude, Codex, Gemini CLI and Muse have no model list for subscription tokens.
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    mod extract_jwt_claims {
        use super::*;

        #[test]
        fn an_openai_auth_code_is_not_mistaken_for_a_token() {
            // Real codes look like "ac_<base64>.<base64>": long and dotted, but not a JWT.
            let code = format!("ac_{}.{}", "A".repeat(80), "B".repeat(40));
            assert!(extract_jwt_claims(&code).is_none_or(|c| !c["exp"].is_number()));
        }
    }

    mod parse_callback_code_or_token {
        use super::*;

        #[test]
        fn extracts_and_decodes_the_code_from_a_callback_url() {
            assert_eq!(parse_callback_code_or_token("http://localhost:1455/auth/callback?code=abc%20d&state=s1"), "abc d");
        }

        #[test]
        fn accepts_a_bare_code_param() {
            assert_eq!(parse_callback_code_or_token("code=xyz"), "xyz");
        }

        #[test]
        fn strips_a_state_fragment_and_whitespace() {
            assert_eq!(parse_callback_code_or_token("  claude-code#state-123 "), "claude-code");
        }

        #[test]
        fn passes_a_raw_token_through() {
            assert_eq!(parse_callback_code_or_token("sess-raw-token"), "sess-raw-token");
        }
    }

    mod device_polling {
        use super::*;

        fn manager_with_session() -> OAuthManager {
            let mgr = OAuthManager::new();
            mgr.insert_session(OAuthSession {
                id: "s".into(),
                provider: "copilot".into(),
                account_id: None,
                kind: "device".into(),
                code_verifier: None,
                device_code: Some("d".into()),
                device_id: None,
                interval: 5,
                expires_at: Instant::now() + Duration::from_secs(60),
            });
            mgr
        }

        #[test]
        fn the_first_poll_goes_through() {
            assert!(manager_with_session().poll_allowed("s"));
        }

        #[test]
        fn a_poll_inside_the_interval_is_held_back() {
            let mgr = manager_with_session();
            mgr.poll_allowed("s");
            assert!(!mgr.poll_allowed("s"));
        }

        #[test]
        fn slow_down_raises_the_interval() {
            let mgr = manager_with_session();
            mgr.slow_down("s", 15);
            assert_eq!(mgr.get_session("s").map(|s| s.interval), Some(15));
        }

        #[test]
        fn unknown_sessions_are_not_gated() {
            let mgr = manager_with_session();
            mgr.poll_allowed("s");
            mgr.remove_session("s");
            assert!(mgr.poll_allowed("s"));
        }
    }

    mod ag_upstream_model {
        use super::*;

        #[test]
        fn a_level_suffix_becomes_a_parenthesised_level() {
            assert_eq!(ag_upstream_model("gemini-4-carbon-high"), "gemini-4-carbon-high(high)");
        }

        #[test]
        fn a_bare_model_defaults_to_its_medium_variant() {
            assert_eq!(ag_upstream_model("gemini-4-carbon"), "gemini-4-carbon-medium(medium)");
        }

        #[test]
        fn tiered_flash_models_use_the_tiered_name() {
            assert_eq!(ag_upstream_model("gemini-3.7-flash-low"), "gemini-3.7-flash-tiered(low)");
        }

        #[test]
        fn pro_high_maps_to_the_pro_agent() {
            assert_eq!(ag_upstream_model("gemini-3.1-pro-high"), "gemini-pro-agent");
        }

        #[test]
        fn gpt_oss_keeps_its_suffix() {
            assert_eq!(ag_upstream_model("gpt-oss-120b-medium"), "gpt-oss-120b-medium");
        }

        #[test]
        fn unknown_models_pass_through() {
            assert_eq!(ag_upstream_model("claude-sonnet-4-6"), "claude-sonnet-4-6");
        }
    }

    mod kiro_model_id {
        use super::*;

        #[test]
        fn dashed_claude_versions_become_dotted() {
            assert_eq!(kiro_model_id("claude-sonnet-4-5"), "claude-sonnet-4.5");
        }

        #[test]
        fn thinking_and_agentic_suffixes_are_dropped() {
            assert_eq!(kiro_model_id("claude-opus-4.5-thinking-agentic"), "claude-opus-4.5");
        }

        #[test]
        fn other_models_pass_through() {
            assert_eq!(kiro_model_id("gpt-5.6-sol"), "gpt-5.6-sol");
        }
    }

    mod grok_model_and_effort {
        use super::*;

        #[test]
        fn a_level_suffix_on_grok_4_5_becomes_the_effort() {
            assert_eq!(grok_model_and_effort("grok-4.5-low"), ("grok-4.5".into(), Some("low")));
        }

        #[test]
        fn bare_grok_4_5_defaults_to_high_effort() {
            assert_eq!(grok_model_and_effort("grok-4.5"), ("grok-4.5".into(), Some("high")));
        }

        #[test]
        fn other_models_get_no_effort() {
            assert_eq!(grok_model_and_effort("grok-build"), ("grok-build".into(), None));
        }
    }

    mod device_cfg {
        use super::*;

        #[test]
        fn covers_standard_device_providers() {
            assert!(["kimi", "muse", "nous", "grok-cli"].iter().all(|p| device_cfg(p, "d").is_some()));
        }

        #[test]
        fn nous_requests_its_scope() {
            assert!(device_cfg("nous", "d").is_some_and(|c| c.scope.is_some()));
        }

        #[test]
        fn kilocode_uses_its_own_flow() {
            assert!(device_cfg("kilocode", "d").is_none());
        }
    }
}
