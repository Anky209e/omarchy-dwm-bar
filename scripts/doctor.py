#!/usr/bin/env python3
"""Read-only install diagnostics. No network, package installs or GPU queries."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

repo=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(repo/'services'))
from sensors import VENDORS, devices, power

required=['python','quickshell','omarchy','omarchy-shell','wpctl']
optional=['btop','htop','top','nvtop','cava','nvidia-smi','busctl']
report={'required':{name:bool(shutil.which(name)) for name in required},
        'optional':{name:bool(shutil.which(name)) for name in optional},
        'hostFiles':{name:(Path('/usr/share/omarchy/shell')/name).is_file() for name in ['plugins/bar/Bar.qml','plugins/bar/BarModel.js','Ui/KeyboardPanel.qml','Ui/WidgetButton.qml']},
        'testedOmarchy':'4.5.0-3','testedQuickshell':'0.3.2',
        'gpus':[{'vendor':VENDORS[vendor],'pci':device.name,'power':power(device)} for device,vendor in devices()]}
for name,command in [('omarchyVersion',['omarchy','version']),('quickshellVersion',['quickshell','--version'])]:
    try:report[name]=subprocess.check_output(command,text=True,timeout=3,stderr=subprocess.DEVNULL).strip()[:256]
    except (OSError,subprocess.SubprocessError):report[name]='unavailable'
report['notes']=['Intel utilization is not implemented; exposed Intel GPU temperatures can be shown.',
                 'AMD requires readable gpu_busy_percent and optionally hwmon temperature.',
                 'Missing optional monitor tools fall back to btop, htop or top.',
                 'Optional cava enables the music visualizer. No package is installed automatically.',
                 'Presence checks do not prove compatibility with untested Omarchy versions.']
print(json.dumps(report,indent=2))
sys.exit(0 if all(report['required'].values()) and all(report['hostFiles'].values()) else 1)
