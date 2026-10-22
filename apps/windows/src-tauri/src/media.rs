//! Now playing from Windows' Global System Media Transport Controls: the one API that covers
//! Spotify, browsers (YouTube, YouTube Music, Spotify Web), Apple Music for Windows and more.

use serde::Serialize;

#[derive(Serialize, Clone, Default)]
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
    use windows::Media::Control::{
        GlobalSystemMediaTransportControlsSession as Session,
        GlobalSystemMediaTransportControlsSessionManager as Manager,
        GlobalSystemMediaTransportControlsSessionPlaybackStatus as Status,
    };
    use windows::Storage::Streams::{DataReader, IRandomAccessStreamReference};

    fn manager() -> windows::core::Result<Manager> {
        Manager::RequestAsync()?.join()
    }

    /// The session Windows considers current (the last one the user touched).
    fn session() -> Option<Session> {
        manager().ok()?.GetCurrentSession().ok()
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
        // shortcut: a 4 MB cap guards against odd players, raise it if real artwork gets dropped.
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

    pub fn now_playing(with_artwork: bool) -> Option<NowPlaying> {
        let session = session()?;
        let props = session.TryGetMediaPropertiesAsync().ok()?.join().ok()?;
        let title = props.Title().ok()?.to_string();
        if title.is_empty() {
            return None;
        }
        let timeline = session.GetTimelineProperties().ok()?;
        let playback = session.GetPlaybackInfo().ok()?;
        let artwork = if with_artwork { props.Thumbnail().ok().and_then(read_artwork) } else { None };

        Some(NowPlaying {
            title,
            artist: props.Artist().map(|s| s.to_string()).unwrap_or_default(),
            album: props.AlbumTitle().map(|s| s.to_string()).unwrap_or_default(),
            is_playing: playback.PlaybackStatus().ok() == Some(Status::Playing),
            position: seconds(timeline.Position().map(|t| t.Duration).unwrap_or(0)),
            duration: seconds(timeline.EndTime().map(|t| t.Duration).unwrap_or(0)),
            updated_at: unix_ms(timeline.LastUpdatedTime().map(|t| t.UniversalTime).unwrap_or(0)),
            artwork,
            source: session.SourceAppUserModelId().map(|s| s.to_string()).unwrap_or_default(),
        })
    }

    pub fn control(action: &str, seek_to: Option<f64>) -> Result<(), String> {
        let session = session().ok_or("Nothing is playing")?;
        let op = match action {
            "toggle" => session.TryTogglePlayPauseAsync(),
            "next" => session.TrySkipNextAsync(),
            "previous" => session.TrySkipPreviousAsync(),
            "seek" => session.TryChangePlaybackPositionAsync((seek_to.unwrap_or(0.0) * 10_000_000.0) as i64),
            _ => return Err(format!("Unknown action {action}")),
        };
        op.and_then(|op| op.join()).map(|_| ()).map_err(|e| e.message())
    }
}

#[cfg(not(windows))]
mod imp {
    //! Lets the UI be developed on macOS: a fake song that plays from the moment the app starts.
    use super::NowPlaying;
    use std::time::{SystemTime, UNIX_EPOCH};

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

#[tauri::command]
pub fn now_playing(with_artwork: bool) -> Option<NowPlaying> {
    imp::now_playing(with_artwork)
}

#[tauri::command]
pub fn media_control(action: String, seek_to: Option<f64>) -> Result<(), String> {
    imp::control(&action, seek_to)
}
