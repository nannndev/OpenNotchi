use serde_json::{json, Value};
use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

fn now_secs() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn extract_text(content: &Value) -> String {
    match content {
        Value::String(s) => s.clone(),
        Value::Array(arr) => {
            let mut out = String::new();
            for part in arr {
                if let Some(txt) = part.get("text").and_then(|t| t.as_str()) {
                    out.push_str(txt);
                }
            }
            out
        }
        _ => String::new(),
    }
}

// ---------------------------------------------------------------------
// OpenAI -> Codex Responses
// ---------------------------------------------------------------------
pub fn openai_to_codex(body: &Value, upstream_model: &str) -> Value {
    let mut system_parts = Vec::new();
    let mut items = Vec::new();

    if let Some(messages) = body.get("messages").and_then(|m| m.as_array()) {
        for m in messages {
            let role = m.get("role").and_then(|r| r.as_str()).unwrap_or("");
            if role == "system" || role == "developer" {
                let txt = extract_text(m.get("content").unwrap_or(&Value::Null));
                if !txt.is_empty() {
                    system_parts.push(txt);
                }
                continue;
            }
            if role == "tool" {
                items.push(json!({
                    "type": "function_call_output",
                    "call_id": m.get("tool_call_id").and_then(|t| t.as_str()).unwrap_or(""),
                    "output": extract_text(m.get("content").unwrap_or(&Value::Null)),
                }));
                continue;
            }
            let text = extract_text(m.get("content").unwrap_or(&Value::Null));
            if !text.is_empty() || role == "user" {
                items.push(json!({
                    "type": "message",
                    "role": role,
                    "content": [{
                        "type": if role == "assistant" { "output_text" } else { "input_text" },
                        "text": text,
                    }]
                }));
            }
            if role == "assistant" {
                if let Some(tool_calls) = m.get("tool_calls").and_then(|t| t.as_array()) {
                    for c in tool_calls {
                        let fn_obj = c.get("function").cloned().unwrap_or(json!({}));
                        items.push(json!({
                            "type": "function_call",
                            "call_id": c.get("id").and_then(|i| i.as_str()).unwrap_or(""),
                            "name": fn_obj.get("name").and_then(|n| n.as_str()).unwrap_or(""),
                            "arguments": fn_obj.get("arguments").and_then(|a| a.as_str()).unwrap_or("{}"),
                        }));
                    }
                }
            }
        }
    }

    let mut out = json!({
        "model": upstream_model,
        "instructions": system_parts.join("\n\n"),
        "input": items,
        "stream": true,
        "store": false,
        "include": [],
    });

    if let Some(tools) = body.get("tools").and_then(|t| t.as_array()) {
        if !tools.is_empty() {
            let mut codex_tools = Vec::new();
            for t in tools {
                if let Some(fn_obj) = t.get("function") {
                    codex_tools.push(json!({
                        "type": "function",
                        "name": fn_obj.get("name").unwrap_or(&json!("")),
                        "description": fn_obj.get("description").unwrap_or(&json!("")),
                        "parameters": fn_obj.get("parameters").unwrap_or(&json!({"type": "object", "properties": {}})),
                        "strict": false,
                    }));
                }
            }
            out["tools"] = Value::Array(codex_tools);
            out["parallel_tool_calls"] = json!(true);
        }
    }

    out
}

pub struct CodexStreamTranslator {
    pub public_model: String,
    pub id: String,
    pub created: u64,
    pub by_item: HashMap<String, usize>,
    pub tool_calls: Vec<Value>,
}

impl CodexStreamTranslator {
    pub fn new(public_model: String) -> Self {
        Self {
            public_model,
            id: format!("chatcmpl-{}", Uuid::new_v4().simple()),
            created: now_secs(),
            by_item: HashMap::new(),
            tool_calls: Vec::new(),
        }
    }

    pub fn start_chunk(&self) -> String {
        self.chunk_data(
            json!({
                "role": "assistant",
                "content": ""
            }),
            None,
        )
    }

    pub fn chunk_data(&self, delta: Value, finish_reason: Option<&str>) -> String {
        let frame = json!({
            "id": self.id,
            "object": "chat.completion.chunk",
            "created": self.created,
            "model": self.public_model,
            "choices": [{
                "index": 0,
                "delta": delta,
                "finish_reason": finish_reason,
            }]
        });
        format!("data: {}\n\n", serde_json::to_string(&frame).unwrap_or_default())
    }

    pub fn feed(&mut self, ev: &Value) -> Vec<String> {
        let mut chunks = Vec::new();
        let ev_type = ev.get("type").and_then(|t| t.as_str()).unwrap_or("");

        if ev_type == "response.output_text.delta" {
            if let Some(delta_str) = ev.get("delta").and_then(|d| d.as_str()) {
                if !delta_str.is_empty() {
                    chunks.push(self.chunk_data(json!({ "content": delta_str }), None));
                }
            }
        } else if ev_type == "response.output_item.added" {
            if let Some(item) = ev.get("item") {
                if item.get("type").and_then(|t| t.as_str()) == Some("function_call") {
                    let index = self.tool_calls.len();
                    let item_id = item.get("id").and_then(|i| i.as_str()).unwrap_or("");
                    let call_id = item.get("call_id").and_then(|c| c.as_str()).unwrap_or(item_id);
                    let name = item.get("name").and_then(|n| n.as_str()).unwrap_or("");
                    let args = item.get("arguments").and_then(|a| a.as_str()).unwrap_or("");

                    self.by_item.insert(item_id.to_string(), index);
                    self.tool_calls.push(json!({
                        "id": call_id,
                        "type": "function",
                        "function": { "name": name, "arguments": args },
                    }));

                    chunks.push(self.chunk_data(
                        json!({
                            "tool_calls": [{
                                "index": index,
                                "id": call_id,
                                "type": "function",
                                "function": { "name": name, "arguments": args },
                            }]
                        }),
                        None,
                    ));
                }
            }
        } else if ev_type == "response.function_call_arguments.delta" {
            if let Some(item_id) = ev.get("item_id").and_then(|i| i.as_str()) {
                if let Some(&index) = self.by_item.get(item_id) {
                    let delta_args = ev.get("delta").and_then(|d| d.as_str()).unwrap_or("");
                    chunks.push(self.chunk_data(
                        json!({
                            "tool_calls": [{
                                "index": index,
                                "function": { "arguments": delta_args }
                            }]
                        }),
                        None,
                    ));
                }
            }
        } else if ev_type == "response.completed" {
            chunks.push(self.chunk_data(json!({}), Some("stop")));
            chunks.push("data: [DONE]\n\n".to_string());
        }

        chunks
    }
}

