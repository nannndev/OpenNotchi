//! AI features: agent status from Claude Code / Codex logs, token usage, the local hook listener,
//! installing our Claude Code hooks, and Ask AI provider calls. Only `ask_ai` talks to the network.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom, Write};
use std::net::{TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{LazyLock, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tauri::Emitter;

pub const HOOK_PORT: u16 = 47823;
const HOOK_URL: &str = "http://127.0.0.1:47823/hook/claude";
const HOOK_EVENTS: [&str; 4] = ["UserPromptSubmit", "PreToolUse", "Notification", "Stop"];
const TAIL_BYTES: u64 = 64 * 1024;
const MINUTE: i64 = 60_000;
const HOUR: i64 = 60 * MINUTE;
const DAY: i64 = 24 * HOUR;
const FIVE_H: i64 = 5 * HOUR;
const ACTIVE_MS: i64 = 30 * MINUTE;

fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as i64).unwrap_or(0)
}

fn mtime_ms(meta: &fs::Metadata) -> i64 {
    meta.modified().ok().and_then(|t| t.duration_since(UNIX_EPOCH).ok()).map(|d| d.as_millis() as i64).unwrap_or(0)
}

/// Expands a leading `~` to the home folder (USERPROFILE on Windows, HOME elsewhere).
fn expand(dir: &str) -> PathBuf {
    let home = std::env::var(if cfg!(windows) { "USERPROFILE" } else { "HOME" }).unwrap_or_default();
    match dir.trim().strip_prefix('~') {
        Some(rest) => PathBuf::from(home).join(rest.trim_start_matches(['/', '\\'])),
        None => PathBuf::from(dir.trim()),
    }
}

fn project_name(cwd: &str) -> String {
    cwd.trim_end_matches(['/', '\\']).rsplit(['/', '\\']).next().unwrap_or(cwd).to_string()
}

/// Unix ms from a timestamp like `2026-10-24T04:20:54.407Z`.
/// shortcut: assumes UTC (`Z`), which both Claude Code and Codex write; parse offsets if that changes.
fn parse_iso_ms(s: &str) -> Option<i64> {
    let n = |a: usize, b: usize| -> Option<i64> { s.get(a..b)?.parse().ok() };
    let (y, mo, d, h, mi, se) = (n(0, 4)?, n(5, 7)?, n(8, 10)?, n(11, 13)?, n(14, 16)?, n(17, 19)?);
    let ms = match s.get(19..20) {
        Some(".") => {
            let frac: String = s[20..].chars().take_while(char::is_ascii_digit).take(3).collect();
            format!("{frac:0<3}").parse().ok()?
        }
        _ => 0,
    };
    // Days since 1970-01-01 (Howard Hinnant's days_from_civil).
    let y = if mo <= 2 { y - 1 } else { y };
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let doy = (153 * ((mo + 9) % 12) + 2) / 5 + d - 1;
    let days = era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468;
    Some(days * DAY + h * HOUR + mi * MINUTE + se * 1000 + ms)
}

/// Subfolders, newest name first (Codex folders are YYYY/MM/DD, so name order is date order).
fn subdirs_desc(p: &Path) -> Vec<PathBuf> {
    let mut v: Vec<PathBuf> = fs::read_dir(p).into_iter().flatten().flatten().map(|e| e.path()).filter(|p| p.is_dir()).collect();
    v.sort();
    v.reverse();
    v
}

fn jsonl_in(dir: &Path) -> Vec<(PathBuf, fs::Metadata)> {
    fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .filter(|e| e.path().extension().is_some_and(|x| x == "jsonl"))
        .filter_map(|e| Some((e.path(), e.metadata().ok()?)))
        .collect()
}

/// The newest `n` day folders under a Codex `sessions` folder.
fn codex_day_dirs(codex_home: &Path, n: usize) -> Vec<PathBuf> {
    let mut out = vec![];
    for y in subdirs_desc(&codex_home.join("sessions")) {
        for m in subdirs_desc(&y) {
            for d in subdirs_desc(&m) {
                if out.len() == n {
                    return out;
                }
                out.push(d);
            }
        }
    }
    out
}

/// Every Claude Code transcript, subagent logs included (they count for usage, not for status).
fn claude_logs(config_dir: &Path, recursive: bool) -> Vec<(PathBuf, fs::Metadata)> {
    let mut out = vec![];
    let mut stack = subdirs_desc(&config_dir.join("projects"));
    while let Some(dir) = stack.pop() {
        out.extend(jsonl_in(&dir));
        if recursive {
            stack.extend(subdirs_desc(&dir));
        }
    }
    out
}

// ---------------------------------------------------------------------------------------------
// Agent status
// ---------------------------------------------------------------------------------------------

#[derive(Serialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AgentSession {
    pub tool: &'static str,
    pub session_id: String,
    pub project: String,
    /// "working" or "done" from the logs; the frontend adds "needs_you" (hooks) and "idle".
    pub state: &'static str,
    pub updated_at: i64,
}

/// The complete lines in the last 64 KB of a file.
fn tail_lines(path: &Path) -> Vec<String> {
    let Ok(mut f) = File::open(path) else { return vec![] };
    let start = f.metadata().map(|m| m.len()).unwrap_or(0).saturating_sub(TAIL_BYTES);
    let mut buf = Vec::new();
    if f.seek(SeekFrom::Start(start)).is_err() || f.read_to_end(&mut buf).is_err() {
        return vec![];
    }
    let mut lines: Vec<String> = String::from_utf8_lossy(&buf).lines().map(str::to_string).collect();
    if start > 0 && !lines.is_empty() {
        lines.remove(0); // cut mid-line
    }
    lines
}

/// Working/done from the tail of a Claude Code transcript, plus the last cwd and session id seen.
fn claude_state(lines: &[String]) -> (Option<&'static str>, String, String) {
    let (mut state, mut cwd, mut sid) = (None, String::new(), String::new());
    for line in lines {
        let Ok(v) = serde_json::from_str::<Value>(line) else { continue };
        if let Some(c) = v["cwd"].as_str() {
            cwd = c.to_string();
        }
        if let Some(s) = v["sessionId"].as_str() {
            sid = s.to_string();
        }
        match v["type"].as_str() {
            Some("assistant") => match v["message"]["stop_reason"].as_str() {
                Some("tool_use") => state = Some("working"),
                Some(_) => state = Some("done"),
                None => {}
            },
            Some("user") if v["isMeta"] != true => state = Some("working"),
            _ => {}
        }
    }
    (state, cwd, sid)
}

