use std::path::Path;

pub(crate) fn is_spotify_service(service: &str) -> bool {
    service
        .strip_prefix("org.mpris.MediaPlayer2.")
        .and_then(|name| name.split('.').next())
        .is_some_and(|name| {
            matches!(
                name,
                "spotify" | "spotifyd" | "spotify_player" | "spotify-player" | "librespot"
            )
        })
}

pub(crate) fn is_spotify_stream(
    binary: Option<&str>,
    application: Option<&str>,
    corked: bool,
) -> bool {
    if corked {
        return false;
    }
    [binary, application].into_iter().flatten().any(|name| {
        let name = Path::new(name)
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or(name)
            .to_ascii_lowercase();
        matches!(
            name.as_str(),
            "spotify" | "spotifyd" | "spotify_player" | "spotify-player" | "librespot"
        )
    })
}

pub(crate) fn is_local_playback(service: &str, playing: bool, spotify_stream_active: bool) -> bool {
    playing && (!is_spotify_service(service) || spotify_stream_active)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn spotify_connect_status_needs_local_audio() {
        for name in [
            "spotify",
            "spotify.instance123",
            "spotifyd",
            "spotify_player",
        ] {
            let service = format!("org.mpris.MediaPlayer2.{name}");
            assert!(!is_local_playback(&service, true, false));
            assert!(is_local_playback(&service, true, true));
            assert!(!is_local_playback(&service, false, true));
        }
    }

    #[test]
    fn other_players_keep_their_playback_detection() {
        assert!(is_local_playback(
            "org.mpris.MediaPlayer2.firefox",
            true,
            false
        ));
        assert!(!is_local_playback(
            "org.mpris.MediaPlayer2.firefox",
            false,
            true
        ));
        assert!(!is_spotify_service("org.mpris.MediaPlayer2.spotify_clone"));
    }

    #[test]
    fn only_uncorked_spotify_streams_count() {
        assert!(is_spotify_stream(Some("/opt/spotify/spotify"), None, false));
        assert!(is_spotify_stream(None, Some("Spotify"), false));
        assert!(is_spotify_stream(Some("spotifyd"), None, false));
        assert!(is_spotify_stream(Some("spotify_player"), None, false));
        assert!(!is_spotify_stream(Some("spotify"), Some("Spotify"), true));
        assert!(!is_spotify_stream(Some("firefox"), Some("Firefox"), false));
        assert!(!is_spotify_stream(None, None, false));
    }
}
