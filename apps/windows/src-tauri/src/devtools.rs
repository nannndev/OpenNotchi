//! Dev tab: localhost ports, system stats and GitHub Actions runs, like the macOS app's DevTools.
//! Parsing is plain functions so it's tested on any OS; the Windows calls sit in `imp`.

use serde::Serialize;
use serde_json::Value;
use std::time::Duration;

#[derive(Serialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ListeningPort {
    pub port: u16,
    pub pid: u32,
    pub process: String,
    /// "127.0.0.1", "0.0.0.0", "[::1]"...
    pub address: String,
}

#[derive(Serialize, Clone, Debug, Default, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SystemStats {
    pub cpu_percent: f64,
    pub mem_used_bytes: u64,
    pub mem_total_bytes: u64,
    /// Bytes per second since the previous call; 0 on the first.
    pub net_down_bps: f64,
    pub net_up_bps: f64,
}

#[derive(Serialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CiRun {
    pub id: u64,
    pub workflow: String,
    pub title: String,
    pub branch: String,
    /// "queued", "in_progress", "completed"
    pub status: String,
    /// "success", "failure", "cancelled"... once completed.
    pub conclusion: Option<String>,
    pub url: String,
    pub updated_at: String,
}

/// TCP LISTENING rows from `netstat -ano`, one per port (IPv4 and IPv6 of the same port are merged), sorted.
pub fn parse_netstat(output: &str) -> Vec<(String, u16, u32)> {
    let mut out: Vec<(String, u16, u32)> = Vec::new();
    for line in output.lines() {
        let cols: Vec<&str> = line.split_whitespace().collect();
        // Proto  Local Address  Foreign Address  State  PID
        if cols.len() != 5 || !cols[0].eq_ignore_ascii_case("TCP") || !cols[3].eq_ignore_ascii_case("LISTENING") {
            continue;
        }
        let Some((addr, port)) = cols[1].rsplit_once(':') else { continue };
        let (Ok(port), Ok(pid)) = (port.parse::<u16>(), cols[4].parse::<u32>()) else { continue };
        if pid == 0 || out.iter().any(|(_, p, _)| *p == port) {
            continue;
        }
        out.push((addr.to_string(), port, pid));
    }
    out.sort_by_key(|(_, p, _)| *p);
    out
}

/// `tasklist /FO CSV /NH` → pid: image name.
pub fn parse_tasklist(output: &str) -> std::collections::HashMap<u32, String> {
    output
        .lines()
        .filter_map(|line| {
            let fields: Vec<&str> = line.split("\",\"").map(|f| f.trim_matches('"')).collect();
            let pid = fields.get(1)?.trim().parse().ok()?;
            Some((pid, fields.first()?.to_string()))
        })
        .collect()
}

/// GitHub's `actions/runs` response → runs, newest first as GitHub returns them.
pub fn parse_runs(v: &Value) -> Vec<CiRun> {
    let Some(items) = v.get("workflow_runs").and_then(|r| r.as_array()) else { return vec![] };
    items
        .iter()
        .filter_map(|r| {
            let s = |k: &str| r.get(k).and_then(|x| x.as_str()).map(str::to_string);
            Some(CiRun {
                id: r.get("id")?.as_u64()?,
                workflow: s("name").unwrap_or_else(|| "Workflow".into()),
                title: s("display_title").or_else(|| s("name")).unwrap_or_default(),
                branch: s("head_branch").unwrap_or_default(),
                status: s("status").unwrap_or_else(|| "completed".into()),
                conclusion: s("conclusion"),
                url: s("html_url").unwrap_or_default(),
                updated_at: s("updated_at").unwrap_or_default(),
            })
        })
        .collect()
}

/// "owner/repo" from a slug or a github.com URL; None if it doesn't look like one.
pub fn clean_repo(raw: &str) -> Option<String> {
    let s = raw.trim().trim_end_matches('/').trim_end_matches(".git");
    let s = s.split("github.com/").last().unwrap_or(s);
    let mut parts = s.split('/').filter(|p| !p.is_empty());
    let (owner, repo) = (parts.next()?, parts.next()?);
    // It goes into the API URL path: exactly two segments, no "." / ".." that would walk out of /repos/.
    let ok = |p: &str| {
        p.chars().all(|c| c.is_ascii_alphanumeric() || "-_.".contains(c)) && !p.chars().all(|c| c == '.')
    };
    (parts.next().is_none() && ok(owner) && ok(repo)).then(|| format!("{owner}/{repo}"))
}

