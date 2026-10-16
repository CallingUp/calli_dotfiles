use crate::{bluetooth, Result};
use dbus::{
    arg::PropMap,
    blocking::Connection,
    channel::MatchingReceiver,
    message::{MatchRule, MessageType},
    Path,
};
use serde_json::{json, Value};
use std::{
    collections::HashMap,
    io::{self, Write},
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    time::{Duration, Instant},
};
static TERMINATE: AtomicBool = AtomicBool::new(false);
extern "C" fn terminate(_: libc::c_int) {
    TERMINATE.store(true, Ordering::Relaxed);
}
type Objects = HashMap<Path<'static>, HashMap<String, PropMap>>;
fn objects(conn: &Connection) -> Result<Objects> {
    let (objects,): (Objects,) = conn
        .with_proxy("org.bluez", "/", Duration::from_secs(5))
        .method_call(
            "org.freedesktop.DBus.ObjectManager",
            "GetManagedObjects",
            (),
        )?;
    Ok(objects)
}
fn snapshot(conn: &Connection) -> Result<Value> {
    let mut result = serde_json::Map::new();
    for (path, interfaces) in objects(conn)? {
        let mut ifaces = serde_json::Map::new();
        for (name, props) in interfaces {
            let mut values = serde_json::Map::new();
            for (key, value) in props {
                let data = if let Some(s) = value.0.as_str() {
                    json!(s)
                } else if let Some(n) = value.0.as_i64() {
                    if ["Powered", "Discovering", "Connected", "Paired"].contains(&key.as_str()) {
                        json!(n != 0)
                    } else {
                        json!(n)
                    }
                } else {
                    Value::Null
                };
                values.insert(key, json!({"data":data}));
            }
            ifaces.insert(name, Value::Object(values));
        }
        result.insert(path.to_string(), Value::Object(ifaces));
    }
    bluetooth(&json!({"data":[result]}))
}
trait Discovery {
    fn start(&mut self) -> Result<()>;
    fn stop(&mut self);
    fn snapshot(&mut self) -> Result<Value>;
    fn wait(&mut self, duration: Duration) -> Result<bool>;
}
struct Guard<'a, T: Discovery>(&'a mut T);
impl<T: Discovery> Drop for Guard<'_, T> {
    fn drop(&mut self) {
        self.0.stop();
    }
}
fn stream<T: Discovery, W: Write>(
    backend: &mut T,
    out: &mut W,
    limit: Duration,
    canceled: impl Fn() -> bool,
) -> Result<()> {
    backend.start()?;
    let guard = Guard(backend);
    let start = Instant::now();
    let mut dirty = true;
    let mut last = Instant::now() - Duration::from_secs(1);
    let mut previous = Value::Null;
    while start.elapsed() < limit && !canceled() {
        if dirty && last.elapsed() >= Duration::from_millis(250) {
            let data = guard.0.snapshot()?;
            let devices = data["devices"].clone();
            if previous != devices {
                writeln!(out, "{}", json!({"event":"devices","devices":devices}))?;
                out.flush()?;
                previous = devices;
            }
            last = Instant::now();
            dirty = false;
        }
        dirty = guard.0.wait(Duration::from_millis(100))? || dirty;
    }
    Ok(())
}
struct Bluez {
    conn: Connection,
    adapter: String,
    dirty: Arc<AtomicBool>,
}
impl Discovery for Bluez {
    fn start(&mut self) -> Result<()> {
        self.conn
            .with_proxy("org.bluez", self.adapter.as_str(), Duration::from_secs(5))
            .method_call::<(), _, _, _>("org.bluez.Adapter1", "StartDiscovery", ())?;
        Ok(())
    }
    fn stop(&mut self) {
        let _: std::result::Result<(), _> = self
            .conn
            .with_proxy("org.bluez", self.adapter.as_str(), Duration::from_secs(3))
            .method_call("org.bluez.Adapter1", "StopDiscovery", ());
    }
    fn snapshot(&mut self) -> Result<Value> {
        snapshot(&self.conn)
    }
    fn wait(&mut self, duration: Duration) -> Result<bool> {
        self.conn.process(duration)?;
        Ok(self.dirty.swap(false, Ordering::Relaxed))
    }
}
pub fn run() -> Result<()> {
    let conn = Connection::new_system()?;
    let adapter = objects(&conn)?
        .into_iter()
        .find(|(_, i)| i.contains_key("org.bluez.Adapter1"))
        .map(|(p, _)| p.to_string())
        .ok_or("no adapter")?;
    let dirty = Arc::new(AtomicBool::new(true));
    let mut rule = MatchRule::new();
    rule.msg_type = Some(MessageType::Signal);
    rule.sender = Some("org.bluez".into());
    conn.add_match_no_cb(&rule.match_str())?;
    let changed = dirty.clone();
    conn.start_receive(
        rule,
        Box::new(move |_, _| {
            changed.store(true, Ordering::Relaxed);
            true
        }),
    );
    unsafe {
        libc::signal(libc::SIGTERM, terminate as *const () as libc::sighandler_t);
        libc::signal(libc::SIGINT, terminate as *const () as libc::sighandler_t);
    }
    stream(
        &mut Bluez {
            conn,
            adapter,
            dirty,
        },
        &mut io::stdout().lock(),
        Duration::from_secs(120),
        || TERMINATE.load(Ordering::Relaxed),
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    struct Fake {
        started: bool,
        stopped: bool,
        fail: bool,
    }
    impl Discovery for Fake {
        fn start(&mut self) -> Result<()> {
            self.started = true;
            Ok(())
        }
        fn stop(&mut self) {
            self.stopped = true;
        }
        fn snapshot(&mut self) -> Result<Value> {
            if self.fail {
                Err("failed".into())
            } else {
                Ok(json!({"devices":[]}))
            }
        }
        fn wait(&mut self, _: Duration) -> Result<bool> {
            std::thread::sleep(Duration::from_millis(1));
            Ok(false)
        }
    }
    #[test]
    fn timeout_cleans() {
        let mut f = Fake {
            started: false,
            stopped: false,
            fail: false,
        };
        let mut out = vec![];
        stream(&mut f, &mut out, Duration::from_millis(5), || false).unwrap();
        assert!(f.started && f.stopped);
        assert_eq!(String::from_utf8(out).unwrap().lines().count(), 1);
    }
    #[test]
    fn cancel_cleans() {
        let mut f = Fake {
            started: false,
            stopped: false,
            fail: false,
        };
        stream(&mut f, &mut vec![], Duration::from_secs(1), || true).unwrap();
        assert!(f.stopped);
    }
    #[test]
    fn snapshot_failure_cleans() {
        let mut f = Fake {
            started: false,
            stopped: false,
            fail: true,
        };
        assert!(stream(&mut f, &mut vec![], Duration::from_secs(1), || false).is_err());
        assert!(f.stopped);
    }
    #[test]
    fn broken_output_cleans() {
        struct Broken;
        impl Write for Broken {
            fn write(&mut self, _: &[u8]) -> io::Result<usize> {
                Err(io::ErrorKind::BrokenPipe.into())
            }
            fn flush(&mut self) -> io::Result<()> {
                Ok(())
            }
        }
        let mut f = Fake {
            started: false,
            stopped: false,
            fail: false,
        };
        assert!(stream(&mut f, &mut Broken, Duration::from_secs(1), || false).is_err());
        assert!(f.stopped);
    }
}
