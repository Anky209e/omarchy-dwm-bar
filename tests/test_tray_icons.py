import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys
import tempfile
import unittest
from urllib.parse import unquote,urlsplit

SERVICES=Path(__file__).resolve().parents[1]/'services'
sys.path.insert(0,str(SERVICES))
import tray_icons

class TrayIconTests(unittest.TestCase):
    def png(self):
        return b'\x89PNG\r\n\x1a\n'+b'\x00\x00\x00\rIHDR'+struct.pack('>II',2,2)+b'\x08\x02\x00\x00\x00'

    def timed(self,value,cache):
        code='import sys;from pathlib import Path;sys.path.insert(0,sys.argv[1]);from tray_icons import resolve;print(resolve(sys.argv[2],Path(sys.argv[3])))'
        result=subprocess.run([sys.executable,'-B','-c',code,str(SERVICES),value,str(cache)],capture_output=True,text=True,timeout=2,check=True)
        return result.stdout.strip()

    def test_fifo_and_provider_paths_do_not_block(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);fifo=root/'blocked.png';os.mkfifo(fifo)
            for raw in [str(fifo),fifo.as_uri(),'image://icon/'+str(fifo),'image://icon/blocked.png?path='+str(root)]:
                self.assertEqual(self.timed(raw,root/'cache'),'')

    def test_special_files_and_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);fifo=root/'fifo';os.mkfifo(fifo);link=root/'link';link.symlink_to(fifo)
            for raw in [str(link),'/dev/zero','/dev/random',str(root)]:
                self.assertEqual(self.timed(raw,root/'cache'),'')

    def test_regular_raster_is_copied_privately_before_display(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);image=root/'app.png';image.write_bytes(self.png())
            old=os.umask(0o022)
            try:source=tray_icons.resolve('image://icon/app?path='+str(root),root/'cache')
            finally:os.umask(old)
            cached=Path(unquote(urlsplit(source).path))
            self.assertEqual(cached.read_bytes(),self.png());self.assertNotEqual(cached,image)
            self.assertEqual(stat.S_IMODE(cached.stat().st_mode),0o600)
            self.assertEqual(stat.S_IMODE(cached.parent.stat().st_mode),0o700)
            image.unlink();os.mkfifo(image)
            self.assertEqual(cached.read_bytes(),self.png(),'Qt must see the private copy after client path replacement')

    def test_remote_unknown_provider_and_oversized_images_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for raw in ['https://example.invalid/a.png','image://qspixmap/1/2','image://evil/tmp/pipe','file://remote/tmp/image']:
                self.assertEqual(tray_icons.resolve(raw,root/'cache'),'')
            image=root/'huge.png';image.write_bytes(self.png()+b'x'*(2*1024*1024))
            self.assertEqual(tray_icons.resolve(str(image),root/'cache'),'')
            image.write_bytes(b'<svg><image href="file:///tmp/pipe"/></svg>')
            self.assertEqual(tray_icons.resolve(str(image),root/'cache'),'')

if __name__=='__main__':unittest.main()
