use crate::{Job, Message};
use iced::futures::SinkExt;
use iced::{Subscription, Task};
use notify::Watcher;
use serde_json::{Value, json};
use std::{
    io::{BufRead, Write},
    os::unix::process::CommandExt,
    path::PathBuf,
    process::Stdio,
    sync::{Arc, Mutex},
};
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt};

pub type Reply = Arc<Mutex<Option<tokio::sync::oneshot::Sender<String>>>>;
#[derive(Clone, Debug)]
pub enum Control {
    Close,
    Step(i64),
    Query(String),
    Source(String),
    Accept,
    Status(Reply),
}
pub fn state_dir() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state/haku_theme")
}
pub fn socket_path() -> PathBuf {
    PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR").expect("XDG_RUNTIME_DIR missing"))
        .join("haku-carousel-rust.sock")
}
pub fn control(request: &str) -> std::io::Result<String> {
    let mut stream = std::os::unix::net::UnixStream::connect(socket_path())?;
    stream.set_read_timeout(Some(std::time::Duration::from_secs(3)))?;
    stream.set_write_timeout(Some(std::time::Duration::from_secs(3)))?;
    writeln!(stream, "{request}")?;
    let mut response = String::new();
    std::io::BufReader::new(stream).read_line(&mut response)?;
    Ok(response.trim().into())
}
struct ProcessGroup {
    pid: u32,
    cancel: bool,
}
impl Drop for ProcessGroup {
    fn drop(&mut self) {
        if self.cancel && self.pid > 0 {
            // This PID owns a dedicated process group created by process_group(0).
            unsafe {
                libc::kill(-(self.pid as i32), libc::SIGTERM);
            }
        }
    }
}
pub async fn backend(request: &Value, cancel_on_close: bool) -> Result<Value, String> {
    let worker = PathBuf::from(std::env::var_os("HOME").ok_or("HOME missing")?)
        .join("haku_shell/tools/haku-wallpaper/target/release/haku-wallpaper");
    let mut command = tokio::process::Command::new("timeout");
    command.as_std_mut().process_group(0);
    let mut child = command
        .args(["--kill-after=2s", "150s"])
        .arg(worker)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())?;
    let mut group = ProcessGroup {
        pid: child.id().ok_or("Worker PID missing")?,
        cancel: cancel_on_close,
    };
    let mut stdin = child.stdin.take().ok_or("Missing worker stdin")?;
    stdin
        .write_all(format!("{request}\n").as_bytes())
        .await
        .map_err(|e| e.to_string())?;
    drop(stdin);
    let out = child.wait_with_output().await.map_err(|e| e.to_string())?;
    group.cancel = false;
    let result: Value = serde_json::from_slice(&out.stdout)
        .map_err(|_| "El backend no devolvió JSON válido".to_string())?;
    if !out.status.success() || result["ok"] != true {
        return Err(result["error"]
            .as_str()
            .unwrap_or("No se pudo completar la operación")
            .into());
    }
    Ok(result)
}
pub fn job(job: Job) -> Task<Message> {
    let request = match &job {
        Job::Catalog => json!({"action":"list"}),
        Job::Search { query, page } => json!({"action":"search","query":query,"page":page}),
        Job::Action { name, item } => json!({"action":name,"item":item.0}),
    };
    Task::perform(
        async move {
            // Read-only requests are cancelled on exit. An explicit Apply/Trash
            // may finish under timeout, avoiding interruption of atomic state writes.
            let result = backend(&request, !matches!(&job, Job::Action { .. })).await;
            (job, result)
        },
        |(job, result)| Message::JobDone(job, result),
    )
}
pub fn thumbnail(item: crate::carousel_model::Row) -> Task<Message> {
    let key = item.key().to_owned();
    Task::perform(
        async move {
            let result = async {
                let result = backend(&json!({"action":"thumb","item":item.0}), true).await?;
                let path = result["image"].as_str().ok_or("Miniatura ausente")?;
                let image = image::open(path).map_err(|e| e.to_string())?.into_rgba8();
                if image.width() > 420 || image.height() > 300 {
                    return Err("Miniatura demasiado grande".into());
                }
                Ok(iced::widget::image::Handle::from_rgba(
                    image.width(),
                    image.height(),
                    image.into_raw(),
                ))
            }
            .await;
            (key, result)
        },
        |(key, result)| Message::ThumbDone(key, result),
    )
}
pub fn ipc() -> Subscription<Message> {
    Subscription::run(|| {
        iced::stream::channel(
            16,
            |mut output: iced::futures::channel::mpsc::Sender<Message>| async move {
                let Ok(listener) = tokio::net::UnixListener::bind(socket_path()) else {
                    std::future::pending::<()>().await;
                    return;
                };
                loop {
                    let Ok((mut stream, _)) = listener.accept().await else {
                        continue;
                    };
                    let mut data = Vec::new();
                    let mut reader = tokio::io::BufReader::new((&mut stream).take(4096));
                    let Ok(Ok(length)) = tokio::time::timeout(
                        std::time::Duration::from_secs(2),
                        reader.read_until(b'\n', &mut data),
                    )
                    .await
                    else {
                        continue;
                    };
                    if length == 4096 || !data.ends_with(b"\n") {
                        continue;
                    }
                    let text = String::from_utf8_lossy(&data[..length]);
                    let request = text.trim();
                    if request == "status" {
                        let (tx, rx) = tokio::sync::oneshot::channel();
                        if output
                            .send(Message::Control(Control::Status(Arc::new(Mutex::new(
                                Some(tx),
                            )))))
                            .await
                            .is_err()
                        {
                            break;
                        }
                        if let Ok(Ok(status)) =
                            tokio::time::timeout(std::time::Duration::from_secs(2), rx).await
                        {
                            let _ = stream.write_all(format!("{status}\n").as_bytes()).await;
                        }
                        continue;
                    }
                    let control = if request == "close" {
                        Some(Control::Close)
                    } else if request == "accept" {
                        Some(Control::Accept)
                    } else if let Some(v) = request.strip_prefix("step ") {
                        v.parse::<i64>()
                            .ok()
                            .map(|v| Control::Step(v.clamp(-100, 100)))
                    } else if let Some(v) = request.strip_prefix("query ") {
                        serde_json::from_str::<String>(v).ok().map(Control::Query)
                    } else {
                        request
                            .strip_prefix("source ")
                            .map(|v| Control::Source(v.into()))
                    };
                    if let Some(control) = control {
                        let _ = stream.write_all(b"ok\n").await;
                        if output.send(Message::Control(control)).await.is_err() {
                            break;
                        }
                    } else {
                        let _ = stream.write_all(b"invalid\n").await;
                    }
                }
            },
        )
    })
}
pub fn colors() -> Subscription<Message> {
    Subscription::run(|| {
        iced::stream::channel(
            4,
            |mut output: iced::futures::channel::mpsc::Sender<Message>| async move {
                let (tx, mut rx) = tokio::sync::mpsc::channel(4);
                let Ok(mut watcher) =
                    notify::recommended_watcher(move |event: notify::Result<notify::Event>| {
                        if let Ok(event) = event {
                            if event
                                .paths
                                .iter()
                                .any(|p| p.file_name().is_some_and(|n| n == "colors.css"))
                            {
                                let _ = tx.try_send(());
                            }
                        }
                    })
                else {
                    std::future::pending::<()>().await;
                    return;
                };
                if watcher
                    .watch(&state_dir(), notify::RecursiveMode::NonRecursive)
                    .is_err()
                {
                    std::future::pending::<()>().await;
                    return;
                }
                while rx.recv().await.is_some() {
                    tokio::time::sleep(std::time::Duration::from_millis(50)).await;
                    while rx.try_recv().is_ok() {}
                    if output.send(Message::ReloadColors).await.is_err() {
                        break;
                    }
                }
            },
        )
    })
}
pub fn accent() -> iced::Color {
    let css = std::fs::read_to_string(state_dir().join("colors.css")).unwrap_or_default();
    css.lines()
        .find(|s| s.contains("accent_color "))
        .and_then(|s| s.split_whitespace().nth(2))
        .and_then(|s| s.trim_end_matches(';').parse().ok())
        .unwrap_or(iced::Color::from_rgb8(185, 149, 115))
}
pub fn font() -> iced::Font {
    let css = std::fs::read_to_string(state_dir().join("fonts.css")).unwrap_or_default();
    let family = css
        .split("font-family:")
        .nth(1)
        .and_then(|s| s.split('"').nth(1))
        .unwrap_or("monospace")
        .to_owned();
    // Iced font names require 'static; allocate once per finite UI process.
    iced::Font::with_name(Box::leak(family.into_boxed_str()))
}

