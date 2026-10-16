use crate::{valid_mac, Result};
use dbus::{
    arg::PropMap, blocking::Connection, channel::Sender, message::MessageType, Message, Path,
};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    ffi::CString,
    io::{self, Read, Write},
    sync::atomic::{AtomicBool, Ordering},
    time::{Duration, Instant},
};
const AGENT: &str = "org.bluez.Agent1";
const PATH: &str = "/org/haku/PairAgent";
static CANCELED: AtomicBool = AtomicBool::new(false);
extern "C" fn cancel(_: libc::c_int) {
    CANCELED.store(true, Ordering::Relaxed);
}
fn emit(data: Value) -> Result<()> {
    let mut out = io::stdout().lock();
    writeln!(out, "{data}")?;
    out.flush()?;
    Ok(())
}
fn send(conn: &Connection, message: Message) -> Result<u32> {
    conn.send(message).map_err(|_| "D-Bus send failed".into())
}
fn reject(conn: &Connection, message: &Message) {
    let _ = conn.send(message.error(
        &"org.bluez.Error.Rejected".into(),
        &CString::new("Canceled or unexpected pairing request").unwrap(),
    ));
}
enum Answer {
    Reject,
    Pin(String),
    Passkey(u32),
    Accept,
    Invalid(&'static str),
}
fn answer(kind: &str, data: &Value) -> Answer {
    if data["accept"] != true {
        return Answer::Reject;
    }
    let value = data["value"].as_str().unwrap_or("");
    match kind {
        "pin" if !(1..=16).contains(&value.chars().count()) || value.contains('\0') => {
            Answer::Invalid("El PIN debe tener entre 1 y 16 caracteres")
        }
        "pin" => Answer::Pin(value.into()),
        "passkey"
            if value.is_empty()
                || value.len() > 6
                || !value.bytes().all(|b| b.is_ascii_digit()) =>
        {
            Answer::Invalid("Introduce entre 1 y 6 dígitos")
        }
        "passkey" => Answer::Passkey(value.parse().unwrap()),
        _ => Answer::Accept,
    }
}
struct Pending {
    message: Message,
    kind: String,
}
fn respond(conn: &Connection, pending: &mut Option<Pending>, data: &Value) -> Result<()> {
    let Some(request) = pending.as_ref() else {
        return Ok(());
    };
    let result = answer(&request.kind, data);
    if let Answer::Invalid(message) = result {
        return emit(json!({"event":"validation","output":message}));
    }
    let request = pending.take().unwrap();
    match result {
        Answer::Reject => reject(conn, &request.message),
        Answer::Pin(value) => {
            send(conn, request.message.method_return().append1(value))?;
        }
        Answer::Passkey(value) => {
            send(conn, request.message.method_return().append1(value))?;
        }
        Answer::Accept => {
            send(conn, request.message.method_return())?;
        }
        Answer::Invalid(_) => unreachable!(),
    }
    emit(json!({"event":"waiting"}))
}
fn agent_call(
    conn: &Connection,
    message: Message,
    device: &str,
    pending: &mut Option<Pending>,
) -> Result<()> {
    let member = message.member().map(|m| m.to_string()).unwrap_or_default();
    if member == "Cancel" || member == "Release" {
        if let Some(request) = pending.take() {
            reject(conn, &request.message);
        }
        send(conn, message.method_return())?;
        return emit(json!({"event":"waiting"}));
    }
    let (target, kind, code, entered): (Path<'static>, &str, String, Option<u16>) =
        match member.as_str() {
            "RequestPinCode" => (message.read1()?, "pin", String::new(), None),
            "RequestPasskey" => (message.read1()?, "passkey", String::new(), None),
            "RequestConfirmation" => {
                let (device, key): (Path<'static>, u32) = message.read2()?;
                (device, "confirm", format!("{key:06}"), None)
            }
            "RequestAuthorization" => (message.read1()?, "authorize", String::new(), None),
            "AuthorizeService" => {
                let (device, _): (Path<'static>, String) = message.read2()?;
                (device, "authorize", String::new(), None)
            }
            "DisplayPinCode" => {
                let (device, code): (Path<'static>, String) = message.read2()?;
                (device, "display", code, None)
            }
            "DisplayPasskey" => {
                let (device, key, entered): (Path<'static>, u32, u16) = message.read3()?;
                (device, "display", format!("{key:06}"), Some(entered))
            }
            _ => {
                reject(conn, &message);
                return Ok(());
            }
        };
    if target.to_string() != device || (kind != "display" && pending.is_some()) {
        reject(conn, &message);
        return Ok(());
    }
    let mut event = json!({"event":"prompt","kind":kind,"code":code});
    if let Some(entered) = entered {
        event["entered"] = entered.into();
    }
    if kind == "display" {
        send(conn, message.method_return())?;
    } else {
        *pending = Some(Pending {
            message,
            kind: kind.into(),
        });
    }
    emit(event)
}
struct Registration<'a> {
    conn: &'a Connection,
    device: String,
    cancel_pair: bool,
}
impl Drop for Registration<'_> {
    fn drop(&mut self) {
        if self.cancel_pair {
            let _: std::result::Result<(), _> = self
                .conn
                .with_proxy("org.bluez", self.device.as_str(), Duration::from_secs(3))
                .method_call("org.bluez.Device1", "CancelPairing", ());
        }
        let _: std::result::Result<(), _> = self
            .conn
            .with_proxy("org.bluez", "/org/bluez", Duration::from_secs(3))
            .method_call(
                "org.bluez.AgentManager1",
                "UnregisterAgent",
                (Path::new(PATH).unwrap(),),
            );
    }
}
fn asynchronous(conn: &Connection, device: &str, method: &str) -> Result<u32> {
    send(
        conn,
        Message::new_method_call("org.bluez", device, "org.bluez.Device1", method)?,
    )
}
fn session(mac: &str) -> Result<()> {
    if !valid_mac(mac) {
        return Err("invalid address".into());
    }
    let conn = Connection::new_system()?;
    let (owner,): (String,) = conn
        .with_proxy(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            Duration::from_secs(5),
        )
        .method_call("org.freedesktop.DBus", "GetNameOwner", ("org.bluez",))?;
    type Objects = HashMap<Path<'static>, HashMap<String, PropMap>>;
    let (objects,): (Objects,) = conn
        .with_proxy("org.bluez", "/", Duration::from_secs(5))
        .method_call(
            "org.freedesktop.DBus.ObjectManager",
            "GetManagedObjects",
            (),
        )?;
    let device = objects
        .into_iter()
        .find(|(_, i)| {
            i.get("org.bluez.Device1")
                .and_then(|d| d.get("Address"))
                .and_then(|v| v.0.as_str())
                .is_some_and(|a| a.eq_ignore_ascii_case(mac))
        })
        .map(|(p, _)| p.to_string());
    let Some(device) = device else {
        return emit(
            json!({"event":"result","success":false,"output":"Dispositivo no disponible; actualiza la lista"}),
        );
    };
    let _: () = conn
        .with_proxy("org.bluez", "/org/bluez", Duration::from_secs(5))
        .method_call(
            "org.bluez.AgentManager1",
            "RegisterAgent",
            (Path::new(PATH)?, "KeyboardDisplay"),
        )?;
    let mut registration = Registration {
        conn: &conn,
        device: device.clone(),
        cancel_pair: true,
    };
    // Application-scoped agent: never RequestDefaultAgent.
    let mut serial = asynchronous(&conn, &device, "Pair")?;
    let mut connecting = false;
    let start = Instant::now();
    let mut deadline = start + Duration::from_secs(65);
    let mut pending = None;
    let mut buffer = Vec::new();
    let flags = unsafe { libc::fcntl(libc::STDIN_FILENO, libc::F_GETFL) };
    if flags < 0
        || unsafe { libc::fcntl(libc::STDIN_FILENO, libc::F_SETFL, flags | libc::O_NONBLOCK) } < 0
    {
        return Err("stdin unavailable".into());
    }
    emit(json!({"event":"waiting"}))?;
    let result = (|| -> Result<bool> {
        loop {
            if CANCELED.load(Ordering::Relaxed)
                || Instant::now() >= deadline
                || start.elapsed() >= Duration::from_secs(75)
            {
                return Ok(false);
            }
            let mut chunk = [0; 4096];
            match io::stdin().read(&mut chunk) {
                Ok(0) => return Ok(false),
                Ok(n) => {
                    buffer.extend_from_slice(&chunk[..n]);
                    if buffer.len() > 16384 {
                        buffer.clear();
                        emit(json!({"event":"validation","output":"Respuesta no válida"}))?;
                    }
                    while let Some(end) = buffer.iter().position(|b| *b == b'\n') {
                        let line: Vec<u8> = buffer.drain(..=end).collect();
                        match serde_json::from_slice::<Value>(&line) {
                            Ok(data) => {
                                if data["cancel"] == true {
                                    return Ok(false);
                                }
                                respond(&conn, &mut pending, &data)?;
                            }
                            Err(_) => {
                                emit(json!({"event":"validation","output":"Respuesta no válida"}))?
                            }
                        }
                    }
                }
                Err(e) if e.kind() == io::ErrorKind::WouldBlock => {}
                Err(_) => return Ok(false),
            }
            if let Some(message) = conn
                .channel()
                .blocking_pop_message(Duration::from_millis(100))?
            {
                if message.get_reply_serial() == Some(serial) {
                    if message.msg_type() == MessageType::Error {
                        return Ok(false);
                    }
                    if message.msg_type() == MessageType::MethodReturn {
                        registration.cancel_pair = false;
                        if connecting {
                            return Ok(true);
                        }
                        connecting = true;
                        serial = asynchronous(&conn, &device, "Connect")?;
                        deadline = Instant::now() + Duration::from_secs(20);
                        emit(json!({"event":"waiting"}))?;
                    }
                } else if message.msg_type() == MessageType::MethodCall
                    && message.path().map(|p| p.to_string()).as_deref() == Some(PATH)
                {
                    if message.sender().map(|s| s.to_string()).as_deref() != Some(owner.as_str()) {
                        reject(&conn, &message);
                        continue;
                    }
                    if message.interface().map(|i| i.to_string()).as_deref() == Some(AGENT) {
                        agent_call(&conn, message, &device, &mut pending)?;
                    } else {
                        reject(&conn, &message);
                    }
                }
            }
        }
    })();
    if let Some(request) = pending.take() {
        reject(&conn, &request.message);
    }
    let success = result.unwrap_or(false);
    emit(
        json!({"event":"result","success":success,"output":if success{"Conectado"}else if connecting{"Emparejado, pero no se pudo conectar"}else{"Emparejamiento cancelado o fallido; verifica el dispositivo y vuelve a intentar"}}),
    )
}
pub fn run(mac: &str) -> Result<()> {
    unsafe {
        libc::signal(libc::SIGTERM, cancel as *const () as libc::sighandler_t);
        libc::signal(libc::SIGINT, cancel as *const () as libc::sighandler_t);
    }
    if session(mac).is_err() {
        emit(
            json!({"event":"result","success":false,"output":"Bluetooth no está disponible o no permite emparejar"}),
        )?;
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn pin_bounds() {
        for value in ["", "abcdefghijklmnopq"] {
            assert!(matches!(
                answer("pin", &json!({"accept":true,"value":value})),
                Answer::Invalid(_)
            ));
        }
        assert!(matches!(
            answer("pin", &json!({"accept":true,"value":"1234"})),
            Answer::Pin(_)
        ));
    }
    #[test]
    fn passkey_strict() {
        for value in ["", "1234567", "１２３", "abc"] {
            assert!(matches!(
                answer("passkey", &json!({"accept":true,"value":value})),
                Answer::Invalid(_)
            ));
        }
        assert!(matches!(
            answer("passkey", &json!({"accept":true,"value":"000123"})),
            Answer::Passkey(123)
        ));
    }
    #[test]
    fn confirmation_explicit() {
        assert!(matches!(answer("confirm", &json!({})), Answer::Reject));
        assert!(matches!(
            answer("confirm", &json!({"accept":false})),
            Answer::Reject
        ));
        assert!(matches!(
            answer("confirm", &json!({"accept":true})),
            Answer::Accept
        ));
    }
    #[test]
    fn authorization_explicit() {
        assert!(matches!(
            answer("authorize", &json!({"accept":true})),
            Answer::Accept
        ));
        assert!(matches!(
            answer("authorize", &json!({"value":"yes"})),
            Answer::Reject
        ));
    }
}