// ---------------------------------------------------------------------
// OpenAI -> Anthropic Messages
// ---------------------------------------------------------------------
pub fn openai_to_anthropic(body: &Value, model: &str) -> Value {
    let mut system_parts = Vec::new();
    let mut turns = Vec::new();

    if let Some(messages) = body.get("messages").and_then(|m| m.as_array()) {
        for m in messages {
            let role = m.get("role").and_then(|r| r.as_str()).unwrap_or("");
            if role == "system" || role == "developer" {
                let txt = extract_text(m.get("content").unwrap_or(&Value::Null));
                if !txt.is_empty() {
                    system_parts.push(txt);
                }
                continue;
            }
            if role == "tool" {
                turns.push(json!({
                    "role": "user",
                    "content": [{
                        "type": "tool_result",
                        "tool_use_id": m.get("tool_call_id").and_then(|t| t.as_str()).unwrap_or(""),
                        "content": extract_text(m.get("content").unwrap_or(&Value::Null)),
                    }]
                }));
            } else if role == "assistant" {
                let mut blocks = Vec::new();
                let txt = extract_text(m.get("content").unwrap_or(&Value::Null));
                if !txt.is_empty() {
                    blocks.push(json!({ "type": "text", "text": txt }));
                }
                if let Some(calls) = m.get("tool_calls").and_then(|t| t.as_array()) {
                    for c in calls {
                        let fn_obj = c.get("function").cloned().unwrap_or(json!({}));
                        let args_str = fn_obj.get("arguments").and_then(|a| a.as_str()).unwrap_or("{}");
                        let args_val: Value = serde_json::from_str(args_str).unwrap_or(json!({}));
                        blocks.push(json!({
                            "type": "tool_use",
                            "id": c.get("id").and_then(|i| i.as_str()).unwrap_or(&format!("toolu_{}", Uuid::new_v4().simple())),
                            "name": fn_obj.get("name").and_then(|n| n.as_str()).unwrap_or(""),
                            "input": args_val,
                        }));
                    }
                }
                turns.push(json!({ "role": "assistant", "content": blocks }));
            } else {
                let txt = extract_text(m.get("content").unwrap_or(&Value::Null));
                turns.push(json!({
                    "role": "user",
                    "content": [{ "type": "text", "text": txt }],
                }));
            }
        }
    }

    let max_tokens = body.get("max_tokens").or_else(|| body.get("max_completion_tokens")).and_then(|v| v.as_u64()).unwrap_or(8192);

    let mut out = json!({
        "model": model,
        "messages": turns,
        "max_tokens": max_tokens,
    });

    if !system_parts.is_empty() {
        out["system"] = json!(system_parts.join("\n\n"));
    }
    if let Some(temp) = body.get("temperature") {
        out["temperature"] = temp.clone();
    }
    if let Some(tools) = body.get("tools").and_then(|t| t.as_array()) {
        let mut anthropic_tools = Vec::new();
        for t in tools {
            if let Some(fn_obj) = t.get("function") {
                anthropic_tools.push(json!({
                    "name": fn_obj.get("name").unwrap_or(&json!("")),
                    "description": fn_obj.get("description").unwrap_or(&json!("")),
                    "input_schema": fn_obj.get("parameters").unwrap_or(&json!({"type": "object", "properties": {}})),
                }));
            }
        }
        if !anthropic_tools.is_empty() {
            out["tools"] = Value::Array(anthropic_tools);
        }
    }

    out
}

// ---------------------------------------------------------------------
// Subscription providers (ported from 7server's formats.ts)
// ---------------------------------------------------------------------
/// Claude OAuth tokens are only accepted for requests that identify as Claude Code.
pub const CLAUDE_CODE_SYSTEM: &str = "You are Claude Code, Anthropic's official CLI for Claude.";

pub fn openai_to_claude_oauth(body: &Value, model: &str) -> Value {
    let mut out = openai_to_anthropic(body, model);
    let mut system = vec![json!({ "type": "text", "text": CLAUDE_CODE_SYSTEM })];
    if let Some(sys) = out.get("system").and_then(|v| v.as_str()) {
        system.push(json!({ "type": "text", "text": sys }));
    }
    out["system"] = json!(system);
    out["stream"] = json!(true);
    out
}

