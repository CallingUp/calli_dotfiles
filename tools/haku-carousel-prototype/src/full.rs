mod card_gpu;
mod carousel_io;
mod carousel_model;
use carousel_io::Control;
use carousel_model::{Model, Row, Source, wrap};
use iced::widget::canvas::{Frame, Geometry, Path, Stroke};
use iced::widget::{button, canvas, column, container, opaque, pin, row, stack, text, text_input};
use iced::{
    Color, Element, Font, Length, Point, Rectangle, Renderer, Size, Subscription, Task, Theme,
};
use iced_layershell::{
    reexport::{Anchor, KeyboardInteractivity, Layer},
    settings::{LayerShellSettings, StartMode},
    to_layer_message,
};
use serde_json::{Value, json};
use std::{
    cell::Cell,
    collections::{HashMap, HashSet},
    time::Instant,
};

#[derive(Clone, Debug)]
enum Job {
    Catalog,
    Search { query: String, page: u64 },
    Action { name: String, item: Row },
}
#[to_layer_message]
#[derive(Clone, Debug)]
enum Message {
    Frame(Instant),
    Key(iced::keyboard::Event),
    Resize(Size),
    Query(String),
    Switch(Source),
    Navigate(i64),
    Accept,
    Trash,
    CancelTrash,
    Close,
    ReloadColors,
    InputFocused(bool),
    JobDone(Job, Result<Value, String>),
    ThumbDone(String, Result<iced::widget::image::Handle, String>),
    Control(Control),
}
struct Full {
    gpu_cards: bool,
    visual_revision: u64,
    model: Model,
    accent: Color,
    font: Font,
    size: Size,
    thumbs: HashMap<String, iced::widget::image::Handle>,
    failed: HashSet<String>,
    thumbnail: Option<String>,
    web_busy: bool,
    action_busy: bool,
    catalog_busy: bool,
    reveal: f32,
    reveal_start: Option<Instant>,
    closing: Option<(Instant, f32)>,
    input_focused: bool,
}
fn hex(value: u32) -> Color {
    Color::from_rgb8((value >> 16) as u8, (value >> 8) as u8, value as u8)
}
fn bold(font: Font) -> Font {
    Font {
        weight: iced::font::Weight::Bold,
        ..font
    }
}
fn focus() -> Task<Message> {
    iced::widget::operation::focus("wallpaper-search")
        .chain(iced::widget::operation::is_focused("wallpaper-search").map(Message::InputFocused))
}
impl Full {
    fn new() -> (Self, Task<Message>) {
        let state = Self {
            gpu_cards: std::env::var("HAKU_CAROUSEL_RENDERER").map_or(true, |v| v == "gpu"),
            visual_revision: 0,
            model: Model::default(),
            accent: carousel_io::accent(),
            font: carousel_io::font(),
            size: Size::new(1920.0, 1080.0),
            thumbs: HashMap::new(),
            failed: HashSet::new(),
            thumbnail: None,
            web_busy: false,
            action_busy: false,
            catalog_busy: true,
            reveal: 0.0,
            reveal_start: None,
            closing: None,
            input_focused: false,
        };
        (
            state,
            Task::batch([carousel_io::job(Job::Catalog), focus()]),
        )
    }
    fn panel(&self) -> Rectangle {
        let width = 440.0_f32.min((self.size.width - 32.0).max(240.0));
        let height = 920.0_f32.min((self.size.height - 64.0).max(300.0));
        Rectangle::new(
            Point::new(
                -width * (1.0 - self.reveal),
                (self.size.height - height) / 2.0,
            ),
            Size::new(width, height),
        )
    }
    fn viewport(&self) -> Rectangle {
        let p = self.panel();
        Rectangle::new(
            Point::new(p.x, p.y + 152.0),
            Size::new(p.width, (p.height - 246.0).max(1.0)),
        )
    }
    fn card(&self, index: i64) -> Rectangle {
        let v = self.viewport();
        let delta = (index as f64 - self.model.position) as f32;
        let w = 350.0_f32.min(v.width - 80.0);
        let h = 242.0;
        let scale = (1.0 - delta.abs() * 0.15).max(0.65);
        let x = v.x + 24.0 + (38.0 - 22.0 * delta * delta).max(0.0);
        let y = v.y + v.height / 2.0 + delta * 220.0 - h / 2.0;
        Rectangle::new(
            Point::new(x + w * (1.0 - scale) / 2.0, y + h * (1.0 - scale) / 2.0),
            Size::new(w * scale, h * scale),
        )
    }
    fn trim(&mut self) {
        let wanted = self.model.wanted();
        self.thumbs.retain(|k, _| wanted.contains(k));
        self.failed.retain(|k| wanted.contains(k));
    }
    fn visible_slots(&self) -> Vec<i64> {
        if self.model.items.is_empty() {
            return Vec::new();
        }
        let center = self.model.position.round() as i64;
        let viewport = self.viewport();
        let mut slots: Vec<_> = (center - 3..=center + 3)
            .filter(|&index| {
                (index as f64 - self.model.position).abs() < 3.2
                    && (self.model.items.len() != 1 || index == self.model.target)
                    && self.card(index).intersection(&viewport).is_some()
            })
            .collect();
        slots.sort_by(|a, b| {
            ((*b as f64 - self.model.position).abs())
                .total_cmp(&(*a as f64 - self.model.position).abs())
        });
        slots
    }
    fn draw_caption(&self, frame: &mut Frame, index: i64) {
        let item = &self.model.items[wrap(index, self.model.items.len())];
        let c = self.card(index);
        let delta = (index as f64 - self.model.position) as f32;
        let scale = c.height / 242.;
        let opacity = (1. - delta.abs() * 0.32).max(0.);
        let active = item.path() == self.model.current;
        let caption = format!(
            "{}{}{}",
            if active { "󰄬 ACTUAL · " } else { "" },
            item.label(),
            if item.field("resolution").is_empty() {
                String::new()
            } else {
                format!(" · {}", item.field("resolution"))
            }
        );
        frame.fill_text(canvas::Text {
            content: elide(&caption, ((c.width - 24. * scale) / (7.5 * scale)) as usize),
            position: Point::new(c.x + 12. * scale, c.y + c.height - 27. * scale),
            font: if delta.abs() < 0.5 {
                bold(self.font)
            } else {
                self.font
            },
            color: Color {
                a: opacity,
                ..if active { self.accent } else { hex(0xe0e0e7) }
            },
            size: (12. * scale).into(),
            ..Default::default()
        });
    }
    fn pump(&mut self) -> Task<Message> {
        self.trim();
        if self.thumbnail.is_some() || self.closing.is_some() {
            return Task::none();
        }
        if let Some(item) = self
            .model
            .priorities()
            .into_iter()
            .find(|r| !self.thumbs.contains_key(r.key()) && !self.failed.contains(r.key()))
        {
            self.thumbnail = Some(item.key().into());
            return carousel_io::thumbnail(item);
        }
        Task::none()
    }
    fn fetch(&mut self, query: String, page: u64) -> Task<Message> {
        if self.web_busy || self.action_busy {
            return Task::none();
        }
        self.web_busy = true;
        self.model.status = "Wallhaven · buscando…".into();
        carousel_io::job(Job::Search { query, page })
    }
    fn navigate(&mut self, delta: i64) -> Task<Message> {
        if self.action_busy {
            return Task::none();
        }
        self.model.navigate(delta, Instant::now());
        if self.model.source == Source::Web
            && !self.model.items.is_empty()
            && wrap(self.model.target, self.model.items.len())
                >= self.model.items.len().saturating_sub(3)
            && self.model.page < self.model.last_page
        {
            return self.fetch(self.model.web_query.clone(), self.model.page + 1);
        }
        Task::none()
    }
    fn switch(&mut self, source: Source) -> Task<Message> {
        if self.action_busy || self.model.trash.is_some() {
            return Task::none();
        }
        self.model.switch(source);
        self.failed.clear();
        if source == Source::Web && self.model.web.is_empty() {
            return Task::batch([self.fetch(String::new(), 1), focus()]);
        }
        focus()
    }
    fn perform(&mut self, name: &str, item: Row) -> Task<Message> {
        if self.action_busy {
            return Task::none();
        }
        self.action_busy = true;
        self.model.status = if name == "trash" {
            "Enviando a la Papelera…"
        } else if item.field("kind") == "web" {
            "Descargando y aplicando…"
        } else {
            "Aplicando…"
        }
        .into();
        carousel_io::job(Job::Action {
            name: name.into(),
            item,
        })
    }
    fn accept(&mut self) -> Task<Message> {
        if self.action_busy {
            return Task::none();
        }
        if let Some(item) = self.model.trash.clone() {
            return self.perform("trash", item);
        }
        if self.model.source == Source::Web && (self.model.web_dirty || self.model.items.is_empty())
        {
            return self.fetch(self.model.query.trim().into(), 1);
        }
        if let Some(item) = self.model.selected().cloned() {
            return self.perform("apply", item);
        }
        Task::none()
    }
    fn close(&mut self) {
        if self.closing.is_none() {
            self.closing = Some((Instant::now(), self.reveal));
        }
    }
    fn status(&self) -> String {
        let (gpu_textures, gpu_uploads) = card_gpu::metrics();
        json!({"renderer":"Rust / Iced / Vulkan","cardRenderer":if self.gpu_cards {"gpu"} else {"canvas"},"source":if self.model.source==Source::Local{"local"}else{"web"},
            "gpuTextures":gpu_textures,"gpuUploads":gpu_uploads,
            "items":self.model.items.len(),"localItems":self.model.local.len(),"index":self.model.target,
            "selected":self.model.selected().map(|r|r.path()),"current":self.model.current,
            "query":self.model.query,"webDirty":self.model.web_dirty,"page":self.model.page,"lastPage":self.model.last_page,
            "total":self.model.total,"thumbnailReferences":self.thumbs.len(),"loading":self.thumbnail.is_some(),
            "searching":self.web_busy,"actionBusy":self.action_busy,"trashConfirmation":self.model.trash.is_some(),
            "status":self.model.status,"searchFocused":self.input_focused,"reveal":self.reveal,"panelWidth":self.panel().width,"panelHeight":self.panel().height,
            "accent":format!("#{:02x}{:02x}{:02x}",(self.accent.r*255.0).round() as u8,(self.accent.g*255.0).round() as u8,(self.accent.b*255.0).round() as u8)}).to_string()
    }
    fn update(&mut self, message: Message) -> Task<Message> {
        if !matches!(
            &message,
            Message::Frame(_) | Message::Control(Control::Status(_))
        ) {
            self.visual_revision = self.visual_revision.wrapping_add(1);
        }
        let task = match message {
            Message::Frame(now) => {
                let previous_slot = self.model.position.round() as i64;
                self.model.tick(now);
                if let Some((start, from)) = self.closing {
                    let t = (now.saturating_duration_since(start).as_secs_f32() / 0.160)
                        .clamp(0.0, 1.0);
                    self.reveal = from * (1.0 - t * t);
                    if t >= 1.0 {
                        return iced::exit();
                    }
                } else {
                    let start = *self.reveal_start.get_or_insert(now);
                    let t = (now.saturating_duration_since(start).as_secs_f32() / 0.160)
                        .clamp(0.0, 1.0);
                    self.reveal = 1.0 - (1.0 - t).powi(3);
                }
                // Thumbnail priorities only change when crossing a card slot.
                // Do not allocate hash sets/clone rows on every animation tick.
                if previous_slot != self.model.position.round() as i64 {
                    return self.pump();
                }
                return Task::none();
            }
            Message::Resize(size) => {
                self.size = size;
                Task::none()
            }
            Message::Query(query) => {
                if !self.action_busy && self.model.trash.is_none() {
                    self.model.query(query);
                }
                Task::none()
            }
            Message::Switch(source) => self.switch(source),
            Message::Navigate(delta) => Task::batch([self.navigate(delta), focus()]),
            Message::Accept => self.accept(),
            Message::Trash => {
                if !self.action_busy {
                    self.model.request_trash();
                }
                Task::none()
            }
            Message::CancelTrash => {
                if !self.action_busy {
                    self.model.trash = None;
                }
                focus()
            }
            Message::Close => {
                self.close();
                Task::none()
            }
            Message::ReloadColors => {
                self.accent = carousel_io::accent();
                Task::none()
            }
            Message::InputFocused(focused) => {
                self.input_focused = focused;
                Task::none()
            }
            Message::Key(iced::keyboard::Event::KeyPressed { key, modifiers, .. }) => {
                use iced::keyboard::{Key, key::Named};
                match key {
                    Key::Named(Named::Escape) => {
                        if self.model.trash.is_some() && !self.action_busy {
                            self.model.trash = None;
                        } else {
                            self.close();
                        }
                        Task::none()
                    }
                    Key::Named(Named::ArrowUp) => self.navigate(-1),
                    Key::Named(Named::ArrowDown) => self.navigate(1),
                    Key::Named(Named::Enter) => self.accept(),
                    Key::Named(Named::Tab) => self.switch(if self.model.source == Source::Local {
                        Source::Web
                    } else {
                        Source::Local
                    }),
                    Key::Named(Named::Delete) if self.model.query.is_empty() => {
                        if !self.action_busy {
                            self.model.request_trash();
                        }
                        Task::none()
                    }
                    Key::Character(s) if modifiers.control() && s.eq_ignore_ascii_case("f") => {
                        self.model.web_dirty = true;
                        Task::batch([
                            focus(),
                            iced::widget::operation::select_all("wallpaper-search"),
                        ])
                    }
                    _ => Task::none(),
                }
            }
            Message::Key(_) => Task::none(),
            Message::ThumbDone(key, result) => {
                self.thumbnail = None;
                if self.model.wanted().contains(&key) {
                    match result {
                        Ok(handle) => {
                            self.thumbs.insert(key, handle);
                        }
                        Err(_) => {
                            self.failed.insert(key);
                        }
                    }
                }
                Task::none()
            }
            Message::JobDone(job, result) => {
                match &job {
                    Job::Catalog => self.catalog_busy = false,
                    Job::Search { .. } => self.web_busy = false,
                    Job::Action { .. } => self.action_busy = false,
                }
                match result {
                    Err(error) => {
                        self.model.status = error;
                        self.model.trash = None;
                        Task::none()
                    }
                    Ok(value) => match job {
                        Job::Catalog => {
                            self.model.load_catalog(&value);
                            if self.model.status == "Cargando fondos…" {
                                self.model.status.clear();
                            }
                            focus()
                        }
                        Job::Search { .. } => {
                            self.model.web_result(&value);
                            Task::none()
                        }
                        Job::Action { name, .. } => {
                            self.model.trash = None;
                            self.model.current = value["current"]
                                .as_str()
                                .unwrap_or(&self.model.current)
                                .into();
                            if name == "trash" {
                                self.model.load_catalog(&value);
                                self.model.status = "Fondo enviado a la Papelera".into();
                            } else {
                                self.model.status = if value["unchanged"] == true {
                                    "Este fondo ya está activo"
                                } else {
                                    "󰄬 Fondo aplicado"
                                }
                                .into();
                            }
                            if name == "apply"
                                && self.model.source == Source::Web
                                && !self.catalog_busy
                            {
                                self.catalog_busy = true;
                                Task::batch([carousel_io::job(Job::Catalog), focus()])
                            } else {
                                focus()
                            }
                        }
                    },
                }
            }
            Message::Control(control) => match control {
                Control::Close => {
                    self.close();
                    Task::none()
                }
                Control::Step(delta) => self.navigate(delta),
                Control::Query(query) => {
                    if !self.action_busy {
                        self.model.query(query);
                    }
                    Task::none()
                }
                Control::Source(source) => match source.as_str() {
                    "local" => self.switch(Source::Local),
                    "web" | "wallhaven" => self.switch(Source::Web),
                    _ => Task::none(),
                },
                Control::Accept => self.accept(),
                Control::Status(reply) => {
                    if let Some(tx) = reply.lock().ok().and_then(|mut v| v.take()) {
                        let _ = tx.send(self.status());
                    }
                    Task::none()
                }
            },
            _ => Task::none(),
        };
        Task::batch([task, self.pump()])
    }
    fn subscription(&self) -> Subscription<Message> {
        let mut result = vec![
            carousel_io::ipc(),
            carousel_io::colors(),
            iced::event::listen_with(|event, _, _| match event {
                iced::Event::Keyboard(event) => Some(Message::Key(event)),
                iced::Event::Window(
                    iced::window::Event::Opened { size, .. } | iced::window::Event::Resized(size),
                ) => Some(Message::Resize(size)),
                _ => None,
            }),
        ];
        if self.model.motion.is_some() || self.reveal < 1.0 || self.closing.is_some() {
            // A fixed animation cadence avoids rebuilding the canvas at the
            // monitor's unrestricted refresh rate (e.g. 144/240 Hz).
            result.push(
                iced::time::every(std::time::Duration::from_nanos(16_666_667)).map(Message::Frame),
            );
        }
        Subscription::batch(result)
    }
    fn source_button<'a>(
        &self,
        label: &'a str,
        active: bool,
        message: Message,
    ) -> iced::widget::Button<'a, Message> {
        let accent = self.accent;
        button(
            container(
                text(label)
                    .size(12)
                    .font(if active { bold(self.font) } else { self.font }),
            )
            .center_y(Length::Fill),
        )
        .height(34)
        .padding([0, 12])
        .on_press(message)
        .style(move |_, status| iced::widget::button::Style {
            background: Some(iced::Background::Color(if active {
                Color { a: 0.22, ..accent }
            } else if status == iced::widget::button::Status::Hovered {
                hex(0x25262c)
            } else {
                hex(0x18191e)
            })),
            text_color: if active { accent } else { hex(0xdedee6) },
            border: iced::Border {
                radius: 8.0.into(),
                ..Default::default()
            },
            ..Default::default()
        })
    }
    fn view(&self) -> Element<'_, Message> {
        let p = self.panel();
        let accent = self.accent;
        let title = text("󰸉  Wallpapers")
            .size(17)
            .font(bold(self.font))
            .color(accent);
        let sources = row![
            self.source_button(
                "Local",
                self.model.source == Source::Local,
                Message::Switch(Source::Local)
            ),
            self.source_button(
                "Wallhaven",
                self.model.source == Source::Web,
                Message::Switch(Source::Web)
            )
        ]
        .spacing(8);
        let input = text_input(
            if self.model.source == Source::Local {
                "Filtrar fondos…"
            } else {
                "Buscar en Wallhaven…"
            },
            &self.model.query,
        )
        .id("wallpaper-search")
        .size(13)
        .font(self.font)
        .padding([11, 10])
        .width(p.width - 78.0)
        .on_input(Message::Query)
        .style(move |_, _| iced::widget::text_input::Style {
            background: iced::Background::Color(Color::TRANSPARENT),
            border: iced::Border::default(),
            icon: accent,
            placeholder: hex(0x9696a1),
            value: hex(0xf0f0f5),
            selection: accent,
        });
        let search = container(
            row![text("󰍉").size(17).color(accent), input]
                .spacing(8)
                .align_y(iced::Alignment::Center),
        )
        .padding([0, 12])
        .width(p.width - 40.0)
        .height(42)
        .style(|_| iced::widget::container::Style {
            background: Some(iced::Background::Color(hex(0x17181c))),
            border: iced::Border {
                radius: 10.0.into(),
                ..Default::default()
            },
            ..Default::default()
        });
        let mut elements: Vec<Element<Message>> =
            vec![canvas(self).width(Length::Fill).height(Length::Fill).into()];
        if self.gpu_cards {
            let live: std::sync::Arc<[_]> =
                self.thumbs.values().map(|handle| handle.id()).collect();
            for index in self.visible_slots() {
                let c = self.card(index);
                let scale = c.height / 242.;
                let delta = (index as f64 - self.model.position) as f32;
                let item = &self.model.items[wrap(index, self.model.items.len())];
                let card = card_gpu::Card {
                    slot: index.rem_euclid(7) as usize,
                    rect: c,
                    clip: self.viewport(),
                    image: Rectangle::new(
                        Point::new(c.x + 7. * scale, c.y + 7. * scale),
                        Size::new(c.width - 14. * scale, 198. * scale),
                    ),
                    radius: 14. * scale,
                    opacity: (1. - delta.abs() * 0.32).max(0.),
                    selected: delta.abs() < 0.5,
                    accent: self.accent,
                    background: if delta.abs() < 0.5 {
                        hex(0x24252b)
                    } else {
                        hex(0x131418)
                    },
                    texture: self.thumbs.get(item.key()).cloned(),
                    live: live.clone(),
                };
                elements.push(
                    iced::widget::shader(card)
                        .width(Length::Fill)
                        .height(Length::Fill)
                        .into(),
                );
                // Interleave captions with their cards to preserve overlap order.
                elements.push(
                    canvas(CardCaption { full: self, index })
                        .width(Length::Fill)
                        .height(Length::Fill)
                        .into(),
                );
            }
        }
        elements.extend([
            pin(title).x(p.x + 20.0).y(p.y + 18.0).into(),
            pin(sources).x(p.x + 20.0).y(p.y + 52.0).into(),
            pin(search).x(p.x + 20.0).y(p.y + 98.0).into(),
        ]);
        if let Some(item) = &self.model.trash {
            let buttons = row![
                self.source_button("Cancelar", false, Message::CancelTrash),
                self.source_button("Papelera", true, Message::Accept)
            ]
            .spacing(12);
            let content = column![
                text("¿Enviar a la Papelera?")
                    .size(17)
                    .font(bold(self.font))
                    .color(accent),
                text(item.label())
                    .size(13)
                    .color(hex(0xdedee6))
                    .width(p.width - 40.0),
                buttons
            ]
            .spacing(18)
            .width(p.width - 40.0);
            let modal = opaque(
                container(content)
                    .width(p.width)
                    .height(p.height)
                    .center_y(p.height)
                    .padding(20)
                    .style(|_| iced::widget::container::Style {
                        background: Some(iced::Background::Color(Color {
                            a: 0.96,
                            ..hex(0x08090b)
                        })),
                        border: iced::Border {
                            radius: 22.0.into(),
                            ..Default::default()
                        },
                        ..Default::default()
                    }),
            );
            elements.push(pin(modal).x(p.x).y(p.y).into());
        }
        stack(elements).into()
    }
}