/// Last few workflow runs of a public repo (unauthenticated: 60 requests/hour per IP, so poll gently).
#[tauri::command]
pub async fn ci_runs(repo: String) -> Result<Vec<CiRun>, String> {
    let repo = clean_repo(&repo).ok_or("Use owner/repo, e.g. nannndev/OpenNotchi")?;
    tauri::async_runtime::spawn_blocking(move || {
        let agent: ureq::Agent = ureq::Agent::config_builder()
            .http_status_as_error(false)
            .timeout_global(Some(Duration::from_secs(10)))
            .build()
            .into();
        let url = format!("https://api.github.com/repos/{repo}/actions/runs?per_page=8");
        let mut resp = agent
            .get(&url)
            .header("Accept", "application/vnd.github+json")
            .header("User-Agent", "OpenNotchi")
            .call()
            .map_err(|e| e.to_string())?;
        match resp.status().as_u16() {
            200 => {}
            404 => return Err("Repo not found or private".into()),
            403 | 429 => return Err("GitHub rate limit reached, try again in a while".into()),
            s => return Err(format!("GitHub API HTTP {s}")),
        }
        let v: Value = resp.body_mut().read_json().map_err(|e| e.to_string())?;
        Ok(parse_runs(&v))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn listening_ports() -> Vec<ListeningPort> {
    tauri::async_runtime::spawn_blocking(imp::listening_ports).await.unwrap_or_default()
}

#[tauri::command]
pub async fn kill_process(pid: u32) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || imp::kill_process(pid)).await.map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn system_stats() -> SystemStats {
    tauri::async_runtime::spawn_blocking(imp::system_stats).await.unwrap_or_default()
}

#[cfg(windows)]
mod imp {
    use super::*;
    use std::os::windows::process::CommandExt;
    use std::process::Command;
    use std::sync::Mutex;
    use std::time::Instant;
    use windows::Win32::Foundation::FILETIME;
    use windows::Win32::NetworkManagement::IpHelper::{FreeMibTable, GetIfTable2, MIB_IF_TABLE2};
    use windows::Win32::NetworkManagement::Ndis::IF_OPER_STATUS;
    use windows::Win32::System::SystemInformation::{GlobalMemoryStatusEx, MEMORYSTATUSEX};
    use windows::Win32::System::Threading::GetSystemTimes;

    /// No console window flashing up for each netstat/tasklist call.
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;

    fn run(cmd: &str, args: &[&str]) -> String {
        Command::new(cmd)
            .args(args)
            .creation_flags(CREATE_NO_WINDOW)
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    }

    pub fn listening_ports() -> Vec<ListeningPort> {
        let names = parse_tasklist(&run("tasklist", &["/FO", "CSV", "/NH"]));
        let mut rows = parse_netstat(&run("netstat", &["-ano", "-p", "TCP"]));
        rows.extend(parse_netstat(&run("netstat", &["-ano", "-p", "TCPv6"])));
        let mut ports: Vec<ListeningPort> = Vec::new();
        for (address, port, pid) in rows {
            // IPv4 and IPv6 listeners on the same port are one server.
            if ports.iter().any(|p| p.port == port) {
                continue;
            }
            let process = names.get(&pid).cloned().unwrap_or_else(|| format!("PID {pid}"));
            ports.push(ListeningPort { port, pid, process, address });
        }
        ports.sort_by_key(|p| p.port);
        ports
    }

    pub fn kill_process(pid: u32) -> Result<(), String> {
        // Never our own process: the notch would vanish without a trace.
        if pid == std::process::id() || pid <= 4 {
            return Err("Refusing to stop that process".into());
        }
        let out = Command::new("taskkill")
            .args(["/PID", &pid.to_string(), "/T", "/F"])
            .creation_flags(CREATE_NO_WINDOW)
            .output()
            .map_err(|e| e.to_string())?;
        if out.status.success() {
            Ok(())
        } else {
            Err(String::from_utf8_lossy(&out.stderr).trim().to_string())
        }
    }

    struct Sample {
        at: Instant,
        idle: u64,
        total: u64,
        rx: u64,
        tx: u64,
    }
    static LAST: Mutex<Option<Sample>> = Mutex::new(None);

    fn ft(t: FILETIME) -> u64 {
        ((t.dwHighDateTime as u64) << 32) | t.dwLowDateTime as u64
    }

    /// Bytes in/out across all connected adapters except loopback.
    fn net_bytes() -> (u64, u64) {
        let mut table: *mut MIB_IF_TABLE2 = std::ptr::null_mut();
        unsafe {
            if GetIfTable2(&mut table).is_err() || table.is_null() {
                return (0, 0);
            }
            let t = &*table;
            let rows = std::slice::from_raw_parts(t.Table.as_ptr(), t.NumEntries as usize);
            let (mut rx, mut tx) = (0u64, 0u64);
            for row in rows {
                // IfOperStatusUp = 1; type 24 is the software loopback.
                if row.OperStatus == IF_OPER_STATUS(1) && row.Type != 24 && row.InterfaceAndOperStatusFlags._bitfield & 1 != 0 {
                    rx += row.InOctets;
                    tx += row.OutOctets;
                }
            }
            FreeMibTable(table as *const _);
            (rx, tx)
        }
    }

    pub fn system_stats() -> SystemStats {
        let mut mem = MEMORYSTATUSEX { dwLength: std::mem::size_of::<MEMORYSTATUSEX>() as u32, ..Default::default() };
        let _ = unsafe { GlobalMemoryStatusEx(&mut mem) };

        let (mut idle, mut kernel, mut user) = (FILETIME::default(), FILETIME::default(), FILETIME::default());
        let _ = unsafe { GetSystemTimes(Some(&mut idle), Some(&mut kernel), Some(&mut user)) };
        let (idle, total) = (ft(idle), ft(kernel) + ft(user)); // kernel time already includes idle
        let (rx, tx) = net_bytes();
        let now = Sample { at: Instant::now(), idle, total, rx, tx };

        let mut stats = SystemStats {
            mem_used_bytes: mem.ullTotalPhys - mem.ullAvailPhys,
            mem_total_bytes: mem.ullTotalPhys,
            ..Default::default()
        };
        let mut last = LAST.lock().unwrap();
        if let Some(prev) = last.as_ref() {
            let dt = now.at.duration_since(prev.at).as_secs_f64().max(0.001);
            let busy = (total - prev.total).saturating_sub(idle - prev.idle);
            stats.cpu_percent = if total > prev.total { busy as f64 * 100.0 / (total - prev.total) as f64 } else { 0.0 };
            stats.net_down_bps = rx.saturating_sub(prev.rx) as f64 / dt;
            stats.net_up_bps = tx.saturating_sub(prev.tx) as f64 / dt;
        }
        *last = Some(now);
        stats
    }
}

#[cfg(not(windows))]
mod imp {
    use super::*;
    pub fn listening_ports() -> Vec<ListeningPort> {
        vec![]
    }
    pub fn kill_process(_pid: u32) -> Result<(), String> {
        Err("Only on Windows".into())
    }
    pub fn system_stats() -> SystemStats {
        SystemStats::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn netstat_listening_rows_one_per_port() {
        let out = "\
Active Connections

  Proto  Local Address          Foreign Address        State           PID
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       1234
  TCP    127.0.0.1:5173         0.0.0.0:0              LISTENING       8812
  TCP    127.0.0.1:5173         127.0.0.1:51000        ESTABLISHED     8812
  TCP    [::1]:5173             [::]:0                 LISTENING       8812
  TCP    [::]:3000              [::]:0                 LISTENING       4400
  TCP    0.0.0.0:49664          0.0.0.0:0              LISTENING       0
  UDP    0.0.0.0:5353           *:*                                    2000
";
        assert_eq!(
            parse_netstat(out),
            vec![
                ("0.0.0.0".into(), 135, 1234),
                ("[::]".into(), 3000, 4400),
                ("127.0.0.1".into(), 5173, 8812),
            ]
        );
    }

    #[test]
    fn tasklist_csv_maps_pid_to_name() {
        let out = "\"node.exe\",\"8812\",\"Console\",\"1\",\"52,104 K\"\n\"svchost.exe\",\"1234\",\"Services\",\"0\",\"9,000 K\"\n";
        let names = parse_tasklist(out);
        assert_eq!(names.get(&8812).map(String::as_str), Some("node.exe"));
        assert_eq!(names.get(&1234).map(String::as_str), Some("svchost.exe"));
    }

    #[test]
    fn github_runs_parse_with_defaults() {
        let v: Value = serde_json::from_str(
            r#"{"workflow_runs":[
                {"id":1,"name":"CI","display_title":"fix: thing","head_branch":"main","status":"completed",
                 "conclusion":"success","html_url":"https://x/1","updated_at":"2026-10-29T03:00:00Z"},
                {"id":2,"status":"in_progress","conclusion":null},
                {"name":"no id"}
            ]}"#,
        )
        .unwrap();
        let runs = parse_runs(&v);
        assert_eq!(runs.len(), 2);
        assert_eq!(runs[0].title, "fix: thing");
        assert_eq!(runs[0].conclusion.as_deref(), Some("success"));
        assert_eq!(runs[1].workflow, "Workflow");
        assert_eq!(runs[1].conclusion, None);
    }

    #[test]
    fn repo_slugs_are_cleaned_and_validated() {
        assert_eq!(clean_repo("nannndev/OpenNotchi").as_deref(), Some("nannndev/OpenNotchi"));
        assert_eq!(clean_repo("https://github.com/nannndev/OpenNotchi.git/").as_deref(), Some("nannndev/OpenNotchi"));
        assert_eq!(clean_repo("just-a-name"), None);
        assert_eq!(clean_repo("a/b c"), None);
        assert_eq!(clean_repo("../../etc"), None);
        assert_eq!(clean_repo("../x"), None);
        assert_eq!(clean_repo("owner/repo/actions"), None);
        assert_eq!(clean_repo("my.org/repo.js").as_deref(), Some("my.org/repo.js"));
    }
}
