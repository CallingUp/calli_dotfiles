#!/usr/bin/env python3
import sys

sys.dont_write_bytecode = True

import json
import subprocess
import time


def connect_private(ssid):
    request = json.loads(sys.stdin.readline())
    password = request.get("password", "")
    security = request.get("security", "")
    if not password or "\n" in password or "\r" in password:
        return {"success": False, "output": "Introduce una contraseña válida"}
    if "EAP" in security or "802.1X" in security:
        return {"success": False, "output": "Esta red requiere configuración empresarial"}
    import dbus
    bus = dbus.SystemBus()
    nm_name = "org.freedesktop.NetworkManager"
    manager = dbus.Interface(bus.get_object(nm_name, "/org/freedesktop/NetworkManager"), nm_name)
    device_path = None
    ap_path = None
    rsn_flags = 0
    for path in manager.GetDevices():
        obj = bus.get_object(nm_name, path)
        props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
        if int(props.Get(nm_name + ".Device", "DeviceType")) != 2:
            continue
        wireless = dbus.Interface(obj, nm_name + ".Device.Wireless")
        for candidate in wireless.GetAccessPoints():
            ap = dbus.Interface(bus.get_object(nm_name, candidate), "org.freedesktop.DBus.Properties")
            info = ap.GetAll(nm_name + ".AccessPoint")
            if bytes(info["Ssid"]).decode("utf-8", errors="replace") == ssid:
                device_path, ap_path = path, candidate
                rsn_flags = int(info["RsnFlags"])
                break
        if ap_path:
            break
    if not ap_path:
        return {"success": False, "output": "La red ya no está disponible; actualiza la lista"}
    # Same minimal settings and memory persistence used by Noctalia.
    settings = dbus.Dictionary({
        "802-11-wireless-security": dbus.Dictionary({
            "key-mgmt": "sae" if rsn_flags & 0x400 else "wpa-psk",
            "psk": password,
        }, signature="sv"),
    }, signature="sa{sv}")
    connection_path = None
    success = False
    try:
        connection_path, active_path, _ = manager.AddAndActivateConnection2(
            settings, device_path, ap_path,
            dbus.Dictionary({"persist": "memory"}, signature="sv"), timeout=30,
        )
        active = dbus.Interface(bus.get_object(nm_name, active_path), "org.freedesktop.DBus.Properties")
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline:
            state = int(active.Get(nm_name + ".Connection.Active", "State"))
            if state == 2:
                success = True
                return {"success": True, "output": "Conectado"}
            if state == 4:
                return {"success": False, "output": "No se pudo conectar; comprueba la contraseña"}
            time.sleep(0.25)
        return {"success": False, "output": "Se agotó el tiempo de conexión"}
    except dbus.DBusException:
        return {"success": False, "output": "NetworkManager no pudo completar la conexión; comprueba la contraseña y los permisos"}
    finally:
        if connection_path and not success:
            try:
                dbus.Interface(bus.get_object(nm_name, connection_path), nm_name + ".Settings.Connection").Delete(timeout=5)
            except dbus.DBusException:
                pass


