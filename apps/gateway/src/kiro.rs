//! Kiro (AWS CodeWhisperer / Q Developer) wire format.
//!
//! Requests are a custom `conversationState` JSON; replies are a binary AWS event stream.
//! This impersonates the Kiro IDE (see `oauth::kiro_headers`) and may break or get an
//! account flagged whenever Kiro changes its client checks.

use crate::translate::SseToOpenAi;
use serde_json::{json, Value};

/// Largest frame we accept; real frames are a few KB.
const MAX_FRAME: usize = 16 * 1024 * 1024;

// ---------------------------------------------------------------------
// AWS event stream framing
// ---------------------------------------------------------------------

/// CRC-32 (IEEE), as used by AWS event stream preludes and messages.
fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFF_FFFFu32;
    for &b in data {
        crc ^= u32::from(b);
        for _ in 0..8 {
            crc = if crc & 1 == 1 { (crc >> 1) ^ 0xEDB8_8320 } else { crc >> 1 };
        }
    }
    !crc
}

fn be_u32(b: &[u8], at: usize) -> Option<u32> {
    b.get(at..at + 4).map(|s| u32::from_be_bytes([s[0], s[1], s[2], s[3]]))
}

/// One decoded frame: its `:message-type`, `:event-type` and JSON payload.
#[derive(Debug, PartialEq)]
pub struct Frame {
    pub message_type: String,
    pub event_type: String,
    pub payload: Value,
}

/// Incremental decoder: feed raw bytes as they arrive, get back complete frames.
#[derive(Default)]
pub struct EventStreamDecoder {
    buf: Vec<u8>,
}

impl EventStreamDecoder {
    /// Appends bytes and returns every complete frame. Err means the stream is corrupt.
    pub fn push(&mut self, bytes: &[u8]) -> Result<Vec<Frame>, String> {
        self.buf.extend_from_slice(bytes);
        let mut out = Vec::new();
        while self.buf.len() >= 12 {
            let (Some(total), Some(headers_len), Some(prelude_crc)) = (be_u32(&self.buf, 0), be_u32(&self.buf, 4), be_u32(&self.buf, 8))
            else {
                break;
            };
            let (total, headers_len) = (total as usize, headers_len as usize);
            if prelude_crc != crc32(&self.buf[..8]) {
                return Err("Kiro event stream: prelude CRC mismatch".into());
            }
            if !(16..=MAX_FRAME).contains(&total) || headers_len > total - 16 {
                return Err("Kiro event stream: invalid frame bounds".into());
            }
            if self.buf.len() < total {
                break;
            }
            let frame: Vec<u8> = self.buf.drain(..total).collect();
            if be_u32(&frame, total - 4) != Some(crc32(&frame[..total - 4])) {
                return Err("Kiro event stream: message CRC mismatch".into());
            }
            out.push(parse_frame(&frame[12..12 + headers_len], &frame[12 + headers_len..total - 4]));
        }
        Ok(out)
    }
}

/// Reads string headers (type 7); other header types are skipped by their encoded size.
fn parse_frame(headers: &[u8], payload: &[u8]) -> Frame {
    let mut f = Frame { message_type: String::new(), event_type: String::new(), payload: Value::Null };
    let mut i = 0;
    while i < headers.len() {
        let name_len = usize::from(headers[i]);
        let Some(name) = headers.get(i + 1..i + 1 + name_len) else { break };
        let name = String::from_utf8_lossy(name).into_owned();
        i += 1 + name_len;
        let Some(&kind) = headers.get(i) else { break };
        i += 1;
        // Value sizes per AWS event stream header type.
        let fixed = match kind {
            0 | 1 => Some(0),
            2 => Some(1),
            3 => Some(2),
            4 => Some(4),
            5 | 8 => Some(8),
            9 => Some(16),
            _ => None,
        };
        if let Some(n) = fixed {
            i += n;
            continue;
        }
        let Some(len) = headers.get(i..i + 2).map(|s| usize::from(u16::from_be_bytes([s[0], s[1]]))) else { break };
        i += 2;
        let Some(val) = headers.get(i..i + len) else { break };
        if kind == 7 {
            let v = String::from_utf8_lossy(val).into_owned();
            match name.as_str() {
                ":message-type" => f.message_type = v,
                ":event-type" => f.event_type = v,
                _ => {}
            }
        }
        i += len;
    }
    f.payload = serde_json::from_slice(payload).unwrap_or_else(|_| json!({ "text": String::from_utf8_lossy(payload) }));
    f
}

