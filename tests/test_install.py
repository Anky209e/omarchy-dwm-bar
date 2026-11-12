import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('dwm_installer', REPO / 'scripts/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dwm-install-test-')
        self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / 'omarchy'
        sources = [REPO, *sorted((REPO / 'plugins').iterdir())]
        self.packages = [(json.loads((p / 'manifest.json').read_text())['id'], p) for p in sources]
        patcher = mock.patch.object(installer, 'packages', return_value=self.packages)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def seed(self):
        self.config.mkdir()
        original = {'version': 1, 'idle': {'lock': 999}, 'plugins': [{'id': 'personal.plugin'}], 'bar': {'background': 'none'}}
        (self.config / 'shell.json').write_text(json.dumps(original))
        tray = self.config / 'plugins/whitewebdev.flat-tray'
        tray.mkdir(parents=True)
        (tray / 'manifest.json').write_text(json.dumps({'id': 'whitewebdev.flat-tray'}))
        old = self.config / 'plugins/anky.dwm-status'
        old.mkdir()
        (old / 'old-marker').write_text('old version')
        return original

    def test_full_install_preserves_other_settings_and_backs_up(self):
        original = self.seed()
        backup = installer.install(self.config, apply_layout=True, reload_shell=False)
        actual = json.loads((self.config / 'shell.json').read_text())
        self.assertEqual(actual['idle'], original['idle'])
        self.assertEqual(actual['plugins'], original['plugins'])
        self.assertEqual(actual['version'], original['version'])
        self.assertEqual(actual['bar'], json.loads((REPO / 'presets/dwm-bar.json').read_text())['bar'])
        self.assertEqual(json.loads((backup / 'shell.json').read_text()), original)
        self.assertEqual((backup / 'anky.dwm-status/old-marker').read_text(), 'old version')
        for plugin_id, _ in self.packages:
            destination = self.config / 'plugins' / plugin_id
            self.assertTrue((destination / 'manifest.json').is_file())
            self.assertTrue((destination / 'LICENSE').is_file())
        self.assertFalse((self.config / 'plugins/anky.dwm-status/scripts').exists())

    def test_code_update_leaves_shell_json_byte_identical(self):
        self.seed()
        before = (self.config / 'shell.json').read_bytes()
        installer.install(self.config, reload_shell=False)
        self.assertEqual((self.config / 'shell.json').read_bytes(), before)

    def test_layout_requires_flat_tray_before_writing(self):
        with self.assertRaisesRegex(RuntimeError, 'Flat Tray|flat-tray'):
            installer.install(self.config, apply_layout=True, reload_shell=False)
        self.assertFalse(self.config.exists())

    def test_dry_run_does_not_create_destination(self):
        installer.install(self.config, reload_shell=False, dry_run=True)
        self.assertFalse(self.config.exists())

    def test_file_failure_rolls_back_every_installed_plugin(self):
        self.seed()
        before = (self.config / 'shell.json').read_bytes()
        copytree = installer.shutil.copytree

        def fail_music(source, *args, **kwargs):
            if Path(source).name == 'anky.music':
                raise OSError('simulated copy failure')
            return copytree(source, *args, **kwargs)

        with mock.patch.object(installer.shutil, 'copytree', side_effect=fail_music):
            with self.assertRaisesRegex(OSError, 'simulated'):
                installer.install(self.config, apply_layout=True, reload_shell=False)
        self.assertEqual((self.config / 'shell.json').read_bytes(), before)
        self.assertEqual((self.config / 'plugins/anky.dwm-status/old-marker').read_text(), 'old version')
        self.assertFalse((self.config / 'plugins/anky.divider').exists())
        self.assertFalse((self.config / 'plugins/anky.indicators').exists())
        self.assertFalse(list((self.config / 'plugins').glob('.dwm-stage-*')))


if __name__ == '__main__':
    unittest.main()
