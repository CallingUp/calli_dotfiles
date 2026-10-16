#!/usr/bin/env python3
"""Real QML cache/navigation checks, without Apply/Trash or deleting cache files."""
import json
import os
from pathlib import Path
import subprocess
import time

repo=Path(__file__).resolve().parents[2]
config=repo/'config/quickshell/minflair-niri/niri-preview.qml'
worker=repo/'tools/haku-wallpaper/target/release/haku-wallpaper'
def ipc(target,method,*args):
    try:
        return subprocess.check_output(['quickshell','ipc','-p',str(config),'call',target,method,*map(str,args)],text=True,timeout=20).strip()
    except subprocess.TimeoutExpired:
        raise RuntimeError(f'QML IPC timed out: {target} {method}') from None
def state():return json.loads(ipc('haku-wallpaper','status'))
def wait(predicate):
    deadline=time.monotonic()+5
    while time.monotonic()<deadline:
        value=state()
        if predicate(value):return value
        time.sleep(.05)
    raise RuntimeError('QML did not reach the expected state')
if ipc('haku-wallpaper-host','status')!='closed':raise SystemExit('Close the carousel before running this test')
catalog=json.loads(subprocess.check_output([worker],input='{"action":"list"}\n',text=True))
warm=[row for row in catalog['rows'] if row.get('cachedThumbnail')]
if len(warm)<7:raise SystemExit('Need at least seven existing cached thumbnails; test will not create fixtures in your gallery')
checks={}
def open_rows(rows):
    ipc('haku-wallpaper-host','toggle',json.dumps(dict(catalog,rows=rows,accent='#B99573',font='Maple Mono NF'),separators=(',',':'),ensure_ascii=False))
try:
    open_rows(warm)
    first=wait(lambda s:s['imageSlots']>0 and not s['loading'])
    start=first['index']
    for _ in range(4):
        ipc('haku-wallpaper-host','step',1)
        time.sleep(.05)
    time.sleep(.3)
    last=state()
    checks['navigation']=last['index']==start+4
    checks['direct_cache_no_workers']=last['workerStarts']==0 and last['cacheHits']>=7
    checks['bounded_cache']=last['thumbnailReferences']<=14
    checks['decode_culling']=0<last['imageSlots']<7
    time.sleep(.3)
    checks['no_queued_rotation']=state()['index']==last['index']
    subprocess.run(['grim','-g','0,80 440x920','/tmp/haku-qml-optimized-verified.png'],check=True)
    ipc('haku-wallpaper-host','close')
    selected=next((r for r in warm if r['path']==catalog['current']),warm[0])
    item=dict(selected,cachedThumbnail=f'haku-missing-thumbnail-{os.getpid()}.jpg')
    if (Path.home()/'.cache/haku-wallpaper-carousel/qml'/item['cachedThumbnail']).exists():raise RuntimeError('Unexpected test path exists')
    open_rows([item])
    fallback=wait(lambda s:s['workerStarts']==1 and not s['loading'] and s['queued']==0 and s['thumbnailReferences']==1)
    time.sleep(.2)
    checks['missing_direct_cache_fallback_once']=state()['workerStarts']==1
    ipc('haku-wallpaper-host','close')
    legacy=dict(selected);legacy.pop('cachedThumbnail')
    open_rows([legacy])
    legacy_state=wait(lambda s:s['workerStarts']==1 and not s['loading'] and s['thumbnailReferences']==1)
    checks['legacy_backend_compatible']=legacy_state['cacheHits']==0
finally:
    ipc('haku-wallpaper-host','close')
checks['closed']=ipc('haku-wallpaper-host','status')=='closed'
print(json.dumps(dict(checks=checks,all_passed=all(checks.values())),indent=2))
if not all(checks.values()):raise SystemExit(1)
