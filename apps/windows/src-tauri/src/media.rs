//! Now playing from Windows' Global System Media Transport Controls: the one API that covers
//! Spotify, browsers (YouTube, YouTube Music, Spotify Web), Apple Music for Windows and more.

use serde::Serialize;

#[derive(Serialize, Clone, Default, Debug)]
#[serde(rename_all = "camelCase")]
pub struct NowPlaying {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub is_playing: bool,
    /// Seconds at `updated_at`; the UI extrapolates while playing.
    pub position: f64,
    pub duration: f64,
    /// Unix milliseconds when `position` was measured.
    pub updated_at: f64,
    /// Album art as a data URL, when the player shares one.
    pub artwork: Option<String>,
    /// App that owns the session, e.g. "Spotify.exe".
    pub source: String,
}

#[cfg(windows)]
mod imp {
    use super::NowPlaying;
    use base64::Engine;
    use std::sync::{mpsc, Arc, OnceLock, RwLock};
    use std::time::Duration;
    use windows::Media::Control::{
        GlobalSystemMediaTransportControlsSession as Session,
        GlobalSystemMediaTransportControlsSessionManager as Manager,
        GlobalSystemMediaTransportControlsSessionPlaybackStatus as Status,
    };
    use windows::Storage::Streams::{DataReader, IRandomAccessStreamReference};
    use windows::Win32::System::Com::{CoInitializeEx, CoUninitialize, COINIT_MULTITHREADED};

    enum MediaCmd {
        Control {
            action: String,
            seek_to: Option<f64>,
        },
    }

    struct MediaState {
        cache: Arc<RwLock<Option<NowPlaying>>>,
        sender: mpsc::Sender<MediaCmd>,
    }

    static MEDIA_STATE: OnceLock<MediaState> = OnceLock::new();

