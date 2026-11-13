import io
import json
import os
from pathlib import Path
import select
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SERVICES = Path(__file__).resolve().parents[1] / 'services'
sys.path.insert(0, str(SERVICES))
import artwork
import preferences
import worker


class PreferencesTests(unittest.TestCase):
    def test_bounds_and_types(self):
        values = preferences.normalize({'fastInterval': 0, 'gpuInterval': 500, 'remoteArtwork': '<img src=x>', 'cpuWarn': True, 'gameMode': '<img src=x>', 'gamingEfficiency':True, 'gameClasses':['A'], 'monitors': {'eDP-1': 'minimal', '__proto__': 'hidden', 'bad': 'evil'}})
        self.assertEqual(values['fastInterval'], 2)
        self.assertEqual(values['gpuInterval'], 5)
        self.assertFalse(values['remoteArtwork'])
        self.assertEqual(values['cpuWarn'], 90)
        self.assertFalse(values['gameMode'])
        self.assertNotIn('gamingEfficiency', values)
        self.assertNotIn('gameClasses', values)
        self.assertEqual(values['monitors'], {'eDP-1': 'minimal'})
        self.assertGreaterEqual(preferences.normalize({'tempWarm': 100, 'tempHot': 50})['tempHot'], 100)

    def test_atomic_save_and_backup(self):
        with tempfile.TemporaryDirectory(prefix='dwm-preferences-') as directory:
            path = Path(directory) / 'settings.json'
            preferences.save({'fastInterval': 3, 'monitors': {'eDP-1':'hidden'}}, path)
            self.assertEqual(preferences.load(path)['fastInterval'], 3)
            preferences.save({'fastInterval': 4}, path)
            self.assertEqual(json.loads(path.with_suffix('.json.bak').read_text())['monitors']['eDP-1'], 'hidden')
            self.assertEqual(preferences.load(path)['fastInterval'], 4)
            self.assertEqual(list(path.parent.glob('.dwm-bar-*')), [])
            path.write_text('<img src=x>')
            self.assertEqual(preferences.load(path)['fastInterval'], 2)


class SleepTests(unittest.TestCase):
    def gpu(self, root, name='0000:01:00.0', status='suspended', vendor='0x10de', kind='0x030000'):
        device = root / name
        (device / 'power').mkdir(parents=True)
        (device / 'vendor').write_text(vendor)
        (device / 'class').write_text(kind)
        (device / 'power/runtime_status').write_text(status)
        return device

    def test_sysfs_reads_do_not_open_device(self):
        with tempfile.TemporaryDirectory(prefix='dwm-sysfs-') as directory:
            root = Path(directory)
            device = self.gpu(root)
            self.gpu(root, '0000:01:00.1', kind='0x040300')
            self.assertEqual(worker.gpu_power(root), 'sleep')
            (device / 'power/runtime_status').write_text('active')
            self.assertEqual(worker.gpu_power(root), 'active')
            self.gpu(root, '0000:02:00.0')
            self.assertEqual(worker.gpu_power(root), 'sleep')
            (device / 'power/runtime_status').unlink()
            (root / '0000:02:00.0/power/runtime_status').write_text('active')
            self.assertEqual(worker.gpu_power(root), 'unknown')

    def test_sleeping_or_unknown_gpu_never_invokes_nvidia(self):
        for state in ['sleep', 'unknown', 'missing']:
            with patch.object(worker, 'gpu_power', return_value=state), patch.object(worker, 'query') as query:
                self.assertEqual(worker.read_gpu(True)['status'], state)
                query.assert_not_called()
        with patch.object(worker, 'gpu_power', return_value='sleep'), patch.object(worker, 'query', return_value='12, 48') as query:
            self.assertEqual(worker.read_gpu(False)['status'], 'ok')
            query.assert_called_once()


