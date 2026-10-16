use regex::Regex;
use serde_json::{json, Value};
use std::{collections::HashSet, fs, path::Path};
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
struct Patterns {
    block: Regex,
    comment: Regex,
    include: Regex,
    inline: Regex,
    bind: Regex,
    title: Regex,
    inline_title: Regex,
    end: Regex,
}
impl Patterns {
    fn new() -> Result<Self> {
        Ok(Self {
            block: Regex::new(r"(?s)/\*.*?\*/")?,
            comment: Regex::new(r"^\s*//\s*([\wÁÉÍÓÚáéíóú].*)$")?,
            include: Regex::new(r#"^\s*include\s+"([^"]+)""#)?,
            inline: Regex::new(r#"^\s*("[^"\n]+"|[\w+.-]+)\s*(.*?)\{\s*([^{}]+)\s*}\s*$"#)?,
            bind: Regex::new(r#"^\s*("[^"\n]+"|[\w+.-]+)\s*(.*?)\{\s*$"#)?,
            title: Regex::new(r#"hotkey-overlay-title="((?:\\.|[^"\\])*)""#)?,
            inline_title: Regex::new(r#"hotkey-overlay-title="([^"]*)""#)?,
            end: Regex::new(r"^\s*}")?,
        })
    }
}
fn eligible(key: &str) -> bool {
    key.contains('+') || key.starts_with("XF86") || key.starts_with("Print")
}
fn row(
    path: &Path,
    key: &str,
    metadata: &str,
    action: &str,
    section: &str,
    title: &Regex,
) -> Option<Value> {
    if metadata.contains("hotkey-overlay-title=null") {
        return None;
    }
    let label = title
        .captures(metadata)
        .map(|c| c[1].to_owned())
        .unwrap_or_else(|| action.to_owned());
    Some(
        json!({"key":key.trim_matches('"').replace('+'," + "),"label":label,"action":action,"category":section,"source":path}),
    )
}
fn collect(
    path: &Path,
    seen: &mut HashSet<std::path::PathBuf>,
    p: &Patterns,
) -> Result<Vec<Value>> {
    if !path.is_file() {
        return Ok(vec![]);
    }
    let path = path.canonicalize()?;
    if !seen.insert(path.clone()) {
        return Ok(vec![]);
    }
    let text = fs::read_to_string(&path)?;
    let text = p.block.replace_all(&text, |c: &regex::Captures<'_>| {
        "\n".repeat(c[0].matches('\n').count())
    });
    let lines: Vec<&str> = text.lines().collect();
    let mut section = String::from("General");
    let mut rows = vec![];
    let mut i = 0;
    while i < lines.len() {
        let line = lines[i];
        if let Some(c) = p.comment.captures(line) {
            section = match c[1].trim() {
                "Help" => "Ayuda",
                "Applications" => "Aplicaciones",
                "Noctalia" => "Shell",
                "Session" => "Sesión",
                s => s,
            }
            .into();
        }
        if let Some(c) = p.include.captures(line) {
            rows.extend(collect(
                &path.parent().ok_or("missing parent")?.join(&c[1]),
                seen,
                p,
            )?);
        }
        if let Some(c) = p.inline.captures(line) {
            if eligible(&c[1]) {
                let action = c[3].trim().trim_end_matches(';').trim();
                let category = if path.file_name().is_some_and(|s| s == "recent-windows.kdl") {
                    "Selector de ventanas"
                } else {
                    &section
                };
                if let Some(r) = row(&path, &c[1], &c[2], action, category, &p.inline_title) {
                    rows.push(r);
                }
            }
        }
        if let Some(c) = p.bind.captures(line) {
            let key = c[1].trim_matches('"');
            if key != "binds" && eligible(key) {
                let mut body = vec![];
                i += 1;
                while i < lines.len() && !p.end.is_match(lines[i]) {
                    let line = lines[i].trim();
                    if !line.is_empty() && !line.starts_with("//") {
                        body.push(line);
                    }
                    i += 1;
                }
                if let Some(r) = row(&path, key, &c[2], &body.join(" · "), &section, &p.title) {
                    rows.push(r);
                }
            }
        }
        i += 1;
    }
    Ok(rows)
}
pub fn run(path: &Path) -> Value {
    match Patterns::new().and_then(|p| collect(path, &mut HashSet::new(), &p)) {
        Ok(rows) => json!({"rows":rows,"error":""}),
        Err(_) => json!({"rows":[],"error":"No se pudieron leer los atajos"}),
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn keys() {
        assert!(eligible("Mod+Return"));
        assert!(eligible("XF86AudioMute"));
        assert!(!eligible("binds"));
    }
    #[test]
    fn metadata() {
        let p = Patterns::new().unwrap();
        let r = row(
            Path::new("/test"),
            "Mod+X",
            r#"hotkey-overlay-title="Texto""#,
            "spawn",
            "General",
            &p.title,
        )
        .unwrap();
        assert_eq!(r["label"], "Texto");
        assert_eq!(r["key"], "Mod + X");
        assert!(row(
            Path::new("/test"),
            "Mod+X",
            "hotkey-overlay-title=null",
            "spawn",
            "General",
            &p.title
        )
        .is_none());
    }
}
