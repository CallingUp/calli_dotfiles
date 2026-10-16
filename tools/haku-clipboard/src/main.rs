use serde_json::{json, Value};
use std::{
    env, fs,
    io::{self, Read, Seek, SeekFrom, Write},
    os::unix::fs::{MetadataExt, PermissionsExt},
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const MAX_BYTES: u64 = 16 * 1024 * 1024;
fn valid_id(id: &str) -> bool {
    !id.is_empty() && id.bytes().all(|b| b.is_ascii_digit())
}
fn classify(text: &str) -> &'static str {
    if text.starts_with("[[ binary data") {
        if text
            .split(|c: char| !c.is_alphanumeric() && c != '_')
            .any(|s| {
                ["png", "jpeg", "jpg", "gif", "webp", "bmp", "image"]
                    .contains(&s.to_ascii_lowercase().as_str())
            })
        {
            "image"
        } else {
            "binary"
        }
    } else if ["https://", "http://"].iter().any(|p| {
        text.strip_prefix(p)
            .is_some_and(|s| s.chars().next().is_some_and(|c| !c.is_whitespace()))
    }) {
        "link"
    } else {
        "text"
    }
}
fn output(args: &[&str]) -> Result<Vec<u8>> {
    let result = Command::new(args[0])
        .args(&args[1..])
        .stderr(Stdio::null())
        .output()?;
    if !result.status.success() {
        return Err("subprocess failed".into());
    }
    Ok(result.stdout)
}
fn parse_entries(text: &str) -> Vec<Value> {
    let mut rows = Vec::new();
    for line in text.split('\n') {
        if let Some((id, label)) = line.split_once('\t') {
            if valid_id(id) {
                rows.push(json!({"id":id,"label":label,"kind":classify(label),"index":rows.len()}));
            }
        }
    }
    rows
}
fn entries() -> Result<Vec<Value>> {
    Ok(parse_entries(std::str::from_utf8(&output(&[
        "cliphist", "list",
    ])?)?))
}
fn runtime() -> PathBuf {
    env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir)
}
fn private_directory(path: &Path) -> Result<()> {
    let m = fs::symlink_metadata(path)?;
    if !m.is_dir() || m.uid() != unsafe { libc::geteuid() } || m.mode() & 0o077 != 0 {
        return Err("not private".into());
    }
    Ok(())
}
fn extension(data: &[u8]) -> &'static str {
    if data.starts_with(b"\x89PNG\r\n\x1a\n") {
        "png"
    } else if data.starts_with(b"\xff\xd8\xff") {
        "jpg"
    } else if data.starts_with(b"GIF87a") || data.starts_with(b"GIF89a") {
        "gif"
    } else if data.starts_with(b"RIFF") && data.get(8..12) == Some(b"WEBP") {
        "webp"
    } else if data.starts_with(b"BM") {
        "bmp"
    } else {
        ""
    }
}
fn valid_preview_name(name: &str) -> bool {
    name.strip_prefix("preview-")
        .and_then(|s| s.rsplit_once('.'))
        .is_some_and(|(id, ext)| {
            valid_id(id) && ["png", "jpg", "gif", "webp", "bmp"].contains(&ext)
        })
}
fn cleanup(path: &Path) -> Result<Value> {
    private_directory(path)?;
    if path.parent().ok_or("missing parent")?.canonicalize()? != runtime().canonicalize()?
        || !path
            .file_name()
            .and_then(|s| s.to_str())
            .is_some_and(|s| s.starts_with("haku-clipboard-"))
    {
        return Err("invalid directory".into());
    }
    let files = fs::read_dir(path)?.collect::<std::result::Result<Vec<_>, _>>()?;
    for file in &files {
        if !valid_preview_name(&file.file_name().to_string_lossy()) || file.file_type()?.is_dir() {
            return Err("unexpected file".into());
        }
    }
    for file in files {
        fs::remove_file(file.path())?;
    }
    fs::remove_dir(path)?;
    Ok(json!({"ok":true}))
}
fn decode(id: &str) -> Result<Vec<u8>> {
    let mut proc = Command::new("cliphist")
        .args(["decode", id])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()?;
    let mut data = Vec::new();
    let read = proc
        .stdout
        .take()
        .ok_or("no stdout")?
        .take(MAX_BYTES + 1)
        .read_to_end(&mut data);
    if read.is_err() || data.len() as u64 > MAX_BYTES {
        let _ = proc.kill();
        let _ = proc.wait();
        return Err("preview limit".into());
    }
    if !proc.wait()?.success() {
        return Err("decode failed".into());
    }
    Ok(data)
}
fn session() -> Result<Value> {
    let rows = entries()?;
    let home = PathBuf::from(env::var_os("HOME").ok_or("HOME missing")?);
    let state = home.join(".local/state/haku_theme");
    let colors = fs::read_to_string(state.join("colors.css")).unwrap_or_default();
    let fonts = fs::read_to_string(state.join("fonts.css")).unwrap_or_default();
    let accent = colors
        .split("accent_color")
        .nth(1)
        .and_then(|s| s.split_whitespace().next())
        .and_then(|s| s.get(..7))
        .filter(|s| {
            s.len() == 7 && s.starts_with('#') && s[1..].bytes().all(|b| b.is_ascii_hexdigit())
        })
        .unwrap_or("#8d7c74");
    let font = fonts
        .split("font-family:")
        .nth(1)
        .and_then(|s| s.split('"').nth(1))
        .unwrap_or("CommitMono Nerd Font");
    let cache = tempfile::Builder::new()
        .prefix("haku-clipboard-")
        .permissions(fs::Permissions::from_mode(0o700))
        .tempdir_in(runtime())?
        .keep();
    Ok(json!({"accent":accent,"font":font,"rows":rows,"cacheDir":cache}))
}
fn worker(args: &[String]) -> Result<Value> {
    let action = args.first().ok_or("missing action")?.as_str();
    if action == "session" {
        return session();
    }
    if action == "cleanup" {
        return cleanup(Path::new(args.get(1).ok_or("missing directory")?));
    }
    if action == "list" {
        return Ok(json!({"ok":true,"rows":entries()?}));
    }
    if action == "wipe" {
        output(&["cliphist", "wipe"])?;
        return Ok(json!({"ok":true,"rows":entries()?}));
    }
    let id = args.get(1).ok_or("missing id")?;
    if !valid_id(id) {
        return Err("invalid id".into());
    }
    match action {
        "delete" => {
            let bytes = output(&["cliphist", "list"])?;
            let text = std::str::from_utf8(&bytes)?;
            let line = text
                .split('\n')
                .find(|line| {
                    line.split_once('\t')
                        .is_some_and(|(row_id, _)| row_id == id)
                })
                .ok_or("missing entry")?;
            let mut proc = Command::new("cliphist")
                .arg("delete")
                .stdin(Stdio::piped())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()?;
            let write = writeln!(proc.stdin.take().ok_or("no stdin")?, "{line}");
            let status = proc.wait()?;
            write?;
            if !status.success() {
                return Err("delete failed".into());
            }
            Ok(json!({"ok":true,"rows":entries()?}))
        }
        "copy" => {
            // Keep originals unbounded on disk, never in the preview buffer.
            let mut file = tempfile::tempfile()?;
            if !Command::new("cliphist")
                .args(["decode", id])
                .stdout(file.try_clone()?)
                .stderr(Stdio::null())
                .status()?
                .success()
            {
                return Err("decode failed".into());
            }
            file.seek(SeekFrom::Start(0))?;
            if !Command::new("wl-copy")
                .stdin(file)
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()?
                .success()
            {
                return Err("copy failed".into());
            }
            Ok(json!({"ok":true}))
        }
        "preview" => {
            let data = decode(id)?;
            let ext = extension(&data);
            if !ext.is_empty() {
                let cache = Path::new(args.get(2).ok_or("missing directory")?);
                private_directory(cache)?;
                let target = cache.join(format!("preview-{id}.{ext}"));
                // Atomically replace the directory entry without following a target symlink.
                let mut file = tempfile::NamedTempFile::new_in(cache)?;
                file.write_all(&data)?;
                file.persist(&target).map_err(|e| e.error)?;
                return Ok(json!({"image":target,"text":"","bytes":data.len()}));
            }
            match std::str::from_utf8(&data) {
                Ok(text) => Ok(
                    json!({"image":"","text":text.chars().take(65536).collect::<String>(),"truncated":text.chars().count()>65536,"bytes":data.len()}),
                ),
                Err(_) => Ok(
                    json!({"image":"","text":format!("Contenido binario · {} bytes",data.len()),"bytes":data.len()}),
                ),
            }
        }
        _ => Err("invalid action".into()),
    }
}
fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    match worker(&args) {
        Ok(value) => {
            let mut out = io::stdout().lock();
            if writeln!(out, "{value}").is_err() {
                if args.first().is_some_and(|a| a == "session") {
                    if let Some(path) = value["cacheDir"].as_str() {
                        let _ = cleanup(Path::new(path));
                    }
                }
                std::process::exit(1);
            }
        }
        Err(_) => {
            println!(
                "{}",
                json!({"ok":false,"error":"No se pudo completar la operación"})
            );
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ids_are_strict() {
        for id in ["", "1;echo", "-1", "１２"] {
            assert!(!valid_id(id));
        }
        assert!(valid_id("123"));
    }
    #[test]
    fn classification() {
        assert_eq!(classify("https://example.org"), "link");
        assert_eq!(classify("[[ binary data PNG ]]"), "image");
        assert_eq!(classify("[[ binary data ]]"), "binary");
        assert_eq!(classify("<b>text</b>"), "text");
    }
    #[test]
    fn signatures() {
        assert_eq!(extension(b"\x89PNG\r\n\x1a\n"), "png");
        assert_eq!(extension(b"RIFF1234WEBP"), "webp");
        assert_eq!(extension(b"hello"), "");
    }
    #[test]
    fn list_is_literal() {
        let rows = parse_entries("42\t$HOME `x`\ninvalid\n43\thttps://test\n");
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0]["label"], "$HOME `x`");
        assert_eq!(rows[1]["kind"], "link");
    }
    #[test]
    fn cleanup_names() {
        assert!(valid_preview_name("preview-123.png"));
        for s in ["keep.txt", "preview-../x.png", "preview-1.sh"] {
            assert!(!valid_preview_name(s));
        }
    }
    #[test]
    fn private_directory_required() {
        let tmp = tempfile::Builder::new()
            .permissions(fs::Permissions::from_mode(0o700))
            .tempdir()
            .unwrap();
        assert!(private_directory(tmp.path()).is_ok());
        fs::set_permissions(tmp.path(), fs::Permissions::from_mode(0o755)).unwrap();
        assert!(private_directory(tmp.path()).is_err());
    }
}
