use iced::widget::canvas::{Frame, Geometry, Path, Stroke};
use iced::widget::{canvas, column, container, text};
use iced::{Color, Element, Length, Point, Rectangle, Renderer, Size, Subscription, Task, Theme};
use serde_json::{Value, json};
use std::{
    io::Write,
    path::PathBuf,
    process::{Command, Stdio},
    time::{Duration, Instant},
};

const DURATION: f32 = 0.210;
const TITLE: &str = "Haku · carrusel Rust experimental";

#[derive(Clone, Copy, Debug)]
struct Motion {
    from: f32,
    target: f32,
    started: Instant,
}
impl Motion {
    fn sample(self, now: Instant) -> (f32, bool) {
        let t = (now.duration_since(self.started).as_secs_f32() / DURATION).clamp(0.0, 1.0);
        (
            self.from + (self.target - self.from) * (1.0 - (1.0 - t).powi(3)),
            t < 1.0,
        )
    }
}
fn wrap(index: i64, count: usize) -> usize {
    index.rem_euclid(count as i64) as usize
}
#[derive(Clone)]
struct Card {
    label: String,
    image: iced::widget::image::Handle,
}
#[derive(Clone)]
struct Carousel {
    cards: Vec<Card>,
    accent: Color,
    position: f32,
    target: i64,
    motion: Option<Motion>,
    exercise: bool,
    exercise_tick: u32,
    last_frame: Option<Instant>,
    frame_intervals: Vec<f32>,
}
#[derive(Clone, Debug)]
enum Message {
    Navigate(i64),
    Frame(Instant),
    Key(iced::keyboard::Event),
    Exercise,
}
fn exercise_after(delay: Duration) -> Task<Message> {
    // Iced's tokio executor runs this one-shot, not a permanent polling loop.
    Task::perform(
        async move {
            tokio::time::sleep(delay).await;
        },
        |_| Message::Exercise,
    )
}

