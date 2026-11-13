"""Validated user preferences; never execute values from configuration."""
import json
import os
from pathlib import Path
import tempfile

DEFAULTS = {
    'fastInterval': 2, 'gpuInterval': 5, 'cpuWarn': 90, 'ramWarn': 90,
    'gpuWarn': 95, 'tempWarm': 75, 'tempHot': 85, 'musicWidth': 240,
    'gamingEfficiency': True, 'sleepAware': True, 'visualizer': True,
    'remoteArtwork': False, 'showCpu': True, 'showRam': True, 'showGpu': True,
    'showVolume': True, 'showTemperature': True, 'showIndicators': True,
    'showTray': True, 'showConnections': True, 'showMusic': True,
    'monitorDefault': 'full', 'monitors': {}, 'gameClasses': [],
}
RANGES = {'fastInterval': (1, 30), 'gpuInterval': (2, 120), 'cpuWarn': (1, 100),
          'ramWarn': (1, 100), 'gpuWarn': (1, 100), 'tempWarm': (30, 110),
          'tempHot': (40, 120), 'musicWidth': (120, 480)}
MODES = ('full', 'minimal', 'hidden')


def normalize(raw):
    result = dict(DEFAULTS, monitors={}, gameClasses=[])
    if not isinstance(raw, dict):
        return result
    for key, default in DEFAULTS.items():
        value = raw.get(key, default)
        if key in RANGES:
            low, high = RANGES[key]
            if isinstance(value, (int, float)) and not isinstance(value, bool) and low <= value <= high:
                result[key] = int(value)
        elif isinstance(default, bool):
            if isinstance(value, bool): result[key] = value
        elif key == 'monitorDefault' and value in MODES:
            result[key] = value
        elif key == 'monitors' and isinstance(value, dict):
            result[key] = {name: mode for name, mode in list(value.items())[:32]
                           if isinstance(name, str) and 0 < len(name) <= 128
                           and name not in ('__proto__', 'constructor', 'prototype') and mode in MODES}
        elif key == 'gameClasses' and isinstance(value, list):
            result[key] = [item for item in value[:64] if isinstance(item, str) and 0 < len(item) <= 128]
    result['tempHot'] = max(result['tempWarm'], result['tempHot'])
    return result


def config_path():
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'omarchy/dwm-bar.json'


def load(path=None):
    try:
        return normalize(json.loads((path or config_path()).read_text()[:65536]))
    except (OSError, ValueError):
        return normalize({})


def save(values, path=None):
    path = path or config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.dwm-bar-', delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(normalize(values), stream, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        if path.exists():
            # One bounded rollback copy; no timestamps accumulate per UI edit.
            path.with_suffix('.json.bak').write_bytes(path.read_bytes()[:65536])
        temporary.replace(path)
    finally:
        if temporary and temporary.exists(): temporary.unlink()
