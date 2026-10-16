"""Native carousel tests using an isolated gallery, never the real wallpaper."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BINARY = Path(__file__).parent / 'target/release/haku-wallpaper'


class WorkerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = {**os.environ, 'HOME': str(self.home)}
        self.gallery = self.home / 'Pictures/Wallpapers'
        self.gallery.mkdir(parents=True)
        self.photo = self.gallery / 'a space.PNG'
        self.photo.write_bytes(b'fake image')
        self.item = {'kind': 'local', 'key': str(self.photo), 'path': str(self.photo)}

    def worker(self, request, success=True):
        proc = subprocess.run([str(BINARY)], input=json.dumps(request) + '\n',
                              text=True, capture_output=True, env=self.env, timeout=5)
        self.assertEqual(proc.returncode == 0, success, proc.stderr)
        return json.loads(proc.stdout)

    def test_list_and_escape_symlink(self):
        outside = self.home / 'outside.png'
        outside.touch()
        (self.gallery / 'escape.png').symlink_to(outside)
        result = self.worker({'action': 'list'})
        self.assertEqual(len(result['rows']), 1)
        self.assertEqual(result['rows'][0]['label'], 'a space')
        self.worker({'action': 'thumb', 'item': {**self.item, 'path': str(outside)}}, success=False)

    def test_existing_python_thumbnail_cache_is_reused(self):
        signature = f'qml-v1:{self.photo}:{self.photo.stat().st_mtime_ns}'
        cache = self.home / '.cache/haku-wallpaper-carousel/qml'
        cache.mkdir(parents=True)
        image = cache / (hashlib.sha256(signature.encode()).hexdigest() + '.jpg')
        image.write_bytes(b'cached')
        result = self.worker({'action': 'thumb', 'item': self.item})
        self.assertEqual(result['image'], str(image))
        self.assertEqual(image.read_bytes(), b'cached')

    def test_catalog_exposes_only_current_nonempty_cached_thumbnail(self):
        result = self.worker({'action': 'list'})
        self.assertIsNone(result['rows'][0]['cachedThumbnail'])
        cache = self.home / '.cache/haku-wallpaper-carousel/qml'
        cache.mkdir(parents=True)
        signature = f'qml-v1:{self.photo}:{self.photo.stat().st_mtime_ns}'
        thumbnail = cache / (hashlib.sha256(signature.encode()).hexdigest() + '.jpg')
        thumbnail.touch()
        self.assertIsNone(self.worker({'action': 'list'})['rows'][0]['cachedThumbnail'])
        thumbnail.write_bytes(b'cached')
        self.assertEqual(self.worker({'action': 'list'})['rows'][0]['cachedThumbnail'], thumbnail.name)
        stamp = self.photo.stat().st_mtime_ns
        os.utime(self.photo, ns=(stamp+1_000_000_000,stamp+1_000_000_000))
        self.assertIsNone(self.worker({'action': 'list'})['rows'][0]['cachedThumbnail'])

    def test_request_does_not_wait_for_stdin_eof(self):
        with subprocess.Popen([str(BINARY)], env=self.env, stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, text=True) as proc:
            proc.stdin.write('{"action":"list"}\n')
            proc.stdin.flush()
            proc.wait(timeout=5)
            self.assertTrue(json.loads(proc.stdout.read())['ok'])

    def fake_quickshell(self, mode):
        tools=self.home/'bin';tools.mkdir(exist_ok=True)
        script=tools/'quickshell'
        script.write_text('''#!/usr/bin/env python3
import sys,os,pathlib,json,time
root=pathlib.Path(os.environ["HOME"])
mode=os.environ["FAKE_SHELL_MODE"]
args=sys.argv[1:]
if args[0]=="ipc":
    method=args[args.index("call")+2]
    target=args[args.index("call")+1]
    if target=="haku-wallpaper": sys.exit(1)
    if mode=="standalone" or mode=="wait": sys.exit(1)
    if method=="status": print("open" if mode=="open" else "closed");sys.exit(0)
    if method=="toggle": (root/"hosted.json").write_text(args[-1])
    if method=="close": (root/"closed").touch()
else:
    path=pathlib.Path(os.environ["HAKU_MENU_REQUEST"])
    (root/"standalone.json").write_text(json.dumps({"request":json.loads(path.read_text()),"path":str(path),"private":path.parent.stat().st_mode&0o777==0o700,"pid":os.getpid()}))
    if mode=="wait": time.sleep(60)
''')
        script.chmod(0o700)
        self.env.update(PATH=str(tools)+':'+os.environ['PATH'],FAKE_SHELL_MODE=mode,XDG_RUNTIME_DIR=str(self.home))

    def test_launcher_hosted_theme(self):
        self.fake_quickshell('hosted')
        state=self.home/'.local/state/haku_theme';state.mkdir(parents=True)
        (state/'colors.css').write_text('@define-color accent_color #B99573;')
        (state/'fonts.css').write_text('font-family: "Maple Mono NF";')
        subprocess.run([str(BINARY),'--launch'],env=self.env,check=True,timeout=5)
        request=json.loads((self.home/'hosted.json').read_text())
        self.assertEqual(request['accent'],'#B99573')
        self.assertEqual(request['font'],'Maple Mono NF')
        self.assertEqual(len(request['rows']),1)

    def test_launcher_close_does_not_scan_gallery(self):
        self.fake_quickshell('open')
        self.photo.unlink();self.gallery.rmdir()
        subprocess.run([str(BINARY),'--launch'],env=self.env,check=True,timeout=5)
        self.assertTrue((self.home/'closed').exists())
        self.assertFalse(self.gallery.exists())

    def test_launcher_standalone_private_request_cleanup(self):
        self.fake_quickshell('standalone')
        subprocess.run([str(BINARY),'--launch'],env=self.env,check=True,timeout=5)
        data=json.loads((self.home/'standalone.json').read_text())
        self.assertTrue(data['private'])
        self.assertEqual(len(data['request']['rows']),1)
        self.assertFalse(Path(data['path']).parent.exists())

    def test_launcher_termination_cleans_standalone_request(self):
        import time
        self.fake_quickshell('wait')
        with subprocess.Popen([str(BINARY),'--launch'],env=self.env) as proc:
            for _ in range(100):
                if (self.home/'standalone.json').exists():break
                time.sleep(.02)
            data=json.loads((self.home/'standalone.json').read_text())
            proc.terminate();proc.wait(timeout=5)
        self.assertFalse(Path(data['path']).parent.exists())

    def sync_scripts(self):
        directory = self.home / '.local/bin'
        directory.mkdir(parents=True)
        for name in ['wallpaper-transition','wallpaper-theme-sync']:
            script = directory / name
            script.write_text('''#!/usr/bin/env python3
import os,sys,pathlib,json
root=pathlib.Path(os.environ["HOME"])
name=pathlib.Path(__file__).name
(root/(name+".json")).write_text(json.dumps({"args":sys.argv[1:],"detached":os.getsid(0)==os.getpid()}))
''')
            script.chmod(0o700)

    def wait_sync(self):
        import time
        for _ in range(100):
            if all((self.home/(name+'.json')).exists() for name in ['wallpaper-transition','wallpaper-theme-sync']):
                return
            time.sleep(.02)
        self.fail('Sync fixture did not run')

    def test_apply_atomic_state_and_detached_sync(self):
        self.sync_scripts()
        result = self.worker({'action':'apply','item':self.item})
        self.assertFalse(result['unchanged'])
        self.wait_sync()
        state=self.home/'.local/state/haku_theme'
        self.assertEqual((state/'current_wallpaper').read_text(),str(self.photo)+'\n')
        generation=(state/'wallpaper_generation').read_text()
        transition=json.loads((self.home/'wallpaper-transition.json').read_text())
        sync=json.loads((self.home/'wallpaper-theme-sync.json').read_text())
        self.assertEqual(transition['args'][:2],['',str(self.photo)])
        self.assertIn(transition['args'][2],['left','right','top','bottom'])
        self.assertEqual(sync['args'],[str(self.photo),generation])
        self.assertTrue(sync['detached'] and transition['detached'])
        self.assertTrue(self.worker({'action':'apply','item':self.item})['unchanged'])
        self.assertEqual((state/'wallpaper_generation').read_text(),generation)

    def test_apply_uses_existing_flock(self):
        import fcntl,time
        self.sync_scripts()
        state=self.home/'.local/state/haku_theme'
        state.mkdir(parents=True)
        with (state/'wallpaper_selector_apply.lock').open('a') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            with subprocess.Popen([str(BINARY)],env=self.env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True) as proc:
                proc.stdin.write(json.dumps({'action':'apply','item':self.item})+'\n');proc.stdin.flush()
                time.sleep(.1)
                self.assertIsNone(proc.poll())
                self.assertFalse((state/'current_wallpaper').exists())
                fcntl.flock(lock,fcntl.LOCK_UN)
                proc.wait(timeout=5)
                self.assertTrue(json.loads(proc.stdout.read())['ok'])
        self.wait_sync()

    def test_concurrent_same_apply_only_changes_once(self):
        from concurrent.futures import ThreadPoolExecutor
        self.sync_scripts()
        with ThreadPoolExecutor(max_workers=4) as pool:
            results=list(pool.map(lambda _:self.worker({'action':'apply','item':self.item}),range(8)))
        self.assertEqual(sum(not r['unchanged'] for r in results),1)
        self.wait_sync()

    def test_missing_sync_scripts_does_not_update_state(self):
        self.worker({'action':'apply','item':self.item},success=False)
        self.assertFalse((self.home/'.local/state/haku_theme/current_wallpaper').exists())

    def test_trash_active_protected_and_fake_trash_only(self):
        state=self.home/'.local/state/haku_theme'
        state.mkdir(parents=True)
        (state/'current_wallpaper').write_text(str(self.photo)+'\n')
        tools=self.home/'bin';tools.mkdir()
        gio=tools/'gio'
        gio.write_text('''#!/usr/bin/env python3
import os,sys,pathlib
assert sys.argv[1]=="trash"
pathlib.Path(sys.argv[2]).rename(pathlib.Path(os.environ["HOME"])/"fake-trash")
''')
        gio.chmod(0o700)
        self.env['PATH']=str(tools)+':'+os.environ['PATH']
        self.worker({'action':'trash','item':self.item},success=False)
        self.assertTrue(self.photo.exists())
        other=self.gallery/'other.jpg';other.write_bytes(b'test')
        self.assertTrue(self.worker({'action':'trash','item':{'path':str(other)}})['ok'])
        self.assertEqual((self.home/'fake-trash').read_bytes(),b'test')
        self.assertTrue(self.photo.exists())

    def test_apply_web_download_original_atomically(self):
        self.fake_curl();self.sync_scripts()
        (self.home/'payload').write_bytes(b'fake-original')
        item={'kind':'web','id':'abc123','path':'https://w.wallhaven.cc/full/a.jpg'}
        result=self.worker({'action':'apply','item':item})
        self.assertEqual(Path(result['current']).read_bytes(),b'fake-original')
        request=json.loads((self.home/'curl-request.json').read_text())
        self.assertIn(str(64*1024*1024),request['args'])
        self.assertEqual(list(self.gallery.glob('.tmp*')),[])
        self.wait_sync()

    def fake_curl(self):
        tools = self.home / 'bin'
        tools.mkdir(exist_ok=True)
        curl = tools / 'curl'
        curl.write_text('''#!/usr/bin/env python3
import os,sys,pathlib,json
args=sys.argv[1:]
root=pathlib.Path(os.environ["HOME"])
config=sys.stdin.read()
(root/"curl-request.json").write_text(json.dumps({"args":args,"config":config}))
pathlib.Path(args[args.index("--output")+1]).write_bytes((root/"payload").read_bytes())
pathlib.Path(args[args.index("--dump-header")+1]).write_text(os.environ.get("FAKE_HEADERS","HTTP/1.1 200 OK\\r\\n\\r\\n"))
print(os.environ.get("FAKE_STATUS","200"),end="")
''')
        curl.chmod(0o700)
        self.env['PATH'] = str(tools) + ':' + os.environ['PATH']

    def test_search_defaults_key_private_and_results(self):
        self.fake_curl()
        config = self.home / '.config/haku'
        config.mkdir(parents=True)
        (config / 'wallhaven_api_key').write_text('test-secret')
        payload = {'data': [{'id':'abc123','resolution':'1920x1080',
                   'thumbs':{'small':'https://th.wallhaven.cc/a.jpg'},
                   'path':'https://w.wallhaven.cc/a.jpg'}], 'meta':{'total':42,'last_page':3}}
        (self.home / 'payload').write_text(json.dumps(payload))
        result = self.worker({'action':'search','query':'cat & moon','page':2})
        self.assertEqual(result['total'],42)
        self.assertEqual(result['rows'][0]['key'],'web:abc123')
        request = json.loads((self.home / 'curl-request.json').read_text())
        self.assertNotIn('test-secret',' '.join(request['args']))
        from urllib.parse import parse_qs, urlsplit
        url = json.loads(request['config'].strip().split(' = ',1)[1])
        params = parse_qs(urlsplit(url).query)
        for key,value in {'sorting':'favorites','purity':'100','categories':'111',
                          'atleast':'1920x1080','ratios':'16x9','q':'cat & moon','page':'2'}.items():
            self.assertEqual(params[key],[value])

    def test_external_redirect_rejected(self):
        self.fake_curl()
        (self.home / 'payload').write_bytes(b'')
        self.env.update(FAKE_STATUS='302', FAKE_HEADERS='HTTP/1.1 302 Found\r\nLocation: https://evil.example/a\r\n\r\n')
        result = self.worker({'action':'search'}, success=False)
        self.assertNotIn('evil.example', json.dumps(result))

    def test_search_response_limit(self):
        self.fake_curl()
        (self.home / 'payload').write_bytes(b'x' * (4*1024*1024+1))
        self.worker({'action':'search'}, success=False)

    def test_web_cached_thumbnail_compatible(self):
        thumb = 'https://th.wallhaven.cc/test.jpg'
        cache = self.home / '.cache/haku-wallpaper-carousel/qml'
        cache.mkdir(parents=True)
        target = cache / (hashlib.sha256(('qml-web-v1:'+thumb).encode()).hexdigest()+'.jpg')
        target.write_bytes(b'cached')
        result = self.worker({'action':'thumb','item':{'kind':'web','key':'web:abc123','thumb':thumb}})
        self.assertEqual(result['image'],str(target))

    def test_new_thumbnail_runs_magick_with_existing_geometry(self):
        tools = self.home / 'bin'
        tools.mkdir()
        magick = tools / 'magick'
        magick.write_text('''#!/usr/bin/env python3
import sys,pathlib,json
pathlib.Path(sys.argv[-1]).write_bytes(b"rendered")
pathlib.Path(__file__).with_name("arguments.json").write_text(json.dumps(sys.argv[1:]))
''')
        magick.chmod(0o700)
        self.env['PATH'] = str(tools) + ':' + os.environ['PATH']
        result = self.worker({'action': 'thumb', 'item': self.item})
        self.assertEqual(Path(result['image']).read_bytes(), b'rendered')
        args = json.loads((tools / 'arguments.json').read_text())
        self.assertEqual(args[0], str(self.photo) + '[0]')
        self.assertIn('420x300^', args)
        self.assertIn('420x300', args)
        self.assertEqual(list(Path(result['image']).parent.glob('thumb-*')), [])


if __name__ == '__main__':
    unittest.main()
