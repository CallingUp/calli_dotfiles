#!/usr/bin/env python3
"""Matched full-catalog comparison; never applies or deletes wallpapers."""
import argparse, json, os, statistics, subprocess, time
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
binary = repo/'tools/haku-carousel-prototype/target/release/haku-carousel'
config = repo/'config/quickshell/minflair-niri/niri-preview.qml'
worker = repo/'tools/haku-wallpaper/target/release/haku-wallpaper'
parser=argparse.ArgumentParser()
parser.add_argument('--modes',default='qml,rust',help='Comma-separated qml,qml-base,qml-opt,rust,canvas,gpu')
modes=parser.parse_args().modes.split(',')
if not modes or len(set(modes))!=len(modes) or any(m not in ['qml','qml-base','qml-opt','rust','canvas','gpu'] for m in modes):raise SystemExit('Invalid modes')
def run(args):
    try:
        return subprocess.run(list(map(str,args)),capture_output=True,text=True,timeout=20)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f'Command timed out: {args[0]} (request omitted)') from None
def ipc(method,*args):
    result=run(['quickshell','ipc','-p',config,'call','haku-wallpaper-host',method,*args])
    if result.returncode: raise RuntimeError(result.stderr)
    return result.stdout.strip()
def find_shell():
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            if (p/'comm').read_text().strip()=='quickshell' and str(config).encode() in (p/'cmdline').read_bytes():return int(p.name)
        except OSError:pass
    raise RuntimeError('The shared Quickshell bar is not running')
shell_pid=find_shell()
catalog=json.loads(subprocess.check_output([worker],input='{"action":"list"}\n',text=True))
colors=Path.home()/'.local/state/haku_theme/colors.css'
request=dict(catalog,accent='#B99573',font='Maple Mono NF')
def sample(extra=None):
    procs={}
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            f=(p/'stat').read_text().rsplit(')',1)[1].split()
            procs[int(p.name)]=(int(f[1]),int(f[11])+int(f[12]))
        except (OSError,ValueError):pass
    if extra and extra not in procs:raise RuntimeError('Carousel exited during measurement; discard this round')
    selected={shell_pid}
    if extra:selected.add(extra)
    for _ in range(8):
        selected.update(pid for pid,(parent,_) in procs.items() if parent in selected)
    mem=swap=0
    ticks={}
    for pid in selected:
        if pid not in procs:continue
        ticks[pid]=procs[pid][1]
        try:
            for line in Path(f'/proc/{pid}/smaps_rollup').read_text().splitlines():
                if line.startswith('Pss:'):mem+=int(line.split()[1])/1024
                if line.startswith('SwapPss:'):swap+=int(line.split()[1])/1024
        except OSError:pass
    return time.monotonic(),ticks,mem,swap
def phase(seconds,extra=None,step=None):
    previous=sample(extra);start=time.monotonic();values=[]
    for i in range(int(seconds*4)):
        if step:step()
        time.sleep(max(0,start+(i+1)*.25-time.monotonic()))
        current=sample(extra)
        cpu=sum(max(0,ticks-previous[1].get(pid,ticks)) for pid,ticks in current[1].items())/os.sysconf('SC_CLK_TCK')/(current[0]-previous[0])*100
        if i>=4:values.append((cpu,current[2],current[3]))
        previous=current
    return dict(cpu_pct=round(statistics.mean(x[0] for x in values),2),pss_MiB=round(statistics.mean(x[1] for x in values),2),swap_pss_MiB=round(statistics.mean(x[2] for x in values),2))
results=[]
proc=None
try:
    run([binary,'--close']);ipc('close');time.sleep(.4)
    for trial in range(3):
        for mode in (modes if trial%2==0 else modes[::-1]):
            base=phase(4)
            if mode.startswith('qml'):
                configured=dict(request)
                if mode!='qml':configured['optimizeThumbnails']=mode=='qml-opt'
                ipc('toggle',json.dumps(configured,separators=(',',':'),ensure_ascii=False));pid=None
                step=lambda:ipc('step','1')
                def verify():
                    if ipc('status')!='open':raise RuntimeError('QML carousel closed; discard this round')
                    if mode!='qml':
                        state=json.loads(subprocess.check_output(['quickshell','ipc','-p',str(config),'call','haku-wallpaper','status'],text=True,timeout=5))
                        if state['optimized']!=(mode=='qml-opt'):raise RuntimeError('Wrong QML optimization mode')
            else:
                env=dict(os.environ,WGPU_POWER_PREF='low',WGPU_BACKEND='vulkan',VK_DRIVER_FILES='/usr/share/vulkan/icd.d/intel_icd.json')
                if mode in ['canvas','gpu']:env['HAKU_CAROUSEL_RENDERER']=mode
                proc=subprocess.Popen([binary],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);pid=proc.pid
                for _ in range(80):
                    s=run([binary,'--status'])
                    if s.returncode==0 and json.loads(s.stdout)['localItems']>0:break
                    time.sleep(.1)
                else:raise RuntimeError('Rust did not open')
                def step():
                    response=run([binary,'--step','1'])
                    if response.returncode:raise RuntimeError('Rust navigation failed; discard this round')
                def verify():
                    response=run([binary,'--status'])
                    if proc.poll() is not None or response.returncode:raise RuntimeError('Rust carousel exited; discard this round')
                    if mode in ['canvas','gpu'] and json.loads(response.stdout)['cardRenderer']!=mode:raise RuntimeError('Wrong renderer')
            time.sleep(1)
            verify()
            opened=phase(5,pid)
            verify()
            navigation=phase(10,pid,step)
            verify()
            settled=phase(4,pid)
            verify()
            diagnostics=None
            if mode.startswith('qml'):
                diagnostics=json.loads(subprocess.check_output(['quickshell','ipc','-p',str(config),'call','haku-wallpaper','status'],text=True,timeout=5))
            if mode.startswith('qml'):ipc('close')
            else:run([binary,'--close']);proc.wait(timeout=5);proc=None
            closed=phase(4)
            result=dict(mode=mode,trial=trial+1,baseline=base,open_idle=opened,navigation=navigation,settled=settled,closed=closed,diagnostics=diagnostics)
            results.append(result);print(json.dumps(result),flush=True)
    summary={mode:{phase_name:{key:round(statistics.median(r[phase_name][key] for r in results if r['mode']==mode),2) for key in ['cpu_pct','pss_MiB','swap_pss_MiB']} for phase_name in ['baseline','open_idle','navigation','settled','closed']} for mode in modes}
    report=dict(catalog_items=len(catalog['rows']),navigation='40 forward steps at 250 ms; full real catalog',summary=summary,trials=results,limitations='Includes shared shell and live descendants; short-lived children between samples and GPU memory are not fully accounted for. CPU is percent of one logical core.')
    destination=Path('/tmp/haku-carousel-full-comparison-'+time.strftime('%Y%m%d-%H%M%S')+'.json')
    destination.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(report=str(destination),summary=summary),indent=2),flush=True)
finally:
    ipc('close');run([binary,'--close'])
    if proc is not None:proc.wait(timeout=5)
