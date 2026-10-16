use serde_json::{json, Value};
use std::{fs, io::Write, path::Path, process::Command};

#[derive(Clone)]
struct Color {
    h: f64,
    s: f64,
    l: f64,
    chroma: f64,
    count: u64,
}

fn hsl(rgb: [u8; 3]) -> (f64, f64, f64) {
    let [r, g, b] = rgb.map(|v| v as f64 / 255.0);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let l = (max + min) / 2.0;
    if max == min {
        return (0.0, 0.0, l);
    }
    let d = max - min;
    let s = if l > 0.5 {
        d / (2.0 - max - min)
    } else {
        d / (max + min)
    };
    let h = if max == r {
        (g - b) / d + if g < b { 6.0 } else { 0.0 }
    } else if max == g {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };
    (h / 6.0 * 360.0, s, l)
}
fn rgb(hex: &str) -> Option<[u8; 3]> {
    if hex.len() != 7 || !hex.starts_with('#') || !hex[1..].is_ascii() {
        return None;
    }
    Some([
        u8::from_str_radix(&hex[1..3], 16).ok()?,
        u8::from_str_radix(&hex[3..5], 16).ok()?,
        u8::from_str_radix(&hex[5..7], 16).ok()?,
    ])
}
fn force(h: f64, s: f64, target_s: f64, l: f64) -> String {
    let s = s.max(target_s);
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = l - c / 2.0;
    let (r, g, b) = if h < 60.0 {
        (c, x, 0.0)
    } else if h < 120.0 {
        (x, c, 0.0)
    } else if h < 180.0 {
        (0.0, c, x)
    } else if h < 240.0 {
        (0.0, x, c)
    } else if h < 300.0 {
        (x, 0.0, c)
    } else {
        (c, 0.0, x)
    };
    let byte = |v: f64| ((v + m) * 255.0).clamp(0.0, 255.0) as u8;
    format!("#{:02x}{:02x}{:02x}", byte(r), byte(g), byte(b))
}
pub fn histogram(text: &str) -> Vec<(String, u64)> {
    let re = regex::Regex::new(r"(\d+):\s*\(.*?\)\s*(#[0-9a-fA-F]{6})").unwrap();
    let mut result: Vec<(String, u64)> = Vec::new();
    for cap in re.captures_iter(text) {
        let Ok(count) = cap[1].parse::<u64>() else {
            continue;
        };
        let hex = cap[2].to_lowercase();
        if let Some(old) = result.iter_mut().find(|c| c.0 == hex) {
            old.1 = old.1.saturating_add(count)
        } else {
            result.push((hex, count))
        }
    }
    result
}
pub fn palette(hist: &[(String, u64)]) -> Option<(Value, Value)> {
    let mut colors = Vec::new();
    for (hex, count) in hist {
        let rgb = rgb(hex)?;
        let (h, s, l) = hsl(rgb);
        colors.push(Color {
            h,
            s,
            l,
            chroma: (*rgb.iter().max()? as f64 - *rgb.iter().min()? as f64) / 255.0,
            count: *count,
        });
    }
    let total: f64 = colors.iter().map(|c| c.count as f64).sum();
    if colors.is_empty() || total == 0.0 {
        return None;
    }
    let mut best_h = 0.0;
    let mut best_chroma = -1.0;
    for c in &colors {
        if c.l > 0.20
            && c.l < 0.90
            && c.chroma < 0.15
            && c.count as f64 / total > 0.005
            && c.chroma > best_chroma
        {
            best_chroma = c.chroma;
            best_h = c.h;
        }
    }
    let gray = colors
        .iter()
        .filter(|c| c.chroma >= 0.08)
        .map(|c| c.count as f64)
        .sum::<f64>()
        / total
        < 0.05;
    // Stable count order and strict comparison preserve Python's first-wins ties.
    colors.sort_by(|a, b| b.count.cmp(&a.count));
    let dominant = colors.iter().find(|c| c.chroma >= 0.08);
    let (h, s) = if gray || dominant.is_none() {
        (best_h, 0.15)
    } else {
        let c = dominant.unwrap();
        (c.h, c.s)
    };
    let bg_s = (s * 0.5).clamp(0.10, 0.20);
    let mut primary = &colors[0];
    if !gray {
        let mut best: Option<&Color> = None;
        for c in colors.iter().take(10).filter(|c| c.chroma >= 0.08) {
            if best.is_none_or(|old| c.chroma > old.chroma) {
                best = Some(c)
            }
        }
        if let Some(c) = best {
            primary = c
        }
    }
    let mut variants = Vec::new();
    for dark in [true, false] {
        let accent = if primary.chroma < 0.08 || gray {
            if best_chroma > 0.01 {
                force(h, 0.40, 0.40, if dark { 0.80 } else { 0.40 })
            } else {
                force(0.0, 0.0, 0.0, if dark { 0.95 } else { 0.05 })
            }
        } else {
            force(primary.h, primary.s, 0.50, if dark { 0.60 } else { 0.45 })
        };
        let (ah, ass, al) = hsl(rgb(&accent)?);
        variants.push(
            json!({"name":if dark {"Wallpaper Theme"}else{"Wallpaper Theme Light"},
            "generateFromWallpaper":true,
            "bg":force(h,bg_s,bg_s,if dark {0.04}else{0.92}),
            "fg":force(h,bg_s,bg_s*0.15,if dark {0.95}else{0.16}),
            "accent":accent,"accentComplementary":force((ah+45.0)%360.0,ass,ass,al)}),
        );
    }
    Some((variants.remove(0), variants.remove(0)))
}
fn magick(path: &Path, args: &[&str]) -> Result<String, String> {
    let out = Command::new("timeout")
        .args(["--kill-after=2s", "30s", "magick"])
        .arg(path)
        .args(args)
        .env("LC_ALL", "C")
        .output()
        .map_err(|e| e.to_string())?;
    if !out.status.success() {
        return Err(format!(
            "ImageMagick failed: {}",
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}
fn atomic(path: &Path, value: &Value) -> Result<(), String> {
    let temp = path.with_extension(format!("{}.tmp", std::process::id()));
    let result = (|| {
        let mut f = fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&temp)?;
        f.write_all(serde_json::to_string_pretty(value)?.as_bytes())?;
        fs::rename(&temp, path)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temp);
    }
    result.map_err(|e: std::io::Error| e.to_string())
}
pub fn run(args: &[String]) -> Result<(), String> {
    let input = args
        .first()
        .ok_or("Usage: haku-info theme IMAGE [true|false]")?;
    let path = fs::canonicalize(input).map_err(|e| e.to_string())?;
    if !path.is_file() {
        return Err("Image is not a file".into());
    }
    let brightness = magick(
        &path,
        &[
            "-background",
            "black",
            "-alpha",
            "remove",
            "-colorspace",
            "gray",
            "-format",
            "%[fx:mean]",
            "info:",
        ],
    )
    .ok()
    .and_then(|s| s.split_whitespace().next()?.parse::<f64>().ok())
    .unwrap_or(0.2);
    let text = magick(
        &path,
        &[
            "-background",
            "black",
            "-alpha",
            "remove",
            "-resize",
            "100x100",
            "-colors",
            "32",
            "-format",
            "%c",
            "histogram:info:",
        ],
    )?;
    let (dark, light) = palette(&histogram(&text)).ok_or("ImageMagick returned no colors")?;
    let cache = std::path::PathBuf::from(std::env::var_os("HOME").ok_or("HOME missing")?)
        .join(".cache/quickshell");
    fs::create_dir_all(&cache).map_err(|e| e.to_string())?;
    let active_file = cache.join("colorscheme.json");
    let previous = fs::read(&active_file)
        .ok()
        .and_then(|v| serde_json::from_slice::<Value>(&v).ok());
    let is_dark = previous
        .as_ref()
        .and_then(|v| v["wallpaperIsDark"].as_bool())
        .unwrap_or(brightness <= 0.4);
    let write_active = args
        .get(1)
        .map(|s| matches!(s.to_lowercase().as_str(), "true" | "1" | "yes"))
        .unwrap_or_else(|| {
            previous
                .as_ref()
                .map(|v| v["generateFromWallpaper"].as_bool().unwrap_or(false))
                .unwrap_or(true)
        });
    let mut active = if is_dark { dark.clone() } else { light.clone() };
    active["wallpaperIsDark"] = json!(is_dark);
    atomic(&cache.join("wallpaper_colorscheme_dark.json"), &dark)?;
    atomic(&cache.join("wallpaper_colorscheme_light.json"), &light)?;
    atomic(&cache.join("wallpaper_colorscheme.json"), &active)?;
    if write_active {
        atomic(&active_file, &active)?;
    }
    println!(
        "Success: Generated wallpaper variants{}",
        if write_active {
            " and colorscheme.json"
        } else {
            " (active colorscheme preserved)"
        }
    );
    println!(
        "COLORS:{}",
        json!({"dark":dark,"light":light,"activeIsDark":is_dark})
    );
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn grayscale() {
        let (d, l) = palette(&[("#808080".into(), 100)]).unwrap();
        assert_eq!(d["accent"], "#f2f2f2");
        assert_eq!(l["accent"], "#0c0c0c");
        assert!(palette(&[]).is_none());
    }
    #[test]
    fn duplicates() {
        assert_eq!(
            histogram("2: (0,0,0) #AABBCC\n3: (0,0,0) #aabbcc"),
            vec![("#aabbcc".into(), 5)]
        );
    }
}
