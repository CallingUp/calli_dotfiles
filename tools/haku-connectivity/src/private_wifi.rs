use crate::Result;
use dbus::{
    arg::{PropMap, RefArg, Variant},
    blocking::{stdintf::org_freedesktop_dbus::Properties, Connection},
    Path,
};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    io::{self, BufRead, Read},
    sync::atomic::{AtomicBool, Ordering},
    thread,
    time::{Duration, Instant},
};
const NM: &str = "org.freedesktop.NetworkManager";
static CANCELED: AtomicBool = AtomicBool::new(false);
extern "C" fn cancel(_: libc::c_int) {
    CANCELED.store(true, Ordering::Relaxed);
}
fn failure(message: &str) -> Value {
    json!({"success":false,"output":message})
}
fn validate(request: &Value) -> Option<Value> {
    let password = request["password"].as_str().unwrap_or("");
    let security = request["security"].as_str().unwrap_or("").to_uppercase();
    if password.is_empty() || password.contains(['\n', '\r']) {
        Some(failure("Introduce una contraseña válida"))
    } else if security.contains("EAP") || security.contains("802.1X") {
        Some(failure("Esta red requiere configuración empresarial"))
    } else {
        None
    }
}
struct Target {
    device: String,
    ap: String,
    flags: u32,
}
trait Network {
    fn find(&mut self, ssid: &str) -> Result<Option<Target>>;
    fn activate(&mut self, target: &Target, password: &str) -> Result<(String, String)>;
    fn state(&mut self, active: &str) -> Result<u32>;
    fn delete(&mut self, connection: &str);
}
struct Pending<'a, T: Network> {
    network: &'a mut T,
    connection: String,
    success: bool,
}
impl<T: Network> Drop for Pending<'_, T> {
    fn drop(&mut self) {
        if !self.success {
            self.network.delete(&self.connection);
        }
    }
}
fn connect<T: Network>(
    network: &mut T,
    ssid: &str,
    request: &Value,
    limit: Duration,
    canceled: impl Fn() -> bool,
) -> Result<Value> {
    if let Some(result) = validate(request) {
        return Ok(result);
    }
    if canceled() {
        return Ok(failure("Conexión cancelada"));
    }
    let Some(target) = network.find(ssid)? else {
        return Ok(failure("La red ya no está disponible; actualiza la lista"));
    };
    if canceled() {
        return Ok(failure("Conexión cancelada"));
    }
    let (connection, active) = network.activate(
        &target,
        request["password"].as_str().ok_or("missing password")?,
    )?;
    let mut pending = Pending {
        network,
        connection,
        success: false,
    };
    let start = Instant::now();
    while start.elapsed() < limit {
        if canceled() {
            return Ok(failure("Conexión cancelada"));
        }
        match pending.network.state(&active)? {
            2 => {
                pending.success = true;
                return Ok(json!({"success":true,"output":"Conectado"}));
            }
            4 => return Ok(failure("No se pudo conectar; comprueba la contraseña")),
            _ => thread::sleep(Duration::from_millis(250)),
        }
    }
    Ok(failure("Se agotó el tiempo de conexión"))
}
impl Network for Connection {
    fn find(&mut self, ssid: &str) -> Result<Option<Target>> {
        let (devices,): (Vec<Path<'static>>,) = self
            .with_proxy(
                NM,
                "/org/freedesktop/NetworkManager",
                Duration::from_secs(5),
            )
            .method_call(NM, "GetDevices", ())?;
        for device in devices {
            let proxy = self.with_proxy(NM, device.clone(), Duration::from_secs(5));
            if proxy.get::<u32>("org.freedesktop.NetworkManager.Device", "DeviceType")? != 2 {
                continue;
            }
            let (aps,): (Vec<Path<'static>>,) = proxy.method_call(
                "org.freedesktop.NetworkManager.Device.Wireless",
                "GetAccessPoints",
                (),
            )?;
            for ap in aps {
                let info = self
                    .with_proxy(NM, ap.clone(), Duration::from_secs(5))
                    .get_all("org.freedesktop.NetworkManager.AccessPoint")?;
                let bytes: Vec<u8> = info
                    .get("Ssid")
                    .and_then(|v| v.0.as_iter())
                    .map(|i| i.filter_map(|b| b.as_u64().map(|n| n as u8)).collect())
                    .unwrap_or_default();
                if String::from_utf8_lossy(&bytes) == ssid {
                    return Ok(Some(Target {
                        device: device.to_string(),
                        ap: ap.to_string(),
                        flags: info.get("RsnFlags").and_then(|v| v.0.as_u64()).unwrap_or(0) as u32,
                    }));
                }
            }
        }
        Ok(None)
    }
    fn activate(&mut self, target: &Target, password: &str) -> Result<(String, String)> {
        let variant = |s: String| Variant(Box::new(s) as Box<dyn RefArg>);
        let security: PropMap = HashMap::from([
            (
                "key-mgmt".into(),
                variant(
                    if target.flags & 0x400 != 0 {
                        "sae"
                    } else {
                        "wpa-psk"
                    }
                    .into(),
                ),
            ),
            ("psk".into(), variant(password.into())),
        ]);
        let settings: HashMap<String, PropMap> =
            HashMap::from([("802-11-wireless-security".into(), security)]);
        let options: PropMap = HashMap::from([("persist".into(), variant("memory".into()))]);
        let (connection, active, _): (Path<'static>, Path<'static>, PropMap) = self
            .with_proxy(
                NM,
                "/org/freedesktop/NetworkManager",
                Duration::from_secs(30),
            )
            .method_call(
                NM,
                "AddAndActivateConnection2",
                (
                    settings,
                    Path::new(target.device.clone())?,
                    Path::new(target.ap.clone())?,
                    options,
                ),
            )?;
        Ok((connection.to_string(), active.to_string()))
    }
    fn state(&mut self, active: &str) -> Result<u32> {
        Ok(self
            .with_proxy(NM, active, Duration::from_secs(5))
            .get("org.freedesktop.NetworkManager.Connection.Active", "State")?)
    }
    fn delete(&mut self, connection: &str) {
        let _: std::result::Result<(), _> = self
            .with_proxy(NM, connection, Duration::from_secs(5))
            .method_call(
                "org.freedesktop.NetworkManager.Settings.Connection",
                "Delete",
                (),
            );
    }
}
pub fn run(ssid: &str) -> Result<Value> {
    let mut input = String::new();
    io::stdin().lock().take(16385).read_line(&mut input)?;
    if input.len() > 16384 {
        return Ok(failure("Solicitud no válida"));
    }
    let request: Value = serde_json::from_str(&input)?;
    if let Some(result) = validate(&request) {
        return Ok(result);
    }
    unsafe {
        libc::signal(libc::SIGTERM, cancel as *const () as libc::sighandler_t);
        libc::signal(libc::SIGINT, cancel as *const () as libc::sighandler_t);
    }
    let result = Connection::new_system()
        .map_err(|e| Box::new(e) as Box<dyn std::error::Error>)
        .and_then(|mut network| {
            connect(
                &mut network,
                ssid,
                &request,
                Duration::from_secs(25),
                || CANCELED.load(Ordering::Relaxed),
            )
        });
    Ok(result.unwrap_or_else(|_| {
        failure(
            "NetworkManager no pudo completar la conexión; comprueba la contraseña y los permisos",
        )
    }))
}
#[cfg(test)]
mod tests {
    use super::*;
    struct Fake {
        found: bool,
        state: u32,
        error: bool,
        activated: bool,
        deleted: bool,
    }
    impl Network for Fake {
        fn find(&mut self, _: &str) -> Result<Option<Target>> {
            Ok(self.found.then(|| Target {
                device: "/device".into(),
                ap: "/ap".into(),
                flags: 0,
            }))
        }
        fn activate(&mut self, _: &Target, password: &str) -> Result<(String, String)> {
            assert_eq!(password, "test-only");
            self.activated = true;
            Ok(("/connection".into(), "/active".into()))
        }
        fn state(&mut self, _: &str) -> Result<u32> {
            if self.error {
                Err("fake error".into())
            } else {
                Ok(self.state)
            }
        }
        fn delete(&mut self, _: &str) {
            self.deleted = true;
        }
    }
    fn fake(state: u32) -> Fake {
        Fake {
            found: true,
            state,
            error: false,
            activated: false,
            deleted: false,
        }
    }
    fn request() -> Value {
        json!({"password":"test-only","security":"WPA2"})
    }
    #[test]
    fn success_keeps_connection() {
        let mut f = fake(2);
        assert_eq!(
            connect(&mut f, "test", &request(), Duration::from_secs(1), || false).unwrap()
                ["success"],
            true
        );
        assert!(!f.deleted);
    }
    #[test]
    fn failed_state_cleans() {
        let mut f = fake(4);
        assert_eq!(
            connect(&mut f, "test", &request(), Duration::from_secs(1), || false).unwrap()
                ["success"],
            false
        );
        assert!(f.deleted);
    }
    #[test]
    fn timeout_cleans() {
        let mut f = fake(1);
        connect(&mut f, "test", &request(), Duration::ZERO, || false).unwrap();
        assert!(f.deleted);
    }
    #[test]
    fn query_error_cleans() {
        let mut f = fake(1);
        f.error = true;
        assert!(connect(&mut f, "test", &request(), Duration::from_secs(1), || false).is_err());
        assert!(f.deleted);
    }
    #[test]
    fn cancellation_cleans() {
        let mut f = fake(1);
        let calls = std::cell::Cell::new(0);
        connect(&mut f, "test", &request(), Duration::from_secs(1), || {
            let n = calls.get() + 1;
            calls.set(n);
            n >= 3
        })
        .unwrap();
        assert!(f.deleted);
    }
    #[test]
    fn invalid_secret_no_activation() {
        for password in ["", "a\nb", "a\rb"] {
            let mut f = fake(2);
            connect(
                &mut f,
                "test",
                &json!({"password":password}),
                Duration::ZERO,
                || false,
            )
            .unwrap();
            assert!(!f.activated);
        }
    }
    #[test]
    fn enterprise_rejected() {
        let mut f = fake(2);
        connect(
            &mut f,
            "test",
            &json!({"password":"test-only","security":"WPA2 802.1X"}),
            Duration::ZERO,
            || false,
        )
        .unwrap();
        assert!(!f.activated);
    }
    #[test]
    fn missing_ap_no_activation() {
        let mut f = fake(2);
        f.found = false;
        connect(&mut f, "test", &request(), Duration::ZERO, || false).unwrap();
        assert!(!f.activated);
    }
}