class ArtworkTests(unittest.TestCase):
    def png(self, width=2, height=2):
        return b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR' + struct.pack('>II',width,height) + b'\x08\x02\x00\x00\x00'

    def test_hosts_tls_and_userinfo(self):
        self.assertTrue(artwork.remote_allowed('https://i.scdn.co/image/cover'))
        for url in ['http://i.scdn.co/cover', 'https://i.scdn.co.evil.invalid/cover', 'https://user:pass@i.scdn.co/image', 'https://127.0.0.1/image', 'https://i.scdn.co:1234/image', 'file:///tmp/a']:
            self.assertFalse(artwork.remote_allowed(url))

    def test_local_cover_is_bounded_and_cached(self):
        with tempfile.TemporaryDirectory(prefix='dwm-art-') as directory:
            root = Path(directory);cover = root / 'cover.png';cache = root / 'cache'
            cover.write_bytes(self.png())
            result = artwork.fetch(cover.as_uri(), False, cache)
            self.assertEqual(result['status'], 'ok')
            self.assertTrue(result['source'].startswith(cache.as_uri()))
            cover.write_bytes(self.png(100000,100000))
            self.assertEqual(artwork.fetch(cover.as_uri(),False,cache)['status'], 'unsupported')
            cover.write_bytes(b'<svg><image href="https://example.invalid"/></svg>')
            self.assertEqual(artwork.fetch(cover.as_uri(),False,cache)['status'], 'unsupported')

    def test_remote_disabled_never_uses_network(self):
        with patch.object(artwork, 'build_opener') as network:
            self.assertEqual(artwork.fetch('https://i.scdn.co/image/cover', False)['status'], 'blocked')
            network.assert_not_called()

    def test_remote_response_validation_and_redirects(self):
        with tempfile.TemporaryDirectory(prefix='dwm-art-') as directory:
            response = io.BytesIO(self.png())
            with patch.object(artwork, 'build_opener') as opener:
                opener.return_value.open.return_value.__enter__.return_value = response
                result = artwork.fetch('https://i.scdn.co/image/cover', True, Path(directory))
                self.assertEqual(result['status'],'ok')
            handler = artwork.SafeRedirect()
            from urllib.request import Request
            request = Request('https://i.scdn.co/a')
            with self.assertRaises(ValueError):
                handler.redirect_request(request,None,302,'',{},'https://127.0.0.1/private')


class PersistentWorkerTests(unittest.TestCase):
    def test_one_process_handles_configuration_refresh_pause_and_shutdown(self):
        with tempfile.TemporaryDirectory(prefix='dwm-worker-') as directory:
            env = dict(os.environ, XDG_CONFIG_HOME=directory, PYTHONDONTWRITEBYTECODE='1')
            process = subprocess.Popen([sys.executable,'-u',str(SERVICES/'worker.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,bufsize=0)
            buffer=b''
            def event(wanted, timeout=5):
                nonlocal buffer
                end=time.monotonic()+timeout
                while time.monotonic()<end:
                    while b'\n' in buffer:
                        line,buffer=buffer.split(b'\n',1)
                        value=json.loads(line)
                        if value['event']==wanted:return value
                    if select.select([process.stdout],[],[],max(0,end-time.monotonic()))[0]:buffer+=os.read(process.stdout.fileno(),65536)
                self.fail('Worker event missing: '+wanted)
            def command(**value):
                process.stdin.write((json.dumps(value)+'\n').encode());process.stdin.flush()
            try:
                self.assertFalse(event('settings')['values']['remoteArtwork'])
                pid=process.pid
                command(command='settings',patch={'gpuInterval':9,'remoteArtwork':False})
                self.assertEqual(event('settings')['values']['gpuInterval'],9)
                command(command='settings',patch={'gameMode':True})
                event('spectrum')
                self.assertTrue(event('settings')['values']['gameMode'])
                self.assertTrue(json.loads((Path(directory)/'omarchy/dwm-bar.json').read_text())['gameMode'])
                command(command='refresh')
                self.assertEqual(event('hardware')['status'],'ok')
                event('gpu')
                command(command='pause',paused=True)
                self.assertEqual(event('spectrum')['status'],'off')
                command(command='visualizer',enabled=False)
                self.assertEqual(event('spectrum')['bars'],[0]*16)
                command(command='settings',patch={'gameMode':False})
                self.assertFalse(event('settings')['values']['gameMode'])
                self.assertEqual(process.pid,pid)
                process.stdin.close();process.wait(timeout=5)
                self.assertEqual(process.returncode,0)
            finally:
                if process.poll() is None:process.terminate();process.wait(timeout=5)
                process.stdout.close();process.stderr.close()


if __name__=='__main__':unittest.main()