pub fn openai_to_gemini(body: &Value, model: &str, project: Option<&str>) -> Value {
    let msgs = body.get("messages").and_then(|m| m.as_array()).cloned().unwrap_or_default();
    let name_of = |id: &str| -> String {
        for m in &msgs {
            for c in m.get("tool_calls").and_then(|t| t.as_array()).into_iter().flatten() {
                if c["id"].as_str() == Some(id) {
                    return c["function"]["name"].as_str().unwrap_or("tool").to_string();
                }
            }
        }
        "tool".into()
    };
    let mut sys = Vec::new();
    let mut contents: Vec<Value> = Vec::new();
    for m in &msgs {
        let role = m["role"].as_str().unwrap_or("");
        let text = extract_text(m.get("content").unwrap_or(&Value::Null));
        let (grole, parts) = match role {
            "system" | "developer" => {
                if !text.is_empty() {
                    sys.push(text);
                }
                continue;
            }
            "tool" => {
                let resp = serde_json::from_str::<Value>(&text).ok().filter(|v| v.is_object()).unwrap_or(json!({ "result": text }));
                (
                    "user",
                    vec![json!({ "functionResponse": { "name": name_of(m["tool_call_id"].as_str().unwrap_or("")), "response": resp } })],
                )
            }
            "assistant" => {
                let mut p = Vec::new();
                if !text.is_empty() {
                    p.push(json!({ "text": text }));
                }
                for c in m.get("tool_calls").and_then(|t| t.as_array()).into_iter().flatten() {
                    let args: Value = serde_json::from_str(c["function"]["arguments"].as_str().unwrap_or("{}")).unwrap_or(json!({}));
                    p.push(json!({ "functionCall": { "name": c["function"]["name"], "args": args } }));
                }
                ("model", p)
            }
            _ => ("user", vec![json!({ "text": text })]),
        };
        if parts.is_empty() {
            continue;
        }
        // Gemini needs alternating turns: merge same-role neighbours.
        match contents.last_mut() {
            Some(last) if last["role"] == grole => {
                if let Some(existing) = last["parts"].as_array_mut() {
                    existing.extend(parts);
                }
            }
            _ => contents.push(json!({ "role": grole, "parts": parts })),
        }
    }
    let mut request = json!({ "contents": contents, "generationConfig": {} });
    if !sys.is_empty() {
        request["systemInstruction"] = json!({ "parts": [{ "text": sys.join("\n\n") }] });
    }
    if let Some(mt) = body.get("max_tokens").or_else(|| body.get("max_completion_tokens")) {
        request["generationConfig"]["maxOutputTokens"] = mt.clone();
    }
    if let Some(t) = body.get("temperature") {
        request["generationConfig"]["temperature"] = t.clone();
    }
    let decls: Vec<Value> = body.get("tools").and_then(|t| t.as_array()).into_iter().flatten()
        .filter_map(|t| t.get("function"))
        .map(|f| json!({ "name": f["name"], "description": f.get("description").cloned().unwrap_or(json!("")), "parameters": f.get("parameters").cloned().unwrap_or(json!({ "type": "object", "properties": {} })) }))
        .collect();
    if !decls.is_empty() {
        request["tools"] = json!([{ "functionDeclarations": decls }]);
    }
    json!({ "model": model, "project": project, "request": request })
}

// ---------------------------------------------------------------------
// OpenAI -> Command Code (/alpha/generate, AI-SDK style messages)
// ---------------------------------------------------------------------
fn commandcode_user_parts(content: &Value) -> Vec<Value> {
    let mut out = Vec::new();
    match content {
        Value::String(t) => out.push(json!({ "type": "text", "text": t })),
        Value::Array(parts) => {
            for p in parts {
                if let Some(t) = p.as_str() {
                    out.push(json!({ "type": "text", "text": t }));
                } else if p["type"] == "text" {
                    out.push(json!({ "type": "text", "text": p["text"].as_str().unwrap_or("") }));
                } else if p["type"] == "image_url" {
                    let url = p["image_url"]["url"].as_str().or(p["image_url"].as_str()).unwrap_or("");
                    // Only inline data URLs are forwarded, as 9router does.
                    if let Some(rest) = url.strip_prefix("data:") {
                        let mime = rest.split(';').next().unwrap_or("image/png");
                        out.push(json!({ "type": "image", "image": url, "mimeType": mime, "mediaType": mime }));
                    }
                }
            }
        }
        _ => {}
    }
    if out.is_empty() {
        out.push(json!({ "type": "text", "text": "" }));
    }
    out
}

/// Builds a Command Code generate request. `thread_id` should be stable per conversation.
pub fn openai_to_commandcode(body: &Value, model: &str, thread_id: &str) -> Value {
    let mut system = Vec::new();
    let mut messages = Vec::new();
    let mut tool_names: HashMap<String, String> = HashMap::new();
    let msgs = body["messages"].as_array().cloned().unwrap_or_default();
    for m in &msgs {
        for c in m["tool_calls"].as_array().into_iter().flatten() {
            if let (Some(id), Some(name)) = (c["id"].as_str(), c["function"]["name"].as_str()) {
                tool_names.insert(id.to_string(), name.to_string());
            }
        }
    }
    for m in &msgs {
        match m["role"].as_str().unwrap_or("user") {
            "system" | "developer" => {
                let t = extract_text(&m["content"]);
                if !t.is_empty() {
                    system.push(t);
                }
            }
            "tool" => {
                let id = m["tool_call_id"].as_str().unwrap_or("");
                let name = m["name"].as_str().map(String::from).or_else(|| tool_names.get(id).cloned()).unwrap_or_else(|| "unknown".into());
                let text = m["content"].as_str().map(String::from).unwrap_or_else(|| extract_text(&m["content"]));
                messages.push(json!({ "role": "tool", "content": [{
                    "type": "tool-result", "toolCallId": id, "toolName": name,
                    "output": { "type": "text", "value": text },
                }]}));
            }
            "assistant" => {
                let mut parts = Vec::new();
                if let Some(r) = m["reasoning_content"].as_str().filter(|r| !r.trim().is_empty()) {
                    parts.push(json!({ "type": "reasoning", "text": r }));
                }
                let t = extract_text(&m["content"]);
                if !t.is_empty() {
                    parts.push(json!({ "type": "text", "text": t }));
                }
                for c in m["tool_calls"].as_array().into_iter().flatten() {
                    let args = &c["function"]["arguments"];
                    let input = match args {
                        Value::String(raw) if raw.trim().is_empty() => json!({}),
                        Value::String(raw) => {
                            serde_json::from_str::<Value>(raw).ok().filter(|v| v.is_object()).unwrap_or_else(|| json!({ "raw": raw }))
                        }
                        Value::Null => json!({}),
                        other => other.clone(),
                    };
                    parts.push(json!({ "type": "tool-call", "toolCallId": c["id"].as_str().unwrap_or(""),
                        "toolName": c["function"]["name"].as_str().unwrap_or(""), "input": input }));
                }
                if parts.is_empty() {
                    parts.push(json!({ "type": "text", "text": "" }));
                }
                messages.push(json!({ "role": "assistant", "content": parts }));
            }
            _ => messages.push(json!({ "role": "user", "content": commandcode_user_parts(&m["content"]) })),
        }
    }
    let mut params = json!({
        "model": model,
        "messages": messages,
        "stream": true,
        "max_tokens": body["max_tokens"].as_u64().or(body["max_completion_tokens"].as_u64()).unwrap_or(64_000),
        "temperature": body["temperature"].as_f64().unwrap_or(0.3),
    });
    if !system.is_empty() {
        params["system"] = json!(system.join("\n\n"));
    }
    if let Some(p) = body.get("top_p").filter(|v| !v.is_null()) {
        params["top_p"] = p.clone();
    }
    if let Some(e) = body["reasoning_effort"].as_str().or(body["reasoning"]["effort"].as_str()) {
        params["reasoning_effort"] = json!(e);
    }
    let tools: Vec<Value> = body["tools"].as_array().into_iter().flatten().filter_map(|t| {
        let f = &t["function"];
        f["name"].as_str().map(|n| json!({ "name": n, "description": f["description"], "input_schema": if f["parameters"].is_null() { json!({"type":"object"}) } else { f["parameters"].clone() } }))
    }).collect();
    if !tools.is_empty() {
        params["tools"] = json!(tools);
    }
    json!({
        "threadId": thread_id,
        "memory": null, "taste": null, "skills": null,
        "permissionMode": "standard",
        "config": {
            "workingDir": "/", "date": chrono::Utc::now().format("%Y-%m-%d").to_string(),
            "environment": std::env::consts::OS, "structure": [], "isGitRepo": false,
            "currentBranch": "", "mainBranch": "", "gitStatus": "", "recentCommits": [],
        },
        "params": params,
    })
}

