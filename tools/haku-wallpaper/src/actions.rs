use crate::{catalog, current, local_path, supported, web, Result, Value};
use serde_json::json;
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    os::{
        fd::AsRawFd,
        unix::{fs::PermissionsExt, process::CommandExt},
    },
    path::{Path, PathBuf},
    process::{Command, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

fn lock(home: &Path) -> Result<File> {
    let state = home.join(".local/state/haku_theme");
    fs::create_dir_all(&state)?;
    let file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(state.join("wallpaper_selector_apply.lock"))?;
    if unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX) } != 0 {
        return Err(std::io::Error::last_os_error().into());
    }
    Ok(file)
}
fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    let mut file = tempfile::NamedTempFile::new_in(path.parent().ok_or("missing parent")?)?;
    file.write_all(bytes)?;
    file.persist(path).map_err(|e| e.error)?;
    Ok(())
}
fn executable(path: &Path) -> Result<()> {
    if !path.is_file() || path.metadata()?.permissions().mode() & 0o111 == 0 {
        return Err("missing sync script".into());
    }
    Ok(())
}
fn detached(script: &Path, args: &[&str]) -> Result<()> {
    let mut command = Command::new(script);
    command
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    unsafe {
        command.pre_exec(|| {
            if libc::setsid() == -1 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    command.spawn()?;
    Ok(())
}
fn target(home: &Path, item: &Value) -> Result<PathBuf> {
    match item["kind"].as_str() {
        Some("local") => local_path(home, item["path"].as_str().ok_or("missing path")?),
        Some("web") => {
            let id = item["id"].as_str().ok_or("missing id")?;
            if id.len() != 6 || !id.bytes().all(|b| b.is_ascii_alphanumeric()) {
                return Err("invalid id".into());
            }
            let url = web::allowed(item["path"].as_str().ok_or("missing URL")?)?;
            let extension = Path::new(url.path())
                .extension()
                .and_then(|s| s.to_str())
                .ok_or("missing extension")?
                .to_ascii_lowercase();
            if !supported(Path::new(&format!("image.{extension}"))) {
                return Err("invalid format".into());
            }
            let gallery = home.join("Pictures/Wallpapers");
            fs::create_dir_all(&gallery)?;
            let target = gallery.join(format!("wallhaven-{id}.{extension}"));
            // Never follow a gallery symlink to a location outside it.
            if fs::symlink_metadata(&target).is_ok() {
                local_path(home, target.to_str().ok_or("invalid path")?)?;
            }
            if !target.is_file() || target.metadata()?.len() == 0 {
                atomic_write(&target, &web::fetch(url.as_str(), 64 * 1024 * 1024)?)?;
            }
            local_path(home, target.to_str().ok_or("invalid path")?)
        }
        _ => Err("invalid kind".into()),
    }
}
pub fn apply(home: &Path, item: &Value) -> Result<Value> {
    let _lock = lock(home)?;
    let target = target(home, item)?;
    let path = target.to_str().ok_or("invalid path")?;
    let previous = current(home);
    if previous == path {
        return Ok(json!({"ok":true,"current":path,"unchanged":true}));
    }
    let transition = home.join(".local/bin/wallpaper-transition");
    let sync = home.join(".local/bin/wallpaper-theme-sync");
    executable(&transition)?;
    executable(&sync)?;
    let state = home.join(".local/state/haku_theme");
    let previous_generation = fs::read_to_string(state.join("wallpaper_generation"))
        .unwrap_or_default()
        .trim()
        .parse::<u128>()
        .unwrap_or(0);
    let generation = SystemTime::now()
        .duration_since(UNIX_EPOCH)?
        .as_nanos()
        .max(previous_generation.saturating_add(1))
        .to_string();
    atomic_write(&state.join("wallpaper_generation"), generation.as_bytes())?;
    atomic_write(
        &state.join("current_wallpaper"),
        format!("{path}\n").as_bytes(),
    )?;
    let mut random = [0u8; 1];
    let _ = File::open("/dev/urandom").and_then(|mut file| file.read_exact(&mut random));
    let direction = ["left", "right", "top", "bottom"][random[0] as usize % 4];
    detached(&transition, &[&previous, path, direction])?;
    detached(&sync, &[path, &generation])?;
    Ok(json!({"ok":true,"current":path,"unchanged":false}))
}
pub fn trash(home: &Path, item: &Value) -> Result<Value> {
    let _lock = lock(home)?;
    let path = local_path(home, item["path"].as_str().ok_or("missing path")?)?;
    if path.to_str() == Some(current(home).as_str()) {
        return Err("active wallpaper".into());
    }
    if !Command::new("gio")
        .arg("trash")
        .arg(path)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?
        .success()
    {
        return Err("trash failed".into());
    }
    catalog(home)
}
