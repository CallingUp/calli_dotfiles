use crate::{catalog, home, Result};
use std::{
    fs,
    io::Write,
    os::unix::fs::PermissionsExt,
    path::Path,
    process::{Command, Stdio},
    sync::atomic::{AtomicBool, Ordering},
    thread,
    time::Duration,
};

static TERMINATE: AtomicBool = AtomicBool::new(false);
extern "C" fn terminate(_: libc::c_int) {
    TERMINATE.store(true, Ordering::Relaxed);
}

fn ipc(config: &Path, target: &str, method: &str, args: &[&str]) -> Result<bool> {
    Ok(Command::new("quickshell")
        .args(["ipc", "-p"])
        .arg(config)
        .args(["call", target, method])
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?
        .success())
}

pub fn launch() -> Result<()> {
    let home = home()?;
    let standalone = home.join("haku_shell/config/quickshell/haku-wallpaper/shell.qml");
    let shell = home.join("haku_shell/config/quickshell/minflair-niri/niri-preview.qml");
    if ipc(&standalone, "haku-wallpaper", "close", &[])? {
        return Ok(());
    }
    // Close immediately without rescanning the gallery on the second keypress.
    let status = Command::new("quickshell")
        .args(["ipc", "-p"])
        .arg(&shell)
        .args(["call", "haku-wallpaper-host", "status"])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()?;
    if status.status.success()
        && status.stdout.strip_suffix(b"\n").unwrap_or(&status.stdout) == b"open"
    {
        if ipc(&shell, "haku-wallpaper-host", "close", &[])? {
            return Ok(());
        }
    }
    let mut request = catalog(&home)?;
    let state = home.join(".local/state/haku_theme");
    let colors = fs::read_to_string(state.join("colors.css")).unwrap_or_default();
    let fonts = fs::read_to_string(state.join("fonts.css")).unwrap_or_default();
    let accent = colors
        .split("accent_color")
        .nth(1)
        .and_then(|s| s.split_whitespace().next())
        .and_then(|s| s.get(..7))
        .filter(|s| s.starts_with('#') && s[1..].bytes().all(|b| b.is_ascii_hexdigit()))
        .unwrap_or("#8d7c74");
    let font = fonts
        .split("font-family:")
        .nth(1)
        .and_then(|s| s.split('"').nth(1))
        .unwrap_or("CommitMono Nerd Font");
    request["accent"] = accent.into();
    request["font"] = font.into();
    if ipc(
        &shell,
        "haku-wallpaper-host",
        "toggle",
        &[&request.to_string()],
    )? {
        return Ok(());
    }

    // No shell is running: retain the independent QML renderer and private request.
    let runtime = std::env::var_os("XDG_RUNTIME_DIR")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(std::env::temp_dir);
    let temp = tempfile::Builder::new()
        .prefix("haku-wallpaper-launch-")
        .permissions(fs::Permissions::from_mode(0o700))
        .tempdir_in(runtime)?;
    let mut file = tempfile::NamedTempFile::new_in(temp.path())?;
    writeln!(file, "{request}")?;
    unsafe {
        libc::signal(libc::SIGTERM, terminate as *const () as libc::sighandler_t);
        libc::signal(libc::SIGINT, terminate as *const () as libc::sighandler_t);
    }
    let mut child = Command::new("quickshell")
        .arg("-p")
        .arg(standalone)
        .arg("--no-duplicate")
        .env("HAKU_MENU_REQUEST", file.path())
        .env_remove("HAKU_MENU_RESULT")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    loop {
        if let Some(status) = child.try_wait()? {
            if !status.success() {
                return Err("standalone launch failed".into());
            }
            break;
        }
        if TERMINATE.load(Ordering::Relaxed) {
            let _ = child.kill();
            let _ = child.wait();
            break;
        }
        thread::sleep(Duration::from_millis(100));
    }
    Ok(())
}
