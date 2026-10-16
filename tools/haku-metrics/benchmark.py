"""Compare helpers' proportional RAM after their first valid sample."""
import json
import selectors
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMANDS = {
    'python_before': ['python3', str(ROOT / 'config/quickshell/minflair-niri/Scripts/system/get_processes.py'),
                      '4000', 'cpu', '--daemon', '--no-processes'],
    'rust_after': [str(Path(__file__).parent / 'target/release/haku-metrics'), '4000'],
}


def measure(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stdin=subprocess.DEVNULL, text=True)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            if not selector.select(15):
                raise RuntimeError('Metrics helper did not produce a sample within 15s')
        sample = json.loads(process.stdout.readline())
        for key in ('cpu_usage', 'mem_used_gb', 'mem_usage', 'cpu_temp', 'uptime'):
            assert key in sample['system'], key
        rollup = Path(f'/proc/{process.pid}/smaps_rollup').read_text()
        memory = {line.split(':')[0]: int(line.split()[1]) for line in rollup.splitlines()
                  if line.startswith(('Rss:', 'Pss:', 'Private_Clean:', 'Private_Dirty:'))}
        return {'memory_kib': memory, 'sample': sample['system']}
    finally:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == '__main__':
    print(json.dumps({name: measure(command) for name, command in COMMANDS.items()}, indent=2))