fn codex_state(lines: &[String]) -> Option<&'static str> {
    lines.iter().filter(|l| l.contains("task_")).filter_map(|l| serde_json::from_str::<Value>(l).ok()).fold(None, |s, v| {
        match v["payload"]["type"].as_str() {
            Some("task_started") => Some("working"),
            Some("task_complete") => Some("done"),
            _ => s,
        }
    })
}

fn first_line(path: &Path) -> Option<Value> {
    let mut line = String::new();
    BufReader::new(File::open(path).ok()?.take(4 << 20)).read_line(&mut line).ok()?;
    serde_json::from_str(&line).ok()
}

fn read_session(tool: &'static str, path: &Path, mtime: i64) -> Option<AgentSession> {
    let lines = tail_lines(path);
    let (state, cwd, sid) = if tool == "claude" {
        claude_state(&lines)
    } else {
        let meta = first_line(path)?;
        let p = &meta["payload"];
        (codex_state(&lines), p["cwd"].as_str().unwrap_or("").into(), p["id"].as_str().unwrap_or("").into())
    };
    let stem = path.file_stem()?.to_string_lossy().to_string();
    Some(AgentSession {
        tool,
        session_id: if sid.is_empty() { stem } else { sid },
        project: project_name(&cwd),
        state: state?,
        updated_at: mtime,
    })
}

/// Parsed state per transcript, re-read only when its mtime changes.
static SESSIONS: LazyLock<Mutex<HashMap<PathBuf, (i64, Option<AgentSession>)>>> = LazyLock::new(Default::default);

/// Agent sessions written to in the last 30 minutes, newest first.
#[tauri::command]
pub fn agent_sessions(claude_dirs: Vec<String>, codex_dirs: Vec<String>) -> Vec<AgentSession> {
    let since = now_ms() - ACTIVE_MS;
    let mut files: Vec<(&'static str, PathBuf, i64)> = vec![];
    for d in &claude_dirs {
        files.extend(claude_logs(&expand(d), false).into_iter().map(|(p, m)| ("claude", p, mtime_ms(&m))));
    }
    for d in &codex_dirs {
        for day in codex_day_dirs(&expand(d), 2) {
            files.extend(jsonl_in(&day).into_iter().map(|(p, m)| ("codex", p, mtime_ms(&m))));
        }
    }
    files.retain(|f| f.2 >= since);

    let mut cache = SESSIONS.lock().unwrap();
    let mut out: Vec<AgentSession> = files
        .into_iter()
        .filter_map(|(tool, path, mtime)| {
            if let Some((m, s)) = cache.get(&path) {
                if *m == mtime {
                    return s.clone();
                }
            }
            let s = read_session(tool, &path, mtime);
            cache.insert(path, (mtime, s.clone()));
            s
        })
        .collect();
    out.sort_by(|a, b| b.updated_at.cmp(&a.updated_at));
    out
}

// ---------------------------------------------------------------------------------------------
// Usage
// ---------------------------------------------------------------------------------------------

#[derive(Deserialize)]
pub struct Account {
    pub name: String,
    pub tool: String,
    pub dir: String,
}

#[derive(Serialize, Default, Debug, Clone, PartialEq)]
pub struct Totals {
    pub tokens: u64,
    /// Estimated USD; only models in the price table add to it.
    pub cost: f64,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct Block {
    pub start: i64,
    pub end: i64,
    pub tokens: u64,
    pub cost: f64,
}

#[derive(Serialize, Debug, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RateWindow {
    pub used_percent: f64,
    pub window_minutes: u64,
    /// Unix seconds.
    pub resets_at: i64,
}

#[derive(Serialize, Debug, Clone, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct CodexLimits {
    pub plan_type: Option<String>,
    pub primary: Option<RateWindow>,
    pub secondary: Option<RateWindow>,
}

#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct UsageReport {
    pub name: String,
    pub tool: String,
    pub dir: String,
    /// False when the folder has no session logs.
    pub found: bool,
    pub today: Totals,
    pub block: Option<Block>,
    /// Tokens per local day, oldest first, today last.
    pub days: Vec<u64>,
    pub limits: Option<CodexLimits>,
}

#[derive(Clone, Debug)]
struct Entry {
    ts: i64,
    model: String,
    /// message.id + requestId: Claude Code logs the same message several times.
    key: String,
    /// input, output, cache write, cache read
    tokens: [u64; 4],
}

#[derive(Deserialize)]
struct UsageLine {
    #[serde(rename = "type")]
    kind: String,
    timestamp: Option<String>,
    #[serde(rename = "requestId")]
    request_id: Option<String>,
    // Newer Claude Code versions log `requestRef` instead of `requestId`.
    #[serde(rename = "requestRef")]
    request_ref: Option<String>,
    message: Option<UsageMessage>,
}

#[derive(Deserialize)]
struct UsageMessage {
    id: Option<String>,
    model: Option<String>,
    usage: Option<Usage>,
}

#[derive(Deserialize)]
struct Usage {
    #[serde(default)]
    input_tokens: u64,
    #[serde(default)]
    output_tokens: u64,
    #[serde(default)]
    cache_creation_input_tokens: u64,
    #[serde(default)]
    cache_read_input_tokens: u64,
}

fn parse_usage_line(line: &str) -> Option<Entry> {
    if !line.contains("\"usage\"") {
        return None; // cheap skip before parsing big transcript lines
    }
    let l: UsageLine = serde_json::from_str(line).ok()?;
    if l.kind != "assistant" {
        return None;
    }
    let m = l.message?;
    let u = m.usage?;
    let req = l.request_id.or(l.request_ref).unwrap_or_default();
    Some(Entry {
        ts: parse_iso_ms(&l.timestamp?)?,
        model: m.model.unwrap_or_default(),
        key: format!("{}:{req}", m.id?),
        tokens: [u.input_tokens, u.output_tokens, u.cache_creation_input_tokens, u.cache_read_input_tokens],
    })
}

