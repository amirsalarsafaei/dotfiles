use std::{env, fs, path::Path, process::ExitCode};

use wl_clipboard_rs::copy::{MimeSource, MimeType, Options, Source};

fn uri(path: &Path) -> String {
    let mut out = String::from("file://");
    for byte in path.as_os_str().as_encoded_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'/' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*byte as char)
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}

fn offer(mime: &str, data: Vec<u8>) -> MimeSource {
    MimeSource {
        source: Source::Bytes(data.into_boxed_slice()),
        mime_type: MimeType::Specific(mime.to_owned()),
    }
}

fn main() -> ExitCode {
    let Some(arg) = env::args_os().nth(1) else {
        eprintln!("usage: clip-image FILE.png");
        return ExitCode::from(2);
    };
    let path = match fs::canonicalize(&arg) {
        Ok(path) => path,
        Err(err) => {
            eprintln!("clip-image: {}: {err}", Path::new(&arg).display());
            return ExitCode::FAILURE;
        }
    };
    let png = match fs::read(&path) {
        Ok(png) => png,
        Err(err) => {
            eprintln!("clip-image: {}: {err}", path.display());
            return ExitCode::FAILURE;
        }
    };
    let link = uri(&path);
    let sources = vec![
        offer("image/png", png),
        offer("x-special/gnome-copied-files", format!("copy\n{link}").into_bytes()),
        offer("text/uri-list", format!("{link}\r\n").into_bytes()),
    ];
    let mut options = Options::new();
    options
        .foreground(true)
        .omit_additional_text_mime_types(true);
    match options.copy_multi(sources) {
        Ok(()) => ExitCode::SUCCESS,
        Err(err) => {
            eprintln!("clip-image: {err}");
            ExitCode::FAILURE
        }
    }
}
