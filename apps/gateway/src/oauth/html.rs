pub fn parse_callback_code_or_token(callback_str: &str) -> String {
    let s = callback_str.trim();
    if s.contains("code=") {
        if let Some(pos) = s.find("code=") {
            let rest = &s[pos + 5..];
            let end = rest.find('&').unwrap_or(rest.len());
            let code = &rest[..end];
            return urlencoding_decode(code);
        }
    }
    // Claude's code-only page shows "code#state"
    s.split('#').next().unwrap_or("").to_string()
}

pub(crate) fn urlencoding_decode(s: &str) -> String {
    let mut out = String::new();
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '%' {
            let hex_str: String = chars.by_ref().take(2).collect();
            if let Ok(b) = u8::from_str_radix(&hex_str, 16) {
                out.push(b as char);
            } else {
                out.push('%');
                out.push_str(&hex_str);
            }
        } else if c == '+' {
            out.push(' ');
        } else {
            out.push(c);
        }
    }
    out
}

pub(crate) fn urlencoding_encode(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b == b'-' || b == b'_' || b == b'.' || b == b'~' {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

pub(crate) fn format_oauth_result_page(ok: bool, msg: &str) -> String {
    let icon = if ok {
        r##"<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#34d399" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>"##
    } else {
        r##"<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#f87171" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m18 6-12 12"/><path d="m6 6 12 12"/></svg>"##
    };
    format!(
        r##"<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenNotchi Gateway — {title}</title>
  <style>
    :root {{ color-scheme: dark; }}
    * {{ box-sizing: border-box; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif;
      background: radial-gradient(ellipse at 50% 0%, rgba(99, 102, 241, 0.16) 0%, #07080d 62%);
      color: #f4f4f5;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 20px;
    }}
    .notch-pill {{
      position: fixed;
      top: 0;
      left: 50%;
      transform: translateX(-50%);
      background: #000000;
      border: 1px solid rgba(255,255,255,0.10);
      border-top: none;
      border-radius: 0 0 18px 18px;
      padding: 8px 18px;
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 12px;
      font-weight: 600;
      letter-spacing: 0.01em;
      box-shadow: 0 10px 30px rgba(0,0,0,0.6);
    }}
    .dot {{
      width: 8px;
      height: 8px;
      border-radius: 999px;
      background: {dot_color};
      box-shadow: 0 0 10px {dot_color};
    }}
    .card {{
      width: 100%;
      max-width: 420px;
      background: rgba(18, 20, 28, 0.88);
      backdrop-filter: blur(24px);
      border: 1px solid rgba(255,255,255,0.09);
      border-radius: 22px;
      padding: 36px 32px 28px;
      text-align: center;
      box-shadow: 0 28px 60px rgba(0,0,0,0.65), inset 0 1px 0 rgba(255,255,255,0.06);
      animation: pop 0.35s cubic-bezier(0.16, 1, 0.3, 1);
    }}
    @keyframes pop {{
      from {{ opacity: 0; transform: translateY(10px) scale(0.97); }}
      to {{ opacity: 1; transform: translateY(0) scale(1); }}
    }}
    .icon-ring {{
      width: 56px;
      height: 56px;
      margin: 0 auto 18px;
      border-radius: 16px;
      background: {badge_bg};
      border: 1px solid {badge_border};
      display: flex;
      align-items: center;
      justify-content: center;
    }}
    h1 {{
      margin: 0 0 8px;
      font-size: 20px;
      font-weight: 650;
      letter-spacing: -0.01em;
      color: {h2_color};
    }}
    p {{
      margin: 0 0 22px;
      font-size: 13.5px;
      line-height: 1.55;
      color: #a1a1aa;
    }}
    .btn {{
      display: inline-block;
      padding: 9px 18px;
      border-radius: 10px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.12);
      color: #f4f4f5;
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
      text-decoration: none;
    }}
    .btn:hover {{ background: rgba(255,255,255,0.14); }}
    .progress {{
      margin-top: 20px;
      height: 3px;
      border-radius: 999px;
      background: rgba(255,255,255,0.07);
      overflow: hidden;
    }}
    .progress-bar {{
      height: 100%;
      width: 100%;
      background: {dot_color};
      transform-origin: left;
      animation: shrink 1.8s linear forwards;
    }}
    @keyframes shrink {{
      from {{ transform: scaleX(1); }}
      to {{ transform: scaleX(0); }}
    }}
    .hint {{
      margin-top: 10px;
      font-size: 11px;
      color: #71717a;
    }}
  </style>
</head>
<body>
  <div class="notch-pill"><span class="dot"></span><span>OpenNotchi Gateway</span></div>
  <div class="card">
    <div class="icon-ring">{icon}</div>
    <h1>{heading}</h1>
    <p>{msg}</p>
    <button class="btn" onclick="window.close()">Close Tab</button>
    {footer}
  </div>
</body>
</html>"##,
        title = if ok { "Connected" } else { "Connection Failed" },
        dot_color = if ok { "#34d399" } else { "#f87171" },
        badge_bg = if ok { "rgba(16, 185, 129, 0.14)" } else { "rgba(239, 68, 68, 0.14)" },
        badge_border = if ok { "rgba(52, 211, 153, 0.28)" } else { "rgba(248, 113, 113, 0.28)" },
        h2_color = if ok { "#f4f4f5" } else { "#fca5a5" },
        icon = icon,
        heading = if ok { "Connected to OpenNotchi" } else { "Connection Failed" },
        msg = msg,
        footer = if ok {
            r##"<div class="progress"><div class="progress-bar"></div></div><div class="hint">Closing automatically…</div><script>setTimeout(() => { try { window.close(); } catch(e){} }, 1850);</script>"##
        } else {
            r##"<div class="hint">Return to OpenNotchi Settings and try again.</div>"##
        }
    )
}
