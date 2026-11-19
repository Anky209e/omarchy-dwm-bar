"""Read live SNI bitmap bytes over D-Bus; never resolve client filenames."""
import json
import os
from pathlib import Path
import re
import selectors
import struct
import subprocess
import time
import zlib
from tray_icons import cache_raster

MAX_REPLY=2*1024*1024
_addresses={}
_address_time=0


def property_value(service,path,interface,name,deadline):
    if not re.fullmatch(r'(?::[0-9]+\.[0-9]+|[A-Za-z_][A-Za-z0-9_-]*(?:\.[A-Za-z_][A-Za-z0-9_-]*)+)',service):raise ValueError('Invalid bus name')
    if not re.fullmatch(r'/(?:[A-Za-z0-9_]+(?:/[A-Za-z0-9_]+)*)?',path):raise ValueError('Invalid object path')
    remaining=deadline-time.monotonic()
    if remaining<=0:raise TimeoutError('Icon deadline')
    process=subprocess.Popen(['busctl','--user','--json=short','get-property',service,path,interface,name],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    selector=selectors.DefaultSelector();data=bytearray()
    try:
        selector.register(process.stdout,selectors.EVENT_READ)
        while True:
            remaining=deadline-time.monotonic()
            if remaining<=0 or not selector.select(remaining):raise TimeoutError('Icon deadline')
            chunk=os.read(process.stdout.fileno(),8192)
            if not chunk:break
            data.extend(chunk)
            if len(data)>MAX_REPLY:raise ValueError('Oversized D-Bus reply')
        process.wait(timeout=max(.01,deadline-time.monotonic()))
        if process.returncode:raise ValueError('D-Bus property unavailable')
        return json.loads(data)['data']
    finally:
        selector.close()
        if process.poll() is None:process.kill();process.wait()
        process.stdout.close()


def address_for(identity,deadline):
    global _addresses,_address_time
    if identity in _addresses and time.monotonic()-_address_time<10:return _addresses[identity]
    entries=property_value('org.kde.StatusNotifierWatcher','/StatusNotifierWatcher','org.kde.StatusNotifierWatcher','RegisteredStatusNotifierItems',deadline)
    if not isinstance(entries,list) or len(entries)>64:raise ValueError('Invalid tray item list')
    addresses={}
    for entry in entries:
        if not isinstance(entry,str) or len(entry)>512:continue
        service,sep,path=entry.partition('/')
        if not sep:continue
        try:value=property_value(service,'/'+path,'org.kde.StatusNotifierItem','Id',deadline)
        except (OSError,ValueError,subprocess.SubprocessError):continue
        if isinstance(value,str) and 0<len(value)<=256:
            addresses[value]=None if value in addresses else (service,'/'+path)
    _addresses=addresses;_address_time=time.monotonic()
    return addresses.get(identity)


def png_from_pixmaps(value):
    if not isinstance(value,list) or len(value)>32:return None
    candidates=[]
    for item in value:
        if not isinstance(item,list) or len(item)!=3:continue
        width,height,pixels=item
        if type(width) is not int or type(height) is not int or not 0<width<=256 or not 0<height<=256:continue
        if not isinstance(pixels,list) or len(pixels)!=width*height*4:continue
        if any(type(v) is not int or not 0<=v<=255 for v in pixels):continue
        candidates.append((abs(width-32)+abs(height-32),width,height,pixels))
    if not candidates:return None
    _,width,height,pixels=min(candidates,key=lambda item:item[0])
    # StatusNotifier's network-order ARGB bytes become ordinary RGBA PNG pixels.
    rows=bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            i=(y*width+x)*4
            rows.extend((pixels[i+1],pixels[i+2],pixels[i+3],pixels[i]))
    def chunk(kind,data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,3))+chunk(b'IEND',b'')


def resolve(identity,attention=False,cache=None):
    if not isinstance(identity,str) or not 0<len(identity)<=256:return ''
    deadline=time.monotonic()+2
    try:
        address=address_for(identity,deadline)
        if not address:return ''
        name='AttentionIconPixmap' if attention else 'IconPixmap'
        try:value=property_value(*address,'org.kde.StatusNotifierItem',name,deadline)
        except (OSError,ValueError,subprocess.SubprocessError):
            if not attention:raise
            value=[]
        data=png_from_pixmaps(value)
        if data is None and attention:data=png_from_pixmaps(property_value(*address,'org.kde.StatusNotifierItem','IconPixmap',deadline))
        return cache_raster(data,cache) if data else ''
    except (OSError,ValueError,KeyError,TypeError,TimeoutError,subprocess.SubprocessError):
        _addresses.pop(identity,None)
        return ''