/// Keeps one entry per message.id + requestId (the last logged, with final output tokens), sorted by time.
fn dedupe(entries: impl IntoIterator<Item = Entry>) -> Vec<Entry> {
    let mut by_key: HashMap<String, Entry> = HashMap::new();
    for e in entries {
        by_key.insert(e.key.clone(), e);
    }
    let mut v: Vec<Entry> = by_key.into_values().collect();
    v.sort_by_key(|e| e.ts);
    v
}

/// USD per million tokens: input, output, cache write (5 min), cache read. Most specific id first.
const PRICES: &[(&str, [f64; 4])] = &[
    ("claude-fable-5-1", [10.0, 50.0, 12.5, 0.25]),
    ("claude-mythos-5-1", [10.0, 50.0, 12.5, 0.25]),
    ("claude-fable-5", [10.0, 50.0, 12.5, 1.0]),
    ("claude-mythos-5", [10.0, 50.0, 12.5, 1.0]),
    ("claude-opus-5-5", [4.0, 20.0, 5.0, 0.2]),
    ("claude-opus-5", [5.0, 25.0, 6.25, 0.5]),
    ("claude-opus-4-8", [5.0, 25.0, 6.25, 0.5]),
    ("claude-opus-4-7", [5.0, 25.0, 6.25, 0.5]),
    ("claude-opus-4-6", [5.0, 25.0, 6.25, 0.5]),
    ("claude-opus-4-5", [5.0, 25.0, 6.25, 0.5]),
    ("claude-sonnet-5-5", [2.0, 10.0, 2.5, 0.2]),
    ("claude-sonnet-5", [2.0, 10.0, 2.5, 0.2]),
    ("claude-sonnet-4", [3.0, 15.0, 3.75, 0.3]),
    ("claude-haiku-5-5", [0.1, 0.5, 0.125, 0.01]),
    ("claude-haiku-4-5", [1.0, 5.0, 1.25, 0.1]),
];

fn cost(e: &Entry) -> f64 {
    PRICES
        .iter()
        .find(|(id, _)| e.model.contains(id))
        .map(|(_, p)| e.tokens.iter().zip(p).map(|(t, p)| *t as f64 * p / 1e6).sum())
        .unwrap_or(0.0)
}

fn add(t: &mut Totals, e: &Entry) {
    t.tokens += e.tokens.iter().sum::<u64>();
    t.cost += cost(e);
}

/// Start of the 5-hour block holding the latest entry, if that block is still running (ccusage rules:
/// a block starts at the first message after a ≥5 h gap or after the previous block ends, floored to the hour).
fn current_block_start(sorted_ts: &[i64], now: i64) -> Option<i64> {
    let (mut start, mut last) = (None::<i64>, 0);
    for &t in sorted_ts {
        if start.is_none_or(|s| t >= s + FIVE_H || t - last >= FIVE_H) {
            start = Some(t - t.rem_euclid(HOUR));
        }
        last = t;
    }
    let s = start?;
    (now < s + FIVE_H && now - last < FIVE_H).then_some(s)
}

struct FileUsage {
    len: u64,
    entries: Vec<Entry>,
}

/// Parsed entries per transcript; logs are append-only, so only new bytes are read on a rescan.
static USAGE: LazyLock<Mutex<HashMap<PathBuf, FileUsage>>> = LazyLock::new(Default::default);

fn file_entries(path: &Path, len: u64, cache: &mut HashMap<PathBuf, FileUsage>) -> Vec<Entry> {
    let cached = cache.remove(path).filter(|c| c.len <= len);
    let (mut offset, mut entries) = cached.map(|c| (c.len, c.entries)).unwrap_or((0, vec![]));
    if offset < len {
        let mut buf = Vec::new();
        if let Ok(mut f) = File::open(path) {
            if f.seek(SeekFrom::Start(offset)).is_ok() {
                let _ = f.take(len - offset).read_to_end(&mut buf);
            }
        }
        // Only complete lines; a half-written last line is read again next time.
        let complete = buf.iter().rposition(|&b| b == b'\n').map_or(0, |i| i + 1);
        entries.extend(String::from_utf8_lossy(&buf[..complete]).lines().filter_map(parse_usage_line));
        offset += complete as u64;
    }
    cache.insert(path.to_path_buf(), FileUsage { len: offset, entries: entries.clone() });
    entries
}

fn local_day(ts: i64, tz_offset_min: i64) -> i64 {
    (ts - tz_offset_min * MINUTE).div_euclid(DAY)
}

fn claude_report(account: &Account, now: i64, tz: i64) -> UsageReport {
    let dir = expand(&account.dir);
    let week_ago = now - 8 * DAY;
    let logs = claude_logs(&dir, true);
    let found = !logs.is_empty();
    let mut all = vec![];
    {
        let mut cache = USAGE.lock().unwrap();
        for (path, meta) in logs.iter().filter(|(_, m)| mtime_ms(m) >= week_ago) {
            all.extend(file_entries(path, meta.len(), &mut cache));
        }
    }
    let entries: Vec<Entry> = dedupe(all.into_iter().filter(|e| e.ts >= week_ago));

    let today = local_day(now, tz);
    let mut days = vec![0u64; 7];
    let mut today_totals = Totals::default();
    for e in &entries {
        let ago = today - local_day(e.ts, tz);
        if (0..7).contains(&ago) {
            days[6 - ago as usize] += e.tokens.iter().sum::<u64>();
        }
        if ago == 0 {
            add(&mut today_totals, e);
        }
    }
    let ts: Vec<i64> = entries.iter().map(|e| e.ts).collect();
    let block = current_block_start(&ts, now).map(|start| {
        let mut t = Totals::default();
        entries.iter().filter(|e| e.ts >= start).for_each(|e| add(&mut t, e));
        Block { start, end: start + FIVE_H, tokens: t.tokens, cost: t.cost }
    });
    UsageReport { name: account.name.clone(), tool: account.tool.clone(), dir: account.dir.clone(), found, today: today_totals, block, days, limits: None }
}

