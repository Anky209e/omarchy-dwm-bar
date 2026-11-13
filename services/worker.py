"""One persistent local reader. Commands and events are bounded JSON lines."""
import concurrent.futures
import json
import os
from pathlib import Path
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from artwork import fetch
from preferences import load, normalize, save
from telemetry import hardware, parse_gpu, query


def gpu_power(sysroot=Path('/sys/bus/pci/devices')):
    """Read kernel power state without opening the NVIDIA device."""
    try:
        candidates = sorted(sysroot.iterdir())
    except OSError:
        return 'unknown'
    states = []
    for device in candidates:
        try:
            if (device / 'vendor').read_text().strip().lower() != '0x10de': continue
            if not (device / 'class').read_text().strip().startswith('0x03'): continue
        except OSError:
            continue
        try:
            states.append((device / 'power/runtime_status').read_text().strip())
        except OSError:
            states.append('unknown')
    if not states: return 'missing'
    # Do not probe a sleeping device just to discover the nvidia-smi index.
    if any(state in ('suspended', 'suspending') for state in states): return 'sleep'
    return 'active' if all(state == 'active' for state in states) else 'unknown'


def read_gpu(sleep_aware=True):
    power = gpu_power()
    if power == 'missing': return {'available': False, 'status': 'missing'}
    if sleep_aware and power in ('sleep', 'unknown'): return {'available': False, 'status': power}
    data = parse_gpu(query(['nvidia-smi', '--query-gpu=utilization.gpu,temperature.gpu', '--format=csv,noheader,nounits', '-i', '0']))
    return dict(data, status='ok' if data['available'] else 'error')


def emit(event, **values):
    print(json.dumps(dict(event=event, **values), separators=(',', ':')), flush=True)


