"""Bounded image caching for local music art and fixed HTTPS cover hosts."""
import hashlib
from contextlib import contextmanager
import secrets
import os
from pathlib import Path
import re
import struct
import stat
from urllib.parse import urlsplit, unquote
from urllib.request import Request, build_opener, HTTPRedirectHandler

HOSTS = {'i.scdn.co', 'mosaic.scdn.co', 'i.ytimg.com', 'img.youtube.com',
         'lastfm.freetls.fastly.net', 'cdn-images.dzcdn.net', 'resources.tidal.com',
         'lh3.googleusercontent.com'}
LIMIT = 2 * 1024 * 1024


def remote_allowed(url):
    try:
        p = urlsplit(url)
        return p.scheme == 'https' and p.hostname in HOSTS and p.port in (None, 443) and not p.username and not p.password
    except ValueError:
        return False


class SafeRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        if not remote_allowed(newurl) or getattr(request, 'cover_redirects', 0) >= 2: raise ValueError('Unsupported redirect')
        redirected = super().redirect_request(request, fp, code, message, headers, newurl)
        if redirected: redirected.cover_redirects = getattr(request, 'cover_redirects', 0) + 1
        return redirected


def dimensions(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n') and len(data) >= 24:
        return struct.unpack('>II', data[16:24])
    if data.startswith(b'\xff\xd8'):
        offset = 2
        while offset + 4 <= len(data):
            if data[offset] != 255: return None
            marker = data[offset + 1]
            if marker == 255: offset += 1; continue
            if marker in (0xD8, 0xD9): offset += 2; continue
            size = int.from_bytes(data[offset + 2:offset + 4], 'big')
            if size < 2: return None
            if marker in (0xC0, 0xC1, 0xC2) and offset + 9 <= len(data):
                return int.from_bytes(data[offset+7:offset+9], 'big'), int.from_bytes(data[offset+5:offset+7], 'big')
            offset += size + 2
    return None


def read_image(path):
    """Bound reads and reject FIFOs, devices and symlinks before decoding."""
    descriptor=os.open(path,os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(descriptor,'rb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):raise ValueError('Not a regular image')
        return stream.read(LIMIT+1)


@contextmanager
def private_cache(cache):
    """Protect copies independently of source permissions and process umask."""
    cache.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory=os.open(cache,os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        if os.fstat(directory).st_uid != os.geteuid():raise PermissionError('Cache is not owned by this user')
        os.fchmod(directory,0o700)
        # Repair pre-fix images and interrupted legacy writes before any reuse.
        for name in os.listdir(directory):
            if not re.fullmatch(r'[a-f0-9]{64}\.(img|tmp)',name):continue
            descriptor=os.open(name,os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC,dir_fd=directory)
            try:
                info=os.fstat(descriptor)
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or info.st_nlink != 1:
                    raise PermissionError('Unsafe cached image')
                os.fchmod(descriptor,0o600)
            finally:os.close(descriptor)
        yield directory
    finally:os.close(directory)


def write_private(directory,target,data):
    # Unique exclusive file: private before the first byte, never follow .tmp links.
    name='.cover-'+secrets.token_hex(16)+'.tmp'
    descriptor=os.open(name,os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,0o600,dir_fd=directory)
    try:
        with os.fdopen(descriptor,'wb') as stream:
            os.fchmod(stream.fileno(),0o600)
            stream.write(data)
        os.replace(name,target.name,src_dir_fd=directory,dst_dir_fd=directory)
    finally:
        try:os.unlink(name,dir_fd=directory)
        except FileNotFoundError:pass


def default_cache():
    return Path(os.environ.get('XDG_CACHE_HOME',str(Path.home()/'.cache')))/'omarchy/dwm-bar/art'


def secure_existing_cache():
    cache=default_cache()
    if cache.exists() or cache.is_symlink():
        with private_cache(cache):pass


def fetch(url, remote=True, cache=None):
    if not isinstance(url,str) or not 0<len(url)<=4096:return {'source':'','status':'none'}
    try:parsed=urlsplit(url)
    except ValueError:return {'source':'','status':'blocked'}
    if not (parsed.scheme=='file' and parsed.netloc in ('','localhost')) and not (remote and remote_allowed(url)):
        return {'source':'','status':'blocked'}
    cache=cache or default_cache()
    try:
        with private_cache(cache) as directory:
            return fetch_private(url,remote,cache,directory)
    except (OSError,ValueError):return {'source':'','status':'unavailable'}


def fetch_private(url, remote, cache, directory):
    if not isinstance(url, str) or not 0 < len(url) <= 4096:
        return {'source': '', 'status': 'none'}
    cache = cache or Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'omarchy/dwm-bar/art'
    try: parsed = urlsplit(url)
    except ValueError: return {'source':'','status':'blocked'}
    if parsed.scheme == 'file' and parsed.netloc in ('', 'localhost'):
        local = Path(unquote(parsed.path))
        if not local.is_absolute(): return {'source': '', 'status': 'blocked'}
        try:
            data = read_image(local)
        except (OSError,ValueError):
            return {'source': '', 'status': 'unavailable'}
    elif remote and remote_allowed(url):
        target = cache / (hashlib.sha256(url.encode()).hexdigest() + '.img')
        if target.is_file():
            try:
                cached_data=read_image(target);cached_size=dimensions(cached_data)
                if len(cached_data)<=LIMIT and cached_size and all(0<side<=4096 for side in cached_size):
                    return {'source':target.as_uri(),'status':'ok'}
            except (OSError,ValueError):pass
            return {'source':'','status':'unsupported'}
        try:
            request = Request(url, headers={'User-Agent': 'Omarchy-DWM-Bar/2.2', 'Accept': 'image/png,image/jpeg'})
            with build_opener(SafeRedirect()).open(request, timeout=3) as response:
                data = response.read(LIMIT + 1)
        except Exception:
            return {'source': '', 'status': 'unavailable'}
    else:
        return {'source': '', 'status': 'blocked'}
    size = dimensions(data)
    if len(data) > LIMIT or not size or not all(0 < side <= 4096 for side in size):
        return {'source': '', 'status': 'unsupported'}
    # Local covers are copied too, so QML never decodes unvalidated files.
    target = cache / (hashlib.sha256(data).hexdigest() + '.img' if parsed.scheme == 'file' else hashlib.sha256(url.encode()).hexdigest() + '.img')
    write_private(directory,target,data)
    cached = sorted((p for p in cache.glob('*.img') if re.fullmatch(r'[a-f0-9]{64}\.img', p.name)), key=lambda p: p.stat().st_mtime)
    for old in cached[:-32]: old.unlink(missing_ok=True)
    return {'source': target.as_uri(), 'status': 'ok'}
