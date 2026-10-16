use regex::Regex;
use serde_json::{json, Value};
use std::{
    collections::HashSet,
    env,
    ffi::CStr,
    fs,
    path::Path,
    process::{Command, Stdio},
};
fn read(path: &str) -> String {
    fs::read_to_string(path)
        .unwrap_or_default()
        .trim()
        .to_owned()
}
fn command(program: &str, args: &[&str]) -> String {
    Command::new("timeout")
        .arg("8s")
        .arg(program)
        .args(args)
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default()
}
fn clean(text: &str) -> String {
    let r = Regex::new(r"(?i)\(R\)|\(TM\)|Corporation|Inc\.|Co\.,?\s*Ltd\.?").unwrap();
    r.replace_all(text, "")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}
fn host(hostname: &str) -> String {
    for path in [
        "/proc/device-tree/model",
        "/sys/firmware/devicetree/base/model",
    ] {
        let model = read(path).replace('\0', "");
        if !model.is_empty() {
            return model;
        }
    }
    let invalid = [
        "none",
        "to be filled by o.e.m.",
        "system product name",
        "system version",
        "default string",
        "not applicable",
        "undefined",
        "type2 - board version",
    ];
    for dir in ["/sys/devices/virtual/dmi/id", "/sys/class/dmi/id"] {
        if !Path::new(dir).exists() {
            continue;
        }
        let value = |name: &str| {
            let s = read(&format!("{dir}/{name}"));
            if invalid.contains(&s.to_lowercase().as_str()) {
                String::new()
            } else {
                s
            }
        };
        let vendor = value("sys_vendor");
        let product = value("product_name");
        let board = value("board_name");
        let board_vendor = value("board_vendor");
        let combine = |vendor: &str, name: &str| {
            if !vendor.is_empty() && !name.to_lowercase().starts_with(&vendor.to_lowercase()) {
                format!("{} {name}", clean(vendor)).trim().into()
            } else {
                name.into()
            }
        };
        if !product.is_empty() {
            return combine(&vendor, &product);
        }
        if !board.is_empty() {
            return combine(
                if board_vendor.is_empty() {
                    &vendor
                } else {
                    &board_vendor
                },
                &board,
            );
        }
        let version = value("product_version");
        if !version.is_empty() {
            return version;
        }
        break;
    }
    hostname.into()
}
fn cpu(text: &str) -> (String, String) {
    let mut model = String::new();
    let mut physical = 0;
    let mut phys = 0;
    let mut cores = HashSet::new();
    let mut threads = 0;
    for line in text.lines() {
        if let Some((key, value)) = line.split_once(':') {
            let key = key.trim();
            let value = value.trim();
            if model.is_empty() && ["model name", "Processor", "Model", "Hardware"].contains(&key) {
                model = value.into();
            }
            match key {
                "processor" => threads += 1,
                "physical id" => phys = value.parse().unwrap_or(0),
                "core id" => {
                    if let Ok(core) = value.parse::<u32>() {
                        cores.insert((phys, core));
                    }
                }
                "cpu cores" if physical == 0 => physical = value.parse().unwrap_or(0),
                _ => {}
            }
        }
    }
    if !cores.is_empty() {
        physical = cores.len();
    }
    if threads == 0 {
        threads = std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(1);
    }
    if model.is_empty()
        || model.eq_ignore_ascii_case("arm")
        || model.eq_ignore_ascii_case("unknown")
    {
        let output = command("lscpu", &[]);
        for line in output.lines() {
            if let Some((key, value)) = line.split_once(':') {
                if key.trim() == "Model name" && model.is_empty() {
                    model = value.trim().into();
                }
                if key.trim() == "Core(s) per socket" && physical == 0 {
                    physical = value.trim().parse().unwrap_or(0);
                }
            }
        }
    }
    if model.is_empty() {
        model = "Generic CPU".into();
    }
    let detail = if physical > 0 && physical != threads {
        format!("{physical} Cores, {threads} Threads")
    } else if physical > 0 {
        format!("{physical} Cores")
    } else {
        format!("{threads} Threads")
    };
    (clean(&model), detail)
}
fn gpus() -> String {
    let mut names = vec![];
    let brackets = Regex::new(r"\[([^\]]+)\]").unwrap();
    let revision = Regex::new(r"\(rev [0-9a-fA-F]+\)").unwrap();
    for line in command("lspci", &[]).lines() {
        let lower = line.to_lowercase();
        if ![
            "vga compatible controller",
            "3d controller",
            "display controller",
        ]
        .iter()
        .any(|s| lower.contains(s))
        {
            continue;
        }
        if let Some(raw) = line.splitn(3, ':').nth(2) {
            let raw = revision.replace_all(raw, "").trim().to_owned();
            let lower = raw.to_lowercase();
            let vendor = if lower.contains("nvidia") {
                "NVIDIA"
            } else if lower.contains("amd") || lower.contains("advanced micro devices") {
                "AMD"
            } else if lower.contains("intel") {
                "Intel"
            } else {
                ""
            };
            if let Some(c) = brackets.captures(&raw) {
                let name = c[1].trim();
                names.push(
                    if !vendor.is_empty()
                        && !name.to_lowercase().starts_with(&vendor.to_lowercase())
                    {
                        format!("{vendor} {name}")
                    } else {
                        name.into()
                    },
                );
            } else {
                names.push(clean(&raw));
            }
        }
    }
    if names.is_empty() {
        if let Ok(cards) = fs::read_dir("/sys/class/drm") {
            for card in cards.flatten() {
                let name = card.file_name().to_string_lossy().into_owned();
                if !name.starts_with("card") || name.contains('-') {
                    continue;
                }
                if let Ok(driver) = fs::read_link(card.path().join("device/driver")) {
                    let name = driver.file_name().unwrap_or_default().to_string_lossy();
                    let label = match name.as_ref() {
                        "asahi" => "Apple Silicon GPU",
                        "v3d" => "Broadcom VideoCore VI",
                        "vc4" => "Broadcom VideoCore IV",
                        "panfrost" => "ARM Mali GPU",
                        "msm" => "Qualcomm Adreno",
                        "virtio-gpu" => "VirtIO GPU",
                        "vmwgfx" => "VMware SVGA3D",
                        "qxl" => "QXL Virtual GPU",
                        "nouveau" => "NVIDIA (Nouveau)",
                        "amdgpu" => "AMD Radeon Graphics",
                        "i915" => "Intel HD/UHD Graphics",
                        "xe" => "Intel Arc / Xe Graphics",
                        _ => "Integrated Graphics",
                    }
                    .to_string();
                    if !names.contains(&label) {
                        names.push(label);
                    }
                }
            }
        }
    }
    if names.is_empty() {
        "Integrated Graphics".into()
    } else {
        names.join(" | ")
    }
}
fn displays() -> String {
    let mut names = vec![];
    if let Ok(entries) = fs::read_dir("/sys/class/drm") {
        let mut paths = entries.flatten().map(|e| e.path()).collect::<Vec<_>>();
        paths.sort();
        for path in paths {
            if fs::read_to_string(path.join("status"))
                .unwrap_or_default()
                .trim()
                == "connected"
            {
                let mode = fs::read_to_string(path.join("modes"))
                    .unwrap_or_default()
                    .lines()
                    .next()
                    .unwrap_or("")
                    .to_owned();
                if !mode.is_empty() {
                    names.push(format!(
                        "{}: {mode}",
                        path.file_name()
                            .unwrap_or_default()
                            .to_string_lossy()
                            .replace("card0-", "")
                            .replace("card1-", "")
                    ));
                }
            }
        }
    }
    if names.is_empty() {
        "1920x1080 @ 60Hz".into()
    } else {
        names.join(", ")
    }
}
pub fn run() -> Value {
    let mut uts = std::mem::MaybeUninit::<libc::utsname>::uninit();
    let (kernel, hostname, arch) = if unsafe { libc::uname(uts.as_mut_ptr()) } == 0 {
        let uts = unsafe { uts.assume_init() };
        let s =
            |p: *const libc::c_char| unsafe { CStr::from_ptr(p) }.to_string_lossy().into_owned();
        (
            s(uts.release.as_ptr()),
            s(uts.nodename.as_ptr()),
            s(uts.machine.as_ptr()),
        )
    } else {
        (String::new(), String::new(), String::new())
    };
    let os = read("/etc/os-release")
        .lines()
        .find_map(|s| {
            s.strip_prefix("PRETTY_NAME=")
                .map(|s| s.trim_matches('"').to_owned())
        })
        .unwrap_or("Linux".into());
    let shell = env::var("SHELL")
        .ok()
        .filter(|s| !s.is_empty())
        .map(|s| {
            Path::new(&s)
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .into_owned()
        })
        .unwrap_or("zsh".into());
    let n = command("pacman", &["-Qn"]).lines().count();
    let aur = command("pacman", &["-Qm"]).lines().count();
    let packages = if aur > 0 {
        format!("{n} (pacman), {aur} (aur)")
    } else {
        format!("{n} (pacman)")
    };
    let (cpu_model, cpu_cores) = cpu(&read("/proc/cpuinfo"));
    let kb = read("/proc/meminfo")
        .lines()
        .find_map(|l| {
            l.strip_prefix("MemTotal:")
                .and_then(|s| s.split_whitespace().next())
                .and_then(|s| s.parse::<f64>().ok())
        })
        .unwrap_or(0.0);
    let mut stat = std::mem::MaybeUninit::<libc::statvfs>::uninit();
    let disk = if unsafe { libc::statvfs(c"/".as_ptr(), stat.as_mut_ptr()) } == 0 {
        let s = unsafe { stat.assume_init() };
        format!(
            "{:.0} GB",
            s.f_blocks as f64 * s.f_frsize as f64 / 1024f64.powi(3)
        )
    } else {
        String::new()
    };
    json!({"os":format!("{os} {arch}").trim(),"host":host(&hostname),"kernel":kernel,"hostname":hostname,"username":env::var("USER").or_else(|_|env::var("LOGNAME")).unwrap_or_default(),"shell":shell,"wm":"Niri (Wayland)","packages":packages,"display":displays(),"cpu_model":cpu_model,"cpu_cores":cpu_cores,"ram_total":format!("{:.1} GB",kb/(1024.0*1024.0)),"disk_total":disk,"gpus":gpus()})
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn branding() {
        assert_eq!(
            clean("Intel(R) Core(TM) Corporation  CPU"),
            "Intel Core CPU"
        );
    }
    #[test]
    fn topology() {
        let (model,cores)=cpu("processor : 0\nmodel name : Test(TM)\nphysical id : 0\ncore id : 0\nprocessor : 1\nphysical id : 0\ncore id : 0\n");
        assert_eq!(model, "Test");
        assert_eq!(cores, "1 Cores, 2 Threads");
    }
}
