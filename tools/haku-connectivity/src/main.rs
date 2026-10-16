use serde_json::{json, Value};
mod pair;
mod private_wifi;
mod scan;
use std::{
    collections::{HashMap, HashSet},
    env,
    os::unix::process::CommandExt,
    process::{Command, Stdio},
};
type Result<T> = std::result::Result<T, Box<dyn std::error::Error>>;
fn command(program: &str, args: &[&str]) -> Result<String> {
    let result = Command::new("timeout")
        .arg("12s")
        .arg(program)
        .args(args)
        .stderr(Stdio::null())
        .output()?;
    if !result.status.success() {
        return Err("command failed".into());
    }
    Ok(String::from_utf8(result.stdout)?)
}
fn fields(line: &str) -> Vec<String> {
    let mut result = vec![String::new()];
    let mut escaped = false;
    for c in line.chars() {
        if escaped {
            result.last_mut().unwrap().push(c);
            escaped = false;
        } else if c == '\\' {
            escaped = true;
        } else if c == ':' {
            result.push(String::new());
        } else {
            result.last_mut().unwrap().push(c);
        }
    }
    if escaped {
        result.last_mut().unwrap().push('\\');
    }
    result
}
fn wifi_status() -> Result<Value> {
    let radio = command("nmcli", &["radio", "wifi"])?;
    let devices = command("nmcli", &["-t", "-f", "TYPE,STATE,CONNECTION", "device"])?;
    let mut connected = "Disconnected".to_string();
    for line in devices.lines() {
        let f = fields(line);
        if f.first().map(String::as_str) == Some("wifi") {
            if f.get(1).map(String::as_str) == Some("connected") {
                connected = f.get(2).cloned().unwrap_or(connected);
            }
            break;
        }
    }
    Ok(json!({"radio":radio.trim()=="enabled","connected_ssid":connected}))
}
fn networks(text: &str, saved: &HashSet<String>) -> Vec<Value> {
    let mut rows: Vec<Value> = vec![];
    let mut seen = HashMap::new();
    for line in text.lines() {
        let f = fields(line);
        if f.len() < 4 || f[0].trim().is_empty() {
            continue;
        }
        let ssid = f[0].trim();
        let signal = f[1].parse::<i64>().unwrap_or(0);
        let active = f[2].trim() == "*";
        let known = active || saved.contains(ssid);
        if let Some(&index) = seen.get(ssid) {
            let row: &mut Value = &mut rows[index];
            row["signal"] = signal.max(row["signal"].as_i64().unwrap_or(0)).into();
            row["active"] = (active || row["active"] == true).into();
            row["saved"] = (known || row["saved"] == true).into();
        } else {
            seen.insert(ssid.to_string(), rows.len());
            rows.push(json!({"ssid":ssid,"signal":signal,"active":active,"saved":known,"security":f[3].trim()}));
        }
    }
    rows.sort_by_key(|r| {
        (
            !(r["active"] == true),
            !(r["saved"] == true),
            -r["signal"].as_i64().unwrap_or(0),
            r["ssid"].as_str().unwrap_or("").to_lowercase(),
        )
    });
    rows
}
fn saved_wifi() -> Result<HashSet<String>> {
    let connections = command(
        "nmcli",
        &["-t", "-f", "NAME,TYPE,TIMESTAMP", "connection", "show"],
    )?;
    Ok(connections
        .lines()
        .map(fields)
        .filter(|f| {
            f.len() >= 3
                && ["wifi", "802-11-wireless"].contains(&f[1].as_str())
                && f[2].parse::<u64>().unwrap_or(0) > 0
        })
        .map(|f| f[0].trim().to_string())
        .collect())
}
fn wifi_scan(rescan: &str) -> Result<Value> {
    let saved = saved_wifi()?;
    let text = command(
        "nmcli",
        &[
            "-t",
            "-f",
            "SSID,SIGNAL,IN-USE,SECURITY",
            "device",
            "wifi",
            "list",
            "--rescan",
            rescan,
        ],
    )?;
    Ok(json!(networks(&text, &saved)))
}
fn bt_status() -> Result<Value> {
    let text = command(
        "busctl",
        &[
            "--system",
            "--timeout=5",
            "--json=short",
            "call",
            "org.bluez",
            "/",
            "org.freedesktop.DBus.ObjectManager",
            "GetManagedObjects",
        ],
    )?;
    bluetooth(&serde_json::from_str(&text)?)
}
fn bluetooth(payload: &Value) -> Result<Value> {
    let objects = payload["data"][0].as_object().ok_or("invalid objects")?;
    let mut powered = false;
    let mut discovering = false;
    let mut devices = vec![];
    let mut found = false;
    for (path, interfaces) in objects {
        if !found && interfaces["org.bluez.Adapter1"].is_object() {
            let a = &interfaces["org.bluez.Adapter1"];
            powered = a["Powered"]["data"] == true;
            discovering = a["Discovering"]["data"] == true;
            found = true;
        }
        if interfaces["org.bluez.Device1"].is_object() {
            let d = &interfaces["org.bluez.Device1"];
            let mac = d["Address"]["data"].as_str().unwrap_or("");
            let name = d["Alias"]["data"]
                .as_str()
                .filter(|s| !s.is_empty())
                .or(d["Name"]["data"].as_str())
                .unwrap_or(mac);
            devices.push(json!({"mac":mac,"name":name,"connected":d["Connected"]["data"]==true,"paired":d["Paired"]["data"]==true,"icon":d["Icon"]["data"].as_str().unwrap_or(""),"path":path}));
        }
    }
    devices.sort_by_key(|d| {
        (
            !(d["connected"] == true),
            !(d["paired"] == true),
            d["name"].as_str().unwrap_or("").to_lowercase(),
        )
    });
    let connected = devices
        .iter()
        .find(|d| d["connected"] == true)
        .map(|d| d["name"].clone())
        .unwrap_or(json!(""));
    Ok(
        json!({"powered":powered,"discovering":discovering,"connected_device":connected,"devices":devices}),
    )
}
fn valid_mac(mac: &str) -> bool {
    mac.len() == 17
        && mac.split(':').count() == 6
        && mac
            .split(':')
            .all(|part| part.len() == 2 && part.bytes().all(|b| b.is_ascii_hexdigit()))
}
fn bt_action(args: &[&str]) -> Result<Value> {
    let output = Command::new("timeout")
        .arg("25s")
        .arg("bluetoothctl")
        .args(args)
        .output()?;
    let timed_out = output.status.code() == Some(124);
    let success = output.status.success();
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let message = if timed_out {
        "Se agotó el tiempo de conexión"
    } else if !stdout.trim().is_empty() {
        stdout.trim()
    } else {
        stderr.trim()
    };
    Ok(json!({"success":success,"output":message}))
}
fn bt_power() -> Result<Value> {
    let status = bt_status()?;
    bt_action(&[
        "power",
        if status["powered"] == true {
            "off"
        } else {
            "on"
        },
    ])
}
fn bt_connect(mac: &str) -> Result<Value> {
    if !valid_mac(mac) {
        return Err("invalid address".into());
    }
    let status = bt_status()?;
    let connected = status["devices"]
        .as_array()
        .ok_or("invalid devices")?
        .iter()
        .any(|d| {
            d["mac"]
                .as_str()
                .is_some_and(|address| address.eq_ignore_ascii_case(mac))
                && d["connected"] == true
        });
    bt_action(&[
        "--timeout",
        "20",
        if connected { "disconnect" } else { "connect" },
        mac,
    ])
}
fn wifi_action(args: &[&str]) -> Result<Value> {
    let output = Command::new("timeout")
        .arg("30s")
        .arg("nmcli")
        .args(args)
        .output()?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let message = if output.status.code() == Some(124) {
        "Se agotó el tiempo de conexión"
    } else if !stdout.trim().is_empty() {
        stdout.trim()
    } else {
        stderr.trim()
    };
    Ok(json!({"success":output.status.success(),"output":message}))
}
fn wifi_radio() -> Result<Value> {
    let enabled = command("nmcli", &["radio", "wifi"])?.trim() == "enabled";
    let mut result = wifi_action(&["radio", "wifi", if enabled { "off" } else { "on" }])?;
    if result["success"] == true {
        result["radio"] = (!enabled).into();
    }
    Ok(result)
}
fn wifi_connect(ssid: &str) -> Result<Value> {
    if ssid.is_empty() {
        return Err("missing network".into());
    }
    if saved_wifi()?.contains(ssid) {
        wifi_action(&["--wait", "25", "connection", "up", "id", ssid])
    } else {
        wifi_action(&["--wait", "25", "device", "wifi", "connect", ssid])
    }
}
fn wifi_disconnect(ssid: Option<&str>) -> Result<Value> {
    let text = command("nmcli", &["-t", "-f", "DEVICE,TYPE", "device"])?;
    let device = text
        .lines()
        .map(fields)
        .find(|f| f.len() >= 2 && f[1] == "wifi")
        .map(|f| f[0].clone());
    if let Some(device) = device {
        wifi_action(&["device", "disconnect", &device])
    } else if let Some(ssid) = ssid.filter(|s| !s.is_empty()) {
        wifi_action(&["connection", "down", "id", ssid])
    } else {
        Err("missing device".into())
    }
}
fn run() -> Result<Value> {
    let args: Vec<String> = env::args().skip(1).collect();
    let family = args.first().map(String::as_str).unwrap_or("");
    let action = args.get(1).map(String::as_str).unwrap_or("status");
    match (family, action) {
        ("wifi", "status") => wifi_status(),
        ("wifi", "connect-private") => private_wifi::run(args.get(2).ok_or("missing network")?),
        ("wifi", "toggle-radio") => wifi_radio(),
        ("wifi", "connect") if args.len() == 3 => wifi_connect(&args[2]),
        ("wifi", "disconnect") => wifi_disconnect(args.get(2).map(String::as_str)),
        ("wifi", "forget") => {
            let ssid = args
                .get(2)
                .filter(|s| !s.is_empty())
                .ok_or("missing network")?;
            wifi_action(&["connection", "delete", "id", ssid])
        }
        ("wifi", "scan") => wifi_scan(if args.get(2).map(String::as_str) == Some("no") {
            "no"
        } else {
            "yes"
        }),
        ("bluetooth", "status") => bt_status(),
        ("bluetooth", "toggle-power") => bt_power(),
        ("bluetooth", "toggle-connect") => bt_connect(args.get(2).ok_or("missing address")?),
        ("wifi" | "bluetooth", _) => {
            let script=format!("{}/haku_shell/config/quickshell/minflair-niri/Modules/ControlCenter/scripts/{family}.py",env::var("HOME")?);
            Err(Command::new("python3")
                .arg(script)
                .args(&args[1..])
                .exec()
                .into())
        }
        _ => Err("invalid action".into()),
    }
}
fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.len() == 3 && args[0] == "bluetooth" && args[1] == "pair" {
        if pair::run(&args[2]).is_err() {
            std::process::exit(1);
        }
        return;
    }
    if env::args().skip(1).collect::<Vec<_>>() == ["bluetooth", "scan"] {
        if scan::run().is_err() {
            std::process::exit(1);
        }
        return;
    }
    match run() {
        Ok(v) => println!("{v}"),
        Err(_) => {
            println!(
                "{}",
                json!({"success":false,"output":"No se pudo consultar la conexión"})
            );
            std::process::exit(1);
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn strict_mac() {
        assert!(valid_mac("AA:bb:CC:00:12:ef"));
        for value in ["", "--help", "AA:BB:CC:DD:EE:FF;echo", "AA:BB:CC:DD:EE:GG"] {
            assert!(!valid_mac(value));
        }
    }
    #[test]
    fn escaped_fields() {
        assert_eq!(
            fields(r"cat\:net:60:*:WPA2"),
            vec!["cat:net", "60", "*", "WPA2"]
        );
        assert_eq!(fields(r"a\\b:1"), vec!["a\\b", "1"]);
    }
    #[test]
    fn merge_sort() {
        let saved = HashSet::from(["Saved".into()]);
        let r = networks(
            "Other:99::WPA2\nSaved:20::WPA2\nActive:10:*:WPA2\nActive:70::WPA2",
            &saved,
        );
        assert_eq!(r.len(), 3);
        assert_eq!(r[0]["ssid"], "Active");
        assert_eq!(r[0]["signal"], 70);
        assert_eq!(r[1]["ssid"], "Saved");
    }
    #[test]
    fn bluez_empty() {
        assert_eq!(
            bluetooth(&json!({"data":[{}]})).unwrap()["devices"],
            json!([])
        );
    }
}
