#!/usr/bin/env python3
"""Three finite GPU trials, including the shared shell left running."""
import json
from pathlib import Path
import statistics
import subprocess
import sys
import time

root=Path(__file__).resolve().parent
config=root.parents[1]/'config/quickshell/minflair-niri/niri-preview.qml'
pid=next(int(p.name) for p in Path('/proc').iterdir() if p.name.isdigit()
    and (p/'cmdline').exists() and str(config).encode() in (p/'cmdline').read_bytes()
    and (p/'comm').read_text().strip()=='quickshell')
images=[str(Path.home()/'Pictures/Wallpapers'/name) for name in ['Angel1.png','BG16x9.jpg','HJGF4cpasAAJAhf.jpeg']]
results=[]
baseline=[]
for trial in range(3):
    for _ in range(5):
        lines=Path(f'/proc/{pid}/smaps_rollup').read_text().splitlines()
        baseline.append(int(next(l.split()[1] for l in lines if l.startswith('Pss:')))/1024)
        time.sleep(1)
    output=subprocess.check_output([sys.executable,'-B',root/'measure.py',
        '--binary',root/'target/release/haku-carousel-gpu','--renderer','gpu',
        '--shell-pid',str(pid),'--images',*images],text=True,timeout=65)
    result=json.loads(output);result['trial']=trial+1
    results.append(result);print(json.dumps(result),flush=True)
    if result['exit_code']!=0:raise SystemExit('GPU prototype failed')
summary={phase:{key:round(statistics.median(r['phases'][phase][key] for r in results),2)
    for key in ['cpu_one_core_mean_pct','pss_mean_MiB','combined_cpu_mean_pct','combined_pss_mean_MiB','combined_swap_pss_mean_MiB']}
    for phase in ['idle','navigation','idle_after']}
print(json.dumps(dict(inputs=images,shell_pid=pid,closed_shell_pss_mean_MiB=round(statistics.mean(baseline),2),median_of_3_runs=summary),indent=2),flush=True)