fn rate_window(v: &Value) -> Option<RateWindow> {
    Some(RateWindow {
        used_percent: v["used_percent"].as_f64()?,
        window_minutes: v["window_minutes"].as_u64().unwrap_or(0),
        resets_at: v["resets_at"].as_i64().unwrap_or(0),
    })
}

/// A Codex `token_count` event: (timestamp, tokens of that turn, rate limits if reported).
fn parse_codex_token_count(line: &str) -> Option<(i64, u64, Option<CodexLimits>)> {
    let v: Value = serde_json::from_str(line).ok()?;
    let p = &v["payload"];
    if p["type"] != "token_count" {
        return None;
    }
    let ts = parse_iso_ms(v["timestamp"].as_str()?)?;
    let last = &p["info"]["last_token_usage"];
    let tokens = last["total_tokens"]
        .as_u64()
        .unwrap_or_else(|| last["input_tokens"].as_u64().unwrap_or(0) + last["output_tokens"].as_u64().unwrap_or(0));
    let rl = &p["rate_limits"];
    let limits = CodexLimits {
        plan_type: rl["plan_type"].as_str().map(str::to_string),
        primary: rate_window(&rl["primary"]),
        secondary: rate_window(&rl["secondary"]),
    };
    let has_limits = limits.primary.is_some() || limits.secondary.is_some();
    Some((ts, tokens, has_limits.then_some(limits)))
}

fn codex_report(account: &Account, now: i64, tz: i64) -> UsageReport {
    let today = local_day(now, tz);
    let mut days = vec![0u64; 7];
    let mut latest: Option<(i64, CodexLimits)> = None;
    let mut found = false;
    // Eight day folders cover the weekly window and a local "today" that spans two UTC dates.
    for day in codex_day_dirs(&expand(&account.dir), 8) {
        for (path, _) in jsonl_in(&day) {
            found = true;
            let Ok(text) = fs::read_to_string(&path) else { continue };
            for (ts, tokens, limits) in text.lines().filter(|l| l.contains("token_count")).filter_map(parse_codex_token_count) {
                let ago = today - local_day(ts, tz);
                if (0..7).contains(&ago) {
                    days[6 - ago as usize] += tokens;
                }
                if let Some(l) = limits {
                    if latest.as_ref().is_none_or(|(t, _)| ts > *t) {
                        latest = Some((ts, l));
                    }
                }
            }
        }
    }
    UsageReport {
        name: account.name.clone(),
        tool: account.tool.clone(),
        dir: account.dir.clone(),
        found,
        today: Totals { tokens: days[6], cost: 0.0 },
        block: None,
        days,
        limits: latest.map(|(_, l)| l),
    }
}

/// Usage per configured account. `tz_offset_min` is JS `Date#getTimezoneOffset()`, for local days.
#[tauri::command]
pub async fn ai_usage(accounts: Vec<Account>, tz_offset_min: i64) -> Vec<UsageReport> {
    tauri::async_runtime::spawn_blocking(move || {
        let now = now_ms();
        accounts
            .iter()
            .map(|a| if a.tool == "codex" { codex_report(a, now, tz_offset_min) } else { claude_report(a, now, tz_offset_min) })
            .collect()
    })
    .await
    .unwrap_or_default()
}

/// The default accounts whose folders exist: `~/.claude` and `~/.codex`.
#[tauri::command]
pub fn ai_default_accounts() -> Vec<Value> {
    [("Claude Code", "claude", "~/.claude"), ("Codex", "codex", "~/.codex")]
        .into_iter()
        .filter(|(_, _, dir)| expand(dir).is_dir())
        .map(|(name, tool, dir)| json!({ "name": name, "tool": tool, "dir": dir }))
        .collect()
}

// ---------------------------------------------------------------------------------------------
// Hook listener on 127.0.0.1:47823
// ---------------------------------------------------------------------------------------------

#[derive(Serialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct HookEvent {
    pub session_id: String,
    pub project: String,
    pub state: &'static str,
    pub message: Option<String>,
}

/// Maps a Claude Code hook payload to a session state.
fn hook_event(v: &Value) -> Option<HookEvent> {
    let state = match v["hook_event_name"].as_str()? {
        "UserPromptSubmit" | "PreToolUse" => "working",
        "Notification" => "needs_you",
        "Stop" => "done",
        _ => return None,
    };
    Some(HookEvent {
        session_id: v["session_id"].as_str()?.to_string(),
        project: project_name(v["cwd"].as_str().unwrap_or("")),
        state,
        message: v["message"].as_str().map(str::to_string),
    })
}

/// Minimal HTTP/1.1 request reader: (request line, lowercase headers, body). Bodies are capped at 1 MB.
fn read_request(r: &mut impl Read) -> Option<(String, HashMap<String, String>, Vec<u8>)> {
    let mut reader = BufReader::new(r);
    let mut request_line = String::new();
    reader.read_line(&mut request_line).ok()?;
    let mut headers = HashMap::new();
    loop {
        let mut line = String::new();
        if reader.read_line(&mut line).ok()? == 0 || line.trim().is_empty() {
            break;
        }
        let (k, v) = line.split_once(':')?;
        headers.insert(k.trim().to_ascii_lowercase(), v.trim().to_string());
    }
    let len: usize = headers.get("content-length").and_then(|v| v.parse().ok()).unwrap_or(0);
    if len > 1 << 20 {
        return None;
    }
    let mut body = vec![0; len];
    reader.read_exact(&mut body).ok()?;
    Some((request_line.trim().to_string(), headers, body))
}

