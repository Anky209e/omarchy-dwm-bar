"""Bounded local hardware reads and event-triggered fullscreen game detection."""
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


def read_environment(pid):
    if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
        return b''
    try:
        with (Path('/proc') / str(pid) / 'environ').open('rb') as stream:
            return stream.read(65536)
    except OSError:
        return b''


def is_game(client, extra_classes=(), environment=read_environment):
    names = {str(client.get(key, '')).casefold() for key in ('class', 'initialClass')}
    known = {'gamescope', 'cs2', 'dota2', 'hl2', 'hl_linux', 'retroarch', 'org.libretro.retroarch'}
    extra = {item.casefold() for item in extra_classes[:64] if isinstance(item, str) and 0 < len(item) <= 128}
    if names & (known | extra) or any(re.fullmatch(r'steam_app_[1-9]\d*', name) for name in names):
        return True
    # Check only Steam identifiers. Never return or log process environments.
    return any(re.fullmatch(rb'(SteamAppId|SteamGameId)=[1-9]\d*', entry) for entry in environment(client.get('pid')).split(b'\0'))


def detect_games(clients, monitors, extra_classes=(), environment=read_environment):
    visible = set()
    for monitor in monitors[:32]:
        if not isinstance(monitor, dict):
            continue
        for key in ('activeWorkspace', 'specialWorkspace'):
            workspace = monitor.get(key, {})
            if isinstance(workspace, dict) and isinstance(workspace.get('id'), int) and workspace['id'] != 0:
                visible.add(workspace['id'])
    count = 0
    for client in clients[:1024]:
        if not isinstance(client, dict):
            continue
        fullscreen = client.get('fullscreen', 0)
        workspace = client.get('workspace', {})
        if not isinstance(fullscreen, int) or not fullscreen & 2 or not isinstance(workspace, dict) or workspace.get('id') not in visible:
            continue
        if client.get('mapped') is False or client.get('hidden') is True:
            continue
        if is_game(client, extra_classes, environment):
            count += 1
    return {'gaming': count > 0, 'games': count}


def gaming(options):
    clients = json.loads(query(['hyprctl', '-j', 'clients']) or '[]')
    monitors = json.loads(query(['hyprctl', '-j', 'monitors']) or '[]')
    if not isinstance(clients, list) or not isinstance(monitors, list):
        return {'gaming': False, 'games': 0}
    classes = options.get('classes', []) if isinstance(options, dict) else []
    return detect_games(clients, monitors, classes if isinstance(classes, list) else [])


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'hardware'
    try:
        if mode in ('hardware', 'snapshot'):
            result = hardware(mode == 'snapshot')
        elif mode == 'gpu':
            result = parse_gpu(query(['nvidia-smi', '--query-gpu=utilization.gpu,temperature.gpu', '--format=csv,noheader,nounits', '-i', '0']))
        elif mode == 'gaming':
            result = gaming(json.loads(sys.argv[2][:16384]) if len(sys.argv) > 2 else {})
        else:
            raise ValueError('Unknown mode')
        print(json.dumps(result))
    except (OSError, ValueError, KeyError, IndexError):
        print('{}')


if __name__ == '__main__':
    main()
