#!/usr/bin/env python3
"""Exercise the real layer UI. Never apply or trash a wallpaper."""
import json
import os
from pathlib import Path
import subprocess
import time

root=Path(__file__).resolve().parent
binary=root/'target/release/haku-carousel'
launcher=Path.home()/'.local/bin/wallpaper-carousel'
mode=Path.home()/'.local/state/haku_theme/carousel_backend'
if mode.read_text().strip()!='rust':raise SystemExit('Select Rust mode first; test will not change your mode')
def command(*args,check=True):
    return subprocess.run([binary,*args],capture_output=True,text=True,timeout=4,check=check)
def status():
    result=command('--status',check=False)
    return json.loads(result.stdout) if result.returncode==0 else None
previous=status()
if previous and previous['actionBusy']:raise SystemExit('An Apply/Trash is in progress; finish it before running this test')
command('--close')
deadline=time.monotonic()+4
while status() is not None and time.monotonic()<deadline:time.sleep(.05)
proc=subprocess.Popen(['bash',launcher],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
checks={}
try:
    deadline=time.monotonic()+8
    while time.monotonic()<deadline:
        state=status()
        if state and state['localItems']>0 and state['searchFocused'] and state['reveal']>=.999:break
        time.sleep(.1)
    else:raise RuntimeError('Layer UI did not become ready')
    checks['full_gallery']=state['items']>3
    checks['input_focus']=state['searchFocused']
    current=state['current']
    command('--query',Path(current).stem)
    state=status()
    checks['local_filter']=state['items']>=1 and state['selected']==current
    command('--query','__haku_ui_test_no_match__')
    checks['empty_filter']=status()['items']==0
    command('--query','')
    command('--step','-1')
    time.sleep(.3)
    checks['bounded_cache']=status()['thumbnailReferences']<=14
    if state.get('cardRenderer')=='gpu':
        first=status()
        time.sleep(.35)
        second=status()
        checks['bounded_gpu_cache']=second['gpuTextures']<=14
        checks['stable_texture_uploads']=first['gpuUploads']==second['gpuUploads']
    command('--source','web')
    start=time.monotonic()
    command('--close')
    proc.wait(timeout=4)
    checks['close_during_search']=proc.returncode==0 and time.monotonic()-start<3
    checks['socket_removed']=not (Path(os.environ['XDG_RUNTIME_DIR'])/'haku-carousel-rust.sock').exists()
    print(json.dumps({'checks':checks,'all_passed':all(checks.values()),'close_seconds':round(time.monotonic()-start,3)},indent=2))
    if not all(checks.values()):raise SystemExit(1)
finally:
    if proc.poll() is None:
        command('--close',check=False)
        try:proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.terminate();proc.wait(timeout=3)
