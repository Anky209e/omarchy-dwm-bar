import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
import zlib
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'services'))
import tray_pixmaps

class TrayPixmapTests(unittest.TestCase):
    def test_argb_pixels_become_rgba_png(self):
        png=tray_pixmaps.png_from_pixmaps([[1,1,[255,10,20,30]]]);self.assertEqual(png[:8],b'\x89PNG\r\n\x1a\n')
        offset=8;image=b''
        while offset<len(png):
            length=struct.unpack('>I',png[offset:offset+4])[0];kind=png[offset+4:offset+8]
            if kind==b'IDAT':image+=png[offset+8:offset+8+length]
            offset+=length+12
        self.assertEqual(zlib.decompress(image),b'\x00\x0a\x14\x1e\xff')

    def test_invalid_or_oversized_pixels_are_rejected(self):
        for value in [None,[[0,1,[]]],[[257,1,[0]*1028]],[[1,1,[0,0,0]]],[[1,1,[256,0,0,0]]],[[True,1,[0]*4]],[[1,1,[True,0,0,0]]]]:
            self.assertIsNone(tray_pixmaps.png_from_pixmaps(value))

    def test_changed_frames_create_different_private_images(self):
        with tempfile.TemporaryDirectory() as directory:
            frames=[[[1,1,[255,255,0,0]]],[[1,1,[255,0,0,255]]]]
            with patch.object(tray_pixmaps,'address_for',return_value=('org.example.Tray','/StatusNotifierItem')),patch.object(tray_pixmaps,'property_value',side_effect=frames):
                first=tray_pixmaps.resolve('discord_status_icon_1',cache=Path(directory));second=tray_pixmaps.resolve('discord_status_icon_1',cache=Path(directory))
            self.assertTrue(first.startswith('file://'));self.assertTrue(second.startswith('file://'));self.assertNotEqual(first,second)

    def test_strings_instead_of_pixels_are_never_opened_as_files(self):
        with tempfile.TemporaryDirectory() as directory:
            fifo=Path(directory)/'fifo';os.mkfifo(fifo)
            with patch.object(tray_pixmaps,'address_for',return_value=('org.example.Tray','/StatusNotifierItem')),patch.object(tray_pixmaps,'property_value',return_value=str(fifo)):
                self.assertEqual(tray_pixmaps.resolve('discord',cache=Path(directory)/'cache'),'')
            self.assertEqual(list(Path(directory).iterdir()),[fifo])

    def test_unresponsive_helper_is_killed_and_reaped(self):
        popen=subprocess.Popen;children=[]
        def sleeper(*args,**kwargs):
            child=popen([sys.executable,'-c','import time;time.sleep(10)'],**kwargs);children.append(child);return child
        with patch.object(tray_pixmaps.subprocess,'Popen',side_effect=sleeper):
            with self.assertRaises(TimeoutError):tray_pixmaps.property_value('org.example.Tray','/StatusNotifierItem','org.kde.StatusNotifierItem','IconPixmap',time.monotonic()+.1)
        self.assertTrue(all(child.poll() is not None and child.stdout.closed for child in children))

if __name__=='__main__':unittest.main()
