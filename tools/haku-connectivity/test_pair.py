"""Full pairing protocol against a private bus; never uses system BlueZ."""
import json
import os
from pathlib import Path
import select
import subprocess
import unittest

ROOT = Path(__file__).parent
BINARY = ROOT / 'target/release/haku-connectivity'


def line(proc, timeout=8):
    ready, _, _ = select.select([proc.stdout], [], [], timeout)
    if not ready:
        raise AssertionError('Timed out waiting for private test bus message')
    data = proc.stdout.readline()
    if not data:
        raise AssertionError('Private test process exited early')
    return json.loads(data)


class PairTests(unittest.TestCase):
    def setUp(self):
        self.bus = subprocess.Popen(['dbus-daemon', '--session', '--nofork', '--print-address=1'],
                                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        self.addCleanup(self.stop, self.bus)
        address = self.bus.stdout.readline().decode().strip()
        self.assertTrue(address.startswith('unix:'))
        self.env = {**os.environ, 'DBUS_SYSTEM_BUS_ADDRESS': address,
                    'HAKU_PRIVATE_PAIR_TEST': '1'}

    @staticmethod
    def stop(proc):
        if proc.poll() is None:
            proc.terminate()
        try:
            proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            proc.kill(); proc.wait(timeout=3)
        for pipe in [proc.stdin, proc.stdout, proc.stderr]:
            if pipe:
                pipe.close()

    def begin(self, mode):
        self.env['PAIR_MODE'] = mode
        self.mock = subprocess.Popen(['python3', str(ROOT / 'bluez_mock.py')], env=self.env,
                                     stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
        self.addCleanup(self.stop, self.mock)
        self.assertEqual(line(self.mock)['event'], 'ready')
        self.worker = subprocess.Popen([str(BINARY), 'bluetooth', 'pair', 'AA:BB:CC:DD:EE:FF'],
                                       env=self.env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.DEVNULL, bufsize=0)
        self.addCleanup(self.stop, self.worker)

    def event(self, target):
        for _ in range(10):
            event = line(self.worker)
            if event['event'] == target:
                return event
        self.fail('Missing pairing event')

    def respond(self, data):
        self.worker.stdin.write((json.dumps(data) + '\n').encode()); self.worker.stdin.flush()

    def cleanup_events(self):
        self.worker.wait(timeout=8)
        events = []
        for _ in range(12):
            event = line(self.mock)
            events.append(event)
            if event['event'] == 'unregistered':
                return events
        self.fail('Agent was not unregistered')

    def test_confirmation_success(self):
        self.begin('confirm')
        prompt = self.event('prompt')
        self.assertEqual(prompt['code'], '123456')
        self.respond({'accept': True})
        self.assertTrue(self.event('result')['success'])
        self.assertIn('connected', [e['event'] for e in self.cleanup_events()])

    def test_pin_validation_then_success(self):
        self.begin('pin'); self.assertEqual(self.event('prompt')['kind'], 'pin')
        self.respond({'accept': True, 'value': ''})
        self.event('validation')
        self.respond({'accept': True, 'value': '1234'})
        self.assertTrue(self.event('result')['success'])
        events = self.cleanup_events()
        self.assertEqual(next(e for e in events if e['event'] == 'accepted')['value'], '1234')

    def test_passkey_success(self):
        self.begin('passkey'); self.event('prompt')
        self.respond({'accept': True, 'value': '000123'})
        self.assertTrue(self.event('result')['success'])
        events = self.cleanup_events()
        self.assertEqual(next(e for e in events if e['event'] == 'accepted')['value'], '123')

    def test_rejection(self):
        self.begin('authorize'); self.event('prompt')
        self.respond({'accept': False})
        self.assertFalse(self.event('result')['success'])
        self.assertNotIn('connected', [e['event'] for e in self.cleanup_events()])

    def test_cancel_message(self):
        self.begin('confirm'); self.event('prompt'); self.respond({'cancel': True})
        self.assertFalse(self.event('result')['success'])
        self.assertIn('canceled', [e['event'] for e in self.cleanup_events()])

    def test_eof_cancels(self):
        self.begin('confirm'); self.event('prompt'); self.worker.stdin.close(); self.worker.stdin = None
        self.assertFalse(self.event('result')['success'])
        self.assertIn('canceled', [e['event'] for e in self.cleanup_events()])

    def test_signal_cancels(self):
        self.begin('confirm'); self.event('prompt'); self.worker.terminate()
        self.assertFalse(self.event('result')['success'])
        self.assertIn('canceled', [e['event'] for e in self.cleanup_events()])

    def test_other_device_rejected(self):
        self.begin('wrong-device')
        self.assertFalse(self.event('result')['success'])
        self.assertNotIn('connected', [e['event'] for e in self.cleanup_events()])

    def test_connect_error_after_pair(self):
        self.begin('connect-error'); self.event('prompt'); self.respond({'accept': True})
        result = self.event('result')
        self.assertFalse(result['success'])
        self.assertIn('Emparejado', result['output'])
        self.cleanup_events()


if __name__ == '__main__':
    unittest.main()