/// Reshapes a Gemini CLI body into what Antigravity's Cloud Code endpoint expects.
pub fn antigravity_envelope(b: &mut Value, default_signature: &str) {
    if b["project"].is_null() {
        // 9router invents a project id when onboarding gave none.
        b["project"] = json!(format!("useful-fuze-{}", &Uuid::new_v4().simple().to_string()[..5]));
    }
    b["userAgent"] = json!("antigravity");
    b["requestId"] = json!(format!("agent/{}/{}/{}/1", Uuid::new_v4(), chrono::Utc::now().timestamp_millis(), Uuid::new_v4()));
    let r = &mut b["request"];
    r["sessionId"] = json!(Uuid::new_v4().to_string());
    if let Some(n) = r["generationConfig"]["maxOutputTokens"].as_u64() {
        r["generationConfig"]["maxOutputTokens"] = json!(n.min(64_000));
    }
    if r["tools"].is_array() {
        r["toolConfig"] = json!({ "functionCallingConfig": { "mode": "VALIDATED" } });
        for d in r["tools"][0]["functionDeclarations"].as_array_mut().into_iter().flatten() {
            let clean: String = d["name"]
                .as_str()
                .unwrap_or("tool")
                .chars()
                .map(|c| if c.is_ascii_alphanumeric() || "_.:-".contains(c) { c } else { '_' })
                .take(64)
                .collect();
            d["name"] = json!(clean);
        }
    }
    // The first function call of each model turn must carry a thought signature.
    for turn in r["contents"].as_array_mut().into_iter().flatten() {
        let mut first = true;
        for part in turn["parts"].as_array_mut().into_iter().flatten() {
            if part.get("functionCall").is_some() {
                if first && part.get("thoughtSignature").is_none() {
                    part["thoughtSignature"] = json!(default_signature);
                }
                first = false;
            }
        }
    }
}

/// Translates a provider's SSE events into OpenAI chat.completion.chunk frames.
pub struct SseToOpenAi {
    pub base: CodexStreamTranslator,
    kind: &'static str,
    claude_tools: HashMap<u64, usize>,
    tool_count: usize,
    finished: bool,
    /// (input, output) tokens reported by the upstream, if any. Input includes cached tokens.
    pub usage: (i64, i64),
    /// Input tokens served from the provider's prompt cache (part of `usage.0`).
    pub cached: i64,
    cc_tools: HashMap<String, usize>,
    cc_finish: Option<String>,
}

impl SseToOpenAi {
    pub fn new(kind: &'static str, public_model: String) -> Self {
        Self {
            base: CodexStreamTranslator::new(public_model),
            kind,
            claude_tools: HashMap::new(),
            tool_count: 0,
            finished: false,
            usage: (0, 0),
            cached: 0,
            cc_tools: HashMap::new(),
            cc_finish: None,
        }
    }

    pub fn is_kiro(&self) -> bool {
        self.kind == "kiro"
    }

    pub fn kind_passthrough(&self) -> bool {
        self.kind == "openai"
    }

    fn tool_frame(&self, index: usize, id: Option<&str>, name: Option<&str>, args: &str) -> String {
        let mut call = json!({ "index": index, "function": { "arguments": args } });
        if let (Some(id), Some(name)) = (id, name) {
            call["id"] = json!(id);
            call["type"] = json!("function");
            call["function"]["name"] = json!(name);
        }
        self.base.chunk_data(json!({ "tool_calls": [call] }), None)
    }

    fn finish(&mut self, reason: &str) -> Vec<String> {
        if self.finished {
            return vec![];
        }
        self.finished = true;
        let reason = if self.tool_count > 0 { "tool_calls" } else { reason };
        vec![self.base.chunk_data(json!({}), Some(reason)), "data: [DONE]\n\n".to_string()]
    }