class Worker:
    def __init__(self):
        self.settings = load()
        self.paused = True
        self.next_fast = self.next_gpu = time.monotonic()
        self.fast_count = self.gpu_count = 0
        self.cava = None
        self.cava_config = None
        self.cava_buffer = b''
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.art = None
        self.pending_art = None

    def send_settings(self):
        emit('settings', values=self.settings)

    def sample_fast(self, manual=False):
        self.fast_count += 1
        try: emit('hardware', status='ok', data=hardware(manual), at=time.time(), count=self.fast_count)
        except (OSError, ValueError, KeyError, IndexError): emit('hardware', status='error', at=time.time(), count=self.fast_count)

    def sample_gpu(self):
        self.gpu_count += 1
        data = read_gpu(self.settings['sleepAware'])
        emit('gpu', data=data, status=data['status'], at=time.time(), count=self.gpu_count)

    def stop_cava(self):
        if self.cava:
            self.cava.terminate()
            try: self.cava.wait(timeout=0.5)
            except subprocess.TimeoutExpired: self.cava.kill(); self.cava.wait()
            self.cava.stdout.close()
            self.cava = None
        if self.cava_config:
            Path(self.cava_config).unlink(missing_ok=True)
            self.cava_config = None
        self.cava_buffer = b''

    def visualizer(self, enabled):
        if not enabled or self.paused or not self.settings['visualizer']:
            self.stop_cava(); emit('spectrum', bars=[0] * 16, status='off'); return
        if self.cava: return
        if not shutil.which('cava'):
            emit('spectrum', bars=[0] * 16, status='unavailable'); return
        with tempfile.NamedTemporaryFile(mode='w', prefix='dwm-cava-', suffix='.conf', delete=False) as stream:
            stream.write('[general]\nbars=16\nframerate=20\n[input]\nmethod=pulse\nsource=auto\n[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=binary\nbit_format=8bit\nchannels=mono\n')
            self.cava_config = stream.name
        try:
            self.cava = subprocess.Popen(['cava', '-p', self.cava_config], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            os.set_blocking(self.cava.stdout.fileno(), False)
            emit('spectrum', bars=[0] * 16, status='ok')
        except OSError:
            self.stop_cava(); emit('spectrum', bars=[0] * 16, status='unavailable')

    def request_art(self, message):
        if self.art and not self.art.done():
            self.pending_art = message
        else:
            self.art_id = str(message.get('request', ''))[:4096]
            self.art = self.executor.submit(fetch, message.get('url', ''), self.settings['remoteArtwork'])

    def command(self, message):
        command = message.get('command')
        if command == 'pause':
            was = self.paused
            self.paused = self.settings['gameMode'] or message.get('paused') is True
            if self.paused: self.visualizer(False)
            if was and not self.paused: self.next_fast = self.next_gpu = time.monotonic()
        elif command == 'refresh':
            self.sample_fast(True); self.sample_gpu()
        elif command == 'settings':
            patch = message.get('patch', {})
            if isinstance(patch, dict):
                candidate = normalize(dict(load(), **patch))
                try:
                    save(candidate)
                    was_paused = self.paused
                    self.settings = candidate
                    self.paused = self.settings['gameMode']
                    if self.paused or not self.settings['visualizer']: self.visualizer(False)
                    if was_paused and not self.paused: self.next_fast = self.next_gpu = time.monotonic()
                    self.send_settings()
                except OSError: emit('settingsError')
        elif command == 'reload':
            self.settings = load(); self.send_settings()
        elif command == 'visualizer':
            self.visualizer(message.get('enabled') is True)
        elif command == 'art':
            self.request_art(message)

    def run(self):
        self.send_settings()
        buffer = b''
        try:
            while True:
                now = time.monotonic()
                delay = min(max(0, self.next_fast - now), max(0, self.next_gpu - now)) if not self.paused else 30
                if self.art: delay = min(delay, 0.1)
                readers = [sys.stdin.fileno()]
                if self.cava: readers.append(self.cava.stdout.fileno())
                ready, _, _ = select.select(readers, [], [], delay)
                if sys.stdin.fileno() in ready:
                    data = os.read(sys.stdin.fileno(), 65536)
                    if not data: return
                    buffer += data
                    if len(buffer) > 131072: buffer = b''
                    while b'\n' in buffer:
                        line, buffer = buffer.split(b'\n', 1)
                        try:
                            message = json.loads(line[:65536])
                            if isinstance(message, dict): self.command(message)
                        except (ValueError, TypeError): continue
                if self.cava and self.cava.stdout.fileno() in ready:
                    try: data = os.read(self.cava.stdout.fileno(), 4096)
                    except BlockingIOError: data = None
                    except OSError: data = b''
                    if data is None: pass
                    elif not data:
                        self.stop_cava(); emit('spectrum', bars=[0]*16, status='unavailable')
                    elif data:
                        self.cava_buffer = (self.cava_buffer + data)[-4096:]
                        if len(self.cava_buffer) >= 16:
                            frames = len(self.cava_buffer) // 16
                            bars = self.cava_buffer[(frames-1)*16:frames*16]
                            self.cava_buffer = self.cava_buffer[frames*16:]
                            emit('spectrum', bars=[round(value/255, 3) for value in bars], status='ok')
                if self.art and self.art.done():
                    try: result = self.art.result()
                    except Exception: result = {'source':'', 'status':'unavailable'}
                    emit('art', request=self.art_id, **result)
                    self.art = None
                    if self.pending_art:
                        message, self.pending_art = self.pending_art, None
                        self.request_art(message)
                now = time.monotonic()
                if not self.paused and now >= self.next_fast:
                    self.sample_fast(); self.next_fast = time.monotonic() + self.settings['fastInterval']
                if not self.paused and now >= self.next_gpu:
                    self.sample_gpu(); self.next_gpu = time.monotonic() + self.settings['gpuInterval']
        finally:
            self.stop_cava()
            self.executor.shutdown(wait=False, cancel_futures=True)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try: Worker().run()
    except (BrokenPipeError, KeyboardInterrupt): pass