/// Status code for a request, and the event to emit if it's a valid hook call.
fn route(request_line: &str, headers: &HashMap<String, String>, body: &[u8]) -> (u16, Option<HookEvent>) {
    let host_ok = headers.get("host").is_some_and(|h| h == "127.0.0.1:47823" || h == "localhost:47823");
    // Browsers always send Origin on cross-site POSTs; curl doesn't. Blocks web pages and DNS rebinding.
    if !host_ok || headers.contains_key("origin") {
        return (403, None);
    }
    if !request_line.starts_with("POST /hook/claude ") {
        return (404, None);
    }
    match serde_json::from_slice::<Value>(body).ok().as_ref().and_then(hook_event) {
        Some(e) => (204, Some(e)),
        None => (204, None), // other hook events are fine, just not shown
    }
}

fn handle(app: &tauri::AppHandle, mut stream: TcpStream) {
    let _ = stream.set_read_timeout(Some(Duration::from_secs(2)));
    let (status, event) = match read_request(&mut stream) {
        Some((line, headers, body)) => route(&line, &headers, &body),
        None => (400, None),
    };
    let reason = match status {
        204 => "No Content",
        403 => "Forbidden",
        404 => "Not Found",
        _ => "Bad Request",
    };
    let _ = write!(stream, "HTTP/1.1 {status} {reason}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
    if let Some(e) = event {
        let _ = app.emit("agent-hook", e);
    }
}

/// Bumped on every start/stop; a listener thread exits once its generation is stale.
static HOOK_GEN: AtomicU64 = AtomicU64::new(0);
static HOOK_ON: Mutex<bool> = Mutex::new(false);

/// Starts or stops the hook listener. Errors (port taken) leave log polling as the only source.
#[tauri::command]
pub fn set_hook_server(app: tauri::AppHandle, on: bool) -> Result<bool, String> {
    let mut running = HOOK_ON.lock().unwrap();
    if !on {
        *running = false;
        HOOK_GEN.fetch_add(1, Ordering::SeqCst);
        return Ok(false);
    }
    if *running {
        return Ok(true);
    }
    // A listener stopped a moment ago may still hold the port for up to one poll.
    let mut bound = TcpListener::bind(("127.0.0.1", HOOK_PORT));
    for _ in 0..4 {
        if bound.is_ok() {
            break;
        }
        std::thread::sleep(Duration::from_millis(150));
        bound = TcpListener::bind(("127.0.0.1", HOOK_PORT));
    }
    let listener = bound.map_err(|e| {
        log::warn!("AI hooks: can't listen on 127.0.0.1:{HOOK_PORT} ({e}); using log polling only");
        format!("Port {HOOK_PORT} is in use, so hooks are off. Agent status still comes from the logs.")
    })?;
    listener.set_nonblocking(true).map_err(|e| e.to_string())?;
    let generation = HOOK_GEN.fetch_add(1, Ordering::SeqCst) + 1;
    *running = true;
    std::thread::spawn(move || {
        while HOOK_GEN.load(Ordering::SeqCst) == generation {
            match listener.accept() {
                Ok((stream, _)) => {
                    let _ = stream.set_nonblocking(false);
                    handle(&app, stream);
                }
                Err(_) => std::thread::sleep(Duration::from_millis(150)),
            }
        }
    });
    Ok(true)
}

// ---------------------------------------------------------------------------------------------
// Installing our hooks into <configDir>/settings.json
// ---------------------------------------------------------------------------------------------

fn hook_command() -> String {
    format!("curl -s -m 2 -X POST -H \"Content-Type: application/json\" --data-binary @- {HOOK_URL}")
}

fn is_ours(hook: &Value) -> bool {
    hook["command"].as_str().is_some_and(|c| c.contains(HOOK_URL))
}

/// Removes only our hooks, plus any group or event list that became empty because of that.
fn strip_hooks(mut settings: Value) -> Value {
    let Some(hooks) = settings.get_mut("hooks").and_then(Value::as_object_mut) else { return settings };
    let had_events = !hooks.is_empty();
    hooks.retain(|_, groups| {
        let Some(arr) = groups.as_array_mut() else { return true };
        let before = arr.len();
        arr.retain_mut(|g| {
            let Some(hs) = g.get_mut("hooks").and_then(Value::as_array_mut) else { return true };
            let n = hs.len();
            hs.retain(|h| !is_ours(h));
            !(hs.is_empty() && n > 0)
        });
        !(arr.is_empty() && before > 0)
    });
    if had_events && hooks.is_empty() {
        settings.as_object_mut().map(|o| o.remove("hooks"));
    }
    settings
}

/// Adds our hook to each event, keeping every other key and hook. Running it twice changes nothing.
fn merge_hooks(settings: Value) -> Result<Value, String> {
    let mut s = strip_hooks(settings);
    let obj = s.as_object_mut().ok_or("settings.json isn't a JSON object")?;
    let hooks = obj.entry("hooks").or_insert_with(|| json!({})).as_object_mut().ok_or("\"hooks\" in settings.json isn't an object")?;
    for event in HOOK_EVENTS {
        let groups = hooks.entry(event).or_insert_with(|| json!([])).as_array_mut().ok_or(format!("\"hooks.{event}\" isn't a list"))?;
        groups.push(json!({ "hooks": [{ "type": "command", "command": hook_command(), "timeout": 5 }] }));
    }
    Ok(s)
}

fn edit_settings(dir: &Path, install: bool) -> Result<(), String> {
    let path = dir.join("settings.json");
    let raw = match fs::read_to_string(&path) {
        Ok(s) => Some(s),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
        Err(e) => return Err(e.to_string()),
    };
    let current: Value = match raw.as_deref().map(str::trim) {
        Some(s) if !s.is_empty() => serde_json::from_str(s).map_err(|e| format!("settings.json isn't valid JSON, so it was left alone ({e})"))?,
        _ => json!({}),
    };
    let next = if install { merge_hooks(current.clone())? } else { strip_hooks(current.clone()) };
    if next == current {
        return Ok(());
    }
    fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    if let Some(raw) = &raw {
        fs::write(dir.join("settings.json.bak"), raw).map_err(|e| format!("Couldn't write the backup: {e}"))?;
    }
    let text = serde_json::to_string_pretty(&next).map_err(|e| e.to_string())?;
    fs::write(&path, text + "\n").map_err(|e| e.to_string())
}

/// Installs (or removes) our hooks in `<dir>/settings.json`; returns whether they're installed now.
#[tauri::command]
pub fn claude_hooks(dir: String, install: bool) -> Result<bool, String> {
    edit_settings(&expand(&dir), install)?;
    Ok(claude_hooks_installed(dir))
}

#[tauri::command]
pub fn claude_hooks_installed(dir: String) -> bool {
    fs::read_to_string(expand(&dir).join("settings.json")).is_ok_and(|s| s.contains(HOOK_URL))
}

// ---------------------------------------------------------------------------------------------
// Ask AI
// ---------------------------------------------------------------------------------------------

const SYSTEM_PROMPT: &str =
    "You answer inside a small panel at the top of the user's screen. Be concise. Reply in plain text, no markdown headings.";

fn key_entry(provider: &str) -> Result<keyring::Entry, String> {
    if provider != "anthropic" && provider != "openai" {
        return Err("Unknown provider".into());
    }
    keyring::Entry::new("OpenNotchi AI", provider).map_err(|e| e.to_string())
}

/// Saves an API key in Windows Credential Manager (Keychain on macOS); an empty key deletes it.
#[tauri::command]
pub fn ai_key_set(provider: String, key: String) -> Result<(), String> {
    let entry = key_entry(&provider)?;
    match key.trim() {
        "" => match entry.delete_credential() {
            Ok(()) | Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(e.to_string()),
        },
        k => entry.set_password(k).map_err(|e| e.to_string()),
    }
}

/// Whether a key is saved; the key itself never goes back to the webview.
#[tauri::command]
pub fn ai_key_exists(provider: String) -> bool {
    key_entry(&provider).is_ok_and(|e| e.get_password().is_ok())
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AskRequest {
    provider: String,
    base_url: String,
    model: String,
    prompt: String,
}

fn error_message(v: &Value) -> Option<String> {
    v["error"]["message"].as_str().or(v["error"].as_str()).map(str::to_string)
}

fn anthropic_text(v: &Value) -> Result<String, String> {
    if v["stop_reason"] == "refusal" {
        return Err("The model declined to answer this one.".into());
    }
    let text: Vec<&str> = v["content"].as_array().into_iter().flatten().filter(|b| b["type"] == "text").filter_map(|b| b["text"].as_str()).collect();
    if text.is_empty() { Err("Empty answer".into()) } else { Ok(text.join("").trim().to_string()) }
}

fn openai_text(v: &Value) -> Result<String, String> {
    v["choices"][0]["message"]["content"].as_str().map(|s| s.trim().to_string()).ok_or("Empty answer".into())
}

fn ollama_text(v: &Value) -> Result<String, String> {
    v["message"]["content"].as_str().map(|s| s.trim().to_string()).ok_or("Empty answer".into())
}

fn ask_blocking(req: &AskRequest) -> Result<String, String> {
    let agent: ureq::Agent = ureq::Agent::config_builder()
        .http_status_as_error(false)
        .timeout_global(Some(Duration::from_secs(90)))
        .build()
        .into();
    let base = req.base_url.trim().trim_end_matches('/');
    let key = || key_entry(&req.provider)?.get_password().map_err(|_| "Add an API key in Settings › AI first.".to_string());
    let send = |r: ureq::RequestBuilder<ureq::typestate::WithBody>, body: Value| -> Result<Value, String> {
        let mut resp = r.send_json(&body).map_err(|e| format!("Couldn't reach the provider ({e})"))?;
        let status = resp.status();
        let v: Value = resp.body_mut().read_json().map_err(|_| format!("The provider answered HTTP {status}"))?;
        if !status.is_success() {
            return Err(error_message(&v).unwrap_or_else(|| format!("The provider answered HTTP {status}")));
        }
        Ok(v)
    };
    let user = json!([{ "role": "user", "content": req.prompt }]);
    match req.provider.as_str() {
        "anthropic" => {
            let mut body = json!({
                "model": req.model,
                "max_tokens": 1024,
                "system": SYSTEM_PROMPT,
                "messages": user,
                "output_config": { "effort": "low" },
            });
            let mut r = agent.post("https://api.anthropic.com/v1/messages").header("x-api-key", &key()?).header("anthropic-version", "2026-10-21");
            // Sonnet 5.5 can retry a safeguard refusal on another model server-side; Haiku has no fallback.
            if req.model == "claude-sonnet-5-5" {
                r = r.header("anthropic-beta", "server-side-fallback-2026-07-01");
                body["fallbacks"] = json!("default");
            }
            anthropic_text(&send(r, body)?)
        }
        "openai" => {
            if !base.starts_with("http://") && !base.starts_with("https://") {
                return Err("The base URL must start with http:// or https://".into());
            }
            let messages = json!([{ "role": "system", "content": SYSTEM_PROMPT }, { "role": "user", "content": req.prompt }]);
            let r = agent.post(format!("{base}/chat/completions")).header("Authorization", &format!("Bearer {}", key()?));
            openai_text(&send(r, json!({ "model": req.model, "messages": messages }))?)
        }
        "ollama" => {
            if !base.starts_with("http://") && !base.starts_with("https://") {
                return Err("The base URL must start with http:// or https://".into());
            }
            let messages = json!([{ "role": "system", "content": SYSTEM_PROMPT }, { "role": "user", "content": req.prompt }]);
            let r = agent.post(format!("{base}/api/chat"));
            ollama_text(&send(r, json!({ "model": req.model, "messages": messages, "stream": false }))?)
        }
        _ => Err("Unknown provider".into()),
    }
}

/// Sends the prompt to the provider chosen in Settings and returns the answer text.
#[tauri::command]
pub async fn ask_ai(req: AskRequest) -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(move || ask_blocking(&req)).await.map_err(|e| e.to_string())?
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(key: &str, ts: i64, out: u64) -> Entry {
        Entry { ts, model: "claude-opus-5-5".into(), key: key.into(), tokens: [1, out, 0, 0] }
    }

    #[test]
    fn iso_timestamps_parse_to_unix_ms() {
        assert_eq!(parse_iso_ms("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(parse_iso_ms("2026-10-24T04:20:54.407Z"), Some(1_792_815_654_407));
        assert_eq!(parse_iso_ms("2024-02-29T12:00:00.5Z"), Some(1_709_208_000_500));
        assert_eq!(parse_iso_ms("nope"), None);
    }

    #[test]
    fn usage_is_deduped_by_message_id_and_request_id() {
        let line = |id: &str, req: &str, out: u64| {
            format!(r#"{{"type":"assistant","timestamp":"2026-10-24T04:00:00Z","requestId":"{req}","message":{{"id":"{id}","model":"claude-opus-5-5","usage":{{"input_tokens":3,"output_tokens":{out},"cache_creation_input_tokens":10,"cache_read_input_tokens":20}}}}}}"#)
        };
        let lines = [line("msg_1", "req_1", 5), line("msg_1", "req_1", 9), line("msg_2", "req_2", 4), line("msg_1", "req_9", 1)];
        let entries = dedupe(lines.iter().filter_map(|l| parse_usage_line(l)));
        assert_eq!(entries.len(), 3);
        let msg1 = entries.iter().find(|e| e.key == "msg_1:req_1").unwrap();
        assert_eq!(msg1.tokens, [3, 9, 10, 20]); // the last copy wins
        // Opus 5.5: 3×4 + 9×20 + 10×5 + 20×0.2 = 246 USD per million
        assert!((cost(msg1) - 246e-6).abs() < 1e-12);
        // requestRef stands in for requestId on newer logs; user lines are ignored.
        let newer = r#"{"type":"assistant","timestamp":"2026-10-24T04:00:00Z","requestRef":"r","message":{"id":"m","usage":{"output_tokens":2}}}"#;
        assert_eq!(parse_usage_line(newer).unwrap().key, "m:r");
        assert!(parse_usage_line(r#"{"type":"user","message":{"id":"m","usage":{}}}"#).is_none());
        assert_eq!(cost(&Entry { model: "gpt-9".into(), ..entry("x", 0, 5) }), 0.0);
    }

    #[test]
    fn five_hour_block_starts_after_a_gap_floored_to_the_hour() {
        let t = |h: i64, m: i64| h * HOUR + m * MINUTE;
        // 01:10 starts a block; 07:30 comes after a 6 h gap, so the current block starts at 07:00.
        let ts = [t(1, 10), t(2, 0), t(7, 30), t(8, 15)];
        assert_eq!(current_block_start(&ts, t(9, 0)), Some(t(7, 0)));
        // Past 12:00 the block has ended.
        assert_eq!(current_block_start(&ts, t(12, 1)), None);
        // Continuous use rolls into a new block when the previous one ends (01:00 → 06:00).
        let busy: Vec<i64> = (0..12).map(|i| t(1, 30) + i * 30 * MINUTE).collect();
        assert_eq!(current_block_start(&busy, t(7, 0)), Some(t(6, 0)));
        assert_eq!(current_block_start(&[], t(7, 0)), None);
    }

    #[test]
    fn state_comes_from_the_log_tail() {
        let lines = |v: &[&str]| v.iter().map(|s| s.to_string()).collect::<Vec<_>>();
        let tool_use = r#"{"type":"assistant","cwd":"/Users/me/code/notch","sessionId":"s1","message":{"stop_reason":"tool_use"}}"#;
        let end = r#"{"type":"assistant","cwd":"/Users/me/code/notch","sessionId":"s1","message":{"stop_reason":"end_turn"}}"#;
        let user = r#"{"type":"user","sessionId":"s1","message":{"role":"user"}}"#;
        let meta = r#"{"type":"user","isMeta":true,"message":{"role":"user"}}"#;
        let (state, cwd, sid) = claude_state(&lines(&[tool_use]));
        assert_eq!((state, project_name(&cwd).as_str(), sid.as_str()), (Some("working"), "notch", "s1"));
        assert_eq!(claude_state(&lines(&[tool_use, end])).0, Some("done"));
        assert_eq!(claude_state(&lines(&[end, user])).0, Some("working"));
        assert_eq!(claude_state(&lines(&[end, meta])).0, Some("done"));
        assert_eq!(claude_state(&lines(&["not json", r#"{"type":"summary"}"#])).0, None);
        assert_eq!(project_name(r"C:\Users\me\repo\"), "repo");

        let started = r#"{"type":"event_msg","payload":{"type":"task_started"}}"#;
        let complete = r#"{"type":"event_msg","payload":{"type":"task_complete"}}"#;
        assert_eq!(codex_state(&lines(&[started])), Some("working"));
        assert_eq!(codex_state(&lines(&[started, complete])), Some("done"));
    }

    #[test]
    fn codex_rate_limits_parse() {
        let line = r#"{"timestamp":"2026-09-15T07:57:21.537Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":20,"total_tokens":120}},"rate_limits":{"primary":{"used_percent":82.5,"window_minutes":300,"resets_at":1784685946},"secondary":{"used_percent":3.0,"window_minutes":10080,"resets_at":1785000000},"plan_type":"plus"}}}"#;
        let (ts, tokens, limits) = parse_codex_token_count(line).unwrap();
        assert_eq!(ts, parse_iso_ms("2026-09-15T07:57:21.537Z").unwrap());
        assert_eq!(tokens, 120);
        let l = limits.unwrap();
        assert_eq!(l.plan_type.as_deref(), Some("plus"));
        assert_eq!(l.primary, Some(RateWindow { used_percent: 82.5, window_minutes: 300, resets_at: 1784685946 }));
        assert_eq!(l.secondary.unwrap().window_minutes, 10080);
        // Null limits (API-key logins) still count tokens.
        let null = r#"{"timestamp":"2026-09-15T07:57:21Z","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":7,"output_tokens":3}},"rate_limits":{"primary":null,"secondary":null}}}"#;
        assert_eq!(parse_codex_token_count(null), Some((parse_iso_ms("2026-09-15T07:57:21Z").unwrap(), 10, None)));
    }

    #[test]
    fn hook_json_maps_to_state() {
        let ev = |name: &str| hook_event(&json!({ "hook_event_name": name, "session_id": "s", "cwd": "/a/b/proj", "message": "Claude needs your permission to use Bash" }));
        assert_eq!(ev("UserPromptSubmit").unwrap().state, "working");
        assert_eq!(ev("PreToolUse").unwrap().state, "working");
        let n = ev("Notification").unwrap();
        assert_eq!((n.state, n.project.as_str(), n.message.as_deref()), ("needs_you", "proj", Some("Claude needs your permission to use Bash")));
        assert_eq!(ev("Stop").unwrap().state, "done");
        assert!(ev("SessionStart").is_none());

        let headers = |host: &str| HashMap::from([("host".to_string(), host.to_string())]);
        let body = br#"{"hook_event_name":"Stop","session_id":"s","cwd":"/x"}"#;
        assert_eq!(route("POST /hook/claude HTTP/1.1", &headers("127.0.0.1:47823"), body).0, 204);
        assert!(route("POST /hook/claude HTTP/1.1", &headers("127.0.0.1:47823"), body).1.is_some());
        assert_eq!(route("POST /hook/claude HTTP/1.1", &headers("evil.example:47823"), body).0, 403);
        let mut browser = headers("127.0.0.1:47823");
        browser.insert("origin".into(), "https://evil.example".into());
        assert_eq!(route("POST /hook/claude HTTP/1.1", &browser, body).0, 403);
        assert_eq!(route("GET / HTTP/1.1", &headers("localhost:47823"), b"").0, 404);

        let raw = b"POST /hook/claude HTTP/1.1\r\nHost: 127.0.0.1:47823\r\nContent-Length: 2\r\n\r\n{}";
        let (line, h, b) = read_request(&mut &raw[..]).unwrap();
        assert_eq!((line.as_str(), h["host"].as_str(), b.as_slice()), ("POST /hook/claude HTTP/1.1", "127.0.0.1:47823", &b"{}"[..]));
    }

    #[test]
    fn settings_merge_keeps_other_hooks_and_remove_takes_only_ours() {
        let original = json!({
            "model": "opus",
            "hooks": {
                "Stop": [{ "hooks": [{ "type": "command", "command": "say done" }] }],
                "PostToolUse": [{ "matcher": "Edit", "hooks": [{ "type": "command", "command": "fmt" }] }]
            }
        });
        let installed = merge_hooks(original.clone()).unwrap();
        assert_eq!(installed["model"], "opus");
        assert_eq!(installed["hooks"]["PostToolUse"], original["hooks"]["PostToolUse"]);
        assert_eq!(installed["hooks"]["Stop"].as_array().unwrap().len(), 2);
        for ev in HOOK_EVENTS {
            assert!(installed["hooks"][ev].as_array().unwrap().iter().any(|g| is_ours(&g["hooks"][0])));
        }
        assert_eq!(merge_hooks(installed.clone()).unwrap(), installed, "install is idempotent");
        assert_eq!(strip_hooks(installed), original);
        assert_eq!(strip_hooks(merge_hooks(json!({})).unwrap()), json!({}));
        assert!(merge_hooks(json!([1])).is_err());
    }

    #[test]
    fn settings_file_gets_a_backup_and_is_left_alone_when_invalid() {
        let dir = std::env::temp_dir().join(format!("opennotchi-hooks-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("settings.json");
        fs::write(&path, r#"{"theme":"dark"}"#).unwrap();
        let d = dir.to_string_lossy().to_string();

        assert!(claude_hooks(d.clone(), true).unwrap());
        assert_eq!(fs::read_to_string(dir.join("settings.json.bak")).unwrap(), r#"{"theme":"dark"}"#);
        let first = fs::read_to_string(&path).unwrap();
        assert!(claude_hooks(d.clone(), true).unwrap());
        assert_eq!(fs::read_to_string(&path).unwrap(), first);
        assert!(!claude_hooks(d.clone(), false).unwrap());
        let after: Value = serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(after, json!({ "theme": "dark" }));

        fs::write(&path, "{ broken").unwrap();
        assert!(claude_hooks(d.clone(), true).is_err());
        assert_eq!(fs::read_to_string(&path).unwrap(), "{ broken");
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn provider_answers_parse() {
        let a = json!({ "content": [{ "type": "thinking", "thinking": "" }, { "type": "text", "text": " Hi " }], "stop_reason": "end_turn" });
        assert_eq!(anthropic_text(&a).unwrap(), "Hi");
        assert!(anthropic_text(&json!({ "content": [], "stop_reason": "refusal" })).is_err());
        assert_eq!(openai_text(&json!({ "choices": [{ "message": { "content": "Yo" } }] })).unwrap(), "Yo");
        assert_eq!(ollama_text(&json!({ "message": { "content": "Hey\n" } })).unwrap(), "Hey");
        assert_eq!(error_message(&json!({ "type": "error", "error": { "type": "x", "message": "bad key" } })).as_deref(), Some("bad key"));
        assert_eq!(error_message(&json!({ "error": "model not found" })).as_deref(), Some("model not found"));
    }

    /// Reads the real logs on this machine: `cargo test real_logs -- --ignored --nocapture`.
    #[test]
    #[ignore]
    fn real_logs() {
        let tz = std::env::var("TZ_OFFSET_MIN").ok().and_then(|v| v.parse().ok()).unwrap_or(0);
        let t = std::time::Instant::now();
        let accounts = vec![
            Account { name: "Claude Code".into(), tool: "claude".into(), dir: "~/.claude".into() },
            Account { name: "Codex".into(), tool: "codex".into(), dir: "~/.codex".into() },
        ];
        let reports: Vec<UsageReport> = accounts.iter().map(|a| if a.tool == "codex" { codex_report(a, now_ms(), tz) } else { claude_report(a, now_ms(), tz) }).collect();
        println!("first scan {:?}", t.elapsed());
        let t = std::time::Instant::now();
        let _ = claude_report(&accounts[0], now_ms(), tz);
        println!("rescan {:?}", t.elapsed());
        for r in &reports {
            println!("{r:#?}");
        }
        println!("{:#?}", agent_sessions(vec!["~/.claude".into()], vec!["~/.codex".into()]));
    }
}