// ---------------------------------------------------------------------
// OpenAI -> Kiro request
// ---------------------------------------------------------------------

fn text_of(content: &Value) -> String {
    match content {
        Value::String(s) => s.clone(),
        Value::Array(parts) => parts.iter().filter_map(|p| p["text"].as_str()).collect::<Vec<_>>().join("\n"),
        _ => String::new(),
    }
}

/// Kiro only accepts `[A-Za-z0-9_-]{1,64}` tool names.
pub fn kiro_tool_name(name: &str) -> String {
    let n: String = name.chars().map(|c| if c.is_ascii_alphanumeric() || c == '_' || c == '-' { c } else { '_' }).take(64).collect();
    if n.is_empty() {
        "tool".into()
    } else {
        n
    }
}

/// Strips JSON-schema bits Kiro rejects: `additionalProperties` and empty `required`.
fn clean_schema(v: &Value) -> Value {
    match v {
        Value::Object(m) => Value::Object(
            m.iter()
                .filter(|(k, val)| *k != "additionalProperties" && !(*k == "required" && val.as_array().is_some_and(Vec::is_empty)))
                .map(|(k, val)| (k.clone(), clean_schema(val)))
                .collect(),
        ),
        Value::Array(a) => Value::Array(a.iter().map(clean_schema).collect()),
        other => other.clone(),
    }
}

