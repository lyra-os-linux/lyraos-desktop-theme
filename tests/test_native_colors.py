"""Recovery and opt-in upgrade boundaries; no access to the host session."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('native_colors', ROOT / 'scripts/apply-native-colors.py')
colors = importlib.util.module_from_spec(spec)
spec.loader.exec_module(colors)


class NativeColorsTests(unittest.TestCase):
    def test_reapply_keeps_original_and_undo_preserves_later_edits(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            css = root / 'gtk.css'
            css.write_bytes(b'user css')
            change = colors.Changes(root / 'state')
            change.file(css, b'palette v1')
            change.file(css, b'palette v2')
            self.assertEqual(change.state['files'][str(css)]['original'], colors.encode(b'user css'))
            css.write_bytes(b'later edit')
            with self.assertRaises(RuntimeError):
                change.file(css, b'palette v3')
            with patch.object(colors.Gio.Settings, 'sync'):
                self.assertEqual(change.undo(), [str(css)])
                self.assertEqual(css.read_bytes(), b'later edit')
                css.write_bytes(b'palette v2')
                self.assertEqual(change.undo(), [])
            self.assertEqual(css.read_bytes(), b'user css')

    def test_refresh_requires_managed_enabled_service(self):
        for managed, edited, enabled in [(False, False, False), (True, True, True),
                                        (True, False, False), (True, False, True)]:
            with self.subTest(managed=managed, edited=edited, enabled=enabled), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                config = root / 'config'
                state = root / 'state'
                unit = config / 'systemd/user/lyra-native-colors.service'
                change = colors.Changes(state / 'lyra-os-theme')
                if managed:
                    change.file(unit, b'managed service')
                    if edited:
                        unit.write_bytes(b'user replacement')
                with patch.object(colors.GLib, 'get_user_config_dir', return_value=str(config)), \
                     patch.object(colors.GLib, 'get_user_state_dir', return_value=str(state)), \
                     patch.object(colors.os, 'geteuid', return_value=1000), \
                     patch.object(colors.sys, 'argv', ['colors', '--refresh']), \
                     patch.object(colors.subprocess, 'run', return_value=SimpleNamespace(returncode=0 if enabled else 1)) as command, \
                     patch.object(colors, 'apply', return_value='dark') as apply, \
                     patch.object(colors, 'install') as install:
                    self.assertEqual(colors.main(), 0)
                    expected = managed and not edited and enabled
                    self.assertEqual(apply.called, expected)
                    self.assertEqual(install.called, expected)
                    if not managed or edited:
                        command.assert_not_called()

    def test_symlink_theme_manager_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / 'original.css'
            original.write_bytes(b'theme manager')
            link = root / 'gtk.css'
            link.symlink_to(original)
            with self.assertRaises(RuntimeError):
                colors.Changes(root / 'state').file(link, b'palette')
            self.assertTrue(link.is_symlink())
            self.assertEqual(original.read_bytes(), b'theme manager')
