#!/usr/bin/env python3
"""One user-initiated pairing; JSON prompts over stdout, replies over stdin."""
import sys
sys.dont_write_bytecode = True
import json
import os
import signal
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

AGENT = "org.bluez.Agent1"


def emit(**data):
    print(json.dumps(data), flush=True)


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class PairAgent(dbus.service.Object):
    def __init__(self, bus, device_path):
        super().__init__(bus, "/org/haku/PairAgent")
        self.device_path = device_path
        self.pending = None
        self.kind = ""

    def prompt(self, device, kind, reply, error, code=""):
        if device != self.device_path or self.pending:
            error(Rejected("Unexpected pairing request"))
            return
        self.pending = (reply, error)
        self.kind = kind
        emit(event="prompt", kind=kind, code=code)

    def respond(self, data):
        if not self.pending:
            return
        reply, error = self.pending
        value = str(data.get("value", ""))
        if not data.get("accept"):
            self.pending = None
            error(Rejected("Canceled by user"))
            return
        if self.kind == "pin" and not 1 <= len(value) <= 16:
            emit(event="validation", output="El PIN debe tener entre 1 y 16 caracteres")
            return
        if self.kind == "passkey" and not (value.isascii() and value.isdigit() and len(value) <= 6):
            emit(event="validation", output="Introduce entre 1 y 6 dígitos")
            return
        self.pending = None
        if self.kind == "pin":
            reply(value)
        elif self.kind == "passkey":
            reply(dbus.UInt32(int(value)))
        else:
            reply()
        emit(event="waiting")

    @dbus.service.method(AGENT, in_signature="o", out_signature="s", async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        self.prompt(device, "pin", reply, error)

    @dbus.service.method(AGENT, in_signature="o", out_signature="u", async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        self.prompt(device, "passkey", reply, error)

    @dbus.service.method(AGENT, in_signature="ou", out_signature="", async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        self.prompt(device, "confirm", reply, error, f"{int(passkey):06d}")

    @dbus.service.method(AGENT, in_signature="o", out_signature="", async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        self.prompt(device, "authorize", reply, error)

    @dbus.service.method(AGENT, in_signature="os", out_signature="", async_callbacks=("reply", "error"))
    def AuthorizeService(self, device, uuid, reply, error):
        self.prompt(device, "authorize", reply, error)

    @dbus.service.method(AGENT, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        if device == self.device_path:
            emit(event="prompt", kind="display", code=str(pincode))

    @dbus.service.method(AGENT, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        if device == self.device_path:
            emit(event="prompt", kind="display", code=f"{int(passkey):06d}", entered=int(entered))

    @dbus.service.method(AGENT, in_signature="", out_signature="")
    def Cancel(self):
        self.respond({"accept": False})
        emit(event="waiting")

    @dbus.service.method(AGENT, in_signature="", out_signature="")
    def Release(self):
        self.Cancel()


def main(mac):
    DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    manager = dbus.Interface(bus.get_object("org.bluez", "/"), "org.freedesktop.DBus.ObjectManager")
    path = next((p for p, interfaces in manager.GetManagedObjects().items()
                 if str(interfaces.get("org.bluez.Device1", {}).get("Address", "")).lower() == mac.lower()), None)
    if path is None:
        emit(event="result", success=False, output="Dispositivo no disponible; actualiza la lista")
        return
    device = dbus.Interface(bus.get_object("org.bluez", path), "org.bluez.Device1")
    agent = PairAgent(bus, path)
    agents = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
    loop = GLib.MainLoop()
    done = False

    def finish(success, message):
        nonlocal done
        if done:
            return
        done = True
        emit(event="result", success=success, output=message)
        loop.quit()

    def cancel(*unused):
        agent.respond({"accept": False})
        try:
            device.CancelPairing(timeout=3)
        except dbus.DBusException:
            pass
        finish(False, "Emparejamiento cancelado")
        return False

    def paired():
        emit(event="waiting")
        device.Connect(reply_handler=lambda: finish(True, "Conectado"),
                       error_handler=lambda error: finish(False, "Emparejado, pero no se pudo conectar"), timeout=20)

    buffer = ""
    def read_input(source, condition):
        nonlocal buffer
        chunk = os.read(sys.stdin.fileno(), 4096)
        if not chunk:
            return cancel()
        buffer += chunk.decode("utf-8")
        while "\n" in buffer:
            line, buffer = buffer.split("\n", 1)
            try:
                data = json.loads(line)
                if data.get("cancel"):
                    return cancel()
                agent.respond(data)
            except (ValueError, TypeError):
                emit(event="validation", output="Respuesta no válida")
        return True

    agents.RegisterAgent("/org/haku/PairAgent", "KeyboardDisplay")
    # Application-scoped agent only; do not replace the desktop's default agent.
    try:
        GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP, read_input)
        GLib.timeout_add_seconds(75, cancel)
        signal.signal(signal.SIGTERM, cancel)
        signal.signal(signal.SIGINT, cancel)
        device.Pair(reply_handler=paired,
                    error_handler=lambda error: finish(False, "No se pudo emparejar; verifica el dispositivo y vuelve a intentar"), timeout=65)
        emit(event="waiting")
        loop.run()
    finally:
        agent.respond({"accept": False})
        try:
            agents.UnregisterAgent("/org/haku/PairAgent")
        except dbus.DBusException:
            pass


if __name__ == "__main__":
    try:
        main(sys.argv[1])
    except (dbus.DBusException, IndexError):
        emit(event="result", success=False, output="Bluetooth no está disponible o no permite emparejar")
