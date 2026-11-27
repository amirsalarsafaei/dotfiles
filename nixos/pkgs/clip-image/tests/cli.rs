use std::fs;
use std::path::PathBuf;
use std::process::{Command, Output};
use std::sync::atomic::{AtomicUsize, Ordering};

struct Fixture(PathBuf);

impl Fixture {
    fn new() -> Self {
        static NEXT_ID: AtomicUsize = AtomicUsize::new(0);
        let path = std::env::temp_dir().join(format!(
            "clip-image-test-{}-{}",
            std::process::id(),
            NEXT_ID.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&path).unwrap();
        Self(path)
    }

    fn run(&self, args: &[&str]) -> Output {
        Command::new(env!("CARGO_BIN_EXE_clip-image"))
            .args(args)
            .current_dir(&self.0)
            .env_remove("WAYLAND_DISPLAY")
            .env_remove("WAYLAND_SOCKET")
            .env("XDG_RUNTIME_DIR", &self.0)
            .output()
            .unwrap()
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        fs::remove_dir_all(&self.0).unwrap();
    }
}

#[test]
fn help_succeeds_without_a_compositor() {
    let fixture = Fixture::new();
    for arg in ["-h", "--help"] {
        let output = fixture.run(&[arg]);
        assert!(output.status.success());
        assert!(String::from_utf8_lossy(&output.stdout).contains("usage:"));
    }
}

#[test]
fn missing_or_extra_arguments_are_usage_errors() {
    let fixture = Fixture::new();
    for args in [vec![], vec!["one.png", "two.png"]] {
        let output = fixture.run(&args);
        assert_eq!(output.status.code(), Some(2));
        assert!(String::from_utf8_lossy(&output.stderr).contains("usage:"));
    }
}

#[test]
fn non_png_and_empty_files_are_rejected_before_connecting() {
    let fixture = Fixture::new();
    for data in [b"".as_slice(), b"not a PNG", b"\x89PNG"] {
        fs::write(fixture.0.join("invalid.png"), data).unwrap();
        let output = fixture.run(&["invalid.png"]);
        assert_eq!(output.status.code(), Some(1));
        assert!(String::from_utf8_lossy(&output.stderr).contains("PNG signature"));
    }
}

#[test]
fn directories_are_rejected_before_connecting() {
    let fixture = Fixture::new();
    let output = fixture.run(&["."]);
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&output.stderr).contains("regular PNG file"));
}

#[test]
fn missing_file_reports_its_name() {
    let fixture = Fixture::new();
    let output = fixture.run(&["missing.png"]);
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&output.stderr).contains("missing.png:"));
}
