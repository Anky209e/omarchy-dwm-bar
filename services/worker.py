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

from artwork import fetch, secure_existing_cache
from preferences import load, normalize, save
from telemetry import hardware
from sensors import read_gpu
from tray_icons import resolve as resolve_tray_icon
from tray_pixmaps import resolve as resolve_tray_pixmap



def close_inherited_fds():
    """Qt can pass non-CLOEXEC graphics handles; this worker needs only stdio."""
    for name in os.listdir('/proc/self/fd'):
        try:
            descriptor=int(name)
            if descriptor>2:os.close(descriptor)
        except (ValueError,OSError):pass


def emit(event, **values):
    print(json.dumps(dict(event=event, **values), separators=(',', ':')), flush=True)


class Worker:
    def __init__(self):
        self.settings = load()
        self.paused = True
        self.fast_enabled = self.gpu_enabled = True
        self.next_fast = self.next_gpu = time.monotonic()
        self.fast_count = self.gpu_count = 0
        self.cava = None
        self.cava_config = None
        self.cava_buffer = b''
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.art = None
        self.pending_art = None
        self.art_cancelled = False
        self.tray_jobs = {}
        self.pixmap_executor=concurrent.futures.ThreadPoolExecutor(max_workers=1)
        self.pixmap_jobs={}
        self.pixmap_pending={}

    def send_settings(self):
        emit('settings', values=self.settings)
        emit('capabilities', values={name:shutil.which(name) is not None for name in ['btop','htop','top','nvtop','cava','nvidia-smi']})

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
            self.art_cancelled = False
            self.art_id = str(message.get('request', ''))[:4096]
            self.art = self.executor.submit(fetch, message.get('url', ''), self.settings['remoteArtwork'])

    def command(self, message):
        command = message.get('command')
        if command == 'trayPixmap':
            identity,request=message.get('identity'),message.get('request')
            if isinstance(identity,str) and 0<len(identity)<=256 and isinstance(request,str) and len(request)<=256:
                if identity in self.pixmap_jobs:self.pixmap_pending[identity]=message
                elif len(self.pixmap_jobs)<16:
                    self.pixmap_jobs[identity]=(request,self.pixmap_executor.submit(resolve_tray_pixmap,identity,message.get('attention') is True))
                else:emit('trayPixmap',identity=identity,request=request,source='')
        elif command == 'trayIcon':
            raw=message.get('icon')
            if isinstance(raw,str) and 0<len(raw)<=4096 and raw not in self.tray_jobs:
                if len(self.tray_jobs)<32:self.tray_jobs[raw]=self.executor.submit(resolve_tray_icon,raw)
                else:emit('trayIcon',icon=raw,source='')
        elif command == 'demand':
            fast, gpu = message.get('fast') is True, message.get('gpu') is True
            if fast and not self.fast_enabled:self.next_fast=time.monotonic()
            if gpu and not self.gpu_enabled:self.next_gpu=time.monotonic()
            self.fast_enabled,self.gpu_enabled=fast,gpu
        elif command == 'artCancel':
            self.pending_art=None
            self.art_cancelled=True
            if self.art and self.art.cancel():self.art=None
        elif command == 'pause':
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
                deadlines=[]
                if not self.paused:
                    if self.fast_enabled:deadlines.append(max(0,self.next_fast-now))
                    if self.gpu_enabled:deadlines.append(max(0,self.next_gpu-now))
                delay=min(deadlines,default=30)
                if self.art or self.tray_jobs: delay = min(delay, 0.1)
                if self.pixmap_jobs:delay=min(delay,.02)
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
                for identity,(request,future) in list(self.pixmap_jobs.items()):
                    if not future.done():continue
                    try:source=future.result()
                    except Exception:source=''
                    emit('trayPixmap',identity=identity,request=request,source=source)
                    del self.pixmap_jobs[identity]
                    pending=self.pixmap_pending.pop(identity,None)
                    if pending:self.command(pending)
                for raw,future in list(self.tray_jobs.items()):
                    if not future.done():continue
                    try:source=future.result()
                    except Exception:source=''
                    emit('trayIcon',icon=raw,source=source)
                    del self.tray_jobs[raw]
                if self.art and self.art.done():
                    try: result = self.art.result()
                    except Exception: result = {'source':'', 'status':'unavailable'}
                    if not self.art_cancelled:emit('art', request=self.art_id, **result)
                    self.art = None
                    if self.pending_art:
                        message, self.pending_art = self.pending_art, None
                        self.request_art(message)
                now = time.monotonic()
                if not self.paused and self.fast_enabled and now >= self.next_fast:
                    self.sample_fast(); self.next_fast = time.monotonic() + self.settings['fastInterval']
                if not self.paused and self.gpu_enabled and now >= self.next_gpu:
                    self.sample_gpu(); self.next_gpu = time.monotonic() + self.settings['gpuInterval']
        finally:
            self.stop_cava()
            self.executor.shutdown(wait=False, cancel_futures=True)
            self.pixmap_executor.shutdown(wait=False,cancel_futures=True)


if __name__ == '__main__':
    close_inherited_fds()
    try:secure_existing_cache()
    except (OSError,ValueError):
        print('Artwork cache permissions could not be secured; artwork requests will fail closed.',file=sys.stderr)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    try: Worker().run()
    except (BrokenPipeError, KeyboardInterrupt): pass
