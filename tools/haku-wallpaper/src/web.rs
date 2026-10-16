use crate::{Result, Value};
use serde_json::json;
use std::{
    fs,
    io::Write,
    path::Path,
    process::{Command, Stdio},
};
use url::Url;

pub fn allowed(value: &str) -> Result<Url> {
    let url = Url::parse(value)?;
    if url.scheme() != "https"
        || !url.username().is_empty()
        || url.password().is_some()
        || !matches!(
            url.host_str(),
            Some("wallhaven.cc" | "w.wallhaven.cc" | "th.wallhaven.cc")
        )
        || url.port().is_some_and(|port| port != 443)
    {
        return Err("invalid URL".into());
    }
    Ok(url)
}

pub fn fetch(value: &str, maximum: u64) -> Result<Vec<u8>> {
    let mut url = allowed(value)?;
    // Curl handles TLS; Rust validates each redirect and limits downloaded data.
    // URL goes through stdin, keeping optional API keys out of process arguments.
    for _ in 0..6 {
        let tmp = tempfile::tempdir()?;
        let headers = tmp.path().join("headers");
        let body = tmp.path().join("body");
        let mut proc = Command::new("curl")
            .args([
                "--disable",
                "--silent",
                "--fail",
                "--proto",
                "=https",
                "--max-time",
                "20",
                "--user-agent",
                "HakuWallpaper/1.0",
                "--max-filesize",
                &maximum.to_string(),
                "--write-out",
                "%{http_code}",
                "--config",
                "-",
            ])
            .arg("--dump-header")
            .arg(&headers)
            .arg("--output")
            .arg(&body)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()?;
        let quoted = url.as_str().replace('\\', "\\\\").replace('"', "\\\"");
        let write = writeln!(
            proc.stdin.take().ok_or("missing stdin")?,
            "url = \"{quoted}\""
        );
        let output = proc.wait_with_output()?;
        write?;
        if !output.status.success() {
            return Err("download failed".into());
        }
        let status: u16 = std::str::from_utf8(&output.stdout)?.trim().parse()?;
        if [301, 302, 303, 307, 308].contains(&status) {
            let text = fs::read_to_string(headers)?;
            let location = text
                .lines()
                .rev()
                .find_map(|line| {
                    let (key, value) = line.split_once(':')?;
                    key.eq_ignore_ascii_case("location").then(|| value.trim())
                })
                .ok_or("missing redirect")?;
            url = allowed(url.join(location)?.as_str())?;
            continue;
        }
        if !(200..300).contains(&status) || body.metadata()?.len() > maximum {
            return Err("invalid response".into());
        }
        return Ok(fs::read(body)?);
    }
    Err("redirect limit".into())
}

fn valid_id(id: &str) -> bool {
    id.len() == 6 && id.bytes().all(|b| b.is_ascii_alphanumeric())
}

pub fn search(home: &Path, data: &Value) -> Result<Value> {
    let query = data["query"].as_str().unwrap_or("");
    let page = data["page"].as_i64().unwrap_or(1).max(1);
    let mut url = allowed("https://wallhaven.cc/api/v1/search")?;
    {
        let mut params = url.query_pairs_mut();
        params.extend_pairs([
            ("q", query),
            ("categories", "111"),
            ("purity", "100"),
            ("sorting", "favorites"),
            ("order", "desc"),
            ("atleast", "1920x1080"),
            ("ratios", "16x9"),
        ]);
        params.append_pair("page", &page.to_string());
        if let Ok(key) = fs::read_to_string(home.join(".config/haku/wallhaven_api_key")) {
            params.append_pair("apikey", key.trim());
        }
    }
    let payload: Value = serde_json::from_slice(&fetch(url.as_str(), 4 * 1024 * 1024)?)?;
    let mut rows = Vec::new();
    if let Some(items) = payload["data"].as_array() {
        for item in items {
            let id = item["id"].as_str().ok_or("missing id")?;
            if !valid_id(id) {
                continue;
            }
            let thumb = item["thumbs"]["small"]
                .as_str()
                .ok_or("missing thumbnail")?;
            let path = item["path"].as_str().ok_or("missing image")?;
            allowed(thumb)?;
            allowed(path)?;
            rows.push(
                json!({"key":format!("web:{id}"),"id":id,"kind":"web","label":id,
                "resolution":item["resolution"],"thumb":thumb,"path":path}),
            );
        }
    }
    Ok(
        json!({"ok":true,"rows":rows,"total":payload["meta"]["total"].as_u64().unwrap_or(rows.len() as u64),
        "lastPage":payload["meta"]["last_page"].as_u64().unwrap_or(1),"page":page,"query":query}),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn url_boundary() {
        assert!(allowed("https://th.wallhaven.cc/small/ab/abcdef.jpg").is_ok());
        for value in [
            "http://wallhaven.cc/a",
            "https://wallhaven.cc.evil.org/a",
            "file:///tmp/a",
            "https://user:pass@wallhaven.cc/a",
            "https://wallhaven.cc:8000/a",
        ] {
            assert!(allowed(value).is_err(), "{value}");
        }
    }
    #[test]
    fn ids() {
        assert!(valid_id("abc123"));
        assert!(!valid_id("../abc"));
        assert!(!valid_id("abcdefg"));
    }
}
