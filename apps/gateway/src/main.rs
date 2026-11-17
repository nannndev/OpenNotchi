use axum::{routing::get, Json};
use notchi_gateway::{gateway_router, GatewayEngine, GatewayStore};
use serde_json::{json, Value};
use std::env;
use std::net::SocketAddr;
use std::path::PathBuf;

struct Config {
    host: String,
    port: u16,
    data_dir: PathBuf,
}

fn default_data_dir() -> PathBuf {
    #[cfg(target_os = "windows")]
    if let Ok(appdata) = env::var("APPDATA") {
        if !appdata.is_empty() {
            return PathBuf::from(appdata).join("notchi-gateway");
        }
    }

    if let Ok(home) = env::var("HOME").or_else(|_| env::var("USERPROFILE")) {
        if !home.is_empty() {
            return PathBuf::from(home).join(".notchi-gateway");
        }
    }

    PathBuf::from(".notchi-gateway")
}

fn parse_args() -> Result<Config, String> {
    let mut host = env::var("NOTCHI_GATEWAY_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let mut port: u16 = env::var("NOTCHI_GATEWAY_PORT").ok().and_then(|v| v.parse().ok()).unwrap_or(20129);
    let mut data_dir =
        env::var("NOTCHI_GATEWAY_DATA_DIR").ok().filter(|v| !v.is_empty()).map(PathBuf::from).unwrap_or_else(default_data_dir);

    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "-h" | "--help" => {
                println!(
                    "notchi-gateway {}\n\nUSAGE:\n  notchi-gateway [OPTIONS]\n\nOPTIONS:\n  --host <HOST>          Bind host (default: 127.0.0.1, env: NOTCHI_GATEWAY_HOST)\n  --port <PORT>          Bind port (default: 20129, env: NOTCHI_GATEWAY_PORT)\n  --data-dir <PATH>      Data directory (default: ~/.notchi-gateway, env: NOTCHI_GATEWAY_DATA_DIR)\n  -h, --help             Print help",
                    env!("CARGO_PKG_VERSION")
                );
                std::process::exit(0);
            }
            "--host" => {
                host = args.next().ok_or("--host requires a value")?;
            }
            "--port" => {
                let val = args.next().ok_or("--port requires a value")?;
                port = val.parse().map_err(|_| format!("invalid --port value: {val}"))?;
            }
            "--data-dir" => {
                let val = args.next().ok_or("--data-dir requires a value")?;
                data_dir = PathBuf::from(val);
            }
            other => return Err(format!("unknown argument: {other}")),
        }
    }

    Ok(Config { host, port, data_dir })
}

async fn root_health() -> Json<Value> {
    Json(json!({
        "status": "ok",
        "service": "notchi-gateway",
        "version": env!("CARGO_PKG_VERSION"),
    }))
}

async fn shutdown_signal() {
    let ctrl_c = async {
        let _ = tokio::signal::ctrl_c().await;
    };

    #[cfg(unix)]
    let terminate = async {
        if let Ok(mut sig) = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            sig.recv().await;
        } else {
            std::future::pending::<()>().await;
        }
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }
}

#[tokio::main]
async fn main() {
    let cfg = match parse_args() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("error: {e}");
            std::process::exit(2);
        }
    };

    let addr: SocketAddr = match format!("{}:{}", cfg.host, cfg.port).parse() {
        Ok(a) => a,
        Err(e) => {
            eprintln!("invalid bind address {}:{}: {e}", cfg.host, cfg.port);
            std::process::exit(2);
        }
    };

    let store = match GatewayStore::new(&cfg.data_dir) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("failed to initialize gateway store at {}: {e}", cfg.data_dir.display());
            std::process::exit(1);
        }
    };

    let engine = GatewayEngine::new(store);
    {
        // Keep provider model lists fresh: check hourly, refetch lists older than a day.
        let engine = engine.clone();
        tokio::spawn(async move {
            loop {
                notchi_gateway::routes::providers::sync_stale_models(&engine).await;
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
            }
        });
    }
    let app = gateway_router(engine).route("/health", get(root_health));

    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("failed to bind {addr}: {e}");
            std::process::exit(1);
        }
    };

    eprintln!("notchi-gateway v{} listening on http://{} (data: {})", env!("CARGO_PKG_VERSION"), addr, cfg.data_dir.display());

    if let Err(e) = axum::serve(listener, app).with_graceful_shutdown(shutdown_signal()).await {
        eprintln!("server error: {e}");
        std::process::exit(1);
    }
}
