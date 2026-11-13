#!/usr/bin/env python3
"""Validate the single Omarchy bar plugin and its private components."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--runtime', action='store_true', help='Also check the active graphical bar; never changes desktop settings')
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
manifest = json.loads((repo / 'manifest.json').read_text())
assert manifest['id'] == 'anky.dwm-bar'
assert manifest['kinds'] == ['bar']
assert manifest['entryPoints'] == {'bar': 'DwmBar.qml'}
assert sorted(p.relative_to(repo).as_posix() for p in repo.rglob('manifest.json') if '.git' not in p.parts) == ['manifest.json'], 'Companion plugin manifests must not return'
assert not (repo / 'scripts/install.py').exists(), 'A separate installer must not be required'
assert (repo / 'widgets/tray/LICENSE').is_file()
subprocess.run(['omarchy', 'plugin', 'validate', str(repo)], check=True)
print('Validated: one root bar manifest, no companion installs, bundled licensed tray.', flush=True)
env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
subprocess.run(['node', 'tests/parsers.test.js'], cwd=repo, env=env, check=True)
subprocess.run(['node', 'tests/bar.test.js'], cwd=repo, env=env, check=True)
subprocess.run([sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py', '-v'], cwd=repo, env=env, check=True)
if args.runtime:
    plugins = json.loads(subprocess.check_output(['omarchy', 'plugin', 'list', '--json'], text=True))
    active = next(p for p in plugins if p['id'] == 'anky.dwm-bar')
    assert active['active'], 'Single bar plugin did not become active'
    required = {'dwm.workspaces', 'dwm.music', 'dwm.status', 'dwm.temperature', 'dwm.indicators', 'dwm.divider', 'dwm.tray', 'omarchy.clock', 'omarchy.audio', 'omarchy.network'}
    # Plugin selection precedes asynchronous per-monitor QML incubation.
    # An immediate post-restart check must wait for the widgets to appear.
    deadline = time.monotonic() + 8
    ids = set()
    while time.monotonic() < deadline:
        geometry = json.loads(subprocess.check_output(['omarchy-shell', 'shell', 'debugBarGeometry'], text=True, timeout=2))
        ids = {entry['id'] for entry in geometry}
        if required <= ids:
            break
        time.sleep(0.1)
    assert required <= ids, f'Missing widgets after startup: {required - ids}'
    assert not any(name.startswith('anky.') or name == 'whitewebdev.flat-tray' for name in ids), 'A legacy companion is still rendering'
    telemetry = json.loads(subprocess.check_output(['omarchy-shell', 'dwm.bar', 'telemetry'], text=True))
    assert isinstance(telemetry['hardwarePaused'], bool)
    assert isinstance(telemetry['fastRequests'], int) and isinstance(telemetry['gpuRequests'], int)
    print('Runtime check passed: one active bar renders private widgets with shared telemetry:', telemetry)
