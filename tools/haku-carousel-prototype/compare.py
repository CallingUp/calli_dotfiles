#!/usr/bin/env python3
"""Alternate software/GPU, same three inputs; report medians, not total PC usage."""
import json
from pathlib import Path
import statistics
import subprocess
import sys

root=Path(__file__).resolve().parent
worker=root.parent/'haku-wallpaper/target/release/haku-wallpaper'
catalog=json.loads(subprocess.check_output([worker],input='{"action":"list"}\n',text=True))
rows=catalog['rows']
index=next((i for i,r in enumerate(rows) if r['path']==catalog['current']),0)
images=[rows[(index+d)%len(rows)]['path'] for d in [-1,0,1]]
results=[]
for trial,renderer in enumerate(['software','gpu','gpu','software','software','gpu'],1):
    binary=root/'target/release'/('haku-carousel-'+renderer)
    output=subprocess.check_output([sys.executable,'-B',root/'measure.py','--binary',binary,
        '--renderer',renderer,'--images',*images],text=True,timeout=65)
    result=json.loads(output)
    result['trial']=trial
    results.append(result)
    print(json.dumps(result),flush=True)
    if result['exit_code']!=0:raise SystemExit('Prototype failed; stopping comparison')
summary={}
for renderer in ['software','gpu']:
    matching=[r for r in results if r['renderer']==renderer]
    summary[renderer]={}
    for phase in ['idle','navigation','idle_after']:
        values=[r['phases'][phase] for r in matching if phase in r['phases']]
        if values:summary[renderer][phase]={k:round(statistics.median(v[k] for v in values),2)
            for k in ['cpu_one_core_mean_pct','pss_mean_MiB']}
    frames=[r['frames']['p95_ms'] for r in matching if 'p95_ms' in r['frames']]
    summary[renderer]['frame_interval_p95_median_ms']=round(statistics.median(frames),2) if frames else None
print(json.dumps({'inputs':images,'median_of_3_runs':summary},indent=2),flush=True)