    /// Err carries an upstream error event.
    pub fn feed(&mut self, ev: &Value) -> Result<Vec<String>, String> {
        let mut out = Vec::new();
        if self.kind == "openai" {
            // Pass-through; just note usage (sent when stream_options.include_usage is set).
            if let Some(u) = ev.get("usage").filter(|u| u.is_object()) {
                self.usage = (u["prompt_tokens"].as_i64().unwrap_or(0), u["completion_tokens"].as_i64().unwrap_or(0));
                self.cached = u["prompt_tokens_details"]["cached_tokens"].as_i64().unwrap_or(0);
            }
            if let Some(e) = ev.get("error") {
                return Err(e["message"].as_str().unwrap_or("Upstream error").to_string());
            }
            out.push(format!("data: {}\n\n", ev));
        } else if self.kind == "codex" {
            match ev["type"].as_str().unwrap_or("") {
                "response.completed" => {
                    let u = &ev["response"]["usage"];
                    self.usage = (u["input_tokens"].as_i64().unwrap_or(0), u["output_tokens"].as_i64().unwrap_or(0));
                    self.cached = u["input_tokens_details"]["cached_tokens"].as_i64().unwrap_or(0);
                    self.tool_count = self.base.tool_calls.len();
                    let reason = if ev["response"]["incomplete_details"]["reason"] == "max_output_tokens" { "length" } else { "stop" };
                    out.extend(self.finish(reason));
                }
                "response.failed" | "error" => {
                    let e = ev["response"]["error"]["message"].as_str().or(ev["message"].as_str()).or(ev["error"]["message"].as_str());
                    return Err(e.unwrap_or("Codex error").to_string());
                }
                _ => out.extend(self.base.feed(ev)),
            }
        } else if self.kind == "commandcode" {
            match ev["type"].as_str().unwrap_or("") {
                "text-delta" => {
                    if let Some(t) = ev["text"].as_str().or(ev["delta"].as_str()).filter(|t| !t.is_empty()) {
                        out.push(self.base.chunk_data(json!({ "content": t }), None));
                    }
                }
                "reasoning-delta" => {
                    if let Some(t) = ev["text"].as_str().filter(|t| !t.is_empty()) {
                        out.push(self.base.chunk_data(json!({ "reasoning_content": t }), None));
                    }
                }
                "tool-input-start" | "tool-call" => {
                    let id = ev["id"].as_str().or(ev["toolCallId"].as_str()).unwrap_or("").to_string();
                    if !self.cc_tools.contains_key(&id) {
                        let idx = self.tool_count;
                        self.tool_count += 1;
                        self.cc_tools.insert(id.clone(), idx);
                        // A whole tool-call carries its input; a streamed one sends it as deltas.
                        let args = if ev["type"] == "tool-call" {
                            ev["input"].as_str().map(String::from).unwrap_or_else(|| ev["input"].to_string())
                        } else {
                            String::new()
                        };
                        out.push(self.tool_frame(idx, Some(&id), ev["toolName"].as_str(), &args));
                    }
                }
                "tool-input-delta" => {
                    let id = ev["id"].as_str().or(ev["toolCallId"].as_str()).unwrap_or("");
                    if let Some(&idx) = self.cc_tools.get(id) {
                        out.push(self.tool_frame(idx, None, None, ev["delta"].as_str().or(ev["inputTextDelta"].as_str()).unwrap_or("")));
                    }
                }
                "finish-step" | "finish" => {
                    let u = if ev["type"] == "finish" && ev["totalUsage"].is_object() { &ev["totalUsage"] } else { &ev["usage"] };
                    if u.is_object() {
                        self.usage = (u["inputTokens"].as_i64().unwrap_or(0), u["outputTokens"].as_i64().unwrap_or(0));
                        self.cached = u["inputTokenDetails"]["cacheReadTokens"].as_i64().unwrap_or(0);
                    }
                    if let Some(r) = ev["finishReason"].as_str() {
                        self.cc_finish = Some(r.to_string());
                    }
                    if ev["type"] == "finish" {
                        let reason = match self.cc_finish.as_deref().unwrap_or("stop") {
                            "length" => "length",
                            "content-filter" => "content_filter",
                            _ => "stop", // tool calls are detected by finish() itself
                        };
                        out.extend(self.finish(reason));
                    }
                }
                "error" => {
                    let e = &ev["error"];
                    let msg = e
                        .as_str()
                        .map(String::from)
                        .or_else(|| e["message"].as_str().map(String::from))
                        .or_else(|| ev["message"].as_str().map(String::from))
                        .unwrap_or_else(|| e.to_string());
                    return Err(format!("Command Code: {msg}"));
                }
                _ => {}
            }
        } else if self.kind == "claude" {
            match ev["type"].as_str().unwrap_or("") {
                "message_start" => {
                    let u = &ev["message"]["usage"];
                    self.cached = u["cache_read_input_tokens"].as_i64().unwrap_or(0);
                    self.usage.0 =
                        u["input_tokens"].as_i64().unwrap_or(0) + self.cached + u["cache_creation_input_tokens"].as_i64().unwrap_or(0);
                }
                "content_block_start" if ev["content_block"]["type"] == "tool_use" => {
                    let idx = self.tool_count;
                    self.claude_tools.insert(ev["index"].as_u64().unwrap_or(0), idx);
                    self.tool_count += 1;
                    out.push(self.tool_frame(idx, ev["content_block"]["id"].as_str(), ev["content_block"]["name"].as_str(), ""));
                }
                "content_block_delta" => {
                    let d = &ev["delta"];
                    if d["type"] == "text_delta" {
                        if let Some(t) = d["text"].as_str().filter(|t| !t.is_empty()) {
                            out.push(self.base.chunk_data(json!({ "content": t }), None));
                        }
                    } else if d["type"] == "input_json_delta" {
                        if let Some(&idx) = self.claude_tools.get(&ev["index"].as_u64().unwrap_or(0)) {
                            out.push(self.tool_frame(idx, None, None, d["partial_json"].as_str().unwrap_or("")));
                        }
                    }
                }
                "message_delta" => {
                    if let Some(o) = ev["usage"]["output_tokens"].as_i64() {
                        self.usage.1 = o;
                    }
                    if let Some(r) = ev["delta"]["stop_reason"].as_str() {
                        out.extend(self.finish(if r == "max_tokens" { "length" } else { "stop" }));
                    }
                }
                "message_stop" => out.extend(self.finish("stop")),
                "error" => return Err(ev["error"]["message"].as_str().unwrap_or("Claude error").to_string()),
                _ => {}
            }
        } else {
            // gemini: events are {response:{candidates:[...]}}; function calls arrive whole.
            let r = ev.get("response").unwrap_or(ev);
            if let Some(u) = r.get("usageMetadata") {
                self.usage = (
                    u["promptTokenCount"].as_i64().unwrap_or(0),
                    u["candidatesTokenCount"].as_i64().unwrap_or(0) + u["thoughtsTokenCount"].as_i64().unwrap_or(0),
                );
                self.cached = u["cachedContentTokenCount"].as_i64().unwrap_or(0);
            }
            let cand = &r["candidates"][0];
            for part in cand["content"]["parts"].as_array().into_iter().flatten() {
                if part["thought"] == true {
                    continue;
                }
                if let Some(t) = part["text"].as_str().filter(|t| !t.is_empty()) {
                    out.push(self.base.chunk_data(json!({ "content": t }), None));
                }
                if let Some(fc) = part.get("functionCall") {
                    let idx = self.tool_count;
                    self.tool_count += 1;
                    let id = format!("call_{}_{}", idx, Uuid::new_v4().simple());
                    let args = serde_json::to_string(fc.get("args").unwrap_or(&json!({}))).unwrap_or_default();
                    out.push(self.tool_frame(idx, Some(&id), fc["name"].as_str(), &args));
                }
            }
            if let Some(fr) = cand["finishReason"].as_str() {
                out.extend(self.finish(if fr == "MAX_TOKENS" { "length" } else { "stop" }));
            }
            if let Some(e) = ev.get("error") {
                return Err(e["message"].as_str().unwrap_or("Gemini error").to_string());
            }
        }
        Ok(out)
    }

