"""Bounded image caching for local music art and fixed HTTPS cover hosts."""
import hashlib
import os
from pathlib import Path
import re
import struct
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


def fetch(url, remote=True, cache=None):
    if not isinstance(url, str) or not 0 < len(url) <= 4096:
        return {'source': '', 'status': 'none'}
    cache = cache or Path(os.environ.get('XDG_CACHE_HOME', str(Path.home() / '.cache'))) / 'omarchy/dwm-bar/art'
    parsed = urlsplit(url)
    if parsed.scheme == 'file' and parsed.netloc in ('', 'localhost'):
        local = Path(unquote(parsed.path))
        if not local.is_absolute(): return {'source': '', 'status': 'blocked'}
        try:
            with local.open('rb') as stream: data = stream.read(LIMIT + 1)
        except OSError:
            return {'source': '', 'status': 'unavailable'}
    elif remote and remote_allowed(url):
        cache.mkdir(parents=True, exist_ok=True)
        target = cache / (hashlib.sha256(url.encode()).hexdigest() + '.img')
        if target.is_file(): return {'source': target.as_uri(), 'status': 'ok'}
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
    cache.mkdir(parents=True, exist_ok=True)
    # Local covers are copied too, so QML never decodes unvalidated files.
    target = cache / (hashlib.sha256(data).hexdigest() + '.img' if parsed.scheme == 'file' else hashlib.sha256(url.encode()).hexdigest() + '.img')
    temporary = target.with_suffix('.tmp')
    temporary.write_bytes(data)
    temporary.replace(target)
    cached = sorted((p for p in cache.glob('*.img') if re.fullmatch(r'[a-f0-9]{64}\.img', p.name)), key=lambda p: p.stat().st_mtime)
    for old in cached[:-32]: old.unlink(missing_ok=True)
    return {'source': target.as_uri(), 'status': 'ok'}
