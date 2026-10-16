"""BlueZ fixture, only launched on the private test bus."""
import os
import json
import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

assert os.environ.get('HAKU_PRIVATE_PAIR_TEST') == '1'
assert os.environ.get('DBUS_SYSTEM_BUS_ADDRESS') and '/run/dbus/system_bus_socket' not in os.environ['DBUS_SYSTEM_BUS_ADDRESS']
DBusGMainLoop(set_as_default=True)
bus = dbus.SystemBus()
name = dbus.service.BusName('org.bluez', bus)
loop = GLib.MainLoop()
DEVICE = '/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF'
mode = os.environ.get('PAIR_MODE', 'confirm')
agent = None


def log(event, **data):
    print(json.dumps({'event': event, **data}), flush=True)


class Manager(dbus.service.Object):
    @dbus.service.method('org.freedesktop.DBus.ObjectManager', out_signature='a{oa{sa{sv}}}')
    def GetManagedObjects(self):
        return {DEVICE: {'org.bluez.Device1': {'Address': 'AA:BB:CC:DD:EE:FF'}}}


class Agents(dbus.service.Object):
    @dbus.service.method('org.bluez.AgentManager1', in_signature='os', sender_keyword='sender')
    def RegisterAgent(self, path, capability, sender=None):
        global agent
        agent = dbus.Interface(bus.get_object(sender, path, introspect=False), 'org.bluez.Agent1')
        log('registered', capability=str(capability))

    @dbus.service.method('org.bluez.AgentManager1', in_signature='o')
    def UnregisterAgent(self, path):
        log('unregistered')


class Device(dbus.service.Object):
    @dbus.service.method('org.bluez.Device1', async_callbacks=('reply', 'error'))
    def Pair(self, reply, error):
        log('pair')
        def accepted(*values):
            log('accepted', value=str(values[0]) if values else '')
            reply()
        if mode == 'pin':
            agent.RequestPinCode(dbus.ObjectPath(DEVICE), reply_handler=accepted, error_handler=error)
        elif mode == 'passkey':
            agent.RequestPasskey(dbus.ObjectPath(DEVICE), reply_handler=accepted, error_handler=error)
        elif mode == 'authorize':
            agent.RequestAuthorization(dbus.ObjectPath(DEVICE), reply_handler=accepted, error_handler=error)
        elif mode == 'wrong-device':
            agent.RequestConfirmation(dbus.ObjectPath('/unexpected'), dbus.UInt32(123456), reply_handler=accepted, error_handler=error)
        else:
            agent.RequestConfirmation(dbus.ObjectPath(DEVICE), dbus.UInt32(123456), reply_handler=accepted, error_handler=error)

    @dbus.service.method('org.bluez.Device1')
    def Connect(self):
        log('connected')
        if mode == 'connect-error':
            raise dbus.exceptions.DBusException('Test connection failure', name='org.bluez.Error.Failed')

    @dbus.service.method('org.bluez.Device1')
    def CancelPairing(self):
        log('canceled')


manager = Manager(bus, '/')
agents = Agents(bus, '/org/bluez')
device = Device(bus, DEVICE)
log('ready')
loop.run()
