import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BINARY=Path(__file__).parent/'target/release/haku-connectivity'

class Tests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name)
        self.env={**os.environ,'PATH':str(self.root)+':'+os.environ['PATH'],'TEST_ROOT':str(self.root)}
        for name in ['nmcli','busctl']:
            script=self.root/name
            script.write_text('''#!/usr/bin/env python3
import json,sys,pathlib,os
root=pathlib.Path(os.environ["TEST_ROOT"])
name=pathlib.Path(__file__).name
args=sys.argv[1:]
if os.environ.get("TEST_FAIL"): sys.exit(1)
if name=="busctl": print((root/"bluez.json").read_text())
elif args==["radio","wifi"]: print(os.environ.get("WIFI_RADIO","enabled"))
elif "TYPE,STATE,CONNECTION" in args: print(r"wifi:connected:Cat\\:Net")
elif "NAME,TYPE,TIMESTAMP" in args: print(os.environ.get("WIFI_SAVED",r"Saved:802-11-wireless:100"))
elif "DEVICE,TYPE" in args: print(os.environ.get("WIFI_DEVICES","wlan0:wifi"))
elif "SSID,SIGNAL,IN-USE,SECURITY" in args: print("Other:99::WPA2\\nSaved:30::WPA2\\nCat\\\\:Net:20:*:WPA2\\nCat\\\\:Net:70::WPA2")
else:
    (root/"wifi-arguments.json").write_text(json.dumps(args))
    if os.environ.get("WIFI_FAIL"): print("Connection failed",file=sys.stderr);sys.exit(1)
    print("Success")
''');script.chmod(0o700)

    def worker(self,*args,success=True):
        p=subprocess.run([str(BINARY),*args],env=self.env,capture_output=True,text=True,timeout=15)
        self.assertEqual(p.returncode==0,success,p.stderr)
        return json.loads(p.stdout)

    def test_wifi_status_escaped(self):
        self.assertEqual(self.worker('wifi','status'),{'radio':True,'connected_ssid':'Cat:Net'})

    def test_private_wifi_invalid_secret_not_echoed(self):
        secret='test-only\nnot-a-real-password'
        p=subprocess.run([str(BINARY),'wifi','connect-private','FakeSSID'],
                         input=json.dumps({'password':secret,'security':'WPA2'})+'\n',
                         env=self.env,capture_output=True,text=True,timeout=5)
        self.assertFalse(json.loads(p.stdout)['success'])
        self.assertNotIn('not-a-real-password',p.stdout+p.stderr)

    def test_private_wifi_stdin_line_without_eof(self):
        with subprocess.Popen([str(BINARY),'wifi','connect-private','FakeSSID'],
                              env=self.env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True) as proc:
            proc.stdin.write('{"password":""}\n');proc.stdin.flush()
            proc.wait(timeout=5)
            self.assertFalse(json.loads(proc.stdout.read())['success'])

    def wifi_args(self):
        return json.loads((self.root/'wifi-arguments.json').read_text())

    def test_wifi_saved_connect(self):
        self.assertTrue(self.worker('wifi','connect','Saved')['success'])
        self.assertEqual(self.wifi_args(),['--wait','25','connection','up','id','Saved'])

    def test_wifi_open_connect_literal_name(self):
        name='Cafe : $HOME `literal`; x'
        self.assertTrue(self.worker('wifi','connect',name)['success'])
        self.assertEqual(self.wifi_args(),['--wait','25','device','wifi','connect',name])

    def test_wifi_saved_escaped_name(self):
        self.env['WIFI_SAVED']=r'Cat\:Net:802-11-wireless:100'
        self.assertTrue(self.worker('wifi','connect','Cat:Net')['success'])
        self.assertEqual(self.wifi_args(),['--wait','25','connection','up','id','Cat:Net'])

    def test_wifi_radio_toggle(self):
        for previous,next_state in [('enabled','off'),('disabled','on')]:
            self.env['WIFI_RADIO']=previous
            result=self.worker('wifi','toggle-radio')
            self.assertTrue(result['success'])
            self.assertEqual(result['radio'],next_state=='on')
            self.assertEqual(self.wifi_args(),['radio','wifi',next_state])

    def test_wifi_disconnect_device_then_profile(self):
        self.assertTrue(self.worker('wifi','disconnect','Saved')['success'])
        self.assertEqual(self.wifi_args(),['device','disconnect','wlan0'])
        self.env['WIFI_DEVICES']='eth0:ethernet'
        self.assertTrue(self.worker('wifi','disconnect','Saved')['success'])
        self.assertEqual(self.wifi_args(),['connection','down','id','Saved'])

    def test_wifi_forget_literal_name(self):
        self.assertTrue(self.worker('wifi','forget','Cat:Net')['success'])
        self.assertEqual(self.wifi_args(),['connection','delete','id','Cat:Net'])

    def test_wifi_action_error_reported(self):
        self.env['WIFI_FAIL']='1'
        result=self.worker('wifi','forget','Saved')
        self.assertFalse(result['success'])
        self.assertEqual(result['output'],'Connection failed')

    def test_wifi_status_failure_never_changes_radio(self):
        self.env['TEST_FAIL']='1'
        self.worker('wifi','toggle-radio',success=False)
        self.assertFalse((self.root/'wifi-arguments.json').exists())

    def test_scan_merge_saved_order(self):
        rows=self.worker('wifi','scan','no')
        self.assertEqual(len(rows),3)
        self.assertEqual(rows[0]['ssid'],'Cat:Net')
        self.assertEqual(rows[0]['signal'],70)
        self.assertEqual(rows[1]['ssid'],'Saved')

    def test_bluetooth_shape(self):
        payload={'data':[{'/adapter':{'org.bluez.Adapter1':{'Powered':{'data':True},'Discovering':{'data':False}}},
                         '/device':{'org.bluez.Device1':{'Address':{'data':'AA:BB:CC:DD:EE:FF'},'Alias':{'data':'Headphones'},'Connected':{'data':True},'Paired':{'data':True}}}}]}
        (self.root/'bluez.json').write_text(json.dumps(payload))
        result=self.worker('bluetooth','status')
        self.assertTrue(result['powered'])
        self.assertEqual(result['connected_device'],'Headphones')
        self.assertTrue(result['devices'][0]['paired'])

    def test_failure_is_json_no_details(self):
        self.env['TEST_FAIL']='1'
        self.assertFalse(self.worker('wifi','status',success=False)['success'])

    def fake_bluetooth(self, connected=False, powered=True):
        (self.root/'bluez.json').write_text(json.dumps({'data':[{
            '/adapter':{'org.bluez.Adapter1':{'Powered':{'data':powered}}},
            '/device':{'org.bluez.Device1':{'Address':{'data':'AA:BB:CC:DD:EE:FF'},'Connected':{'data':connected},'Paired':{'data':True}}}
        }]}))
        script=self.root/'bluetoothctl'
        script.write_text('''#!/usr/bin/env python3
import sys,os,pathlib,json
root=pathlib.Path(os.environ["TEST_ROOT"])
(root/"bt-arguments.json").write_text(json.dumps(sys.argv[1:]))
if os.environ.get("BT_FAIL"):
    print("Connection failed",file=sys.stderr);sys.exit(1)
print("Success")
''');script.chmod(0o700)

    def test_bluetooth_connect_and_disconnect(self):
        for connected,action in [(False,'connect'),(True,'disconnect')]:
            self.fake_bluetooth(connected=connected)
            self.assertTrue(self.worker('bluetooth','toggle-connect','aa:bb:cc:dd:ee:ff')['success'])
            self.assertEqual(json.loads((self.root/'bt-arguments.json').read_text()),['--timeout','20',action,'aa:bb:cc:dd:ee:ff'])

    def test_bluetooth_power_both_directions(self):
        for powered,action in [(False,'on'),(True,'off')]:
            self.fake_bluetooth(powered=powered)
            self.assertTrue(self.worker('bluetooth','toggle-power')['success'])
            self.assertEqual(json.loads((self.root/'bt-arguments.json').read_text()),['power',action])

    def test_invalid_address_never_calls_bluetoothctl(self):
        self.fake_bluetooth()
        self.worker('bluetooth','toggle-connect','--help',success=False)
        self.assertFalse((self.root/'bt-arguments.json').exists())

    def test_bluetooth_action_failure_propagates(self):
        self.fake_bluetooth();self.env['BT_FAIL']='1'
        result=self.worker('bluetooth','toggle-connect','AA:BB:CC:DD:EE:FF')
        self.assertFalse(result['success'])
        self.assertEqual(result['output'],'Connection failed')

    def test_status_failure_never_changes_power(self):
        self.fake_bluetooth();self.env['TEST_FAIL']='1'
        self.worker('bluetooth','toggle-power',success=False)
        self.assertFalse((self.root/'bt-arguments.json').exists())

if __name__=='__main__':unittest.main()