/// Builds a Kiro `generateAssistantResponse` body.
///
/// History must alternate user/assistant, so system text is folded into the first user turn,
/// tool results become user turns, and same-role neighbours are merged.
pub fn openai_to_kiro(body: &Value, model: &str, conversation_id: &str, profile_arn: Option<&str>) -> Value {
    let msgs = body["messages"].as_array().cloned().unwrap_or_default();
    let system: Vec<String> =
        msgs.iter().filter(|m| matches!(m["role"].as_str(), Some("system" | "developer"))).map(|m| text_of(&m["content"])).collect();

    // (is_user, text, tool_results, tool_uses)
    let mut turns: Vec<(bool, String, Vec<Value>, Vec<Value>)> = Vec::new();
    for m in &msgs {
        let (is_user, text, results, uses) = match m["role"].as_str().unwrap_or("user") {
            "system" | "developer" => continue,
            "tool" => (
                true,
                String::new(),
                vec![json!({ "toolUseId": m["tool_call_id"], "status": "success", "content": [{ "text": text_of(&m["content"]) }] })],
                vec![],
            ),
            "assistant" => {
                let uses = m["tool_calls"]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .map(|c| {
                        let input = c["function"]["arguments"].as_str().and_then(|a| serde_json::from_str::<Value>(a).ok()).unwrap_or(json!({}));
                        json!({ "toolUseId": c["id"], "name": kiro_tool_name(c["function"]["name"].as_str().unwrap_or("")), "input": input })
                    })
                    .collect();
                (false, text_of(&m["content"]), vec![], uses)
            }
            _ => (true, text_of(&m["content"]), vec![], vec![]),
        };
        match turns.last_mut() {
            Some(last) if last.0 == is_user => {
                if !text.is_empty() {
                    if !last.1.is_empty() {
                        last.1.push_str("\n\n");
                    }
                    last.1.push_str(&text);
                }
                last.2.extend(results);
                last.3.extend(uses);
            }
            _ => turns.push((is_user, text, results, uses)),
        }
    }
    // The current message must be a user turn.
    if turns.last().is_none_or(|t| !t.0) {
        turns.push((true, String::new(), vec![], vec![]));
    }

    let now = chrono::Utc::now().to_rfc3339();
    let mut prefix = format!("[Context: Current time is {now}]");
    if !system.is_empty() {
        prefix = format!("<instructions>\n{}\n</instructions>\n\n{prefix}", system.join("\n\n"));
    }
    if let Some(first_user) = turns.iter_mut().find(|t| t.0) {
        first_user.1 = if first_user.1.is_empty() { prefix } else { format!("{prefix}\n\n{}", first_user.1) };
    }

    let tools: Vec<Value> = body["tools"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|t| {
            let f = &t["function"];
            let name = f["name"].as_str()?;
            let desc: String = f["description"].as_str().unwrap_or(name).chars().take(10_237).collect();
            let schema =
                if f["parameters"].is_object() { clean_schema(&f["parameters"]) } else { json!({ "type": "object", "properties": {} }) };
            Some(json!({ "toolSpecification": { "name": kiro_tool_name(name), "description": desc, "inputSchema": { "json": schema } } }))
        })
        .collect();

    let user_msg = |text: &str, results: &[Value], with_tools: bool| {
        let mut u = json!({
            "content": if text.is_empty() { if results.is_empty() { "continue" } else { "Tool results provided." } } else { text },
            "modelId": model,
            "origin": "AI_EDITOR",
        });
        let mut ctx = serde_json::Map::new();
        if !results.is_empty() {
            ctx.insert("toolResults".into(), json!(results));
        }
        if with_tools && !tools.is_empty() {
            ctx.insert("tools".into(), json!(tools));
        }
        if !ctx.is_empty() {
            u["userInputMessageContext"] = Value::Object(ctx);
        }
        json!({ "userInputMessage": u })
    };

    let Some((_, cur_text, cur_results, _)) = turns.pop() else { return Value::Null };
    let history: Vec<Value> = turns
        .iter()
        .map(|(is_user, text, results, uses)| {
            if *is_user {
                user_msg(text, results, false)
            } else {
                let mut a = json!({ "content": if text.is_empty() { "..." } else { text } });
                if !uses.is_empty() {
                    a["toolUses"] = json!(uses);
                }
                json!({ "assistantResponseMessage": a })
            }
        })
        .collect();

    let mut out = json!({
        "conversationState": {
            "chatTriggerType": "MANUAL",
            "conversationId": conversation_id,
            "currentMessage": user_msg(&cur_text, &cur_results, true),
            "history": history,
        },
        "inferenceConfig": { "maxTokens": 32_000 },
    });
    if let Some(t) = body["temperature"].as_f64() {
        out["inferenceConfig"]["temperature"] = json!(t);
    }
    if let Some(p) = body["top_p"].as_f64() {
        out["inferenceConfig"]["topP"] = json!(p);
    }
    if let Some(arn) = profile_arn.filter(|a| !a.is_empty()) {
        out["profileArn"] = json!(arn);
    }
    out
}

// ---------------------------------------------------------------------
// Kiro event stream -> OpenAI chunks
// ---------------------------------------------------------------------

/// Streaming state for one Kiro reply.
#[derive(Default)]
pub struct KiroStream {
    decoder: EventStreamDecoder,
    in_thinking: bool,
    /// Tool calls in arrival order: (id, name, buffered input).
    tools: Vec<(String, String, String)>,
    stop_reason: Option<String>,
}