def get_wifi_device():
    try:
        res = subprocess.run(
            ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        for line in res.stdout.strip().splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[1] == "wifi":
                return parts[0]
    except Exception:
        pass
    return None


def get_saved_connections():
    saved = set()
    try:
        res = subprocess.run(
            ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "connection", "show"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        for line in res.stdout.strip().splitlines():
            if ":" in line:
                parts = line.split(":")
                if len(parts) >= 2:
                    name = parts[0]
                    conn_type = parts[1]
                    timestamp = 0
                    if len(parts) >= 3:
                        try:
                            timestamp = int(parts[2])
                        except ValueError:
                            timestamp = 0
                    if conn_type in ("802-11-wireless", "wifi") and timestamp > 0:
                        saved.add(name.strip())
    except Exception:
        pass
    return saved


def get_status():
    radio = False
    connected_ssid = "Disconnected"
    try:
        res = subprocess.run(
            ["nmcli", "radio", "wifi"], capture_output=True, text=True, timeout=5
        )
        radio = res.stdout.strip() == "enabled"
    except Exception:
        pass

    try:
        res = subprocess.run(
            ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        for line in res.stdout.strip().splitlines():
            if line.startswith("wifi:"):
                parts = line.split(":")
                if len(parts) >= 3 and parts[1] == "connected":
                    connected_ssid = parts[2]
                break
    except Exception:
        pass

    return {"radio": radio, "connected_ssid": connected_ssid}


def scan_networks(rescan=True):
    saved = get_saved_connections()
    networks = []
    seen = {}

    cmd = [
        "nmcli",
        "-t",
        "-f",
        "SSID,SIGNAL,IN-USE,SECURITY",
        "device",
        "wifi",
        "list",
    ]
    if rescan:
        cmd.extend(["--rescan", "yes"])
    else:
        cmd.extend(["--rescan", "no"])

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        for raw_line in res.stdout.strip().splitlines():
            if not raw_line:
                continue
            line = raw_line.replace(r"\:", "__COLON__")
            parts = line.split(":")
            if len(parts) < 4:
                continue
            ssid = parts[0].replace("__COLON__", ":").strip()
            if not ssid:
                continue
            try:
                signal = int(parts[1])
            except ValueError:
                signal = 0
            in_use = parts[2].strip() == "*"
            security = parts[3].replace("__COLON__", ":").strip()

            is_saved = in_use or (ssid in saved)

            if ssid in seen:
                idx = seen[ssid]
                if in_use or signal > networks[idx]["signal"]:
                    networks[idx]["signal"] = max(networks[idx]["signal"], signal)
                    networks[idx]["active"] = networks[idx]["active"] or in_use
                    networks[idx]["saved"] = networks[idx]["saved"] or is_saved
            else:
                seen[ssid] = len(networks)
                networks.append(
                    {
                        "ssid": ssid,
                        "signal": signal,
                        "active": in_use,
                        "saved": is_saved,
                        "security": security,
                    }
                )
    except Exception:
        pass

    networks.sort(
        key=lambda x: (not x["active"], not x["saved"], -x["signal"], x["ssid"].lower())
    )
    return networks


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "scan"

    if action == "connect-private" and len(sys.argv) > 2:
        print(json.dumps(connect_private(sys.argv[2])))
    elif action == "status":
        print(json.dumps(get_status()))
    elif action == "scan":
        rescan = sys.argv[2] != "no" if len(sys.argv) > 2 else True
        print(json.dumps(scan_networks(rescan)))
    elif action == "toggle-radio":
        st = get_status()
        new_state = "off" if st["radio"] else "on"
        subprocess.run(["nmcli", "radio", "wifi", new_state])
        print(json.dumps({"radio": new_state == "on"}))
    elif action == "connect" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        password = sys.argv[3] if len(sys.argv) > 3 else None
        saved = get_saved_connections()

        if ssid in saved and not password:
            res = subprocess.run(
                ["nmcli", "--wait", "25", "connection", "up", "id", ssid],
                capture_output=True,
                text=True,
                timeout=30,
            )
        else:
            cmd = ["nmcli", "--wait", "25", "device", "wifi", "connect", ssid]
            if password:
                cmd.extend(["password", password])
            res = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30,
            )

        print(
            json.dumps(
                {
                    "success": res.returncode == 0,
                    "output": res.stdout.strip() or res.stderr.strip(),
                }
            )
        )
    elif action == "disconnect":
        dev = get_wifi_device()
        if dev:
            subprocess.run(["nmcli", "device", "disconnect", dev])
        elif len(sys.argv) > 2:
            ssid = sys.argv[2]
            subprocess.run(["nmcli", "connection", "down", "id", ssid])
        print(json.dumps({"success": True}))
    elif action == "forget" and len(sys.argv) > 2:
        ssid = sys.argv[2]
        subprocess.run(["nmcli", "connection", "delete", "id", ssid])
        print(json.dumps({"success": True}))
    else:
        print(json.dumps(scan_networks(True)))


if __name__ == "__main__":
    try:
        main()
    except subprocess.TimeoutExpired:
        print(json.dumps({"success": False, "output": "Se agotó el tiempo de conexión"}))