    /// Called when the upstream stream ends, in case it never sent a stop event.
    pub fn end(&mut self) -> Vec<String> {
        if self.kind == "openai" {
            // Upstream already sent its own finish chunk; only the [DONE] line (not JSON) was dropped.
            if self.finished {
                return vec![];
            }
            self.finished = true;
            return vec!["data: [DONE]\n\n".to_string()];
        }
        self.finish("stop")
    }
}

/// Folds OpenAI chat.completion.chunk SSE frames into one non-streaming chat.completion.
pub fn aggregate_sse(sse: &str, usage: (i64, i64)) -> Value {
    let (mut id, mut model, mut created) = (Value::Null, Value::Null, json!(now_secs()));
    let mut content = String::new();
    let mut finish = Value::Null;
    let mut tools: Vec<Value> = Vec::new();
    for line in sse.lines() {
        let Some(data) = line.trim().strip_prefix("data:") else { continue };
        let Ok(ev) = serde_json::from_str::<Value>(data.trim()) else { continue };
        if id.is_null() {
            id = ev["id"].clone();
            model = ev["model"].clone();
            created = ev["created"].clone();
        }
        let ch = &ev["choices"][0];
        if let Some(t) = ch["delta"]["content"].as_str() {
            content.push_str(t);
        }
        if !ch["finish_reason"].is_null() {
            finish = ch["finish_reason"].clone();
        }
        for tc in ch["delta"]["tool_calls"].as_array().into_iter().flatten() {
            let i = tc["index"].as_u64().unwrap_or(0) as usize;
            while tools.len() <= i {
                tools.push(json!({ "id": "", "type": "function", "function": { "name": "", "arguments": "" } }));
            }
            if let Some(v) = tc["id"].as_str() {
                tools[i]["id"] = json!(v);
            }
            if let Some(v) = tc["function"]["name"].as_str() {
                tools[i]["function"]["name"] = json!(v);
            }
            if let Some(v) = tc["function"]["arguments"].as_str() {
                let cur = tools[i]["function"]["arguments"].as_str().unwrap_or("").to_string();
                tools[i]["function"]["arguments"] = json!(cur + v);
            }
        }
    }
    let mut message = json!({ "role": "assistant", "content": content });
    if !tools.is_empty() {
        message["tool_calls"] = json!(tools);
    }
    json!({
        "id": id, "object": "chat.completion", "created": created, "model": model,
        "choices": [{ "index": 0, "message": message, "finish_reason": if finish.is_null() { json!("stop") } else { finish } }],
        "usage": { "prompt_tokens": usage.0, "completion_tokens": usage.1, "total_tokens": usage.0 + usage.1 },
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Feeds events in order and returns every frame produced, joined.
    fn feed_all(t: &mut SseToOpenAi, events: &[Value]) -> String {
        events.iter().map(|e| t.feed(e).unwrap().concat()).collect()
    }

    mod openai_to_codex {
        use super::*;

        fn sample() -> Value {
            openai_to_codex(
                &json!({"messages":[{"role":"system","content":"You are Beacon AI."},{"role":"user","content":"Hello world"}]}),
                "gpt-5.6-terra",
            )
        }

        #[test]
        fn uses_the_upstream_model_name() {
            assert_eq!(sample()["model"], "gpt-5.6-terra");
        }

        #[test]
        fn moves_system_messages_into_instructions() {
            assert_eq!(sample()["instructions"], "You are Beacon AI.");
        }

        #[test]
        fn keeps_only_non_system_turns_as_input() {
            assert_eq!(sample()["input"], json!([{"type":"message","role":"user","content":[{"type":"input_text","text":"Hello world"}]}]));
        }
    }

    mod openai_to_anthropic {
        use super::*;

        fn sample() -> Value {
            openai_to_anthropic(
                &json!({"messages":[{"role":"system","content":"System prompt"},{"role":"user","content":"Ping"}]}),
                "claude-sonnet-5-5",
            )
        }

        #[test]
        fn moves_system_messages_into_the_system_field() {
            assert_eq!(sample()["system"], "System prompt");
        }

        #[test]
        fn keeps_only_non_system_turns_as_messages() {
            assert_eq!(sample()["messages"].as_array().map(Vec::len), Some(1));
        }
    }

    mod openai_to_claude_oauth {
        use super::*;

        fn sample() -> Value {
            openai_to_claude_oauth(
                &json!({"messages":[{"role":"system","content":"Be terse"},{"role":"user","content":"Ping"}]}),
                "claude-sonnet-5-5",
            )
        }

        #[test]
        fn leads_the_system_prompt_with_the_claude_code_identity() {
            assert_eq!(sample()["system"][0]["text"], CLAUDE_CODE_SYSTEM);
        }

        #[test]
        fn keeps_the_callers_system_prompt_after_the_identity() {
            assert_eq!(sample()["system"][1]["text"], "Be terse");
        }

        #[test]
        fn always_streams() {
            assert_eq!(sample()["stream"], true);
        }
    }

    mod openai_to_gemini {
        use super::*;

        #[test]
        fn merges_consecutive_same_role_turns() {
            let g = openai_to_gemini(
                &json!({"messages":[{"role":"user","content":"a"},{"role":"user","content":"b"}]}),
                "gemini-2.5-flash",
                Some("proj"),
            );
            assert_eq!(g["request"]["contents"].as_array().map(Vec::len), Some(1));
        }

        #[test]
        fn wraps_the_request_with_the_project() {
            let g = openai_to_gemini(&json!({"messages":[]}), "gemini-2.5-flash", Some("proj"));
            assert_eq!(g["project"], "proj");
        }
    }

    mod antigravity_envelope {
        use super::*;

        fn sample() -> Value {
            let mut b = openai_to_gemini(
                &json!({"max_tokens":200000,"messages":[{"role":"user","content":"a"},
                {"role":"assistant","tool_calls":[{"id":"1","function":{"name":"x","arguments":"{}"}},{"id":"2","function":{"name":"y","arguments":"{}"}}]}],
                "tools":[{"function":{"name":"my tool!","parameters":{}}}]}),
                "m",
                None,
            );
            antigravity_envelope(&mut b, "SIG");
            b
        }

        #[test]
        fn invents_a_project_when_none_is_known() {
            let b = sample();
            assert!(b["project"].as_str().is_some_and(|p| p.starts_with("useful-fuze-")), "project: {}", b["project"]);
        }

        #[test]
        fn caps_max_output_tokens_at_64k() {
            assert_eq!(sample()["request"]["generationConfig"]["maxOutputTokens"], 64000);
        }

        #[test]
        fn replaces_disallowed_characters_in_tool_names() {
            assert_eq!(sample()["request"]["tools"][0]["functionDeclarations"][0]["name"], "my_tool_");
        }

        #[test]
        fn signs_the_first_function_call_of_a_turn() {
            assert_eq!(sample()["request"]["contents"][1]["parts"][0]["thoughtSignature"], "SIG");
        }

        #[test]
        fn leaves_later_function_calls_unsigned() {
            assert!(sample()["request"]["contents"][1]["parts"][1].get("thoughtSignature").is_none());
        }
    }

    mod openai_to_commandcode {
        use super::*;

        fn sample() -> Value {
            openai_to_commandcode(
                &json!({"messages":[
                    {"role":"system","content":"Be brief"},
                    {"role":"user","content":"hi"},
                    {"role":"assistant","content":"","tool_calls":[{"id":"c1","type":"function","function":{"name":"ls","arguments":"{\"p\":1}"}}]},
                    {"role":"tool","tool_call_id":"c1","content":"ok"}
                ],"tools":[{"type":"function","function":{"name":"ls","parameters":{"type":"object"}}}]}),
                "deepseek/deepseek-v4-pro",
                "t-1",
            )
        }

        #[test]
        fn carries_the_thread_id() {
            assert_eq!(sample()["threadId"], "t-1");
        }

        #[test]
        fn moves_system_messages_into_params_system() {
            assert_eq!(sample()["params"]["system"], "Be brief");
        }

        #[test]
        fn parses_tool_call_arguments_into_objects() {
            assert_eq!(sample()["params"]["messages"][1]["content"][0]["input"]["p"], 1);
        }

        #[test]
        fn recovers_the_tool_name_for_tool_results_from_the_call_id() {
            assert_eq!(sample()["params"]["messages"][2]["content"][0]["toolName"], "ls");
        }

        #[test]
        fn converts_tools_to_input_schema() {
            assert_eq!(sample()["params"]["tools"][0]["input_schema"]["type"], "object");
        }
    }

    mod sse_claude {
        use super::*;

        #[test]
        fn text_deltas_become_content_chunks() {
            let mut t = SseToOpenAi::new("claude", "cc/x".into());
            let out = feed_all(&mut t, &[json!({"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}})]);
            assert!(out.contains("\"content\":\"Hi\""), "{out}");
        }

        #[test]
        fn tool_use_blocks_become_numbered_tool_calls() {
            let mut t = SseToOpenAi::new("claude", "cc/x".into());
            let out = feed_all(
                &mut t,
                &[json!({"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_1","name":"probe"}})],
            );
            assert!(out.contains("\"name\":\"probe\"") && out.contains("\"index\":0"), "{out}");
        }

        #[test]
        fn tool_use_stop_finishes_with_tool_calls_and_done() {
            let mut t = SseToOpenAi::new("claude", "cc/x".into());
            let out = feed_all(
                &mut t,
                &[
                    json!({"type":"content_block_start","index":1,"content_block":{"type":"tool_use","id":"toolu_1","name":"probe"}}),
                    json!({"type":"message_delta","delta":{"stop_reason":"tool_use"}}),
                ],
            );
            assert!(out.contains("\"finish_reason\":\"tool_calls\"") && out.ends_with("data: [DONE]\n\n"), "{out}");
        }

        #[test]
        fn end_adds_nothing_after_the_stream_finished() {
            let mut t = SseToOpenAi::new("claude", "cc/x".into());
            feed_all(&mut t, &[json!({"type":"message_stop"})]);
            assert!(t.end().is_empty());
        }

        #[test]
        fn error_events_become_errors() {
            let mut t = SseToOpenAi::new("claude", "cc/x".into());
            assert!(t.feed(&json!({"type":"error","error":{"message":"overloaded"}})).is_err());
        }
    }

    mod sse_codex {
        use super::*;

        fn finished() -> (SseToOpenAi, String) {
            super::sse_codex_finished()
        }

        #[test]
        fn records_usage_from_response_completed() {
            assert_eq!(finished().0.usage, (7, 3));
        }

        #[test]
        fn end_adds_nothing_after_response_completed() {
            assert!(finished().0.end().is_empty());
        }

        #[test]
        fn response_failed_becomes_an_error() {
            let mut t = SseToOpenAi::new("codex", "cx/gpt-5".into());
            assert!(t.feed(&json!({"type":"response.failed","response":{"error":{"message":"boom"}}})).is_err());
        }
    }

    mod sse_commandcode {
        use super::*;

        fn new() -> SseToOpenAi {
            SseToOpenAi::new("commandcode", "cmc/x".into())
        }

        #[test]
        fn text_deltas_become_content_chunks() {
            let out = feed_all(&mut new(), &[json!({"type":"text-delta","text":"Hi"})]);
            assert!(out.contains("\"content\":\"Hi\""), "{out}");
        }

        #[test]
        fn reasoning_deltas_become_reasoning_content() {
            let out = feed_all(&mut new(), &[json!({"type":"reasoning-delta","text":"hmm"})]);
            assert!(out.contains("\"reasoning_content\":\"hmm\""), "{out}");
        }

        #[test]
        fn a_tool_call_after_streamed_input_is_not_emitted_twice() {
            let mut t = new();
            feed_all(
                &mut t,
                &[json!({"type":"tool-input-start","id":"k1","toolName":"ls"}), json!({"type":"tool-input-delta","id":"k1","delta":"{}"})],
            );
            assert!(t.feed(&json!({"type":"tool-call","toolCallId":"k1","toolName":"ls","input":{}})).unwrap().is_empty());
        }

        #[test]
        fn finish_after_tool_calls_reports_tool_calls() {
            let mut t = new();
            let out = feed_all(
                &mut t,
                &[json!({"type":"tool-input-start","id":"k1","toolName":"ls"}), json!({"type":"finish","finishReason":"tool-calls"})],
            );
            assert!(out.contains("\"finish_reason\":\"tool_calls\""), "{out}");
        }

        #[test]
        fn finish_records_total_usage() {
            let mut t = new();
            feed_all(&mut t, &[json!({"type":"finish","finishReason":"stop","totalUsage":{"inputTokens":9,"outputTokens":4}})]);
            assert_eq!(t.usage, (9, 4));
        }

        #[test]
        fn error_events_carry_the_upstream_message() {
            let err = new().feed(&json!({"type":"error","error":"quota"})).unwrap_err();
            assert!(err.contains("quota"), "{err}");
        }
    }

    mod cached_tokens {
        use super::*;

        #[test]
        fn claude_cache_reads_are_counted() {
            let mut t = SseToOpenAi::new("claude", "cc/x".into());
            feed_all(&mut t, &[json!({"type":"message_start","message":{"usage":{"input_tokens":4,"cache_read_input_tokens":6}}})]);
            assert_eq!((t.usage.0, t.cached), (10, 6));
        }

        #[test]
        fn openai_cached_prompt_tokens_are_counted() {
            let mut t = SseToOpenAi::new("openai", "oa/x".into());
            feed_all(
                &mut t,
                &[json!({"choices":[],"usage":{"prompt_tokens":10,"completion_tokens":1,"prompt_tokens_details":{"cached_tokens":7}}})],
            );
            assert_eq!(t.cached, 7);
        }

        #[test]
        fn codex_cached_input_tokens_are_counted() {
            let mut t = SseToOpenAi::new("codex", "cx/x".into());
            feed_all(
                &mut t,
                &[
                    json!({"type":"response.completed","response":{"usage":{"input_tokens":9,"output_tokens":1,"input_tokens_details":{"cached_tokens":5}}}}),
                ],
            );
            assert_eq!(t.cached, 5);
        }
    }

    mod sse_gemini {
        use super::*;

        fn out() -> String {
            let mut t = SseToOpenAi::new("gemini", "gc/x".into());
            feed_all(
                &mut t,
                &[
                    json!({"response":{"candidates":[{"content":{"parts":[{"text":"yo"},{"functionCall":{"name":"f","args":{}}}]},"finishReason":"STOP"}]}}),
                ],
            )
        }

        #[test]
        fn text_parts_become_content() {
            assert!(out().contains("\"content\":\"yo\""));
        }

        #[test]
        fn function_calls_become_tool_calls() {
            assert!(out().contains("\"name\":\"f\""));
        }

        #[test]
        fn stop_after_a_function_call_reports_tool_calls() {
            assert!(out().contains("\"finish_reason\":\"tool_calls\""));
        }
    }

    mod sse_openai_passthrough {
        use super::*;

        #[test]
        fn records_usage_from_the_usage_chunk() {
            let mut t = SseToOpenAi::new("openai", "oa/gpt".into());
            feed_all(&mut t, &[json!({"choices":[],"usage":{"prompt_tokens":4,"completion_tokens":2}})]);
            assert_eq!(t.usage, (4, 2));
        }

        #[test]
        fn end_appends_done_exactly_once() {
            let mut t = SseToOpenAi::new("openai", "oa/gpt".into());
            let first = t.end();
            assert_eq!((first, t.end()), (vec!["data: [DONE]\n\n".to_string()], vec![]));
        }
    }

    mod aggregate_sse {
        use super::*;

        fn agg() -> Value {
            let (t, sse) = super::sse_codex_finished();
            aggregate_sse(&sse, t.usage)
        }

        #[test]
        fn joins_content_deltas() {
            assert_eq!(agg()["choices"][0]["message"]["content"], "Hello");
        }

        #[test]
        fn joins_tool_call_argument_deltas() {
            assert_eq!(agg()["choices"][0]["message"]["tool_calls"][0]["function"]["arguments"], "{}");
        }

        #[test]
        fn keeps_the_finish_reason() {
            assert_eq!(agg()["choices"][0]["finish_reason"], "tool_calls");
        }

        #[test]
        fn totals_usage() {
            assert_eq!(agg()["usage"]["total_tokens"], 10);
        }
    }

    /// Shared fixture: a finished Codex stream with text, one tool call and usage.
    fn sse_codex_finished() -> (SseToOpenAi, String) {
        let mut t = SseToOpenAi::new("codex", "cx/gpt-5".into());
        let mut sse = t.base.start_chunk();
        sse += &feed_all(
            &mut t,
            &[
                json!({"type":"response.output_text.delta","delta":"He"}),
                json!({"type":"response.output_text.delta","delta":"llo"}),
                json!({"type":"response.output_item.added","item":{"type":"function_call","id":"i1","call_id":"c1","name":"f"}}),
                json!({"type":"response.function_call_arguments.delta","item_id":"i1","delta":"{}"}),
                json!({"type":"response.completed","response":{"usage":{"input_tokens":7,"output_tokens":3}}}),
            ],
        );
        (t, sse)
    }
}