impl KiroStream {
    /// Turns raw bytes into OpenAI chunk frames. Tool calls are held until the stream ends
    /// because Kiro streams their JSON input in fragments.
    pub fn push(&mut self, tr: &mut SseToOpenAi, bytes: &[u8]) -> Result<Vec<String>, String> {
        let mut out = Vec::new();
        for f in self.decoder.push(bytes)? {
            if f.message_type == "error" || f.message_type == "exception" {
                let msg = f.payload["message"].as_str().or(f.payload["Message"].as_str()).unwrap_or("Kiro upstream error");
                return Err(format!("Kiro: {msg}"));
            }
            let p = &f.payload;
            match f.event_type.as_str() {
                "assistantResponseEvent" => {
                    if let Some(text) = p["content"].as_str() {
                        let visible = self.strip_thinking(text);
                        if !visible.is_empty() {
                            out.push(tr.base.chunk_data(json!({ "content": visible }), None));
                        }
                    }
                }
                "reasoningContentEvent" => {
                    let r = p.get("reasoningContentEvent").unwrap_or(p);
                    if let Some(t) = r.as_str().or(r["text"].as_str()).or(r["content"].as_str()).filter(|t| !t.is_empty()) {
                        out.push(tr.base.chunk_data(json!({ "reasoning_content": t }), None));
                    }
                }
                "codeEvent" => {
                    if let Some(t) = p["content"].as_str().filter(|t| !t.is_empty()) {
                        out.push(tr.base.chunk_data(json!({ "content": t }), None));
                    }
                }
                "toolUseEvent" => {
                    let items = if p.is_array() { p.as_array().cloned().unwrap_or_default() } else { vec![p.clone()] };
                    for item in items {
                        let id = item["toolUseId"].as_str().map(String::from).unwrap_or_else(|| format!("call_{}", self.tools.len() + 1));
                        let name = item["name"].as_str().unwrap_or("").trim().to_string();
                        let idx = match self.tools.iter().position(|t| t.0 == id) {
                            Some(i) => i,
                            None => {
                                self.tools.push((id, name, String::new()));
                                self.tools.len() - 1
                            }
                        };
                        match &item["input"] {
                            Value::String(s) => self.tools[idx].2.push_str(s),
                            v @ Value::Object(_) => self.tools[idx].2 = v.to_string(),
                            _ => {}
                        }
                    }
                }
                "messageStopEvent" | "metadataEvent" | "MetadataEvent" => {
                    let m = p.get("metadataEvent").or(p.get("metadata")).unwrap_or(p);
                    if let Some(r) = m["stopReason"].as_str().or(m["stop_reason"].as_str()) {
                        self.stop_reason = Some(r.to_string());
                    }
                }
                "metricsEvent" => {
                    let m = p.get("metricsEvent").unwrap_or(p);
                    let (i, o) = (m["inputTokens"].as_i64().unwrap_or(0), m["outputTokens"].as_i64().unwrap_or(0));
                    if i > 0 || o > 0 {
                        tr.usage = (i, o);
                    }
                }
                _ => {}
            }
        }
        Ok(out)
    }

    /// Emits buffered tool calls, the finish chunk and `[DONE]`.
    pub fn finish(&mut self, tr: &mut SseToOpenAi) -> Vec<String> {
        let mut out = Vec::new();
        for (idx, (id, name, input)) in self.tools.drain(..).enumerate() {
            let args = if input.trim().is_empty() { "{}".to_string() } else { input };
            out.push(tr.base.chunk_data(
                json!({ "tool_calls": [{ "index": idx, "id": id, "type": "function", "function": { "name": name, "arguments": args } }] }),
                None,
            ));
        }
        let had_tools = !out.is_empty();
        let reason = match self.stop_reason.as_deref() {
            _ if had_tools => "tool_calls",
            Some("max_tokens" | "length" | "MAX_TOKENS") => "length",
            _ => "stop",
        };
        out.push(tr.base.chunk_data(json!({}), Some(reason)));
        out.push("data: [DONE]\n\n".into());
        out
    }

