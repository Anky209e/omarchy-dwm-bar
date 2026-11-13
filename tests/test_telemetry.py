import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('telemetry', Path(__file__).resolve().parents[1] / 'services/telemetry.py')
telemetry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(telemetry)


class TelemetryTests(unittest.TestCase):
    def test_bad_sensor_values_fail_closed(self):
        self.assertEqual(telemetry.parse_gpu('28, 48\n'), {'available': True, 'gpu': 28, 'temperature': 48})
        for raw in ['101, 48', '28, 151', 'N/A, N/A', '<img src=x>', '28, -1']:
            self.assertEqual(telemetry.parse_gpu(raw), {'available': False})

    def test_cpu_guest_time_is_not_counted_twice(self):
        with tempfile.TemporaryDirectory(prefix='dwm-proc-test-') as directory:
            proc = Path(directory)
            (proc / 'stat').write_text('cpu 100 0 100 800 0 0 0 0 50 0\n')
            (proc / 'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 250 kB\n')
            self.assertEqual(telemetry.cpu_memory(proc), {'total': 1000, 'idle': 800, 'ram': 75})


if __name__ == '__main__':
    unittest.main()
