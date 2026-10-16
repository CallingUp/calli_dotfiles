#!/usr/bin/env python3
"""Measure hosted QML without changing its source, wallpaper or files."""
import json
import os
from pathlib import Path
import statistics
import subprocess
import time

root=Path(__file__).resolve().parents[2]
config=root/'config/quickshell/minflair-niri/niri-preview.qml'
def ipc(target,method,*args):
    return subprocess.check_output(['quickshell','ipc','-p',config,'call',target,method,*map(str,args)],text=True,timeout=5).strip()
pid=next(int(p.name) for p in Path('/proc').iterdir() if p.name.isdigit()
    and (p/'cmdline').exists() and str(config).encode() in (p/'cmdline').read_bytes()
    and (p/'comm').read_text().strip()=='quickshell')
worker=root/'tools/haku-wallpaper/target/release/haku-wallpaper'
catalog=json.loads(subprocess.check_output([worker],input='{"action":"list"}\n',text=True))
index=next((i for i,r in enumerate(catalog['rows']) if r['path']==catalog['current']),0)
rows=[catalog['rows'][(index+d)%len(catalog['rows'])] for d in [-1,0,1]]
request=dict(catalog,rows=rows,current=rows[1]['path'],accent='#B99573',font='monospace')
def sample():
    p=Path(f'/proc/{pid}')
    fields=(p/'stat').read_text().rsplit(')',1)[1].split()
    mem={}
    for line in (p/'smaps_rollup').read_text().splitlines():
        if line.startswith(('Pss:','SwapPss:')):
            k,v=line.split(':',1);mem[k]=int(v.split()[0])/1024
    return time.monotonic(),int(fields[11])+int(fields[12]),mem['Pss']
def phase(seconds,navigate=False):
    start=time.monotonic();previous=sample();samples=[];steps=0
    for i in range(round(seconds/0.25)):
        if navigate:ipc('haku-wallpaper-host','step',1);steps+=1
        time.sleep(max(0,start+(i+1)*0.25-time.monotonic()))
        current=sample()
        if i>=4:
            elapsed=current[0]-previous[0]
            samples.append(((current[1]-previous[1])/os.sysconf('SC_CLK_TCK')/elapsed*100,current[2]))
        previous=current
    return dict(cpu_one_core_mean_pct=round(statistics.mean(s[0] for s in samples),2),
        pss_mean_MiB=round(statistics.mean(s[1] for s in samples),2),samples=len(samples),steps=steps)

results=[]
try:
    ipc('haku-wallpaper-host','close')
    for trial in range(3):
        base=phase(5)
        ipc('haku-wallpaper-host','toggle',json.dumps(request))
        opened=phase(5)
        navigation=phase(10,True)
        quiet=phase(5)
        ipc('haku-wallpaper-host','close')
        closed=phase(5)
        result=dict(trial=trial+1,pid=pid,base=base,open_idle=opened,navigation=navigation,open_after=quiet,closed_after=closed)
        results.append(result);print(json.dumps(result),flush=True)
    summary={phase_name:{key:round(statistics.median(r[phase_name][key] for r in results),2)
        for key in ['cpu_one_core_mean_pct','pss_mean_MiB']}
        for phase_name in ['base','open_idle','navigation','open_after','closed_after']}
    print(json.dumps(dict(inputs=[r['path'] for r in rows],median_of_3_runs=summary,
        note='Shared shell process; 3-item test catalog; original QML 440x920 vs Rust 480x820, not pixel-identical'),indent=2),flush=True)
finally:
    ipc('haku-wallpaper-host','close')
