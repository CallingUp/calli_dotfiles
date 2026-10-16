use serde_json::{json, Value};
use std::{
    collections::{HashMap, HashSet},
    env, fs,
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
};
const KNOWN: &[&str] = &[
    "spotify",
    "youtube-music",
    "kew",
    "vlc",
    "mpv",
    "amberol",
    "rhythmbox",
    "clementine",
    "strawberry",
    "cider",
    "audacious",
    "deadbeef",
    "elisa",
    "lollypop",
    "tauonmb",
    "tauon",
    "quodlibet",
    "sayonara",
    "musique",
    "feishin",
    "supersonic",
    "g4music",
    "shortwave",
    "tidal-hifi",
    "nuclear",
    "celluloid",
    "dopamine",
    "foobar2000",
    "sonora",
    "harmony",
    "museeks",
    "deezer",
];
const EXCLUDE_NAMES: &[&str] = &[
    "mixer",
    "volume control",
    "recorder",
    "capture",
    "test utility",
    "equalizer",
    "editor",
    "effects",
    "converter",
    "settings",
];
const EXCLUDE_EXECS: &[&str] = &[
    "pavucontrol",
    "obs",
    "qv4l2",
    "qvidcap",
    "audacity",
    "easyeffects",
    "helvum",
    "alsamixer",
    "pw-top",
    "wireplumber",
    "qpaeq",
    "sound-recorder",
];
fn entry(text: &str) -> Option<HashMap<String, String>> {
    let mut sections: HashMap<String, HashMap<String, String>> = HashMap::new();
    let mut section = String::new();
    let mut previous: Option<(String, usize)> = None;
    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') || line.starts_with(';') {
            continue;
        }
        let indent = raw.len() - raw.trim_start().len();
        if let Some((key, base)) = &previous {
            if indent > *base {
                let value = sections.get_mut(&section)?.get_mut(key)?;
                value.push('\n');
                value.push_str(line);
                continue;
            }
        }
        if line.starts_with('[') {
            let end = line.find(']')?;
            let name = &line[1..end];
            if sections.contains_key(name) {
                return None;
            }
            sections.insert(name.into(), HashMap::new());
            section = name.into();
            previous = None;
            continue;
        }
        let delimiter = line.char_indices().find(|(_, c)| *c == '=' || *c == ':')?.0;
        let key = line[..delimiter].trim().to_lowercase();
        if key.is_empty() {
            return None;
        }
        let map = sections.get_mut(&section)?;
        if map.contains_key(&key) {
            return None;
        }
        map.insert(key.clone(), line[delimiter + 1..].trim().into());
        previous = Some((key, indent));
    }
    let own = sections.remove("Desktop Entry")?;
    let mut result = sections.remove("DEFAULT").unwrap_or_default();
    result.extend(own);
    Some(result)
}
fn which(binary: &str) -> bool {
    let executable = |p: &Path| {
        p.is_file()
            && p.metadata()
                .is_ok_and(|m| m.permissions().mode() & 0o111 != 0)
    };
    if binary.contains('/') {
        return executable(Path::new(binary));
    }
    env::split_paths(&env::var_os("PATH").unwrap_or_default()).any(|p| executable(&p.join(binary)))
}
fn candidate(path: &Path, text: &str) -> Option<(Value, String)> {
    let e = entry(text)?;
    let get = |key: &str| e.get(key).map(String::as_str).unwrap_or("");
    if get("nodisplay").eq_ignore_ascii_case("true") || get("hidden").eq_ignore_ascii_case("true") {
        return None;
    }
    let name = get("name").trim();
    let raw = get("exec").trim();
    let executable = raw.split(" %").next()?.replace('"', "").trim().to_owned();
    let clean = executable.strip_prefix("/usr/bin/").unwrap_or(&executable);
    let base = clean.split_whitespace().next()?;
    let exec_lower = base.to_lowercase();
    let name_lower = name.to_lowercase();
    let stem = path.file_stem()?.to_str()?;
    let stem_lower = stem.to_lowercase();
    if EXCLUDE_NAMES.iter().any(|s| name_lower.contains(s))
        || EXCLUDE_EXECS.iter().any(|s| exec_lower.contains(s))
    {
        return None;
    }
    let cats: Vec<&str> = get("categories")
        .split(';')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .collect();
    let known = KNOWN
        .iter()
        .find(|k| exec_lower.contains(**k) || name_lower.contains(**k) || stem_lower.contains(**k));
    let player = (cats.contains(&"Player")
        || cats.contains(&"Music")
        || (cats.contains(&"AudioVideo") && !cats.contains(&"Video") && cats.contains(&"Audio")))
        && !cats
            .iter()
            .any(|c| ["Recorder", "Mixer", "Settings", "Editor"].contains(c));
    if known.is_none() && !player {
        return None;
    }
    if !which(base) && !Path::new(base).exists() && !which(executable.split_whitespace().next()?) {
        return None;
    }
    let id = known.map(|k| k.to_string()).unwrap_or(exec_lower);
    Some((
        json!({"id":id,"name":name,"exec":clean,"icon":e.get("icon").map(String::as_str).unwrap_or("music"),"terminal":get("terminal").eq_ignore_ascii_case("true"),"desktopEntry":stem}),
        base.into(),
    ))
}
pub fn run() -> Value {
    let home = PathBuf::from(env::var_os("HOME").unwrap_or_default());
    let dirs = env::var("XDG_DATA_DIRS").unwrap_or("/usr/local/share:/usr/share".into());
    let mut paths = dirs
        .split(':')
        .map(|p| PathBuf::from(p).join("applications"))
        .collect::<Vec<_>>();
    paths.extend([
        home.join(".local/share/applications"),
        home.join(".local/share/flatpak/exports/share/applications"),
        PathBuf::from("/var/lib/flatpak/exports/share/applications"),
    ]);
    let mut ids = HashSet::new();
    let mut execs = HashSet::new();
    let mut results = vec![];
    for directory in paths {
        if let Ok(files) = fs::read_dir(directory) {
            for file in files.flatten() {
                let path = file.path();
                if path.extension().is_none_or(|s| s != "desktop") {
                    continue;
                }
                if let Ok(text) = fs::read_to_string(&path) {
                    if let Some((row, base)) = candidate(&path, &text) {
                        let id = row["id"].as_str().unwrap().to_string();
                        if !ids.contains(&id) && !execs.contains(&base) {
                            ids.insert(id);
                            execs.insert(base);
                            results.push(row);
                        }
                    }
                }
            }
        }
    }
    for (id, name, icon) in [
        ("kew", "kew", "music"),
        ("cmus", "Cmus", "terminal"),
        ("mocp", "MOC", "terminal"),
        ("ncmpcpp", "ncmpcpp", "terminal"),
        ("mpd", "MPD", "music"),
        ("rmpc", "rmpc", "terminal"),
        ("musikcube", "musikcube", "terminal"),
    ] {
        if which(id) && !ids.contains(id) && !execs.contains(id) {
            ids.insert(id.into());
            execs.insert(id.into());
            results.push(json!({"id":id,"name":name,"exec":id,"icon":icon,"terminal":true,"desktopEntry":id}));
        }
    }
    results.sort_by_key(|r| r["name"].as_str().unwrap_or("").to_lowercase());
    json!(results)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ini_sections() {
        let e=entry("[DEFAULT]\nIcon=music\n[Desktop Entry]\nName=Test\nExec=player %U\n[Desktop Action Other]\nExec=other\n").unwrap();
        assert_eq!(e["name"], "Test");
        assert_eq!(e["icon"], "music");
        assert_eq!(e["exec"], "player %U");
    }
    #[test]
    fn invalid_duplicate() {
        assert!(entry("[Desktop Entry]\nName=A\nName=B\n").is_none());
    }
    #[test]
    fn percent_literal() {
        assert_eq!(
            entry("[Desktop Entry]\nName=100% Music\n").unwrap()["name"],
            "100% Music"
        );
    }
}
