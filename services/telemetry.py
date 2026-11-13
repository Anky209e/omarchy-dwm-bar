"""Bounded local CPU, memory and GPU reads."""
import json
from pathlib import Path
import re
import subprocess
import sys
import time


def query(command):
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=2)
        return result.stdout[:262144] if result.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def cpu_memory(proc=Path('/proc')):
    fields = (proc / 'stat').read_text().splitlines()[0].split()[1:9]
    times = [int(value) for value in fields]
    if len(times) != 8 or any(value < 0 for value in times):
        raise ValueError('Invalid CPU counters')
    memory = {}
    for line in (proc / 'meminfo').read_text().splitlines():
        key, _, value = line.partition(':')
        if key in ('MemTotal', 'MemAvailable'):
            memory[key] = int(value.split()[0])
    total, available = memory['MemTotal'], memory['MemAvailable']
    if total <= 0 or available < 0 or available > total:
        raise ValueError('Invalid memory counters')
    # Guest CPU counters are already included in user and nice.
    return {'total': sum(times), 'idle': times[3] + times[4], 'ram': round(100 * (1 - available / total))}


def hardware(snapshot=False):
    first = cpu_memory()
    if not snapshot:
        return first
    time.sleep(0.2)
    result = cpu_memory()
    delta = result['total'] - first['total']
    result['cpu'] = max(0, min(100, round(100 * (1 - (result['idle'] - first['idle']) / delta)))) if delta > 0 else None
    return result


def parse_gpu(raw):
    match = re.fullmatch(r'\s*(\d{1,3})\s*,\s*(\d{1,3})\s*', raw)
    if not match:
        return {'available': False}
    load, temperature = map(int, match.groups())
    return {'available': True, 'gpu': load, 'temperature': temperature} if load <= 100 and temperature <= 150 else {'available': False}



def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'hardware'
    try:
        if mode in ('hardware', 'snapshot'):
            result = hardware(mode == 'snapshot')
        elif mode == 'gpu':
            result = parse_gpu(query(['nvidia-smi', '--query-gpu=utilization.gpu,temperature.gpu', '--format=csv,noheader,nounits', '-i', '0']))
        else:
            raise ValueError('Unknown mode')
        print(json.dumps(result))
    except (OSError, ValueError, KeyError, IndexError):
        print('{}')


if __name__ == '__main__':
    main()
