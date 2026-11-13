import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('telemetry', Path(__file__).resolve().parents[1] / 'services/telemetry.py')
telemetry = importlib.util.module_from_spec(spec)
spec.loader.exec_module(telemetry)


def client(name='steam_app_730', fullscreen=2, workspace=1):
    return {'class': name, 'initialClass': name, 'pid': 123, 'fullscreen': fullscreen, 'workspace': {'id': workspace}, 'mapped': True}


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.monitors = [{'activeWorkspace': {'id': 1}}, {'activeWorkspace': {'id': 11}}]
        self.environment = Mock(return_value=b'')

    def detect(self, clients, extra=()):
        return telemetry.detect_games(clients, self.monitors, extra, self.environment)

    def test_fullscreen_game_on_either_monitor(self):
        self.assertTrue(self.detect([client(workspace=11)])['gaming'])
        self.assertTrue(self.detect([client(fullscreen=3)])['gaming'])

    def test_maximized_window_or_hidden_workspace_does_not_pause(self):
        self.assertFalse(self.detect([client(fullscreen=1)])['gaming'])
        self.assertFalse(self.detect([client(workspace=9)])['gaming'])
        self.environment.assert_not_called()

    def test_browser_video_does_not_pause(self):
        self.assertFalse(self.detect([client(name='firefox')])['gaming'])
        self.assertFalse(self.detect([client(name='chromium')])['gaming'])

    def test_native_game_uses_steam_environment_without_exposing_it(self):
        self.environment.return_value = b'SECRET=not-for-output\0SteamAppId=730\0'
        self.assertEqual(self.detect([client(name='UnknownGame')]), {'gaming': True, 'games': 1})
        self.environment.return_value = b'SteamAppId=0\0SteamGameId=not-a-number\0'
        self.assertFalse(self.detect([client(name='steam')])['gaming'])

    def test_custom_classes_are_exact_and_case_insensitive(self):
        self.assertTrue(self.detect([client(name='MYGAME')], ['MyGame'])['gaming'])
        self.assertFalse(self.detect([client(name='OtherGame')], ['.*'])['gaming'])

    def test_game_exit_or_workspace_change_resumes(self):
        self.assertTrue(self.detect([client()])['gaming'])
        self.assertFalse(self.detect([])['gaming'])
        self.monitors = [{'activeWorkspace': {'id': 2}}]
        self.assertFalse(self.detect([client()])['gaming'])

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