pub fn init_logging() {
    struct AdapterLogger;
    impl log::Log for AdapterLogger {
        fn enabled(&self, m: &log::Metadata) -> bool {
            m.target().starts_with("iced_wgpu") && m.level() <= log::Level::Info
        }
        fn log(&self, r: &log::Record) {
            if self.enabled(r.metadata()) {
                let message = r.args().to_string();
                if message.starts_with("Selected:") {
                    eprintln!("{message}");
                }
            }
        }
        fn flush(&self) {}
    }
    static LOGGER: AdapterLogger = AdapterLogger;
    let _ = log::set_logger(&LOGGER);
    log::set_max_level(log::LevelFilter::Info);
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn cancelling_read_job_terminates_its_group() {
        tokio::runtime::Runtime::new().unwrap().block_on(async {
            let mut command = tokio::process::Command::new("timeout");
            command.as_std_mut().process_group(0);
            let mut child = command.args(["5s", "sleep", "4"]).spawn().unwrap();
            let group = ProcessGroup {
                pid: child.id().unwrap(),
                cancel: true,
            };
            tokio::time::sleep(std::time::Duration::from_millis(25)).await;
            drop(group);
            let status = tokio::time::timeout(std::time::Duration::from_secs(2), child.wait())
                .await
                .unwrap()
                .unwrap();
            assert!(!status.success());
        });
    }
    #[test]
    fn confirmed_actions_can_finish_without_ui() {
        tokio::runtime::Runtime::new().unwrap().block_on(async {
            let mut command = tokio::process::Command::new("timeout");
            command.as_std_mut().process_group(0);
            let mut child = command.args(["2s", "sleep", "0.05"]).spawn().unwrap();
            drop(ProcessGroup {
                pid: child.id().unwrap(),
                cancel: false,
            });
            assert!(child.wait().await.unwrap().success());
        });
    }
}