    fn get_state() -> &'static MediaState {
        MEDIA_STATE.get_or_init(|| {
            let cache = Arc::new(RwLock::new(None));
            let (tx, rx) = mpsc::channel();
            let cache_clone = Arc::clone(&cache);

            std::thread::Builder::new()
                .name("smtc-media-poller".into())
                .spawn(move || {
                    run_media_poller(cache_clone, rx);
                })
                .expect("Failed to spawn media worker thread");

            MediaState { cache, sender: tx }
        })
    }

    pub fn init() {
        let _ = get_state();
    }

    /// 100-nanosecond ticks to seconds.
    fn seconds(ticks: i64) -> f64 {
        ticks as f64 / 10_000_000.0
    }

    /// Windows FILETIME-based DateTime to Unix milliseconds.
    fn unix_ms(universal_time: i64) -> f64 {
        (universal_time - 116_444_736_000_000_000) as f64 / 10_000.0
    }

    fn read_artwork(thumbnail: IRandomAccessStreamReference) -> Option<String> {
        let stream = thumbnail.OpenReadAsync().ok()?.join().ok()?;
        let size = stream.Size().ok()? as u32;
        if size == 0 || size > 4_000_000 {
            return None;
        }
        let reader = DataReader::CreateDataReader(&stream).ok()?;
        reader.LoadAsync(size).ok()?.join().ok()?;
        let mut bytes = vec![0u8; size as usize];
        reader.ReadBytes(&mut bytes).ok()?;
        let mime = stream.ContentType().map(|t| t.to_string()).unwrap_or_default();
        let mime = if mime.is_empty() { "image/png".to_string() } else { mime };
        Some(format!("data:{mime};base64,{}", base64::engine::general_purpose::STANDARD.encode(bytes)))
    }

    fn execute_control(session: &Session, action: &str, seek_to: Option<f64>) -> Result<(), String> {
        let op = match action {
            "toggle" => session.TryTogglePlayPauseAsync(),
            "next" => session.TrySkipNextAsync(),
            "previous" => session.TrySkipPreviousAsync(),
            "seek" => session.TryChangePlaybackPositionAsync((seek_to.unwrap_or(0.0) * 10_000_000.0) as i64),
            _ => return Err(format!("Unknown action {action}")),
        };
        op.and_then(|op| op.join()).map(|_| ()).map_err(|e| e.to_string())
    }

    fn is_dedicated_music_app(app_id: &str) -> bool {
        let lower = app_id.to_lowercase();
        lower.contains("spotify")
            || lower.contains("applemusic")
            || lower.contains("apple music")
            || lower.contains("tidal")
            || lower.contains("deezer")
            || lower.contains("qobuz")
            || lower.contains("amazonmusic")
            || lower.contains("musicbee")
            || lower.contains("foobar2000")
            || lower.contains("itunes")
            || lower.contains("winamp")
            || lower.contains("aimp")
            || lower.contains("pandora")
            || lower.contains("wmp")
    }

    fn is_browser_app(app_id: &str) -> bool {
        let lower = app_id.to_lowercase();
        lower.contains("chrome")
            || lower.contains("msedge")
            || lower.contains("edge")
            || lower.contains("firefox")
            || lower.contains("brave")
            || lower.contains("opera")
            || lower.contains("vivaldi")
    }

    fn get_all_sessions(mgr: &Manager) -> Vec<Session> {
        let mut sessions = Vec::new();
        if let Ok(vec_view) = mgr.GetSessions() {
            if let Ok(size) = vec_view.Size() {
                for i in 0..size {
                    if let Ok(session) = vec_view.GetAt(i) {
                        sessions.push(session);
                    }
                }
            }
        }
        sessions
    }

    fn find_best_session(mgr: &Manager, last_source: &str) -> Option<Session> {
        let sessions = get_all_sessions(mgr);
        if sessions.is_empty() {
            return mgr.GetCurrentSession().ok();
        }

        let has_music_app = sessions.iter().any(|s| {
            let app_id = s.SourceAppUserModelId().map(|x| x.to_string()).unwrap_or_default();
            is_dedicated_music_app(&app_id)
        });

        struct Candidate {
            session: Session,
            score: i32,
        }

        let mut candidates: Vec<Candidate> = Vec::new();

        for session in sessions {
            let app_id = session.SourceAppUserModelId().map(|s| s.to_string()).unwrap_or_default();
            let status = session.GetPlaybackInfo().ok().and_then(|p| p.PlaybackStatus().ok());
            let is_playing = status == Some(Status::Playing);
            let is_music = is_dedicated_music_app(&app_id);
            let is_browser = is_browser_app(&app_id);
            let is_prev = !last_source.is_empty() && app_id == last_source;

            // If a dedicated music app session exists on the system, NEVER select a paused browser tab
            if has_music_app && is_browser && !is_playing {
                continue;
            }

            let score = if is_playing {
                if is_music {
                    10_000 + if is_prev { 1_000 } else { 0 }
                } else if is_browser {
                    5_000 + if is_prev { 500 } else { 0 }
                } else {
                    6_000 + if is_prev { 500 } else { 0 }
                }
            } else {
                // Not playing (paused, buffering, track changing)
                if is_prev && is_music {
                    4_000
                } else if is_music {
                    2_000
                } else if is_prev {
                    1_500
                } else if is_browser {
                    10
                } else {
                    100
                }
            };

            candidates.push(Candidate { session, score });
        }

        candidates.sort_by(|a, b| b.score.cmp(&a.score));

        for c in candidates {
            if let Ok(props_op) = c.session.TryGetMediaPropertiesAsync() {
                if let Ok(props) = props_op.join() {
                    let title = props.Title().map(|s| s.to_string()).unwrap_or_default();
                    if !title.is_empty() {
                        return Some(c.session);
                    }
                }
            }
        }

        mgr.GetCurrentSession().ok()
    }

    fn run_media_poller(cache: Arc<RwLock<Option<NowPlaying>>>, rx: mpsc::Receiver<MediaCmd>) {
        unsafe {
            let _ = CoInitializeEx(None, COINIT_MULTITHREADED);
        }

        let mut manager_opt: Option<Manager> = None;
        let mut last_track_id = String::new();
        let mut last_artwork: Option<String> = None;
        let mut last_source = String::new();
        let mut active_session: Option<Session> = None;
        let mut missed_ticks = 0;

        loop {
            // Handle any commands queued up
            while let Ok(cmd) = rx.try_recv() {
                match cmd {
                    MediaCmd::Control { action, seek_to } => {
                        let target = active_session.clone()
                            .or_else(|| manager_opt.as_ref().and_then(|m| m.GetCurrentSession().ok()));
                        if let Some(session) = &target {
                            let _ = execute_control(session, &action, seek_to);
                        }
                    }
                }
            }

            // Ensure we have a Manager instance
            if manager_opt.is_none() {
                if let Ok(op) = Manager::RequestAsync() {
                    if let Ok(mgr) = op.join() {
                        manager_opt = Some(mgr);
                    }
                }
            }

            let mut updated = false;
            if let Some(ref mgr) = manager_opt {
                if let Some(session) = find_best_session(mgr, &last_source) {
                    if let Ok(props_op) = session.TryGetMediaPropertiesAsync() {
                        if let Ok(props) = props_op.join() {
                            let title = props.Title().map(|s| s.to_string()).unwrap_or_default();
                            if !title.is_empty() {
                                let artist = props.Artist().map(|s| s.to_string()).unwrap_or_default();
                                let album = props.AlbumTitle().map(|s| s.to_string()).unwrap_or_default();
                                let source = session.SourceAppUserModelId().map(|s| s.to_string()).unwrap_or_default();
                                let track_id = format!("{}\u{0000}{}\u{0000}{}", title, artist, source);

                                if track_id != last_track_id {
                                    last_track_id = track_id;
                                    last_artwork = props.Thumbnail().ok().and_then(read_artwork);
                                }

                                last_source = source.clone();
                                active_session = Some(session.clone());
                                missed_ticks = 0;

                                let timeline = session.GetTimelineProperties().ok();
                                let playback = session.GetPlaybackInfo().ok();

                                let np = NowPlaying {
                                    title,
                                    artist,
                                    album,
                                    is_playing: playback.and_then(|p| p.PlaybackStatus().ok()) == Some(Status::Playing),
                                    position: seconds(timeline.as_ref().and_then(|t| t.Position().ok()).map(|d| d.Duration).unwrap_or(0)),
                                    duration: seconds(timeline.as_ref().and_then(|t| t.EndTime().ok()).map(|d| d.Duration).unwrap_or(0)),
                                    updated_at: unix_ms(timeline.as_ref().and_then(|t| t.LastUpdatedTime().ok()).map(|u| u.UniversalTime).unwrap_or(0)),
                                    artwork: last_artwork.clone(),
                                    source,
                                };

                                if let Ok(mut lock) = cache.write() {
                                    *lock = Some(np);
                                }
                                updated = true;
                            }
                        }
                    }
                }
            }

            if !updated {
                missed_ticks += 1;
                // Give a 2-tick (1s) grace period during song transitions before completely clearing
                if missed_ticks >= 2 {
                    last_track_id.clear();
                    last_artwork = None;
                    last_source.clear();
                    active_session = None;
                    if let Ok(mut lock) = cache.write() {
                        if lock.is_some() {
                            *lock = None;
                        }
                    }
                }
            }

            // Sleep 500ms or wake up on incoming control command
            match rx.recv_timeout(Duration::from_millis(500)) {
                Ok(MediaCmd::Control { action, seek_to }) => {
                    let target = active_session.clone()
                        .or_else(|| manager_opt.as_ref().and_then(|m| m.GetCurrentSession().ok()));
                    if let Some(session) = &target {
                        let _ = execute_control(session, &action, seek_to);
                    }
                }
                Err(mpsc::RecvTimeoutError::Timeout) => {}
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
            }
        }

        unsafe {
            CoUninitialize();
        }
    }

    pub fn now_playing(with_artwork: bool) -> Option<NowPlaying> {
        let state = get_state();
        let mut np = state.cache.read().ok()?.clone();
        if !with_artwork {
            if let Some(ref mut item) = np {
                item.artwork = None;
            }
        }
        np
    }

    pub fn control(action: &str, seek_to: Option<f64>) -> Result<(), String> {
        let state = get_state();
        state
            .sender
            .send(MediaCmd::Control {
                action: action.to_string(),
                seek_to,
            })
            .map_err(|e| e.to_string())
    }
}

#[cfg(not(windows))]
mod imp {
    //! Lets the UI be developed on macOS: a fake song that plays from the moment the app starts.
    use super::NowPlaying;
    use std::time::{SystemTime, UNIX_EPOCH};

    pub fn init() {}

    pub fn now_playing(_with_artwork: bool) -> Option<NowPlaying> {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).ok()?.as_millis() as f64;
        Some(NowPlaying {
            title: "Shape of My Heart".into(),
            artist: "Backstreet Boys".into(),
            album: "Black & Blue".into(),
            is_playing: true,
            position: 0.0,
            duration: 230.0,
            updated_at: now - 75_000.0,
            artwork: None,
            source: "demo".into(),
        })
    }

    pub fn control(_action: &str, _seek_to: Option<f64>) -> Result<(), String> {
        Ok(())
    }
}

pub fn init() {
    imp::init();
}

#[tauri::command]
pub fn now_playing(with_artwork: bool) -> Option<NowPlaying> {
    imp::now_playing(with_artwork)
}

#[tauri::command]
pub fn media_control(action: String, seek_to: Option<f64>) -> Result<(), String> {
    imp::control(&action, seek_to)
}
