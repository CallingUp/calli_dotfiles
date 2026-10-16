#!/usr/bin/env python3
"""Finite read-only UI exercise; no keyboard injection or wallpaper changes."""
import json
import os
from pathlib import Path
import selectors
import statistics
import subprocess
import time
import argparse

parser=argparse.ArgumentParser()
parser.add_argument("--binary",type=Path,default=Path(__file__).resolve().parent / "target/release/haku-carousel-prototype")
parser.add_argument("--renderer",choices=["software","gpu"],default="software")
parser.add_argument("--images",nargs=3)
parser.add_argument("--shell-pid",type=int)
args=parser.parse_args()
env=dict(os.environ)
if args.renderer=="gpu":
    env.update(WGPU_POWER_PREF="low",WGPU_BACKEND="vulkan",
               VK_DRIVER_FILES="/usr/share/vulkan/icd.d/intel_icd.json")
proc = subprocess.Popen([args.binary, "--exercise",*(args.images or [])], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,env=env)
selector = selectors.DefaultSelector()
selector.register(proc.stdout, selectors.EVENT_READ)
phase = "startup"
samples = {}
previous = None
deadline = time.monotonic() + 55
frames={}
phase_started=time.monotonic()
system_start=Path('/proc/stat').read_text().splitlines()[0].split()[1:9]
system_start=list(map(int,system_start))

def shell_sample():
    if not args.shell_pid:return 0,0.0,0.0
    p=Path(f'/proc/{args.shell_pid}')
    fields=(p/'stat').read_text().rsplit(')',1)[1].split()
    mem={}
    for line in (p/'smaps_rollup').read_text().splitlines():
        if line.startswith(('Pss:','SwapPss:')):
            k,v=line.split(':',1);mem[k]=int(v.split()[0])/1024
    return int(fields[11])+int(fields[12]),mem['Pss'],mem['SwapPss']

try:
    while proc.poll() is None and time.monotonic() < deadline:
        for key, _ in selector.select(timeout=1):
            line = key.fileobj.readline().strip()
            if "phase=" in line:
                phase = line.split("phase=", 1)[1]
                previous = None
                phase_started=time.monotonic()
            if line.startswith("FRAMES:"):
                frames=json.loads(line[7:])
        try:
            fields = Path(f"/proc/{proc.pid}/stat").read_text().rsplit(")", 1)[1].split()
            ticks = int(fields[11]) + int(fields[12])
            now = time.monotonic()
            shell_ticks,shell_pss,shell_swap=shell_sample()
            memory = {}
            for line in Path(f"/proc/{proc.pid}/smaps_rollup").read_text().splitlines():
                if line.startswith(("Pss:", "SwapPss:")):
                    k, v = line.split(":", 1)
                    memory[k] = int(v.split()[0]) / 1024
            if previous is not None and now - previous[0] >= 0.25 and now-phase_started>=1.0:
                cpu = (ticks - previous[1]) / os.sysconf("SC_CLK_TCK") / (now - previous[0]) * 100
                shell_cpu=(shell_ticks-previous[2])/os.sysconf('SC_CLK_TCK')/(now-previous[0])*100
                samples.setdefault(phase, []).append((cpu, memory.get("Pss", 0),cpu+shell_cpu,
                    memory.get('Pss',0)+shell_pss,memory.get('SwapPss',0)+shell_swap))
            previous = (now, ticks,shell_ticks)
        except (FileNotFoundError, ProcessLookupError):
            break
    if proc.poll() is None:
        proc.terminate()
    code = proc.wait(timeout=5)
    for line in proc.stdout.read().splitlines():
        if line.startswith("FRAMES:"):frames=json.loads(line[7:])
    diagnostics=proc.stderr.read()
    system_end=list(map(int,Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    total=sum(system_end)-sum(system_start)
    idle=(system_end[3]+system_end[4])-(system_start[3]+system_start[4])
    print(json.dumps({"exit_code": code, "renderer": args.renderer,
        "system_busy_pct":round((1-idle/total)*100,2) if total else 0,
        "frames":frames,"adapter_diagnostics":diagnostics.strip(),"phases": {
        phase: {"samples": len(values), "cpu_one_core_mean_pct": round(statistics.mean(v[0] for v in values), 2),
                "pss_mean_MiB": round(statistics.mean(v[1] for v in values), 2),
                "combined_cpu_mean_pct":round(statistics.mean(v[2] for v in values),2),
                "combined_pss_mean_MiB":round(statistics.mean(v[3] for v in values),2),
                "combined_swap_pss_mean_MiB":round(statistics.mean(v[4] for v in values),2)}
        for phase, values in samples.items()
    }}, indent=2))
finally:
    selector.close()
    if proc.poll() is None:
        proc.terminate()
        proc.wait(timeout=5)
