use serde_json::{json, Value};
use std::process::Command;

fn tier(name: &str, query: &str) -> u8 {
    if name == query {
        0
    } else if name.starts_with(query) {
        1
    } else if name
        .char_indices()
        .any(|(i, c)| matches!(c, '-' | '_') && name[i + 1..].starts_with(query))
    {
        2
    } else if name.contains(query) {
        3
    } else {
        4
    }
}

fn parse(output: &str, query: &str) -> Value {
    let lines: Vec<_> = output.trim().lines().collect();
    let mut packages = Vec::new();
    for pair in lines.chunks(2) {
        let header = pair[0].trim();
        let Some((repo_name, rest)) = header.split_once(' ') else {
            continue;
        };
        let Some((repo, name)) = repo_name.split_once('/') else {
            continue;
        };
        packages.push(json!({
            "name":name, "version":rest.split_whitespace().next().unwrap_or(""),
            "repo":repo, "source":if repo == "aur" {"AUR"} else {"pacman"},
            "description":pair.get(1).unwrap_or(&"").trim(),
            "installed":header.contains("(Installed)") || header.contains("(Installed:")
        }));
    }
    let query = query.to_lowercase();
    packages.sort_by_key(|p| {
        let name = p["name"].as_str().unwrap_or("").to_lowercase();
        (
            tier(&name, &query),
            !p["installed"].as_bool().unwrap_or(false),
            p["source"] == "AUR",
            name.chars().count(),
        )
    });
    packages.truncate(50);
    json!(packages)
}

pub fn run(query: &str) -> Value {
    if query.chars().count() < 2 {
        return json!([]);
    }
    // Query is a separate argument, never shell code. Bound the external search.
    let result = Command::new("timeout")
        .args([
            "--kill-after=2s",
            "15s",
            "yay",
            "-Ss",
            "--color=never",
            "--",
            query,
        ])
        .env("LC_ALL", "C")
        .output();
    match result {
        Ok(out) if out.status.success() => parse(&String::from_utf8_lossy(&out.stdout), query),
        _ => json!([]),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ranking_and_fields() {
        let p = parse("aur/foo-bar 2.0\n  third\nextra/bar 1.0 (Installed)\n  exact\nextra/bar-tools 3\n  prefix\n", "bar");
        assert_eq!(p[0]["name"], "bar");
        assert_eq!(p[0]["installed"], true);
        assert_eq!(p[1]["name"], "bar-tools");
        assert_eq!(p[2]["source"], "AUR");
    }
    #[test]
    fn literal_query_and_bad_headers() {
        assert_eq!(tier("foo-a.b", "a.b"), 2);
        assert_eq!(tier("foo-a-b", "a-b"), 2);
        assert_eq!(tier("foo-axb", "a.b"), 4);
        assert_eq!(parse("invalid\n description", "foo"), json!([]));
        assert_eq!(run("x"), json!([]));
    }
    #[test]
    fn limit_and_missing_description() {
        assert_eq!(parse("extra/test 1", "test")[0]["description"], "");
        let text = (0..70)
            .map(|i| format!("extra/pkg{i} 1\n desc\n"))
            .collect::<String>();
        assert_eq!(parse(&text, "pkg").as_array().unwrap().len(), 50);
    }
}
