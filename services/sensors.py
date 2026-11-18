"""Read one stable PCI GPU, without opening devices or changing permissions."""
from pathlib import Path
from telemetry import parse_gpu, query

VENDORS = {'0x10de':'NVIDIA', '0x1002':'AMD', '0x8086':'Intel'}

def devices(sysroot=Path('/sys/bus/pci/devices')):
    result=[]
    try: entries=sorted(sysroot.iterdir())
    except OSError: return result
    for entry in entries:
        try:
            vendor=(entry/'vendor').read_text().strip().lower()
            if vendor not in VENDORS or not (entry/'class').read_text().strip().startswith('0x03'):continue
            result.append((entry,vendor))
        except OSError:continue
    # Preserve the user's discrete GPU reading on hybrid laptops, even asleep.
    return sorted(result,key=lambda pair:({'0x10de':0,'0x1002':1,'0x8086':2}[pair[1]],pair[0].name))

def power(device):
    try: value=(device/'power/runtime_status').read_text().strip()
    except OSError:return 'unknown'
    if value in ('suspended','suspending'):return 'sleep'
    return 'active' if value=='active' else 'unknown'

def temperature(device):
    for file in sorted((device/'hwmon').glob('hwmon*/temp1_input')):
        try:
            value=int(file.read_text().strip())/1000
            if 0<=value<=150:return round(value)
        except (OSError,ValueError):pass
    return -1

def read_gpu(sleep_aware=True,sysroot=Path('/sys/bus/pci/devices')):
    found=devices(sysroot)
    if not found:return {'available':False,'status':'missing'}
    device,vendor=found[0]
    base={'vendor':VENDORS[vendor],'device':device.name,'gpu':-1,'temperature':-1}
    state=power(device)
    if sleep_aware and state in ('sleep','unknown'):return dict(base,available=False,status=state)
    if vendor=='0x10de':
        # Address the same PCI device whose power state was checked, not index 0.
        raw=query(['nvidia-smi','--query-gpu=utilization.gpu,temperature.gpu','--format=csv,noheader,nounits','-i',device.name])
        sample=parse_gpu(raw)
        return dict(base | sample,status='ok' if sample.get('available') else 'error')
    busy=-1
    if vendor=='0x1002':
        try:
            value=int((device/'gpu_busy_percent').read_text().strip())
            if 0<=value<=100:busy=value
        except (OSError,ValueError):pass
    temp=temperature(device)
    return dict(base | {'gpu':busy,'temperature':temp},available=busy>=0 or temp>=0,status='ok' if busy>=0 or temp>=0 else 'missing')
