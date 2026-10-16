use serde_json::Value;
use std::{collections::HashSet, time::Instant};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Source {
    Local,
    Web,
}
#[derive(Clone, Debug, PartialEq)]
pub struct Row(pub Value);
impl Row {
    pub fn field(&self, key: &str) -> &str {
        self.0[key].as_str().unwrap_or("")
    }
    pub fn key(&self) -> &str {
        self.field("key")
    }
    pub fn label(&self) -> &str {
        self.field("label")
    }
    pub fn path(&self) -> &str {
        self.field("path")
    }
}
pub fn rows(value: &Value) -> Vec<Row> {
    value
        .as_array()
        .into_iter()
        .flatten()
        .filter(|v| v["key"].as_str().is_some_and(|k| !k.is_empty()))
        .cloned()
        .map(Row)
        .collect()
}
pub fn wrap(index: i64, length: usize) -> usize {
    if length == 0 {
        0
    } else {
        index.rem_euclid(length as i64) as usize
    }
}
#[derive(Clone, Copy, Debug)]
pub struct Motion {
    pub from: f64,
    pub target: f64,
    pub started: Instant,
}
impl Motion {
    pub fn sample(self, now: Instant) -> (f64, bool) {
        let t = (now.saturating_duration_since(self.started).as_secs_f64() / 0.210).clamp(0.0, 1.0);
        (
            self.from + (self.target - self.from) * (1.0 - (1.0 - t).powi(3)),
            t < 1.0,
        )
    }
}
#[derive(Clone, Debug)]
pub struct Model {
    pub local: Vec<Row>,
    pub web: Vec<Row>,
    pub items: Vec<Row>,
    pub source: Source,
    pub query: String,
    pub web_query: String,
    pub web_dirty: bool,
    pub page: u64,
    pub last_page: u64,
    pub total: u64,
    pub current: String,
    pub status: String,
    pub trash: Option<Row>,
    pub target: i64,
    pub position: f64,
    pub motion: Option<Motion>,
}
impl Default for Model {
    fn default() -> Self {
        Self {
            local: vec![],
            web: vec![],
            items: vec![],
            source: Source::Local,
            query: String::new(),
            web_query: String::new(),
            web_dirty: false,
            page: 0,
            last_page: 1,
            total: 0,
            current: String::new(),
            status: "Cargando fondos…".into(),
            trash: None,
            target: 0,
            position: 0.0,
            motion: None,
        }
    }
}
impl Model {
    pub fn selected(&self) -> Option<&Row> {
        self.items.get(wrap(self.target, self.items.len()))
    }
    pub fn reset(&mut self, index: usize) {
        self.target = index as i64;
        self.position = index as f64;
        self.motion = None;
    }
    pub fn filter(&mut self) {
        let words: Vec<_> = self
            .query
            .split_whitespace()
            .map(str::to_lowercase)
            .collect();
        self.items = self
            .local
            .iter()
            .filter(|r| words.iter().all(|w| r.label().to_lowercase().contains(w)))
            .cloned()
            .collect();
        let index = self
            .items
            .iter()
            .position(|r| r.path() == self.current)
            .unwrap_or(0);
        self.reset(index);
    }
    pub fn load_catalog(&mut self, result: &Value) {
        self.local = rows(&result["rows"]);
        self.current = result["current"].as_str().unwrap_or("").into();
        if self.source == Source::Local {
            self.filter();
        }
    }
    pub fn query(&mut self, text: String) {
        self.query = text;
        if self.source == Source::Local {
            self.filter();
        } else {
            self.web_dirty = true;
        }
    }
    pub fn switch(&mut self, source: Source) {
        if self.source == source {
            return;
        }
        self.source = source;
        self.query.clear();
        self.status.clear();
        self.trash = None;
        if source == Source::Local {
            self.filter();
        } else {
            self.items = self.web.clone();
            self.web_dirty = false;
            self.reset(0);
        }
    }
    pub fn navigate(&mut self, delta: i64, now: Instant) {
        if self.items.is_empty() || self.trash.is_some() {
            return;
        }
        if let Some(m) = self.motion {
            self.position = m.sample(now).0;
        }
        self.target = self.target.saturating_add(delta.clamp(-100, 100));
        self.motion = Some(Motion {
            from: self.position,
            target: self.target as f64,
            started: now,
        });
    }
    pub fn tick(&mut self, now: Instant) {
        if let Some(m) = self.motion {
            let (p, active) = m.sample(now);
            self.position = p;
            if !active {
                self.motion = None;
            }
        }
    }
    pub fn wanted(&self) -> HashSet<String> {
        let mut result = HashSet::new();
        if self.items.is_empty() {
            return result;
        }
        for center in [self.position.round() as i64, self.target] {
            for offset in -3..=3 {
                result.insert(
                    self.items[wrap(center + offset, self.items.len())]
                        .key()
                        .into(),
                );
            }
        }
        result
    }
    pub fn priorities(&self) -> Vec<Row> {
        if self.items.is_empty() {
            return vec![];
        }
        let mut seen = HashSet::new();
        [0, -1, 1, -2, 2, -3, 3]
            .into_iter()
            .map(|o| self.items[wrap(self.target + o, self.items.len())].clone())
            .filter(|r| seen.insert(r.key().to_owned()))
            .collect()
    }
    pub fn web_result(&mut self, result: &Value) {
        self.web_query = result["query"].as_str().unwrap_or("").into();
        self.page = result["page"].as_u64().unwrap_or(1);
        self.last_page = result["lastPage"].as_u64().unwrap_or(1);
        self.total = result["total"].as_u64().unwrap_or(0);
        if self.page == 1 {
            self.web = rows(&result["rows"]);
        } else {
            let mut keys: HashSet<_> = self.web.iter().map(|r| r.key().to_owned()).collect();
            self.web.extend(
                rows(&result["rows"])
                    .into_iter()
                    .filter(|r| keys.insert(r.key().into())),
            );
        }
        if self.source == Source::Web {
            self.items = self.web.clone();
            if self.page == 1 {
                self.reset(0);
            }
            self.web_dirty = self.query.trim() != self.web_query;
            self.status = if self.total > 0 {
                "Favoritos · SFW · 1920×1080 · 16:9"
            } else {
                "Sin resultados"
            }
            .into();
        }
    }
    pub fn request_trash(&mut self) {
        let Some(item) = self.selected().cloned() else {
            return;
        };
        if self.source == Source::Web {
            self.web.retain(|r| r.key() != item.key());
            self.items = self.web.clone();
            self.reset(0);
            self.status = "Resultado ocultado durante esta sesión".into();
        } else if item.path() == self.current {
            self.status = "No se puede borrar el fondo activo".into();
        } else {
            self.trash = Some(item);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::time::Duration;
    fn model() -> Model {
        let mut m = Model::default();
        m.load_catalog(&json!({"current":"/b","rows":[
            {"key":"a","path":"/a","label":"Gato Café"},{"key":"b","path":"/b","label":"Bosque"},
            {"key":"c","path":"/c","label":"Otro Gato"}]}));
        m
    }
    #[test]
    fn current_and_filter() {
        let mut m = model();
        assert_eq!(m.selected().unwrap().key(), "b");
        m.query("GATO café".into());
        assert_eq!(m.items.len(), 1);
        assert_eq!(m.selected().unwrap().key(), "a");
        m.query("inexistente".into());
        assert!(m.selected().is_none());
    }
    #[test]
    fn no_active_trash() {
        let mut m = model();
        m.request_trash();
        assert!(m.trash.is_none());
        assert!(m.status.contains("activo"));
        m.reset(0);
        m.request_trash();
        assert_eq!(m.trash.unwrap().key(), "a");
    }
    #[test]
    fn web_hide_is_not_delete() {
        let mut m = model();
        m.switch(Source::Web);
        m.web_result(&json!({"query":"","page":1,"lastPage":2,"total":2,"rows":[{"key":"web:abc","path":"https://w.wallhaven.cc/a","label":"abc"}]}));
        m.request_trash();
        assert!(m.web.is_empty());
        assert!(m.trash.is_none());
        assert_eq!(m.local.len(), 3);
    }
    #[test]
    fn stable_web_dedup_and_dirty() {
        let mut m = model();
        m.switch(Source::Web);
        m.query("new".into());
        m.web_result(&json!({"query":"old","page":1,"rows":[{"key":"web:a"}]}));
        assert!(m.web_dirty);
        m.web_result(&json!({"query":"old","page":2,"rows":[{"key":"web:a"},{"key":"web:b"}]}));
        assert_eq!(m.web.len(), 2);
    }
    #[test]
    fn movement_stops_and_wraps() {
        let mut m = model();
        let now = Instant::now();
        for _ in 0..20 {
            m.navigate(-1, now);
        }
        m.tick(now + Duration::from_millis(220));
        assert!(m.motion.is_none());
        assert_eq!(m.position, m.target as f64);
        assert!(m.selected().is_some());
    }
    #[test]
    fn cache_bound() {
        let mut m = model();
        m.local = (0..100)
            .map(|i| Row(json!({"key":i.to_string(),"path":i.to_string(),"label":i.to_string()})))
            .collect();
        m.filter();
        m.navigate(50, Instant::now());
        assert!(m.wanted().len() <= 14);
        assert!(m.priorities().len() <= 7);
    }
    #[test]
    fn switching_resets_filter() {
        let mut m = model();
        m.query("gato".into());
        m.switch(Source::Web);
        m.switch(Source::Local);
        assert_eq!(m.items.len(), 3);
        assert_eq!(m.selected().unwrap().key(), "b");
    }
}
