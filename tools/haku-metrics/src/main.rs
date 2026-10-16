//! Demand-driven system metrics for QML. No subprocesses, GPU probes or crates.
use std::{
    env, fs,
    io::{self, Write},
    path::PathBuf,
    thread,
    time::Duration,
};

#[derive(Clone, Copy, Default)]
struct Cpu {
    total: u64,
    idle: u64,
}

fn cpu_ticks(text: &str) -> Option<Cpu> {
    let mut fields = text.lines().next()?.split_whitespace();
    if fields.next()? != "cpu" {
        return None;
    }
    let values: Vec<u64> = fields
        .take(8)
        .map(str::parse)
        .collect::<Result<_, _>>()
        .ok()?;
    if values.len() < 5 {
        return None;
    }
    Some(Cpu {
        total: values.iter().sum(),
        idle: values[3] + values[4],
    })
}

fn cpu() -> Option<Cpu> {
    cpu_ticks(&fs::read_to_string("/proc/stat").ok()?)
}

fn cpu_percent(previous: Cpu, now: Cpu) -> f64 {
    let total = now.total.saturating_sub(previous.total);
    if total == 0 {
        return 0.0;
    }
    let idle = now.idle.saturating_sub(previous.idle);
    (100.0 * total.saturating_sub(idle) as f64 / total as f64).clamp(0.0, 100.0)
}

fn memory(text: &str) -> (f64, f64) {
    let mut total = 0u64;
    let mut available = None;
    for line in text.lines() {
        let mut fields = line.split_whitespace();
        let key = fields.next().unwrap_or("");
        let value = fields
            .next()
            .and_then(|v| v.parse::<u64>().ok())
            .unwrap_or(0);
        match key {
            "MemTotal:" => total = value,
            "MemAvailable:" => available = Some(value),
            _ => {}
        }
    }
    if total == 0 || available.is_none() {
        return (0.0, 0.0);
    }
    let used = total.saturating_sub(available.unwrap_or(total));
    (
        used as f64 / 1_048_576.0,
        100.0 * used as f64 / total as f64,
    )
}

fn temperature_path() -> Option<PathBuf> {
    for entry in fs::read_dir("/sys/class/hwmon").ok()?.flatten() {
        let base = entry.path();
        let name = fs::read_to_string(base.join("name")).unwrap_or_default();
        if !["coretemp", "k10temp", "cpu_thermal", "zenpower", "Tctl"].contains(&name.trim()) {
            continue;
        }
        let mut sensors: Vec<PathBuf> = fs::read_dir(&base)
            .ok()?
            .flatten()
            .map(|e| e.path())
            .filter(|p| {
                p.file_name()
                    .and_then(|n| n.to_str())
                    .is_some_and(|n| n.starts_with("temp") && n.ends_with("_input"))
            })
            .collect();
        sensors.sort();
        // Prefer the package/Tctl sensor over an individual core.
        for sensor in &sensors {
            let label =
                sensor.with_file_name(sensor.file_name()?.to_str()?.replace("_input", "_label"));
            let name = fs::read_to_string(label).unwrap_or_default();
            if name.contains("Package") || name.trim() == "Tctl" {
                return Some(sensor.clone());
            }
        }
        if let Some(sensor) = sensors.into_iter().next() {
            return Some(sensor);
        }
    }
    for entry in fs::read_dir("/sys/class/thermal").ok()?.flatten() {
        let base = entry.path();
        let kind = fs::read_to_string(base.join("type")).unwrap_or_default();
        if ["x86_pkg_temp", "cpu_thermal", "acpitz"].contains(&kind.trim()) {
            return Some(base.join("temp"));
        }
    }
    None
}

fn main() -> io::Result<()> {
    let mut interval = 4000u64;
    let mut once = false;
    for arg in env::args().skip(1) {
        if arg == "--once" {
            once = true;
        } else if let Ok(value) = arg.parse::<u64>() {
            interval = value.clamp(1000, 60_000);
        }
    }
    let mut previous = cpu();
    let mut sensor = temperature_path();
    thread::sleep(Duration::from_millis(200));
    let stdout = io::stdout();
    let mut output = stdout.lock();
    loop {
        let now = cpu();
        let usage = previous
            .zip(now)
            .map(|(a, b)| cpu_percent(a, b))
            .unwrap_or(0.0);
        previous = now;
        let (used, percent) = memory(&fs::read_to_string("/proc/meminfo").unwrap_or_default());
        let temp = sensor
            .as_ref()
            .and_then(|p| fs::read_to_string(p).ok())
            .and_then(|s| s.trim().parse::<i64>().ok())
            .filter(|t| *t > 0 && *t < 150_000);
        if temp.is_none() {
            sensor = temperature_path();
        }
        let temperature = temp
            .map(|t| format!("{}°C", t / 1000))
            .unwrap_or_else(|| "--°C".into());
        let seconds = fs::read_to_string("/proc/uptime")
            .unwrap_or_default()
            .split_whitespace()
            .next()
            .and_then(|s| s.parse::<f64>().ok())
            .unwrap_or(0.0) as u64;
        let uptime = format!(
            "{}d {}h {}m",
            seconds / 86400,
            seconds / 3600 % 24,
            seconds / 60 % 60
        );
        writeln!(output, "{{\"system\":{{\"cpu_usage\":{usage:.1},\"mem_used_gb\":{used:.1},\"mem_usage\":{percent:.1},\"cpu_temp\":\"{temperature}\",\"uptime\":\"{uptime}\"}}}}")?;
        output.flush()?;
        if once {
            return Ok(());
        }
        thread::sleep(Duration::from_millis(interval));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn guest_time_not_double_counted() {
        let ticks = cpu_ticks("cpu 10 0 10 70 10 0 0 0 999 999\n").unwrap();
        assert_eq!(ticks.total, 100);
        assert_eq!(ticks.idle, 80);
    }
    #[test]
    fn usage_and_counter_reset_are_safe() {
        assert_eq!(
            cpu_percent(
                Cpu::default(),
                Cpu {
                    total: 100,
                    idle: 80
                }
            ),
            20.0
        );
        assert_eq!(
            cpu_percent(
                Cpu {
                    total: 200,
                    idle: 150
                },
                Cpu { total: 10, idle: 8 }
            ),
            0.0
        );
    }
    #[test]
    fn memory_uses_available_not_free() {
        let (gb, pct) = memory("MemTotal: 2097152 kB\nMemFree: 1 kB\nMemAvailable: 1048576 kB\n");
        assert_eq!((gb, pct), (1.0, 50.0));
    }
    #[test]
    fn missing_memory_and_cpu_are_safe() {
        assert_eq!(memory(""), (0.0, 0.0));
        assert!(cpu_ticks("cpu nope").is_none());
        assert!(cpu_ticks("cpu0 1 2 3 4 5").is_none());
    }
}