fn backend(request: Value) -> Result<Value, String> {
    let worker = PathBuf::from(std::env::var_os("HOME").ok_or("HOME missing")?)
        .join("haku_shell/tools/haku-wallpaper/target/release/haku-wallpaper");
    let mut child = Command::new(worker)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| e.to_string())?;
    writeln!(child.stdin.take().unwrap(), "{request}").map_err(|e| e.to_string())?;
    let output = child.wait_with_output().map_err(|e| e.to_string())?;
    let value: Value = serde_json::from_slice(&output.stdout).map_err(|e| e.to_string())?;
    if !output.status.success() || value["ok"] != true {
        return Err(value.to_string());
    }
    Ok(value)
}
impl Carousel {
    fn load() -> Result<Self, String> {
        let args: Vec<_> = std::env::args().skip(1).collect();
        let exercise = args.iter().any(|a| a == "--exercise");
        let paths: Vec<_> = args
            .iter()
            .filter(|a| !["--exercise", "--toggle"].contains(&a.as_str()))
            .collect();
        let rows: Vec<Value> = if paths.is_empty() {
            let catalog = backend(json!({"action":"list"}))?;
            let rows = catalog["rows"].as_array().ok_or("Invalid catalog")?;
            if rows.len() < 3 {
                return Err("At least three wallpapers are required".into());
            }
            let index = rows
                .iter()
                .position(|r| r["path"] == catalog["current"])
                .unwrap_or(0);
            [-1, 0, 1]
                .into_iter()
                .map(|delta| rows[wrap(index as i64 + delta, rows.len())].clone())
                .collect()
        } else {
            if paths.len() != 3 {
                return Err(
                    "Usage: haku-carousel-prototype [--exercise] [IMAGE1 IMAGE2 IMAGE3]".into(),
                );
            }
            paths
                .iter()
                .map(|p| json!({"kind":"local","key":p,"path":p}))
                .collect()
        };
        let mut cards = Vec::new();
        for row in rows {
            let thumb = backend(json!({"action":"thumb","item":row}))?;
            let path = thumb["image"].as_str().ok_or("Missing thumbnail")?;
            let image = image::open(path).map_err(|e| e.to_string())?.into_rgba8();
            let label = row["label"].as_str().map(str::to_owned).unwrap_or_else(|| {
                PathBuf::from(row["path"].as_str().unwrap_or(""))
                    .file_stem()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .into_owned()
            });
            cards.push(Card {
                label,
                image: iced::widget::image::Handle::from_rgba(
                    image.width(),
                    image.height(),
                    image.into_raw(),
                ),
            });
        }
        let home = PathBuf::from(std::env::var_os("HOME").unwrap_or_default());
        let css = std::fs::read_to_string(home.join(".local/state/haku_theme/colors.css"))
            .unwrap_or_default();
        let accent = css
            .lines()
            .find(|l| l.contains("@define-color accent_color "))
            .and_then(|l| l.split_whitespace().nth(2))
            .and_then(|s| s.trim_end_matches(';').parse::<Color>().ok())
            .unwrap_or(Color::from_rgb8(185, 149, 115));
        Ok(Self {
            cards,
            accent,
            position: 1.0,
            target: 1,
            motion: None,
            exercise,
            exercise_tick: 0,
            last_frame: None,
            frame_intervals: Vec::new(),
        })
    }
    fn navigate(&mut self, delta: i64) {
        self.last_frame = None;
        let now = Instant::now();
        if let Some(m) = self.motion {
            self.position = m.sample(now).0
        }
        self.target += delta;
        self.motion = Some(Motion {
            from: self.position,
            target: self.target as f32,
            started: now,
        });
    }
    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Navigate(delta) => self.navigate(delta),
            Message::Frame(now) => {
                if let Some(m) = self.motion {
                    if self.exercise {
                        if let Some(last) = self.last_frame {
                            self.frame_intervals
                                .push(now.duration_since(last).as_secs_f32() * 1000.0);
                        }
                        self.last_frame = Some(now);
                    }
                    let (p, active) = m.sample(now);
                    self.position = p;
                    if !active {
                        self.motion = None
                    }
                }
            }
            Message::Key(iced::keyboard::Event::KeyPressed { key, .. }) => match key {
                iced::keyboard::Key::Named(iced::keyboard::key::Named::ArrowUp) => {
                    self.navigate(-1)
                }
                iced::keyboard::Key::Named(iced::keyboard::key::Named::ArrowDown) => {
                    self.navigate(1)
                }
                iced::keyboard::Key::Named(iced::keyboard::key::Named::Escape) => {
                    return iced::exit();
                }
                _ => {}
            },
            Message::Key(_) => {}
            Message::Exercise => {
                self.exercise_tick += 1;
                if self.exercise_tick == 1 {
                    println!("phase=navigation");
                }
                if self.exercise_tick <= 40 {
                    self.navigate(1);
                    return exercise_after(Duration::from_millis(250));
                }
                if self.exercise_tick == 41 {
                    println!("phase=idle_after");
                    return exercise_after(Duration::from_secs(5));
                }
                let mut frames = self.frame_intervals.clone();
                frames.sort_by(f32::total_cmp);
                if !frames.is_empty() {
                    println!(
                        "FRAMES:{}",
                        json!({"intervals":frames.len(),
                        "mean_ms":frames.iter().sum::<f32>()/frames.len() as f32,
                        "p95_ms":frames[((frames.len()-1) as f32*0.95) as usize],
                        "over_33ms":frames.iter().filter(|v|**v>33.34).count()})
                    );
                }
                return iced::exit();
            }
        }
        Task::none()
    }
    fn subscription(&self) -> Subscription<Message> {
        let mut subs = vec![iced::keyboard::listen().map(Message::Key)];
        if self.motion.is_some() {
            subs.push(iced::window::frames().map(Message::Frame));
        }
        Subscription::batch(subs)
    }
    fn view(&self) -> Element<'_, Message> {
        container(
            column![
                text("Wallpaper · Rust / Iced").size(18).color(self.accent),
                text("↑ / ↓ navegar · Escape cerrar · no aplica fondos")
                    .size(12)
                    .color(Color::from_rgb8(190, 178, 163)),
                canvas(self).width(Length::Fill).height(Length::Fill),
                text(format!(
                    "{} / 3 · prototipo independiente",
                    wrap(self.target, self.cards.len()) + 1
                ))
                .size(12)
                .color(self.accent)
            ]
            .spacing(10),
        )
        .padding(18)
        .into()
    }
}
impl canvas::Program<Message> for Carousel {
    type State = ();
    fn update(
        &self,
        _: &mut (),
        event: &canvas::Event,
        _: Rectangle,
        _: iced::mouse::Cursor,
    ) -> Option<canvas::Action<Message>> {
        if let canvas::Event::Mouse(iced::mouse::Event::WheelScrolled { delta }) = event {
            let y = match delta {
                iced::mouse::ScrollDelta::Lines { y, .. }
                | iced::mouse::ScrollDelta::Pixels { y, .. } => *y,
            };
            if y != 0.0 {
                return Some(
                    canvas::Action::publish(Message::Navigate(if y > 0.0 { -1 } else { 1 }))
                        .and_capture(),
                );
            }
        }
        None
    }
    fn draw(
        &self,
        _: &(),
        renderer: &Renderer,
        _: &Theme,
        bounds: Rectangle,
        _: iced::mouse::Cursor,
    ) -> Vec<Geometry> {
        let mut frame = Frame::new(renderer, bounds.size());
        let center = Point::new(bounds.width / 2.0, bounds.height / 2.0);
        let spacing = (bounds.height / 3.0).min(245.0);
        let first = self.position.floor() as i64;
        // Five transient slots recycle the same three decoded images; only three
        // cards are fully in view at rest. No additional image decoding per frame.
        for slot in (first - 2)..=(first + 2) {
            let distance = slot as f32 - self.position;
            if distance.abs() > 1.7 {
                continue;
            }
            let scale = 1.0 - 0.38 * distance.abs().min(1.0);
            let width = (bounds.width - 32.0).min(380.0) * scale;
            let height = width * 300.0 / 420.0;
            let x = center.x - width / 2.0 + distance.abs().min(1.0) * 10.0;
            let y = center.y + distance * spacing - height / 2.0;
            let card = &self.cards[wrap(slot, self.cards.len())];
            let rect = Rectangle::new(Point::new(x, y), Size::new(width, height));
            frame.draw_image(
                rect,
                iced::advanced::image::Image::new(card.image.clone())
                    .opacity((1.0 - distance.abs() * 0.30).max(0.25)),
            );
            let selected = 1.0 - distance.abs().min(1.0);
            let border = Path::rectangle(
                Point::new(x - 3.0, y - 3.0),
                Size::new(width + 6.0, height + 6.0),
            );
            frame.stroke(
                &border,
                Stroke::default()
                    .with_width(1.0 + selected * 2.0)
                    .with_color(Color {
                        a: 0.30 + selected * 0.70,
                        ..self.accent
                    }),
            );
            frame.fill_rectangle(
                Point::new(x, y + height - 22.0),
                Size::new(width, 22.0),
                Color {
                    a: 0.85,
                    ..Color::BLACK
                },
            );
            let limit = ((width - 14.0) / 7.5) as usize;
            let mut label: String = card.label.chars().take(limit).collect();
            if card.label.chars().count() > limit {
                label.push('…');
            }
            frame.fill_text(canvas::Text {
                content: label,
                position: Point::new(x + 7.0, y + height - 20.0),
                font: iced::Font::MONOSPACE,
                color: self.accent,
                size: 12.0.into(),
                ..Default::default()
            });
        }
        vec![frame.into_geometry()]
    }
}
fn main() -> iced::Result {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let toggle = args.iter().any(|a| a == "--toggle");
    let close = args.iter().any(|a| a == "--close");
    if toggle || close {
        let output = Command::new("niri")
            .args(["msg", "-j", "windows"])
            .output()
            .unwrap_or_else(|e| {
                eprintln!("Niri IPC failed: {e}");
                std::process::exit(1)
            });
        if !output.status.success() {
            eprintln!("Niri IPC unavailable");
            std::process::exit(1)
        }
        let windows: Value = serde_json::from_slice(&output.stdout).unwrap_or(Value::Null);
        let ids = prototype_windows(&windows);
        for id in &ids {
            let _ = Command::new("niri")
                .args(["msg", "action", "close-window", "--id", &id.to_string()])
                .status();
        }
        if close || !ids.is_empty() {
            return Ok(());
        }
    }
    // Hold the runtime lock for the lifetime of a launcher-created window.
    let _instance_lock = if toggle {
        let runtime =
            PathBuf::from(std::env::var_os("XDG_RUNTIME_DIR").expect("XDG_RUNTIME_DIR missing"));
        let file = std::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .open(runtime.join("haku-carousel-rust.lock"))
            .expect("Cannot open runtime lock");
        if file.try_lock().is_err() {
            return Ok(());
        }
        Some(file)
    } else {
        None
    };
    #[cfg(feature = "gpu")]
    {
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
    let state = Carousel::load().unwrap_or_else(|e| {
        eprintln!("{e}");
        std::process::exit(1)
    });
    println!(
        "Haku Rust prototype: 3 thumbnails, renderer={}, phase=idle",
        if cfg!(feature = "gpu") {
            "wgpu"
        } else {
            "tiny-skia"
        }
    );
    iced::application(
        move || {
            (
                state.clone(),
                if state.exercise {
                    exercise_after(Duration::from_secs(5))
                } else {
                    Task::none()
                },
            )
        },
        Carousel::update,
        Carousel::view,
    )
    .title(TITLE)
    .default_font(iced::Font::MONOSPACE)
    .subscription(Carousel::subscription)
    .window(iced::window::Settings {
        size: Size::new(480.0, 820.0),
        min_size: Some(Size::new(480.0, 820.0)),
        max_size: Some(Size::new(480.0, 820.0)),
        resizable: false,
        platform_specific: iced::window::settings::PlatformSpecific {
            application_id: "haku-carousel-prototype".into(),
            ..Default::default()
        },
        ..Default::default()
    })
    .theme(Theme::Dark)
    .style(|_, _| iced::theme::Style {
        background_color: Color::BLACK,
        text_color: Color::WHITE,
    })
    .run()
}

fn prototype_windows(windows: &Value) -> Vec<u64> {
    windows
        .as_array()
        .into_iter()
        .flatten()
        .filter(|w| w["app_id"] == "haku-carousel-prototype")
        .filter_map(|w| w["id"].as_u64())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn closes_only_prototype_windows() {
        assert_eq!(
            prototype_windows(
                &json!([{"id":1,"app_id":"kitty"},{"id":2,"app_id":"haku-carousel-prototype"}])
            ),
            vec![2]
        );
        assert!(prototype_windows(&Value::Null).is_empty());
    }
    #[test]
    fn negative_wrap() {
        assert_eq!(wrap(-1, 3), 2);
        assert_eq!(wrap(4, 3), 1);
    }
    #[test]
    fn motion_ends() {
        let t = Instant::now();
        let m = Motion {
            from: 0.0,
            target: 1.0,
            started: t,
        };
        assert_eq!(m.sample(t), (0.0, true));
        assert_eq!(m.sample(t + Duration::from_millis(211)), (1.0, false));
    }
    #[test]
    fn ease_out() {
        let t = Instant::now();
        let m = Motion {
            from: 0.0,
            target: 1.0,
            started: t,
        };
        let (p, active) = m.sample(t + Duration::from_millis(105));
        assert!((p - 0.875).abs() < 0.001);
        assert!(active);
    }
    #[test]
    fn release_does_not_queue_motion() {
        let mut state = Carousel {
            cards: Vec::new(),
            accent: Color::WHITE,
            position: 0.0,
            target: 0,
            motion: None,
            exercise: false,
            exercise_tick: 0,
            last_frame: None,
            frame_intervals: Vec::new(),
        };
        for _ in 0..20 {
            state.navigate(1);
        }
        assert_eq!(state.target, 20);
        let end = state.motion.unwrap().started + Duration::from_millis(211);
        let _ = state.update(Message::Frame(end));
        assert_eq!(state.position, 20.0);
        assert!(state.motion.is_none());
        let _ = state.update(Message::Frame(end + Duration::from_secs(1)));
        assert_eq!(state.position, 20.0);
    }
}
