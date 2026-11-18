#!/usr/bin/env python3
"""Opt-in desktop smoke checks; restores changed bar preferences on exit."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--exercise',action='store_true',help='Temporarily exercise drawer, Game mode, monitor profiles and panel routing')
args=parser.parse_args()
def ipc(target,method,*values):
    return subprocess.check_output(['omarchy-shell',target,method,*values],text=True,timeout=5).strip()
def telemetry(): return json.loads(ipc('dwm.bar','telemetry'))
def geometry(): return json.loads(ipc('shell','debugBarGeometry'))
def wait_for(check):
    deadline=time.monotonic()+8
    while time.monotonic()<deadline:
        if check(): return
        time.sleep(.1)
    raise AssertionError('Desktop state did not settle')
prefs=Path(os.environ.get('XDG_CONFIG_HOME',str(Path.home()/'.config')))/'omarchy/dwm-bar.json'
original=json.loads(prefs.read_text())
keys=['overflowAlways','gameMode','monitors']
def patch(values):
    current=json.loads(prefs.read_text());current.update(values)
    temporary=prefs.with_name('.dwm-smoke.json')
    temporary.write_text(json.dumps(current,indent=2)+'\n');temporary.replace(prefs)
    ipc('dwm.bar','reloadSettings')
assert telemetry()['backendRunning']
outputs=[s['name'] for s in json.loads(subprocess.check_output(['hyprctl','monitors','-j'],text=True))]
print('Active outputs:', ', '.join(outputs))
if args.exercise:
    try:
        patch({'overflowAlways':True,'gameMode':False})
        wait_for(lambda: len([e for e in geometry() if e['id']=='dwm.overflow' and e['visible']])==len(outputs))
        configured={e['id'] for e in geometry()}
        for control in ['omarchy.network','omarchy.audio','omarchy.agents','crmne.hyprmoncfg']:
            if control not in configured: continue
            assert ipc('dwm.bar.ui','control',control)=='true',control
            time.sleep(.2)
        ipc('dwm.bar.ui','overflow');time.sleep(.2);ipc('dwm.bar.ui','close')
        patch({'gameMode':True})
        wait_for(lambda:telemetry()['hardwarePaused'])
        time.sleep(.2);before=telemetry();time.sleep(2.2);after=telemetry()
        assert before['fastRequests']==after['fastRequests']
        assert before['gpuRequests']==after['gpuRequests']
        patch({'gameMode':False})
        wait_for(lambda: not telemetry()['hardwarePaused'])
        # Exercise a secondary output if one is available; restore in finally.
        name=outputs[-1];modes=dict(original.get('monitors',{}));modes[name]='minimal'
        patch({'monitors':modes})
        wait_for(lambda:sum(e['id']=='dwm.status' and e['visible'] for e in geometry())==len(outputs)-1)
        modes[name]='full';patch({'monitors':modes})
        wait_for(lambda:sum(e['id']=='dwm.status' and e['visible'] for e in geometry())==len(outputs))
        print('Passed: per-output drawer, native/Agents/monitor panel routing, Game mode pause/resume, minimal/full profiles.')
    finally:
        ipc('dwm.bar.ui','close')
        current=json.loads(prefs.read_text())
        for key in keys:
            if key in original:current[key]=original[key]
            else:current.pop(key,None)
        temporary=prefs.with_name('.dwm-smoke.json');temporary.write_text(json.dumps(current,indent=2)+'\n');temporary.replace(prefs)
        ipc('dwm.bar','reloadSettings')
print('Backend:',telemetry())
