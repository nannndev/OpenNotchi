use crate::cipher::Cipher;
use parking_lot::Mutex;
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

pub const KEY_PREFIX: &str = "gw-sk-";

pub fn now() -> f64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0)
}

pub fn hash_key(secret: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(secret.as_bytes());
    hex::encode(hasher.finalize())
}

/// Runs a read query; a broken database logs and yields no rows instead of panicking.
fn query_rows<T, P: rusqlite::Params>(
    conn: &Connection,
    sql: &str,
    params: P,
    map: impl FnMut(&rusqlite::Row<'_>) -> rusqlite::Result<T>,
) -> Vec<T> {
    let run = || -> rusqlite::Result<Vec<T>> {
        let mut stmt = conn.prepare(sql)?;
        // Skip individual rows that fail to decode, as before.
        let rows = stmt.query_map(params, map)?.flatten().collect();
        Ok(rows)
    };
    run().unwrap_or_else(|e| {
        tracing::warn!("[gateway db] query failed: {e}");
        Vec::new()
    })
}

/// One row of the request log.
pub struct UsageEntry<'a> {
    pub key_id: Option<&'a str>,
    pub key_name: Option<&'a str>,
    pub provider: Option<&'a str>,
    pub model: Option<&'a str>,
    pub input_tokens: i64,
    pub output_tokens: i64,
    pub duration_ms: i64,
    /// "success" or "error".
    pub status: &'a str,
    pub status_code: i64,
    pub error: Option<&'a str>,
    pub streaming: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountRecord {
    pub id: String,
    pub provider: String,
    pub label: Option<String>,
    pub email: Option<String>,
    pub connected_at: f64,
    pub refreshed_at: Option<f64>,
    pub last_error: Option<String>,
    pub sort_order: i64,
    pub enabled: bool,
    pub cred: Value,
}

impl AccountRecord {
    pub fn detect_plan(&self) -> String {
        if self.provider == "codex" {
            if let Some(p) = self.cred.get("plan").and_then(|v| v.as_str()) {
                if !p.is_empty() {
                    return p.to_lowercase();
                }
            }
            if let Some(token) = self.cred.get("access_token").and_then(|t| t.as_str()) {
                let parts: Vec<&str> = token.split('.').collect();
                if parts.len() >= 2 {
                    let decoded_res = base64::Engine::decode(&base64::engine::general_purpose::URL_SAFE_NO_PAD, parts[1])
                        .or_else(|_| base64::Engine::decode(&base64::engine::general_purpose::URL_SAFE, parts[1]));
                    if let Ok(decoded) = decoded_res {
                        if let Ok(claims) = serde_json::from_slice::<Value>(&decoded) {
                            if let Some(plan) =
                                claims.get("https://api.openai.com/auth").and_then(|a| a.get("chatgpt_plan_type")).and_then(|p| p.as_str())
                            {
                                return plan.to_lowercase();
                            }
                        }
                    }
                }
            }
        }
        if let Some(p) = self.cred.get("plan").and_then(|v| v.as_str()) {
            return p.to_lowercase();
        }
        "free".to_string()
    }

    pub fn is_free(&self) -> bool {
        let plan = self.detect_plan();
        plan == "free" || plan == "none" || plan.is_empty()
    }

    pub fn display_plan(&self) -> String {
        match self.detect_plan().as_str() {
            "free" => "Free".to_string(),
            "plus" => "Plus".to_string(),
            "pro" => "Pro".to_string(),
            "team" => "Team".to_string(),
            "business" => "Business".to_string(),
            "enterprise" => "Enterprise".to_string(),
            other => {
                if other.is_empty() {
                    "Free".to_string()
                } else {
                    let mut c = other.chars();
                    match c.next() {
                        None => String::new(),
                        Some(f) => f.to_uppercase().collect::<String>() + c.as_str(),
                    }
                }
            }
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderRecord {
    pub id: String,
    pub enabled: bool,
    pub base_url: Option<String>,
    pub default_model: Option<String>,
    pub models: Vec<String>,
    pub verified_at: Option<f64>,
    pub latency_ms: Option<i64>,
    pub error: Option<String>,
    pub has_key: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VirtualKeyRecord {
    pub id: String,
    pub name: String,
    pub key_prefix: String,
    pub enabled: bool,
    pub allowed_providers: Option<Vec<String>>,
    pub rate_limit_per_min: Option<i64>,
    pub created_at: f64,
    pub last_used_at: Option<f64>,
    pub total_requests: i64,
    pub total_input_tokens: i64,
    pub total_output_tokens: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GatewaySettings {
    /// "priority" (ordered fallback), "round_robin", or "fill_first" (sticky until it fails).
    pub routing_strategy: String,
    /// "model_first": try a model on every account before the next model; "account_first": the reverse.
    pub fallback_order: String,
    /// Provider ids in the order `auto` tries them; unlisted connected providers follow alphabetically.
    pub provider_priority: Vec<String>,
    /// How many models per API-key provider `auto` tries (its custom models first, then seeds).
    pub auto_models_per_provider: usize,
    /// Seconds an account/provider is skipped after a rate limit or quota error.
    pub cooldown_secs: u64,
    pub gemini_oauth_client_id: String,
    pub gemini_oauth_client_secret_masked: Option<String>,
    pub gemini_oauth_configured: bool,
}

#[derive(Clone)]
pub struct GatewayStore {
    conn: Arc<Mutex<Connection>>,
    /// In-memory "skip until" unix times, keyed by account id or "apikey:<provider>".
    cooldowns: Arc<Mutex<HashMap<String, f64>>>,
    pub cipher: Cipher,
    pub directory: PathBuf,
}

impl GatewayStore {
    pub fn new<P: AsRef<Path>>(directory: P) -> Result<Self, String> {
        let dir = directory.as_ref();
        let _ = fs::create_dir_all(dir);
        let db_path = dir.join("gateway.db");
        let conn = Connection::open(&db_path).map_err(|e| format!("Failed to open gateway.db: {}", e))?;

        let cipher = Cipher::new(dir)?;
        let store = Self { conn: Arc::new(Mutex::new(conn)), cooldowns: Default::default(), cipher, directory: dir.to_path_buf() };
        store.init_tables()?;
        Ok(store)
    }

    fn init_tables(&self) -> Result<(), String> {
        let conn = self.conn.lock();
        conn.execute_batch(
            r#"
            CREATE TABLE IF NOT EXISTS keys (
              id TEXT PRIMARY KEY, name TEXT NOT NULL, key_hash TEXT NOT NULL UNIQUE,
              key_prefix TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1,
              allowed_providers TEXT, rate_limit_per_min INTEGER,
              created_at REAL NOT NULL, last_used_at REAL,
              total_requests INTEGER NOT NULL DEFAULT 0,
              total_input_tokens INTEGER NOT NULL DEFAULT 0,
              total_output_tokens INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS providers (
              id TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 1,
              api_key TEXT, base_url TEXT, default_model TEXT, models TEXT,
              verified_at REAL, latency_ms INTEGER, error TEXT
            );
            CREATE TABLE IF NOT EXISTS combos (name TEXT PRIMARY KEY, targets TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS usage (
              id TEXT PRIMARY KEY, ts REAL NOT NULL, key_id TEXT, key_name TEXT,
              provider TEXT, model TEXT, input_tokens INTEGER, output_tokens INTEGER,
              duration_ms INTEGER, status TEXT, status_code INTEGER, error TEXT, streaming INTEGER
            );
            CREATE INDEX IF NOT EXISTS usage_ts ON usage(ts);
            CREATE TABLE IF NOT EXISTS accounts (
              id TEXT PRIMARY KEY, provider TEXT NOT NULL, label TEXT, email TEXT,
              connected_at REAL NOT NULL, refreshed_at REAL, last_error TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0, enabled INTEGER NOT NULL DEFAULT 1,
              secret TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS accounts_provider ON accounts(provider, sort_order);
            CREATE TABLE IF NOT EXISTS settings (
              key TEXT PRIMARY KEY, value TEXT NOT NULL
            );
            "#,
        )
        .map_err(|e| format!("Failed to init gateway schema: {}", e))?;
        // Safe migration for existing gateway.db files created before `enabled` existed.
        let _ = conn.execute("ALTER TABLE accounts ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1", []);
        // Model lists fetched from each provider's /models endpoint.
        let _ = conn.execute("ALTER TABLE providers ADD COLUMN synced_models TEXT", []);
        let _ = conn.execute("ALTER TABLE providers ADD COLUMN models_synced_at REAL", []);
        Ok(())
    }

    // ---- Accounts (OAuth) -------------------------------------------
    pub fn list_accounts(&self) -> Vec<AccountRecord> {
        let conn = self.conn.lock();
        let rows = query_rows(&conn, "SELECT id, provider, label, email, connected_at, refreshed_at, last_error, sort_order, secret, enabled FROM accounts ORDER BY provider, sort_order, connected_at", [], |row| {
                let id: String = row.get(0)?;
                let provider: String = row.get(1)?;
                let label: Option<String> = row.get(2)?;
                let email: Option<String> = row.get(3)?;
                let connected_at: f64 = row.get(4)?;
                let refreshed_at: Option<f64> = row.get(5)?;
                let last_error: Option<String> = row.get(6)?;
                let sort_order: i64 = row.get(7)?;
                let secret: String = row.get(8)?;
                let enabled: bool = row.get::<_, i64>(9).map(|v| v != 0).unwrap_or(true);
                Ok((id, provider, label, email, connected_at, refreshed_at, last_error, sort_order, secret, enabled))
            });

        let mut out = Vec::new();
        for item in rows {
            let (id, provider, label, email, connected_at, refreshed_at, last_error, sort_order, secret, enabled) = item;
            let cred = if let Ok(dec) = self.cipher.decrypt(&secret) {
                serde_json::from_str::<Value>(&dec).unwrap_or(json!({}))
            } else {
                json!({})
            };
            out.push(AccountRecord { id, provider, label, email, connected_at, refreshed_at, last_error, sort_order, enabled, cred });
        }
        out
    }

    pub fn get_settings(&self) -> GatewaySettings {
        self.get_gateway_settings()
    }

    pub fn save_account(&self, provider: &str, cred: &Value, label: Option<&str>, email: Option<&str>) -> Result<String, String> {
        self.update_or_save_account(provider, cred, label, email, None)
    }

    pub fn update_or_save_account(
        &self,
        provider: &str,
        cred: &Value,
        label: Option<&str>,
        email: Option<&str>,
        target_account_id: Option<&str>,
    ) -> Result<String, String> {
        let cred_str = serde_json::to_string(cred).map_err(|e| e.to_string())?;
        let encrypted = self.cipher.encrypt(&cred_str)?;
        let conn = self.conn.lock();

        // 1. If target_account_id provided, update that specific record
        if let Some(target_id) = target_account_id {
            let updated = conn.execute(
                "UPDATE accounts SET secret = ?1, email = coalesce(?2, email), label = coalesce(?3, label), refreshed_at = ?4, last_error = NULL WHERE id = ?5",
                params![encrypted, email, label, now(), target_id],
            ).unwrap_or(0);
            if updated > 0 {
                return Ok(target_id.to_string());
            }
        }

        // 2. If same email already exists for this provider, update it instead of duplicating
        if let Some(em) = email {
            let mut stmt = conn.prepare("SELECT id FROM accounts WHERE provider = ?1 AND email = ?2 LIMIT 1").map_err(|e| e.to_string())?;
            let existing_id: Option<String> = stmt.query_row(params![provider, em], |r| r.get(0)).ok();
            if let Some(eid) = existing_id {
                let _ = conn.execute(
                    "UPDATE accounts SET secret = ?1, label = coalesce(?2, label), refreshed_at = ?3, last_error = NULL WHERE id = ?4",
                    params![encrypted, label, now(), eid],
                );
                return Ok(eid);
            }
        }

        // 3. Otherwise insert fresh account
        let id = format!("{}:{}", provider, &Uuid::new_v4().to_string()[..8]);
        conn.execute(
            "INSERT INTO accounts (id, provider, label, email, connected_at, secret) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![id, provider, label, email, now(), encrypted],
        )
        .map_err(|e| format!("Failed to insert account: {}", e))?;
        Ok(id)
    }

    pub fn record_account_error(&self, id: &str, err: Option<&str>) -> Result<(), String> {
        let conn = self.conn.lock();
        conn.execute("UPDATE accounts SET last_error = ?1 WHERE id = ?2", params![err, id]).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn remove_account(&self, provider: &str, account_id: Option<&str>) -> Result<bool, String> {
        let conn = self.conn.lock();
        let rows = if let Some(id) = account_id {
            conn.execute("DELETE FROM accounts WHERE provider = ?1 AND id = ?2", params![provider, id])
        } else {
            conn.execute("DELETE FROM accounts WHERE provider = ?1", params![provider])
        }
        .map_err(|e| e.to_string())?;
        Ok(rows > 0)
    }

    // ---- Providers (API Keys) ---------------------------------------
    pub fn list_providers(&self) -> Vec<ProviderRecord> {
        let conn = self.conn.lock();
        query_rows(
            &conn,
            "SELECT id, enabled, api_key, base_url, default_model, models, verified_at, latency_ms, error FROM providers",
            [],
            |row| {
                let id: String = row.get(0)?;
                let enabled: bool = row.get(1)?;
                let api_key: Option<String> = row.get(2)?;
                let base_url: Option<String> = row.get(3)?;
                let default_model: Option<String> = row.get(4)?;
                let models_json: Option<String> = row.get(5)?;
                let verified_at: Option<f64> = row.get(6)?;
                let latency_ms: Option<i64> = row.get(7)?;
                let error: Option<String> = row.get(8)?;

                let models = models_json.and_then(|j| serde_json::from_str::<Vec<String>>(&j).ok()).unwrap_or_default();

                Ok(ProviderRecord {
                    id,
                    enabled,
                    base_url,
                    default_model,
                    models,
                    verified_at,
                    latency_ms,
                    error,
                    has_key: api_key.is_some_and(|k| !k.is_empty()),
                })
            },
        )
    }

    pub fn save_provider_key(&self, provider_id: &str, raw_key: &str) -> Result<(), String> {
        let encrypted = self.cipher.encrypt(raw_key)?;
        let conn = self.conn.lock();
        conn.execute(
            r#"
            INSERT INTO providers (id, api_key, enabled) VALUES (?1, ?2, 1)
            ON CONFLICT(id) DO UPDATE SET api_key = ?2, enabled = 1
            "#,
            params![provider_id, encrypted],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn get_provider_key(&self, provider_id: &str) -> Option<String> {
        let conn = self.conn.lock();
        let mut stmt = conn.prepare("SELECT api_key FROM providers WHERE id = ?1").ok()?;
        let enc: Option<String> = stmt.query_row(params![provider_id], |r| r.get(0)).ok()?;
        enc.and_then(|blob| self.cipher.decrypt(&blob).ok())
    }

    pub fn get_provider_record(&self, provider_id: &str) -> Option<ProviderRecord> {
        let conn = self.conn.lock();
        let mut stmt = conn
            .prepare(
                "SELECT id, enabled, api_key, base_url, default_model, models, verified_at, latency_ms, error FROM providers WHERE id = ?1",
            )
            .ok()?;
        stmt.query_row(params![provider_id], |row| {
            let id: String = row.get(0)?;
            let enabled: bool = row.get(1)?;
            let api_key: Option<String> = row.get(2)?;
            let base_url: Option<String> = row.get(3)?;
            let default_model: Option<String> = row.get(4)?;
            let models_json: Option<String> = row.get(5)?;
            let verified_at: Option<f64> = row.get(6)?;
            let latency_ms: Option<i64> = row.get(7)?;
            let error: Option<String> = row.get(8)?;

            let models = models_json.and_then(|j| serde_json::from_str::<Vec<String>>(&j).ok()).unwrap_or_default();

            Ok(ProviderRecord {
                id,
                enabled,
                base_url,
                default_model,
                models,
                verified_at,
                latency_ms,
                error,
                has_key: api_key.is_some_and(|k| !k.is_empty()),
            })
        })
        .ok()
    }

    pub fn set_provider_verification(&self, provider_id: &str, latency_ms: Option<i64>, error: Option<&str>) -> Result<(), String> {
        let conn = self.conn.lock();
        conn.execute(
            "UPDATE providers SET latency_ms = ?1, error = ?2, verified_at = ?3 WHERE id = ?4",
            params![latency_ms, error, now(), provider_id],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn set_synced_models(&self, provider_id: &str, models: &[String]) -> Result<(), String> {
        let json_str = serde_json::to_string(models).map_err(|e| e.to_string())?;
        let conn = self.conn.lock();
        conn.execute(
            r#"
            INSERT INTO providers (id, enabled, synced_models, models_synced_at) VALUES (?1, 1, ?2, ?3)
            ON CONFLICT(id) DO UPDATE SET synced_models = ?2, models_synced_at = ?3
            "#,
            params![provider_id, json_str, now()],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    }

    /// Models last fetched from the provider (empty if never synced) and when.
    pub fn get_synced_models(&self, provider_id: &str) -> (Vec<String>, Option<f64>) {
        let conn = self.conn.lock();
        conn.query_row("SELECT synced_models, models_synced_at FROM providers WHERE id = ?1", params![provider_id], |r| {
            Ok((r.get::<_, Option<String>>(0)?, r.get::<_, Option<f64>>(1)?))
        })
        .map(|(j, at)| (j.and_then(|j| serde_json::from_str(&j).ok()).unwrap_or_default(), at))
        .unwrap_or_default()
    }

    /// What pickers show: the user's custom models, then the provider's live list
    /// (or the built-in seeds when it was never synced).
    pub fn display_models(&self, provider_id: &str, seed: &[&str]) -> Vec<String> {
        let mut out = self.get_provider_custom_models(provider_id);
        let (synced, _) = self.get_synced_models(provider_id);
        let base: Vec<String> = if synced.is_empty() { seed.iter().map(|s| s.to_string()).collect() } else { synced };
        for m in base {
            if !out.contains(&m) {
                out.push(m);
            }
        }
        out
    }

    // ---- Combos -----------------------------------------------------
    pub fn list_combos(&self) -> HashMap<String, Vec<String>> {
        let conn = self.conn.lock();
        query_rows(&conn, "SELECT name, targets FROM combos", [], |row| {
            let name: String = row.get(0)?;
            let targets_json: String = row.get(1)?;
            let targets: Vec<String> = serde_json::from_str(&targets_json).unwrap_or_default();
            Ok((name, targets))
        })
        .into_iter()
        .collect()
    }

    pub fn save_combo(&self, name: &str, targets: &[String]) -> Result<(), String> {
        let targets_json = serde_json::to_string(targets).map_err(|e| e.to_string())?;
        let conn = self.conn.lock();
        conn.execute("INSERT OR REPLACE INTO combos (name, targets) VALUES (?1, ?2)", params![name, targets_json])
            .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn delete_combo(&self, name: &str) -> Result<bool, String> {
        let conn = self.conn.lock();
        let count = conn.execute("DELETE FROM combos WHERE name = ?1", params![name]).map_err(|e| e.to_string())?;
        Ok(count > 0)
    }

    // ---- Account Reordering ----------------------------------------
    pub fn reorder_accounts(&self, provider: &str, account_ids: &[String]) -> Result<(), String> {
        let conn = self.conn.lock();
        for (i, id) in account_ids.iter().enumerate() {
            let _ = conn.execute("UPDATE accounts SET sort_order = ?1 WHERE provider = ?2 AND id = ?3", params![i as i64, provider, id]);
        }
        Ok(())
    }

    // ---- Provider Connect / Disconnect -----------------------------
    pub fn connect_provider(&self, provider_id: &str, api_key: &str, base_url: Option<&str>) -> Result<(), String> {
        let encrypted = self.cipher.encrypt(api_key)?;
        let conn = self.conn.lock();
        conn.execute(
            r#"
            INSERT INTO providers (id, api_key, base_url, enabled, verified_at)
            VALUES (?1, ?2, ?3, 1, ?4)
            ON CONFLICT(id) DO UPDATE SET api_key = ?2, base_url = coalesce(?3, base_url), enabled = 1, verified_at = ?4
            "#,
            params![provider_id, encrypted, base_url, now()],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn disconnect_provider(&self, provider_id: &str) -> Result<(), String> {
        let conn = self.conn.lock();
        conn.execute(
            "UPDATE providers SET api_key = NULL, enabled = 0, synced_models = NULL, models_synced_at = NULL WHERE id = ?1",
            params![provider_id],
        )
        .map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn set_account_enabled(&self, provider: &str, account_id: &str, enabled: Option<bool>) -> Result<bool, String> {
        let conn = self.conn.lock();
        let current: i64 = conn
            .query_row("SELECT enabled FROM accounts WHERE provider = ?1 AND id = ?2", params![provider, account_id], |r| r.get(0))
            .map_err(|_| format!("Account '{}' for provider '{}' not found", account_id, provider))?;
        let next = enabled.unwrap_or(current == 0);
        conn.execute(
            "UPDATE accounts SET enabled = ?1 WHERE provider = ?2 AND id = ?3",
            params![if next { 1 } else { 0 }, provider, account_id],
        )
        .map_err(|e| e.to_string())?;
        Ok(next)
    }

    pub fn is_provider_enabled(&self, provider_id: &str) -> bool {
        let conn = self.conn.lock();
        conn.query_row("SELECT enabled FROM providers WHERE id = ?1", params![provider_id], |r| r.get::<_, i64>(0))
            .map(|v| v != 0)
            .unwrap_or(true)
    }

    pub fn set_provider_enabled(&self, provider_id: &str, enabled: Option<bool>) -> Result<bool, String> {
        let conn = self.conn.lock();
        let current: Option<i64> = conn.query_row("SELECT enabled FROM providers WHERE id = ?1", params![provider_id], |r| r.get(0)).ok();
        let next = enabled.unwrap_or_else(|| current.map(|v| v == 0).unwrap_or(false));
        let val = if next { 1 } else { 0 };
        conn.execute(
            r#"
            INSERT INTO providers (id, enabled) VALUES (?1, ?2)
            ON CONFLICT(id) DO UPDATE SET enabled = ?2
            "#,
            params![provider_id, val],
        )
        .map_err(|e| e.to_string())?;
        Ok(next)
    }

    pub fn get_provider_custom_models(&self, provider_id: &str) -> Vec<String> {
        let conn = self.conn.lock();
        let raw: Option<String> =
            conn.query_row("SELECT models FROM providers WHERE id = ?1", params![provider_id], |r| r.get(0)).ok().flatten();
        raw.and_then(|j| serde_json::from_str::<Vec<String>>(&j).ok()).unwrap_or_default()
    }

    pub fn set_provider_models(&self, provider_id: &str, models: &[String]) -> Result<Vec<String>, String> {
        let mut cleaned = Vec::new();
        for m in models {
            let trimmed = m.trim();
            if !trimmed.is_empty() && !cleaned.iter().any(|x| x == trimmed) {
                cleaned.push(trimmed.to_string());
            }
        }
        let json_str = serde_json::to_string(&cleaned).map_err(|e| e.to_string())?;
        let conn = self.conn.lock();
        conn.execute(
            r#"
            INSERT INTO providers (id, enabled, models) VALUES (?1, 1, ?2)
            ON CONFLICT(id) DO UPDATE SET models = ?2
            "#,
            params![provider_id, json_str],
        )
        .map_err(|e| e.to_string())?;
        Ok(cleaned)
    }

    pub fn add_provider_model(&self, provider_id: &str, model: &str) -> Result<Vec<String>, String> {
        let trimmed = model.trim();
        if trimmed.is_empty() {
            return Err("Model name cannot be empty".to_string());
        }
        let mut current = self.get_provider_custom_models(provider_id);
        if !current.iter().any(|m| m == trimmed) {
            current.push(trimmed.to_string());
        }
        self.set_provider_models(provider_id, &current)
    }

    pub fn remove_provider_model(&self, provider_id: &str, model: &str) -> Result<Vec<String>, String> {
        let target = model.trim();
        let mut current = self.get_provider_custom_models(provider_id);
        current.retain(|m| m != target);
        self.set_provider_models(provider_id, &current)
    }

    // ---- Virtual Keys ----------------------------------------------
    pub fn list_virtual_keys(&self) -> Vec<VirtualKeyRecord> {
        let conn = self.conn.lock();
        query_rows(&conn, "SELECT id, name, key_prefix, enabled, allowed_providers, rate_limit_per_min, created_at, last_used_at, total_requests, total_input_tokens, total_output_tokens FROM keys ORDER BY created_at DESC", [], |r| {
                let allowed_providers_json: Option<String> = r.get(4)?;
                let allowed_providers = allowed_providers_json.and_then(|j| serde_json::from_str(&j).ok());
                Ok(VirtualKeyRecord {
                    id: r.get(0)?,
                    name: r.get(1)?,
                    key_prefix: r.get(2)?,
                    enabled: r.get::<_, i64>(3)? != 0,
                    allowed_providers,
                    rate_limit_per_min: r.get(5)?,
                    created_at: r.get(6)?,
                    last_used_at: r.get(7)?,
                    total_requests: r.get(8)?,
                    total_input_tokens: r.get(9)?,
                    total_output_tokens: r.get(10)?,
                })
            })
    }

    pub fn create_virtual_key(
        &self,
        name: &str,
        allowed_providers: Option<Vec<String>>,
        rate_limit_per_min: Option<i64>,
    ) -> Result<(VirtualKeyRecord, String), String> {
        let id = Uuid::new_v4().to_string();
        let random_hex: String = (0..32).map(|_| format!("{:x}", rand::random::<u8>() % 16)).collect();
        let secret = format!("{}{}", KEY_PREFIX, random_hex);
        let key_hash = hash_key(&secret);
        let key_prefix = format!("{}...", &secret[..std::cmp::min(12, secret.len())]);
        let created_at = now();
        let allowed_json = allowed_providers.as_ref().and_then(|p| serde_json::to_string(p).ok());

        let conn = self.conn.lock();
        conn.execute(
            r#"
            INSERT INTO keys (id, name, key_hash, key_prefix, enabled, allowed_providers, rate_limit_per_min, created_at)
            VALUES (?1, ?2, ?3, ?4, 1, ?5, ?6, ?7)
            "#,
            params![id, name, key_hash, key_prefix, allowed_json, rate_limit_per_min, created_at],
        )
        .map_err(|e| e.to_string())?;

        let record = VirtualKeyRecord {
            id,
            name: name.to_string(),
            key_prefix,
            enabled: true,
            allowed_providers,
            rate_limit_per_min,
            created_at,
            last_used_at: None,
            total_requests: 0,
            total_input_tokens: 0,
            total_output_tokens: 0,
        };
        Ok((record, secret))
    }

    pub fn toggle_virtual_key(&self, id: &str) -> Result<VirtualKeyRecord, String> {
        let conn = self.conn.lock();
        conn.execute("UPDATE keys SET enabled = 1 - enabled WHERE id = ?1", params![id]).map_err(|e| e.to_string())?;
        drop(conn);
        self.list_virtual_keys().into_iter().find(|k| k.id == id).ok_or_else(|| "Key not found".to_string())
    }

    pub fn delete_virtual_key(&self, id: &str) -> Result<bool, String> {
        let conn = self.conn.lock();
        let rows = conn.execute("DELETE FROM keys WHERE id = ?1", params![id]).map_err(|e| e.to_string())?;
        Ok(rows > 0)
    }

    /// Looks up a virtual key by its plaintext secret.
    pub fn find_virtual_key(&self, secret: &str) -> Option<VirtualKeyRecord> {
        let id: String = {
            let conn = self.conn.lock();
            conn.query_row("SELECT id FROM keys WHERE key_hash = ?1", params![hash_key(secret)], |r| r.get(0)).ok()?
        };
        self.list_virtual_keys().into_iter().find(|k| k.id == id)
    }

    pub fn key_requests_since(&self, id: &str, since: f64) -> i64 {
        let conn = self.conn.lock();
        conn.query_row("SELECT COUNT(*) FROM usage WHERE key_id = ?1 AND ts >= ?2", params![id, since], |r| r.get(0)).unwrap_or(0)
    }

    pub fn touch_virtual_key(&self, id: &str, input_tokens: i64, output_tokens: i64) {
        let conn = self.conn.lock();
        let _ = conn.execute(
            "UPDATE keys SET last_used_at = ?1, total_requests = total_requests + 1, total_input_tokens = total_input_tokens + ?2, total_output_tokens = total_output_tokens + ?3 WHERE id = ?4",
            params![now(), input_tokens, output_tokens, id],
        );
    }

    // ---- Cooldowns -------------------------------------------------
    pub fn cool_down(&self, key: &str, secs: u64) {
        self.cooldowns.lock().insert(key.to_string(), now() + secs as f64);
    }

    pub fn clear_cooldown(&self, key: &str) {
        self.cooldowns.lock().remove(key);
    }

    pub fn cooling_until(&self, key: &str) -> Option<f64> {
        self.cooldowns.lock().get(key).copied().filter(|t| *t > now())
    }

    // ---- Settings --------------------------------------------------
    pub fn get_setting(&self, key: &str) -> Option<String> {
        let conn = self.conn.lock();
        let mut stmt = conn.prepare("SELECT value FROM settings WHERE key = ?1").ok()?;
        stmt.query_row(params![key], |r| r.get(0)).ok()
    }

    pub fn set_setting(&self, key: &str, value: &str) -> Result<(), String> {
        let conn = self.conn.lock();
        conn.execute("INSERT OR REPLACE INTO settings (key, value) VALUES (?1, ?2)", params![key, value]).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn get_gateway_settings(&self) -> GatewaySettings {
        let strategy = self.get_setting("routing_strategy").unwrap_or_default();
        let client_id = self.get_setting("gemini_oauth_client_id").unwrap_or_default();
        let client_secret = self.get_setting("gemini_oauth_client_secret");
        let secret_masked = client_secret.as_ref().filter(|s| !s.is_empty()).map(|s| {
            if s.len() > 4 {
                format!("••••{}", &s[s.len() - 4..])
            } else {
                "••••".to_string()
            }
        });
        let configured = !client_id.is_empty() && client_secret.is_some();
        let routing_strategy = match strategy.as_str() {
            "round_robin" | "fill_first" => strategy,
            _ => "priority".to_string(), // also maps the legacy "ordered"
        };
        GatewaySettings {
            routing_strategy,
            fallback_order: if self.get_setting("fallback_order").as_deref() == Some("account_first") {
                "account_first".into()
            } else {
                "model_first".into()
            },
            provider_priority: self.get_setting("provider_priority").and_then(|j| serde_json::from_str(&j).ok()).unwrap_or_default(),
            auto_models_per_provider: self
                .get_setting("auto_models_per_provider")
                .and_then(|v| v.parse().ok())
                .filter(|n| *n > 0)
                .unwrap_or(2),
            cooldown_secs: self.get_setting("cooldown_secs").and_then(|v| v.parse().ok()).unwrap_or(60),
            gemini_oauth_client_id: client_id,
            gemini_oauth_client_secret_masked: secret_masked,
            gemini_oauth_configured: configured,
        }
    }

    // ---- Usage & Stats ---------------------------------------------
    pub fn list_usage(&self, limit: i64) -> Vec<Value> {
        let conn = self.conn.lock();
        query_rows(&conn, "SELECT id, ts, key_id, key_name, provider, model, input_tokens, output_tokens, duration_ms, status, status_code, error, streaming FROM usage ORDER BY ts DESC LIMIT ?1", params![limit], |r| {
                Ok(json!({
                    "id": r.get::<_, String>(0)?,
                    "ts": r.get::<_, f64>(1)?,
                    "key_id": r.get::<_, Option<String>>(2)?,
                    "key_name": r.get::<_, Option<String>>(3)?,
                    "provider": r.get::<_, Option<String>>(4)?,
                    "model": r.get::<_, Option<String>>(5)?,
                    "input_tokens": r.get::<_, Option<i64>>(6)?.unwrap_or(0),
                    "output_tokens": r.get::<_, Option<i64>>(7)?.unwrap_or(0),
                    "duration_ms": r.get::<_, Option<i64>>(8)?.unwrap_or(0),
                    "status": r.get::<_, Option<String>>(9)?.unwrap_or_else(|| "success".to_string()),
                    "status_code": r.get::<_, Option<i64>>(10)?.unwrap_or(200),
                    "error": r.get::<_, Option<String>>(11)?,
                    "streaming": r.get::<_, Option<i64>>(12)?.unwrap_or(0) != 0,
                }))
            })
    }

    pub fn clear_usage(&self) -> Result<(), String> {
        let conn = self.conn.lock();
        conn.execute("DELETE FROM usage", []).map_err(|e| e.to_string())?;
        Ok(())
    }

    pub fn record_usage(&self, u: &UsageEntry<'_>) {
        let conn = self.conn.lock();
        let id = format!("usg_{}", uuid::Uuid::new_v4().simple());
        let _ = conn.execute(
            "INSERT INTO usage (id, ts, key_id, key_name, provider, model, input_tokens, output_tokens, duration_ms, status, status_code, error, streaming) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13)",
            params![
                id, now(), u.key_id, u.key_name, u.provider, u.model,
                u.input_tokens, u.output_tokens, u.duration_ms, u.status, u.status_code, u.error,
                i64::from(u.streaming)
            ],
        );
    }

    /// Tokens per provider per local day for the last `days` days (oldest first, today last).
    /// `utc_offset_secs` shifts unix time to the caller's local day.
    pub fn daily_tokens_by_provider(&self, days: u32, utc_offset_secs: i64) -> HashMap<String, Vec<i64>> {
        let conn = self.conn.lock();
        let today = (now() as i64 + utc_offset_secs).div_euclid(86_400);
        let first = today - i64::from(days.max(1)) + 1;
        let rows = query_rows(
            &conn,
            "SELECT provider, CAST((ts + ?1) / 86400 AS INTEGER) AS d, SUM(COALESCE(input_tokens,0) + COALESCE(output_tokens,0))
             FROM usage WHERE provider IS NOT NULL AND (ts + ?1) >= ?2 * 86400 GROUP BY provider, d",
            params![utc_offset_secs, first],
            |r| Ok((r.get::<_, String>(0)?, r.get::<_, i64>(1)?, r.get::<_, i64>(2)?)),
        );
        let mut out: HashMap<String, Vec<i64>> = HashMap::new();
        for (provider, day, tokens) in rows {
            let idx = day - first;
            if (0..i64::from(days.max(1))).contains(&idx) {
                out.entry(provider).or_insert_with(|| vec![0; days.max(1) as usize])[idx as usize] += tokens;
            }
        }
        out
    }

    /// Request log rollup for charts: per-day totals, latest requests and top models.
    /// `days` None covers all history; days are local per `utc_offset_secs`.
    pub fn analytics(&self, days: Option<u32>, utc_offset_secs: i64) -> Value {
        let conn = self.conn.lock();
        let since = days.map_or(0.0, |d| {
            let today = (now() as i64 + utc_offset_secs).div_euclid(86_400);
            ((today - i64::from(d.max(1)) + 1) * 86_400 - utc_offset_secs) as f64
        });
        let day_rows = query_rows(
            &conn,
            "SELECT CAST((ts + ?1) / 86400 AS INTEGER) AS d, COUNT(*), SUM(COALESCE(input_tokens,0)), SUM(COALESCE(output_tokens,0))
             FROM usage WHERE ts >= ?2 GROUP BY d ORDER BY d",
            params![utc_offset_secs, since],
            |r| Ok((r.get::<_, i64>(0)?, r.get::<_, i64>(1)?, r.get::<_, i64>(2)?, r.get::<_, i64>(3)?)),
        );
        let days_json: Vec<Value> = day_rows
            .into_iter()
            .map(|(d, req, inp, out)| {
                let date = chrono::DateTime::from_timestamp(d * 86_400, 0).map(|t| t.format("%Y-%m-%d").to_string()).unwrap_or_default();
                json!({ "date": date, "requests": req, "input": inp, "cached": 0, "output": out, "cost": 0.0 })
            })
            .collect();
        let recent = query_rows(
            &conn,
            "SELECT ts, COALESCE(model,'auto'), COALESCE(provider,''), COALESCE(input_tokens,0), COALESCE(output_tokens,0), COALESCE(status_code,200)
             FROM usage ORDER BY ts DESC LIMIT 20",
            [],
            |r| {
                Ok(json!({
                    "ts": r.get::<_, f64>(0)?, "model": r.get::<_, String>(1)?, "provider": r.get::<_, String>(2)?,
                    "input": r.get::<_, i64>(3)?, "output": r.get::<_, i64>(4)?, "ok": r.get::<_, i64>(5)? < 400,
                }))
            },
        );
        let today_start = ((now() as i64 + utc_offset_secs).div_euclid(86_400) * 86_400 - utc_offset_secs) as f64;
        let top = query_rows(
            &conn,
            "SELECT COALESCE(model,'auto'), COALESCE(provider,''), SUM(COALESCE(input_tokens,0) + COALESCE(output_tokens,0)) AS tok
             FROM usage WHERE ts >= ?1 GROUP BY model, provider ORDER BY tok DESC LIMIT 8",
            params![today_start],
            |r| {
                Ok(
                    json!({ "model": r.get::<_, String>(0)?, "provider": r.get::<_, String>(1)?, "tokens": r.get::<_, i64>(2)?, "cost": 0.0 }),
                )
            },
        );
        let models = query_rows(
            &conn,
            "SELECT COALESCE(model,'auto'), COALESCE(provider,''), SUM(COALESCE(input_tokens,0) + COALESCE(output_tokens,0)) AS tok
             FROM usage WHERE ts >= ?1 GROUP BY model, provider ORDER BY tok DESC LIMIT 12",
            params![since],
            |r| {
                Ok(
                    json!({ "model": r.get::<_, String>(0)?, "provider": r.get::<_, String>(1)?, "tokens": r.get::<_, i64>(2)?, "cost": 0.0 }),
                )
            },
        );
        // `top_models` covers today only; `models` covers the requested range.
        json!({ "days": days_json, "recent": recent, "top_models": top, "models": models })
    }

    pub fn get_stats(&self) -> Value {
        let conn = self.conn.lock();
        let mut stats = json!({
            "requests": 0,
            "input_tokens": 0,
            "output_tokens": 0,
            "errors": 0,
            "active_keys": 0,
            "connected_providers": 0,
        });

        let _ = conn.query_row(
            "SELECT COUNT(*), COALESCE(SUM(input_tokens), 0), COALESCE(SUM(output_tokens), 0), COALESCE(SUM(CASE WHEN status = 'error' OR status_code >= 400 THEN 1 ELSE 0 END), 0) FROM usage",
            [],
            |r| {
                stats["requests"] = json!(r.get::<_, i64>(0)?);
                stats["input_tokens"] = json!(r.get::<_, i64>(1)?);
                stats["output_tokens"] = json!(r.get::<_, i64>(2)?);
                stats["errors"] = json!(r.get::<_, i64>(3)?);
                Ok(())
            },
        );

        let active_keys: i64 = conn.query_row("SELECT COUNT(*) FROM keys WHERE enabled = 1", [], |r| r.get(0)).unwrap_or(0);
        stats["active_keys"] = json!(active_keys);

        let mut connected_count: i64 = conn
            .query_row("SELECT COUNT(DISTINCT id) FROM providers WHERE api_key IS NOT NULL AND api_key != '' AND enabled = 1", [], |r| {
                r.get(0)
            })
            .unwrap_or(0);
        let accounts_count: i64 =
            conn.query_row("SELECT COUNT(DISTINCT provider) FROM accounts WHERE enabled = 1", [], |r| r.get(0)).unwrap_or(0);
        connected_count += accounts_count;
        stats["connected_providers"] = json!(connected_count);

        stats
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A fresh store in a temp dir; keep the dir alive for the test's duration.
    fn store() -> (GatewayStore, tempfile::TempDir) {
        let dir = tempfile::tempdir().unwrap();
        (GatewayStore::new(dir.path()).unwrap(), dir)
    }

    fn account_enabled(store: &GatewayStore, id: &str) -> Option<bool> {
        store.list_accounts().into_iter().find(|a| a.id == id).map(|a| a.enabled)
    }

    mod accounts {
        use super::*;

        fn with_account() -> (GatewayStore, tempfile::TempDir, String) {
            let (s, d) = store();
            let id = s.save_account("codex", &json!({ "access_token": "tok" }), Some("Main"), Some("a@b.com")).unwrap();
            (s, d, id)
        }

        #[test]
        fn new_accounts_start_enabled() {
            let (s, _d, id) = with_account();
            assert_eq!(account_enabled(&s, &id), Some(true));
        }

        #[test]
        fn toggling_without_a_value_flips_enabled() {
            let (s, _d, id) = with_account();
            s.set_account_enabled("codex", &id, None).unwrap();
            assert_eq!(account_enabled(&s, &id), Some(false));
        }

        #[test]
        fn an_explicit_value_re_enables() {
            let (s, _d, id) = with_account();
            s.set_account_enabled("codex", &id, Some(false)).unwrap();
            s.set_account_enabled("codex", &id, Some(true)).unwrap();
            assert_eq!(account_enabled(&s, &id), Some(true));
        }

        #[test]
        fn credentials_are_decrypted_on_read() {
            let (s, _d, id) = with_account();
            let acc = s.list_accounts().into_iter().find(|a| a.id == id).unwrap();
            assert_eq!(acc.cred["access_token"], "tok");
        }

        #[test]
        fn reorder_changes_the_listing_order() {
            let (s, _d, a) = with_account();
            let b = s.save_account("codex", &json!({ "access_token": "t2" }), Some("Second"), None).unwrap();
            s.reorder_accounts("codex", &[b.clone(), a]).unwrap();
            assert_eq!(s.list_accounts()[0].id, b);
        }
    }

    mod providers {
        use super::*;

        #[test]
        fn disabling_a_provider_keeps_its_key() {
            let (s, _d) = store();
            s.save_provider_key("openai", "sk-test-123").unwrap();
            s.set_provider_enabled("openai", Some(false)).unwrap();
            assert_eq!(s.get_provider_key("openai").as_deref(), Some("sk-test-123"));
        }

        #[test]
        fn disabling_a_provider_reports_it_disabled() {
            let (s, _d) = store();
            s.save_provider_key("openai", "sk").unwrap();
            s.set_provider_enabled("openai", Some(false)).unwrap();
            assert!(!s.is_provider_enabled("openai"));
        }

        #[test]
        fn adding_the_same_custom_model_twice_keeps_one() {
            let (s, _d) = store();
            s.add_provider_model("openai", "gpt-custom-1").unwrap();
            assert_eq!(s.add_provider_model("openai", "gpt-custom-1").unwrap(), vec!["gpt-custom-1".to_string()]);
        }

        #[test]
        fn removing_a_custom_model_drops_it() {
            let (s, _d) = store();
            s.add_provider_model("openai", "gpt-custom-1").unwrap();
            assert!(s.remove_provider_model("openai", "gpt-custom-1").unwrap().is_empty());
        }

        #[test]
        fn disconnecting_clears_the_key() {
            let (s, _d) = store();
            s.save_provider_key("openai", "sk").unwrap();
            s.disconnect_provider("openai").unwrap();
            assert_eq!(s.get_provider_key("openai"), None);
        }
    }

    mod synced_models {
        use super::*;

        #[test]
        fn display_falls_back_to_seeds_before_any_sync() {
            let (s, _d) = store();
            assert_eq!(s.display_models("openai", &["seed-a"]), vec!["seed-a"]);
        }

        #[test]
        fn display_uses_the_synced_list_instead_of_seeds() {
            let (s, _d) = store();
            s.set_synced_models("openai", &["live-1".into()]).unwrap();
            assert_eq!(s.display_models("openai", &["seed-a"]), vec!["live-1"]);
        }

        #[test]
        fn display_lists_custom_models_first() {
            let (s, _d) = store();
            s.set_synced_models("openai", &["live-1".into()]).unwrap();
            s.add_provider_model("openai", "mine").unwrap();
            assert_eq!(s.display_models("openai", &[]), vec!["mine", "live-1"]);
        }

        #[test]
        fn sync_records_when_it_happened() {
            let (s, _d) = store();
            s.set_synced_models("openai", &["live-1".into()]).unwrap();
            assert!(s.get_synced_models("openai").1.is_some());
        }

        #[test]
        fn disconnecting_forgets_the_synced_list() {
            let (s, _d) = store();
            s.save_provider_key("openai", "sk").unwrap();
            s.set_synced_models("openai", &["live-1".into()]).unwrap();
            s.disconnect_provider("openai").unwrap();
            assert!(s.get_synced_models("openai").0.is_empty());
        }
    }

    mod virtual_keys {
        use super::*;

        #[test]
        fn a_created_key_is_found_by_its_secret() {
            let (s, _d) = store();
            let (rec, secret) = s.create_virtual_key("ci", None, None).unwrap();
            assert_eq!(s.find_virtual_key(&secret).map(|k| k.id), Some(rec.id));
        }

        #[test]
        fn a_wrong_secret_finds_nothing() {
            let (s, _d) = store();
            s.create_virtual_key("ci", None, None).unwrap();
            assert!(s.find_virtual_key("gw-sk-wrong").is_none());
        }

        #[test]
        fn secrets_carry_the_gateway_prefix() {
            let (s, _d) = store();
            let (_, secret) = s.create_virtual_key("ci", None, None).unwrap();
            assert!(secret.starts_with(KEY_PREFIX), "{secret}");
        }

        #[test]
        fn touching_a_key_counts_requests_and_tokens() {
            let (s, _d) = store();
            let (rec, secret) = s.create_virtual_key("ci", None, None).unwrap();
            s.touch_virtual_key(&rec.id, 10, 5);
            let k = s.find_virtual_key(&secret).unwrap();
            assert_eq!((k.total_requests, k.total_input_tokens, k.total_output_tokens), (1, 10, 5));
        }

        #[test]
        fn toggling_disables_a_key() {
            let (s, _d) = store();
            let (rec, _) = s.create_virtual_key("ci", None, None).unwrap();
            assert!(!s.toggle_virtual_key(&rec.id).unwrap().enabled);
        }

        #[test]
        fn recent_requests_are_counted_per_key() {
            let (s, _d) = store();
            let (rec, _) = s.create_virtual_key("ci", None, None).unwrap();
            s.record_usage(&UsageEntry {
                key_id: Some(&rec.id),
                key_name: Some("ci"),
                provider: Some("openai"),
                model: Some("gpt"),
                input_tokens: 1,
                output_tokens: 1,
                duration_ms: 1,
                status: "success",
                status_code: 200,
                error: None,
                streaming: false,
            });
            assert_eq!(s.key_requests_since(&rec.id, now() - 60.0), 1);
        }
    }

    mod cooldowns {
        use super::*;

        #[test]
        fn a_cooled_key_reports_until_when() {
            let (s, _d) = store();
            s.cool_down("acc-1", 60);
            assert!(s.cooling_until("acc-1").is_some_and(|t| t > now()));
        }

        #[test]
        fn clearing_ends_the_cooldown() {
            let (s, _d) = store();
            s.cool_down("acc-1", 60);
            s.clear_cooldown("acc-1");
            assert!(s.cooling_until("acc-1").is_none());
        }

        #[test]
        fn a_zero_second_cooldown_is_already_over() {
            let (s, _d) = store();
            s.cool_down("acc-1", 0);
            assert!(s.cooling_until("acc-1").is_none());
        }
    }

    mod settings {
        use super::*;

        #[test]
        fn defaults_to_priority_routing() {
            let (s, _d) = store();
            assert_eq!(s.get_gateway_settings().routing_strategy, "priority");
        }

        #[test]
        fn maps_the_legacy_ordered_strategy_to_priority() {
            let (s, _d) = store();
            s.set_setting("routing_strategy", "ordered").unwrap();
            assert_eq!(s.get_gateway_settings().routing_strategy, "priority");
        }

        #[test]
        fn reads_the_saved_provider_priority() {
            let (s, _d) = store();
            s.set_setting("provider_priority", r#"["deepseek","openai"]"#).unwrap();
            assert_eq!(s.get_gateway_settings().provider_priority, vec!["deepseek", "openai"]);
        }

        #[test]
        fn defaults_to_two_auto_models_per_provider() {
            let (s, _d) = store();
            assert_eq!(s.get_gateway_settings().auto_models_per_provider, 2);
        }
    }

    mod analytics {
        use super::*;

        fn log(s: &GatewayStore, provider: &str, tokens: i64, status_code: i64) {
            s.record_usage(&UsageEntry {
                key_id: None,
                key_name: None,
                provider: Some(provider),
                model: Some("m"),
                input_tokens: tokens,
                output_tokens: 0,
                duration_ms: 1,
                status: if status_code < 400 { "success" } else { "error" },
                status_code,
                error: None,
                streaming: false,
            });
        }

        #[test]
        fn todays_tokens_land_in_the_last_day_slot() {
            let (s, _d) = store();
            log(&s, "codex", 7, 200);
            assert_eq!(s.daily_tokens_by_provider(7, 0).get("codex").map(|d| d[6]), Some(7));
        }

        #[test]
        fn daily_tokens_cover_the_requested_number_of_days() {
            let (s, _d) = store();
            log(&s, "codex", 7, 200);
            assert_eq!(s.daily_tokens_by_provider(14, 0).get("codex").map(Vec::len), Some(14));
        }

        #[test]
        fn analytics_counts_requests_per_day() {
            let (s, _d) = store();
            log(&s, "codex", 1, 200);
            log(&s, "codex", 1, 200);
            assert_eq!(s.analytics(Some(7), 0)["days"][0]["requests"], 2);
        }

        #[test]
        fn analytics_marks_failed_requests() {
            let (s, _d) = store();
            log(&s, "codex", 1, 429);
            assert_eq!(s.analytics(None, 0)["recent"][0]["ok"], false);
        }

        #[test]
        fn analytics_lists_models_for_the_whole_range() {
            let (s, _d) = store();
            log(&s, "codex", 5, 200);
            assert_eq!(s.analytics(None, 0)["models"][0]["provider"], "codex");
        }

        #[test]
        fn analytics_ranks_todays_models_by_tokens() {
            let (s, _d) = store();
            log(&s, "codex", 5, 200);
            assert_eq!(s.analytics(Some(1), 0)["top_models"][0]["tokens"], 5);
        }
    }

    mod stats {
        use super::*;

        fn log(s: &GatewayStore, status: &str, code: i64) {
            s.record_usage(&UsageEntry {
                key_id: None,
                key_name: None,
                provider: Some("codex"),
                model: Some("m"),
                input_tokens: 1,
                output_tokens: 1,
                duration_ms: 1,
                status,
                status_code: code,
                error: None,
                streaming: false,
            });
        }

        #[test]
        fn successful_requests_are_not_counted_as_errors() {
            let (s, _d) = store();
            log(&s, "success", 200);
            assert_eq!(s.get_stats()["errors"], 0);
        }

        #[test]
        fn failed_requests_are_counted_as_errors() {
            let (s, _d) = store();
            log(&s, "error", 429);
            assert_eq!(s.get_stats()["errors"], 1);
        }
    }

    mod combos {
        use super::*;

        #[test]
        fn a_saved_combo_is_listed_with_its_targets() {
            let (s, _d) = store();
            s.save_combo("mix", &["oa/gpt-4o".into()]).unwrap();
            assert_eq!(s.list_combos().get("mix"), Some(&vec!["oa/gpt-4o".to_string()]));
        }
    }
}