#[derive(Default)]
struct CanvasState {
    wheel: f32,
    background: canvas::Cache,
    background_bounds: Cell<Option<Rectangle>>,
    cards: [canvas::Cache; 7],
    card_keys: [Cell<Option<(u64, i64, u64, u32)>>; 7],
}
struct CardCaption<'a> {
    full: &'a Full,
    index: i64,
}
#[derive(Default)]
struct CaptionState {
    cache: canvas::Cache,
    key: Cell<Option<(u64, i64, u64, u32)>>,
}
impl canvas::Program<Message> for CardCaption<'_> {
    type State = CaptionState;
    fn draw(
        &self,
        state: &CaptionState,
        renderer: &Renderer,
        _: &Theme,
        bounds: Rectangle,
        _: iced::mouse::Cursor,
    ) -> Vec<Geometry> {
        let full = self.full;
        let key = (
            full.visual_revision,
            self.index,
            full.model.position.to_bits(),
            full.reveal.to_bits(),
        );
        if state.key.replace(Some(key)) != Some(key) {
            state.cache.clear();
        }
        vec![state.cache.draw(renderer, bounds.size(), |frame| {
            frame.with_clip(full.viewport(), |frame| {
                let item = &full.model.items[wrap(self.index, full.model.items.len())];
                if !full.thumbs.contains_key(item.key()) {
                    let c = full.card(self.index);
                    let scale = c.height / 242.;
                    let opacity = (1.
                        - (self.index as f64 - full.model.position).abs() as f32 * 0.32)
                        .max(0.);
                    frame.fill_text(canvas::Text {
                        content: "󰸉".into(),
                        position: Point::new(c.center_x() - 15., c.y + 80. * scale),
                        font: full.font,
                        color: Color {
                            a: opacity,
                            ..full.accent
                        },
                        size: (30. * scale).into(),
                        ..Default::default()
                    });
                }
                full.draw_caption(frame, self.index);
            });
        })]
    }
}
impl canvas::Program<Message> for Full {
    type State = CanvasState;
    fn update(
        &self,
        state: &mut CanvasState,
        event: &canvas::Event,
        _: Rectangle,
        cursor: iced::mouse::Cursor,
    ) -> Option<canvas::Action<Message>> {
        let Some(point) = cursor.position() else {
            return None;
        };
        let panel = self.panel();
        match event {
            canvas::Event::Mouse(iced::mouse::Event::ButtonPressed(iced::mouse::Button::Left)) => {
                if !panel.contains(point) {
                    return Some(canvas::Action::publish(Message::Close).and_capture());
                }
                if self.model.trash.is_some() || !self.viewport().contains(point) {
                    return None;
                }
                let center = self.model.position.round() as i64;
                let mut slots: Vec<_> = (-3..=3).map(|o| center + o).collect();
                slots.sort_by(|a, b| {
                    ((*a as f64 - self.model.position).abs())
                        .total_cmp(&(*b as f64 - self.model.position).abs())
                });
                for index in slots {
                    let delta = index as f64 - self.model.position;
                    if delta.abs() < 3.2
                        && self.card(index).contains(point)
                        && !self.model.items.is_empty()
                    {
                        return Some(
                            canvas::Action::publish(if delta.abs() < 0.5 {
                                Message::Accept
                            } else {
                                Message::Navigate(index - self.model.target)
                            })
                            .and_capture(),
                        );
                    }
                }
                None
            }
            canvas::Event::Mouse(iced::mouse::Event::WheelScrolled { delta })
                if panel.contains(point) =>
            {
                let y = match delta {
                    iced::mouse::ScrollDelta::Lines { y, .. } => *y,
                    iced::mouse::ScrollDelta::Pixels { y, .. } => *y / 120.0,
                };
                state.wheel += y;
                if state.wheel.abs() >= 0.75 {
                    let direction = if state.wheel > 0.0 { -1 } else { 1 };
                    state.wheel = 0.0;
                    Some(canvas::Action::publish(Message::Navigate(direction)).and_capture())
                } else {
                    None
                }
            }
            _ => None,
        }
    }
    fn draw(
        &self,
        state: &CanvasState,
        renderer: &Renderer,
        _: &Theme,
        bounds: Rectangle,
        _: iced::mouse::Cursor,
    ) -> Vec<Geometry> {
        let p = self.panel();
        let v = self.viewport();
        if state.background_bounds.replace(Some(p)) != Some(p) {
            state.background.clear();
        }
        let background = state.background.draw(renderer, bounds.size(), |frame| {
            let bg = Path::rounded_rectangle(
                Point::new(p.x - 22.0, p.y),
                Size::new(p.width + 22.0, p.height),
                22.0.into(),
            );
            frame.fill(&bg, hex(0x08090b));
        });
        let mut geometries = vec![background];
        let mut frame = Frame::new(renderer, bounds.size());
        if self.model.items.is_empty() {
            frame.fill_text(canvas::Text {
                content: if self.web_busy {
                    "Buscando…"
                } else if self.catalog_busy {
                    "Cargando fondos…"
                } else {
                    "No se encontraron fondos"
                }
                .into(),
                position: Point::new(p.x + 50.0, v.y + v.height / 2.0),
                color: hex(0xaaaab3),
                font: self.font,
                size: 13.0.into(),
                ..Default::default()
            });
        } else if !self.gpu_cards {
            let center = self.model.position.round() as i64;
            let mut slots: Vec<_> = (-3..=3).map(|o| center + o).collect();
            slots.sort_by(|a, b| {
                ((*b as f64 - self.model.position).abs())
                    .total_cmp(&(*a as f64 - self.model.position).abs())
            });
            for index in slots {
                // Cull before creating frames, shaping labels or cloning image
                // handles. Clipping later does not avoid that CPU work.
                let c = self.card(index);
                if c.intersection(&v).is_none() {
                    continue;
                }
                let slot = index.rem_euclid(7) as usize;
                let key = (
                    self.visual_revision,
                    index,
                    self.model.position.to_bits(),
                    self.reveal.to_bits(),
                );
                if state.card_keys[slot].replace(Some(key)) != Some(key) {
                    state.cards[slot].clear();
                }
                // Cache::clear retains prior GPU storage for reuse. Unlike a
                // fresh Frame each tick this also reuses unchanged geometry.
                let geometry = state.cards[slot].draw(renderer, bounds.size(), |card_frame| {
                    card_frame.with_clip(v, |frame| {
                        let delta = (index as f64 - self.model.position) as f32;
                        if delta.abs() >= 3.2
                            || (self.model.items.len() == 1 && index != self.model.target)
                        {
                            return;
                        }
                        let item = &self.model.items[wrap(index, self.model.items.len())];
                        let c = self.card(index);
                        let scale = c.height / 242.0;
                        let opacity = (1.0 - delta.abs() * 0.32).max(0.0);
                        let background =
                            Path::rounded_rectangle(c.position(), c.size(), (14.0 * scale).into());
                        frame.fill(
                            &background,
                            Color {
                                a: opacity,
                                ..if delta.abs() < 0.5 {
                                    hex(0x24252b)
                                } else {
                                    hex(0x131418)
                                }
                            },
                        );
                        if delta.abs() < 0.5 {
                            frame.stroke(
                                &background,
                                Stroke::default().with_width(2.0).with_color(self.accent),
                            );
                        }
                        let image_rect = Rectangle::new(
                            Point::new(c.x + 7.0 * scale, c.y + 7.0 * scale),
                            Size::new(c.width - 14.0 * scale, 198.0 * scale),
                        );
                        if let Some(handle) = self.thumbs.get(item.key()) {
                            let ih = image_rect.width * 300.0 / 420.0;
                            let h = ih.max(image_rect.height);
                            let w = h * 420.0 / 300.0;
                            let clipped = image_rect
                                .intersection(&v)
                                .unwrap_or(Rectangle::new(Point::ORIGIN, Size::ZERO));
                            frame.with_clip(clipped, |frame| {
                                frame.draw_image(
                                    Rectangle::new(
                                        Point::new(
                                            image_rect.center_x() - w / 2.0,
                                            image_rect.center_y() - h / 2.0,
                                        ),
                                        Size::new(w, h),
                                    ),
                                    iced::advanced::image::Image::new(handle.clone())
                                        .opacity(opacity),
                                )
                            });
                        } else {
                            frame.fill_text(canvas::Text {
                                content: "󰸉".into(),
                                position: Point::new(c.center_x() - 15.0, c.y + 80.0 * scale),
                                font: self.font,
                                color: Color {
                                    a: opacity,
                                    ..self.accent
                                },
                                size: (30.0 * scale).into(),
                                ..Default::default()
                            });
                        }
                        let active = item.path() == self.model.current;
                        let caption = format!(
                            "{}{}{}",
                            if active { "󰄬 ACTUAL · " } else { "" },
                            item.label(),
                            if item.field("resolution").is_empty() {
                                String::new()
                            } else {
                                format!(" · {}", item.field("resolution"))
                            }
                        );
                        frame.fill_text(canvas::Text {
                            content: elide(
                                &caption,
                                ((c.width - 24.0 * scale) / (7.5 * scale)) as usize,
                            ),
                            position: Point::new(c.x + 12.0 * scale, c.y + c.height - 27.0 * scale),
                            font: if delta.abs() < 0.5 {
                                bold(self.font)
                            } else {
                                self.font
                            },
                            color: Color {
                                a: opacity,
                                ..if active { self.accent } else { hex(0xe0e0e7) }
                            },
                            size: (12.0 * scale).into(),
                            ..Default::default()
                        });
                    });
                });
                geometries.push(geometry);
            }
        }
        if !self.model.items.is_empty() {
            let counter = format!(
                "{} / {}",
                wrap(self.model.target, self.model.items.len()) + 1,
                if self.model.source == Source::Web {
                    self.model.total as usize
                } else {
                    self.model.items.len()
                }
            );
            frame.fill_text(canvas::Text {
                content: counter,
                position: Point::new(p.x + p.width / 2.0, p.y + p.height - 90.0),
                align_x: iced::advanced::text::Alignment::Center,
                color: self.accent,
                font: bold(self.font),
                size: 13.0.into(),
                ..Default::default()
            });
        }
        let status = if self.model.status.is_empty() {
            "↑ ↓ / rueda · Enter aplica · Tab cambia origen"
        } else {
            &self.model.status
        };
        for (label, bottom, color) in [
            (status, 60.0, hex(0xb9b9c3)),
            (
                "Supr: Papelera · Ctrl+F: buscar · Esc: cerrar",
                38.0,
                hex(0x858590),
            ),
        ] {
            frame.fill_text(canvas::Text {
                content: elide(label, ((p.width - 40.0) / 6.7) as usize),
                position: Point::new(p.x + 20.0, p.y + p.height - bottom),
                color,
                font: self.font,
                size: 11.0.into(),
                ..Default::default()
            });
        }
        geometries.push(frame.into_geometry());
        geometries
    }
}
fn elide(text: &str, limit: usize) -> String {
    if text.chars().count() <= limit {
        text.into()
    } else {
        text.chars()
            .take(limit.saturating_sub(1))
            .chain(std::iter::once('…'))
            .collect()
    }
}
struct SocketCleanup(std::path::PathBuf);
impl Drop for SocketCleanup {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.0);
    }
}
fn main() -> iced_layershell::Result {
    carousel_io::init_logging();
    let args: Vec<_> = std::env::args().skip(1).collect();
    if let Some(arg) = args.first() {
        let request = match arg.as_str() {
            "--toggle" | "--close" => Some("close".into()),
            "--status" => Some("status".into()),
            "--step" => Some(format!(
                "step {}",
                args.get(1).map(String::as_str).unwrap_or("0")
            )),
            "--query" => Some(format!(
                "query {}",
                json!(args.get(1).cloned().unwrap_or_default())
            )),
            "--source" => Some(format!(
                "source {}",
                args.get(1).map(String::as_str).unwrap_or("local")
            )),
            "--accept" => Some("accept".into()),
            _ => None,
        };
        if let Some(request) = request {
            match carousel_io::control(&request) {
                Ok(response) => {
                    if arg == "--status" {
                        println!("{response}");
                    }
                    return Ok(());
                }
                Err(_) if arg == "--toggle" => {}
                Err(_) if arg == "--close" => return Ok(()),
                Err(e) => {
                    eprintln!("No hay carrusel Rust abierto: {e}");
                    std::process::exit(1)
                }
            }
        }
    }
    let socket = carousel_io::socket_path();
    let lock = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(socket.with_extension("lock"))
        .expect("Cannot open runtime lock");
    if lock.try_lock().is_err() {
        return Ok(());
    }
    let _ = std::fs::remove_file(&socket);
    let _cleanup = SocketCleanup(socket);
    iced_layershell::application(
        Full::new,
        || "haku-wallpaper-carousel-rust".into(),
        Full::update,
        Full::view,
    )
    .subscription(Full::subscription)
    .theme(|_: &Full| Theme::Dark)
    .default_font(carousel_io::font())
    .style(|_, _| iced::theme::Style {
        background_color: Color::TRANSPARENT,
        text_color: hex(0xe0e0e7),
    })
    .layer_settings(LayerShellSettings {
        anchor: Anchor::Top | Anchor::Bottom | Anchor::Left | Anchor::Right,
        layer: Layer::Overlay,
        size: Some((0, 0)),
        exclusive_zone: -1,
        keyboard_interactivity: KeyboardInteractivity::Exclusive,
        start_mode: StartMode::Active,
        ..Default::default()
    })
    .run()
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture() -> Full {
        let (mut state, _) = Full::new();
        state.reveal = 1.0;
        state.model.load_catalog(&json!({"current":"/a","rows":[
            {"key":"a","path":"/a","kind":"local","label":"A"},
            {"key":"b","path":"/b","kind":"local","label":"B"}]}));
        state
    }
    fn key(named: iced::keyboard::key::Named) -> Message {
        use iced::keyboard::*;
        Message::Key(Event::KeyPressed {
            key: Key::Named(named),
            modified_key: Key::Named(named),
            physical_key: key::Physical::Unidentified(key::NativeCode::Unidentified),
            location: Location::Standard,
            modifiers: Modifiers::empty(),
            text: None,
            repeat: false,
        })
    }
    #[test]
    fn arrows_delete_and_escape() {
        use iced::keyboard::key::Named;
        let mut state = fixture();
        let _ = state.update(key(Named::Delete));
        assert!(state.model.trash.is_none());
        let _ = state.update(key(Named::ArrowDown));
        assert_eq!(state.model.target, 1);
        let _ = state.update(key(Named::Delete));
        assert!(state.model.trash.is_some());
        assert!(!state.action_busy);
        let _ = state.update(key(Named::Escape));
        assert!(state.model.trash.is_none());
        assert!(state.closing.is_none());
    }
    #[test]
    fn delete_does_not_trash_when_searching() {
        let mut state = fixture();
        state.model.query("B".into());
        let _ = state.update(key(iced::keyboard::key::Named::Delete));
        assert!(state.model.trash.is_none());
    }
    #[test]
    fn wheel_accumulates_small_events() {
        let state = fixture();
        let mut canvas = CanvasState::default();
        let event = canvas::Event::Mouse(iced::mouse::Event::WheelScrolled {
            delta: iced::mouse::ScrollDelta::Pixels { x: 0.0, y: -30.0 },
        });
        let cursor = iced::mouse::Cursor::Available(Point::new(20.0, 500.0));
        let bounds = Rectangle::new(Point::ORIGIN, state.size);
        for _ in 0..2 {
            assert!(
                <Full as canvas::Program<Message>>::update(
                    &state,
                    &mut canvas,
                    &event,
                    bounds,
                    cursor
                )
                .is_none()
            );
        }
        assert!(
            <Full as canvas::Program<Message>>::update(&state, &mut canvas, &event, bounds, cursor)
                .is_some()
        );
        assert_eq!(canvas.wheel, 0.0);
    }
    #[test]
    fn async_action_result_and_duplicate_guard() {
        let mut state = fixture();
        let item = state.model.selected().unwrap().clone();
        let _ = state.accept();
        assert!(state.action_busy);
        let _ = state.accept();
        let _ = state.update(Message::JobDone(
            Job::Action {
                name: "apply".into(),
                item,
            },
            Ok(json!({"current":"/a","unchanged":true})),
        ));
        assert!(!state.action_busy);
        assert_eq!(state.model.status, "Este fondo ya está activo");
    }
    #[test]
    fn stale_thumbnail_is_discarded() {
        let mut state = fixture();
        state.thumbnail = Some("gone".into());
        let handle = iced::widget::image::Handle::from_rgba(1, 1, vec![0, 0, 0, 255]);
        let _ = state.update(Message::ThumbDone("gone".into(), Ok(handle)));
        assert!(!state.thumbs.contains_key("gone"));
    }
    #[test]
    fn unicode_elision() {
        assert_eq!(elide("gato", 5), "gato");
        assert_eq!(elide("Gato Café", 6), "Gato …");
    }
    #[test]
    fn empty_accept_does_not_apply() {
        let (mut state, _) = Full::new();
        let _ = state.accept();
        assert!(!state.action_busy);
    }
    #[test]
    fn action_reentry_is_blocked() {
        let (mut state, _) = Full::new();
        state.action_busy = true;
        let _ = state.accept();
        let _ = state.switch(Source::Web);
        assert_eq!(state.model.source, Source::Local);
    }
    #[test]
    fn close_is_finite() {
        let (mut state, _) = Full::new();
        state.reveal = 1.0;
        state.close();
        let (start, _) = state.closing.unwrap();
        let _ = state.update(Message::Frame(start + std::time::Duration::from_millis(80)));
        assert!(state.reveal < 1.0);
    }
}
