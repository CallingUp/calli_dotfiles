use serde_json::{json, Value};
mod actions;
mod launcher;
mod web;
use sha2::{Digest, Sha256};
use std::{
    env, fs,
    io::{self, BufRead, Read},
    path::{Path, PathBuf},
    process::{Command, Stdio},
    thread,
    time::{Duration, Instant, UNIX_EPOCH},
};

type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
const EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "webp", "avif", "gif"];
fn supported(path: &Path) -> bool {
    path.extension()
        .and_then(|s| s.to_str())
        .is_some_and(|s| EXTENSIONS.contains(&s.to_ascii_lowercase().as_str()))
}
fn home() -> Result<PathBuf> {
    Ok(PathBuf::from(env::var_os("HOME").ok_or("missing HOME")?))
}
fn current(home: &Path) -> String {
    fs::read_to_string(home.join(".local/state/haku_theme/current_wallpaper"))
        .unwrap_or_default()
        .trim()
        .to_owned()
}
fn local_path(home: &Path, value: &str) -> Result<PathBuf> {
    let path = Path::new(value).canonicalize()?;
    if path.parent() != Some(home.join("Pictures/Wallpapers").canonicalize()?.as_path())
        || !path.is_file()
        || !supported(&path)
    {
        return Err("invalid gallery path".into());
    }
    Ok(path)
}
fn catalog(home: &Path) -> Result<Value> {
    let gallery = home.join("Pictures/Wallpapers");
    fs::create_dir_all(&gallery)?;
    let mut files = fs::read_dir(&gallery)?.collect::<std::result::Result<Vec<_>, _>>()?;
    files.sort_by_key(|f| f.file_name().to_string_lossy().to_lowercase());
    let mut rows = Vec::new();
    for file in files {
        let path = file.path();
        if !path.is_file() || !supported(&path) {
            continue;
        }
        let Ok(resolved) = local_path(home, path.to_str().ok_or("invalid UTF-8 path")?) else {
            continue;
        };
        let cached = local_thumbnail_target(home, &resolved)
            .ok()
            .filter(|target| nonempty_file(target))
            .and_then(|target| {
                target
                    .file_name()
                    .map(|name| name.to_string_lossy().into_owned())
            });
        rows.push(json!({"key": resolved, "path": resolved, "label": path.file_stem().unwrap_or_default().to_string_lossy(), "kind":"local", "id":"", "resolution":"", "cachedThumbnail":cached}));
    }
    Ok(json!({"ok":true,"rows":rows,"current":current(home)}))
}
fn nonempty_file(path: &Path) -> bool {
    path.metadata()
        .is_ok_and(|metadata| metadata.is_file() && metadata.len() > 0)
}
fn local_thumbnail_target(home: &Path, source: &Path) -> Result<PathBuf> {
    // Same signature as thumbnail() and the previous Python implementation.
    // A modified original gets a different cache path, never a stale preview.
    let mtime = source
        .metadata()?
        .modified()?
        .duration_since(UNIX_EPOCH)?
        .as_nanos();
    let signature = format!("qml-v1:{}:{mtime}", source.to_str().ok_or("invalid path")?);
    Ok(home
        .join(".cache/haku-wallpaper-carousel/qml")
        .join(format!("{:x}.jpg", Sha256::digest(signature.as_bytes()))))
}
fn thumbnail(home: &Path, item: &Value) -> Result<Value> {
    let local = item["kind"] == "local";
    let source = if local {
        local_path(home, item["path"].as_str().ok_or("missing path")?)?
    } else {
        PathBuf::new()
    };
    // Preserve the Python cache keys so existing thumbnails are reused.
    let cache = home.join(".cache/haku-wallpaper-carousel/qml");
    fs::create_dir_all(&cache)?;
    let target = if local {
        local_thumbnail_target(home, &source)?
    } else {
        let thumb = item["thumb"].as_str().ok_or("missing URL")?;
        web::allowed(thumb)?;
        let signature = format!("qml-web-v1:{thumb}");
        cache.join(format!("{:x}.jpg", Sha256::digest(signature.as_bytes())))
    };
    if nonempty_file(&target) {
        return Ok(json!({"ok":true,"key":item["key"],"image":target}));
    }
    let temp = tempfile::Builder::new()
        .prefix("thumb-")
        .tempdir_in(&cache)?;
    let image = temp.path().join("thumb.jpg");
    let source = if local {
        source
    } else {
        let path = temp.path().join("source");
        fs::write(
            &path,
            web::fetch(
                item["thumb"].as_str().ok_or("missing URL")?,
                8 * 1024 * 1024,
            )?,
        )?;
        path
    };
    let mut proc = Command::new("magick")
        .arg(format!("{}[0]", source.to_str().ok_or("invalid path")?))
        .args([
            "-auto-orient",
            "-thumbnail",
            "420x300^",
            "-gravity",
            "center",
            "-extent",
            "420x300",
            "-strip",
            "-quality",
            "82",
        ])
        .arg(&image)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    let start = Instant::now();
    loop {
        if let Some(status) = proc.try_wait()? {
            if !status.success() {
                return Err("thumbnail failed".into());
            }
            break;
        }
        if start.elapsed() >= Duration::from_secs(20) {
            let _ = proc.kill();
            let _ = proc.wait();
            return Err("thumbnail timed out".into());
        }
        thread::sleep(Duration::from_millis(20));
    }
    fs::rename(image, &target)?;
    Ok(json!({"ok":true,"key":item["key"],"image":target}))
}
fn run() -> Result<()> {
    let home = home()?;
    let mut request = String::new();
    io::stdin()
        .lock()
        .take(4 * 1024 * 1024 + 1)
        .read_line(&mut request)?;
    if request.len() > 4 * 1024 * 1024 {
        return Err("request too large".into());
    }
    let data: Value = serde_json::from_str(&request)?;
    let result = match data["action"].as_str() {
        Some("list") => catalog(&home)?,
        Some("thumb") => thumbnail(&home, &data["item"])?,
        Some("search") => web::search(&home, &data)?,
        Some("apply") => actions::apply(&home, &data["item"])?,
        Some("trash") => actions::trash(&home, &data["item"])?,
        _ => return Err("unknown action".into()),
    };
    println!("{result}");
    Ok(())
}
fn main() {
    let result = if env::args().nth(1).as_deref() == Some("--launch") {
        launcher::launch()
    } else {
        run()
    };
    if result.is_err() {
        println!(
            "{}",
            json!({"ok":false,"error":"No se pudo completar la operación. Reintenta."})
        );
        std::process::exit(1);
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn formats() {
        assert!(supported(Path::new("photo.PNG")));
        assert!(!supported(Path::new("photo.sh")));
    }
    #[test]
    fn gallery_restrictions() {
        let home = tempfile::tempdir().unwrap();
        let gallery = home.path().join("Pictures/Wallpapers");
        fs::create_dir_all(&gallery).unwrap();
        let inside = gallery.join("a.png");
        fs::write(&inside, b"test").unwrap();
        let outside = home.path().join("a.png");
        fs::write(&outside, b"test").unwrap();
        assert!(local_path(home.path(), inside.to_str().unwrap()).is_ok());
        assert!(local_path(home.path(), outside.to_str().unwrap()).is_err());
        std::os::unix::fs::symlink(&outside, gallery.join("escape.png")).unwrap();
        assert_eq!(
            catalog(home.path()).unwrap()["rows"]
                .as_array()
                .unwrap()
                .len(),
            1
        );
    }
    #[test]
    fn empty_gallery() {
        let home = tempfile::tempdir().unwrap();
        let result = catalog(home.path()).unwrap();
        assert_eq!(result["rows"], json!([]));
        assert_eq!(result["current"], "");
    }
}
