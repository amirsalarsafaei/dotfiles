use std::{env, fs, io, path::Path, process::ExitCode};

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

fn read_png(path: &Path) -> io::Result<Vec<u8>> {
    if !fs::metadata(path)?.is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "expected a regular PNG file",
        ));
    }
    let data = fs::read(path)?;
    if !data.starts_with(b"\x89PNG\r\n\x1a\n") {
        return Err(io::Error::new(
            io::ErrorKind::InvalidData,
            "file does not have a PNG signature",
        ));
    }
    Ok(data)
}

fn main() -> ExitCode {
    let args: Vec<_> = env::args_os().skip(1).collect();
    if matches!(args.as_slice(), [arg] if arg == "--help" || arg == "-h") {
        println!("usage: clip-image FILE.png");
        return ExitCode::SUCCESS;
    }
    let [arg] = args.as_slice() else {
        eprintln!("usage: clip-image FILE.png");
        return ExitCode::from(2);
    };
    let path = match fs::canonicalize(arg) {
        Ok(path) => path,
        Err(err) => {
            eprintln!("clip-image: {}: {err}", Path::new(arg).display());
            return ExitCode::FAILURE;
        }
    };
    let png = match read_png(&path) {
        Ok(png) => png,
        Err(err) => {
            eprintln!("clip-image: {}: {err}", path.display());
            return ExitCode::FAILURE;
        }
    };
    let link = uri(&path);
    let sources = vec![
        offer("image/png", png),
        offer(
            "x-special/gnome-copied-files",
            format!("copy\n{link}").into_bytes(),
        ),
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;

    #[test]
    fn file_uri_escapes_reserved_characters_and_line_breaks() {
        assert_eq!(
            uri(Path::new("/tmp/a b#c%?\r\n.png")),
            "file:///tmp/a%20b%23c%25%3F%0D%0A.png"
        );
    }

    #[test]
    fn file_uri_preserves_utf8_and_non_utf8_filename_bytes() {
        assert_eq!(uri(Path::new("/tmp/é.png")), "file:///tmp/%C3%A9.png");
        assert_eq!(
            uri(Path::new(OsStr::from_bytes(b"/tmp/\xff.png"))),
            "file:///tmp/%FF.png"
        );
    }

    #[test]
    fn file_uri_keeps_unreserved_characters() {
        assert_eq!(
            uri(Path::new("/tmp/AZaz09-_.~.png")),
            "file:///tmp/AZaz09-_.~.png"
        );
    }
}