    /// Hides `<thinking>…</thinking>` blocks, which may span several events.
    fn strip_thinking(&mut self, text: &str) -> String {
        let mut out = String::new();
        let mut rest = text;
        loop {
            if self.in_thinking {
                match rest.find("</thinking>") {
                    Some(i) => {
                        self.in_thinking = false;
                        rest = rest[i + 11..].trim_start_matches('\n');
                    }
                    None => return out,
                }
            } else {
                match rest.find("<thinking>") {
                    Some(i) => {
                        out.push_str(&rest[..i]);
                        self.in_thinking = true;
                        rest = &rest[i + 10..];
                    }
                    None => {
                        out.push_str(rest);
                        return out;
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Encodes one event stream frame with string headers, for tests.
    fn frame(message_type: &str, event_type: &str, payload: &Value) -> Vec<u8> {
        let mut headers = Vec::new();
        for (k, v) in [(":message-type", message_type), (":event-type", event_type), (":content-type", "application/json")] {
            headers.push(k.len() as u8);
            headers.extend_from_slice(k.as_bytes());
            headers.push(7);
            headers.extend_from_slice(&(v.len() as u16).to_be_bytes());
            headers.extend_from_slice(v.as_bytes());
        }
        let body = payload.to_string().into_bytes();
        let total = (12 + headers.len() + body.len() + 4) as u32;
        let mut f = Vec::new();
        f.extend_from_slice(&total.to_be_bytes());
        f.extend_from_slice(&(headers.len() as u32).to_be_bytes());
        let prelude_crc = crc32(&f);
        f.extend_from_slice(&prelude_crc.to_be_bytes());
        f.extend_from_slice(&headers);
        f.extend_from_slice(&body);
        let crc = crc32(&f);
        f.extend_from_slice(&crc.to_be_bytes());
        f
    }

    fn event(event_type: &str, payload: Value) -> Vec<u8> {
        frame("event", event_type, &payload)
    }

    fn run(bytes: &[u8]) -> (SseToOpenAi, String) {
        let mut tr = SseToOpenAi::new("kiro", "kr/x".into());
        let mut s = KiroStream::default();
        let mut out = s.push(&mut tr, bytes).unwrap().concat();
        out += &s.finish(&mut tr).concat();
        (tr, out)
    }

    mod crc32 {
        use super::super::crc32;

        #[test]
        fn matches_the_standard_check_value() {
            assert_eq!(crc32(b"123456789"), 0xCBF4_3926);
        }
    }

    mod event_stream_decoder {
        use super::*;

        #[test]
        fn decodes_a_complete_frame() {
            let frames = EventStreamDecoder::default().push(&event("assistantResponseEvent", json!({"content":"hi"}))).unwrap();
            assert_eq!(
                frames,
                vec![Frame { message_type: "event".into(), event_type: "assistantResponseEvent".into(), payload: json!({"content":"hi"}) }]
            );
        }

        #[test]
        fn waits_for_a_frame_split_across_chunks() {
            let bytes = event("assistantResponseEvent", json!({"content":"hi"}));
            let mut d = EventStreamDecoder::default();
            let first = d.push(&bytes[..10]).unwrap();
            let second = d.push(&bytes[10..]).unwrap();
            assert_eq!((first.len(), second.len()), (0, 1));
        }

        #[test]
        fn decodes_several_frames_in_one_chunk() {
            let mut bytes = event("assistantResponseEvent", json!({"content":"a"}));
            bytes.extend(event("assistantResponseEvent", json!({"content":"b"})));
            assert_eq!(EventStreamDecoder::default().push(&bytes).unwrap().len(), 2);
        }

        #[test]
        fn rejects_a_corrupted_prelude() {
            let mut bytes = event("assistantResponseEvent", json!({"content":"hi"}));
            bytes[9] ^= 0xFF;
            assert!(EventStreamDecoder::default().push(&bytes).is_err());
        }

        #[test]
        fn rejects_a_corrupted_payload() {
            let mut bytes = event("assistantResponseEvent", json!({"content":"hi"}));
            let n = bytes.len();
            bytes[n - 6] ^= 0xFF;
            assert!(EventStreamDecoder::default().push(&bytes).is_err());
        }
    }

    mod kiro_stream {
        use super::*;

        #[test]
        fn text_becomes_content() {
            assert!(run(&event("assistantResponseEvent", json!({"content":"hello"}))).1.contains("\"content\":\"hello\""));
        }

        #[test]
        fn thinking_blocks_are_hidden_from_content() {
            let (_, out) = run(&event("assistantResponseEvent", json!({"content":"<thinking>plan</thinking>answer"})));
            assert!(out.contains("\"content\":\"answer\"") && !out.contains("plan"), "{out}");
        }

        #[test]
        fn thinking_spanning_events_is_hidden() {
            let mut b = event("assistantResponseEvent", json!({"content":"<thinking>a"}));
            b.extend(event("assistantResponseEvent", json!({"content":"b</thinking>c"})));
            let (_, out) = run(&b);
            assert!(out.contains("\"content\":\"c\"") && !out.contains("\"content\":\"a"), "{out}");
        }

        #[test]
        fn reasoning_events_become_reasoning_content() {
            assert!(run(&event("reasoningContentEvent", json!({"text":"hmm"}))).1.contains("\"reasoning_content\":\"hmm\""));
        }

        #[test]
        fn fragmented_tool_input_is_joined_into_one_call() {
            let mut b = event("toolUseEvent", json!({"toolUseId":"t1","name":"ls","input":"{\"p\":"}));
            b.extend(event("toolUseEvent", json!({"toolUseId":"t1","name":"ls","input":"1}"})));
            assert!(run(&b).1.contains(r#""arguments":"{\"p\":1}""#));
        }

        #[test]
        fn a_tool_call_finishes_with_tool_calls() {
            let (_, out) = run(&event("toolUseEvent", json!({"toolUseId":"t1","name":"ls","input":"{}"})));
            assert!(out.contains("\"finish_reason\":\"tool_calls\""), "{out}");
        }

        #[test]
        fn max_tokens_finishes_with_length() {
            assert!(run(&event("messageStopEvent", json!({"stopReason":"max_tokens"}))).1.contains("\"finish_reason\":\"length\""));
        }

        #[test]
        fn metrics_set_usage() {
            assert_eq!(run(&event("metricsEvent", json!({"inputTokens":12,"outputTokens":3}))).0.usage, (12, 3));
        }

        #[test]
        fn ends_with_done() {
            assert!(run(&event("assistantResponseEvent", json!({"content":"x"}))).1.ends_with("data: [DONE]\n\n"));
        }

        #[test]
        fn exception_frames_become_errors() {
            let mut tr = SseToOpenAi::new("kiro", "kr/x".into());
            let err = KiroStream::default()
                .push(&mut tr, &frame("exception", "ThrottlingException", &json!({"message":"slow down"})))
                .unwrap_err();
            assert!(err.contains("slow down"), "{err}");
        }
    }

    mod openai_to_kiro {
        use super::*;

        fn sample() -> Value {
            openai_to_kiro(
                &json!({"messages":[
                    {"role":"system","content":"Be brief"},
                    {"role":"user","content":"hi"},
                    {"role":"assistant","content":"","tool_calls":[{"id":"c1","function":{"name":"read file","arguments":"{\"p\":1}"}}]},
                    {"role":"tool","tool_call_id":"c1","content":"ok"}
                ],"tools":[{"function":{"name":"read file","parameters":{"type":"object","additionalProperties":false,"required":[]}}}]}),
                "claude-sonnet-4.5",
                "conv-1",
                Some("arn:x"),
            )
        }

        #[test]
        fn wraps_system_text_in_instructions_on_the_first_user_turn() {
            let first = sample()["conversationState"]["history"][0]["userInputMessage"]["content"].as_str().unwrap().to_string();
            assert!(first.starts_with("<instructions>\nBe brief\n</instructions>") && first.ends_with("hi"), "{first}");
        }

        #[test]
        fn assistant_tool_calls_become_tool_uses_with_parsed_input() {
            assert_eq!(sample()["conversationState"]["history"][1]["assistantResponseMessage"]["toolUses"][0]["input"]["p"], 1);
        }

        #[test]
        fn tool_results_are_sent_on_the_current_message() {
            let cur = &sample()["conversationState"]["currentMessage"]["userInputMessage"];
            assert_eq!(cur["userInputMessageContext"]["toolResults"][0]["toolUseId"], "c1");
        }

        #[test]
        fn tool_names_are_sanitised() {
            let cur = &sample()["conversationState"]["currentMessage"]["userInputMessage"];
            assert_eq!(cur["userInputMessageContext"]["tools"][0]["toolSpecification"]["name"], "read_file");
        }

        #[test]
        fn schemas_drop_fields_kiro_rejects() {
            let cur = &sample()["conversationState"]["currentMessage"]["userInputMessage"];
            assert_eq!(cur["userInputMessageContext"]["tools"][0]["toolSpecification"]["inputSchema"]["json"], json!({"type":"object"}));
        }

        #[test]
        fn carries_the_profile_arn() {
            assert_eq!(sample()["profileArn"], "arn:x");
        }

        #[test]
        fn consecutive_user_messages_are_merged() {
            let b = openai_to_kiro(&json!({"messages":[{"role":"user","content":"a"},{"role":"user","content":"b"}]}), "m", "c", None);
            assert!(b["conversationState"]["history"].as_array().is_some_and(Vec::is_empty));
        }
    }
}
