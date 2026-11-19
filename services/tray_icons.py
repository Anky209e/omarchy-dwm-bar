"""Stage client local raster icons outside the rendering thread. No network."""
import hashlib
import re
from pathlib import Path
from urllib.parse import unquote,urlsplit,parse_qs
from artwork import read_image, dimensions, private_cache, write_private, default_cache

LIMIT=2*1024*1024

def local_path(raw):
    if not isinstance(raw,str) or not 0<len(raw)<=4096 or any(ord(c)<32 or ord(c)==127 for c in raw):return None
    try:
        if raw.startswith('image://icon/'):
            value=raw[len('image://icon/'):]
            name,_,query=value.partition('?');name=unquote(name)
            if name.startswith('/'):path=Path(name)
            elif re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,255}',name) and name not in ('.','..'):
                options=parse_qs(query,strict_parsing=True)
                if set(options)!={'path'} or len(options['path'])!=1:return None
                directory=Path(options['path'][0])
                if not directory.is_absolute():return None
                path=directory/name
                # Some clients supply an extensionless theme icon name.
                if path.suffix.lower() not in ('.png','.jpg','.jpeg'):
                    return [path,Path(str(path)+'.png')]
            else:return None
        elif raw.startswith('file://'):
            url=urlsplit(raw)
            if url.netloc not in ('','localhost') or url.query or url.fragment:return None
            path=Path(unquote(url.path))
        elif raw.startswith('/'):path=Path(raw)
        else:return None
        return [path] if path.is_absolute() else None
    except (ValueError,OSError):return None

def resolve(raw,cache=None):
    candidates=local_path(raw)
    if not candidates:return ''
    cache=cache or default_cache().parent/'tray'
    for path in candidates:
        try:
            data=read_image(path)
            size=dimensions(data)
            if len(data)>LIMIT or not size or not all(0<side<=1024 for side in size):continue
            target=cache/(hashlib.sha256(data).hexdigest()+'.img')
            with private_cache(cache) as directory:
                write_private(directory,target,data)
                images=sorted(cache.glob('*.img'),key=lambda f:f.stat().st_mtime)
                for old in images[:-64]:old.unlink(missing_ok=True)
            return target.as_uri()
        except (OSError,ValueError):continue
    return ''
