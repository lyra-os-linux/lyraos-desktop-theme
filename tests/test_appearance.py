"""Exercise migrations in temporary profiles; never access the user's dconf."""
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
loader = SourceFileLoader('appearance', str(ROOT / 'src/defaults/lyra-os-apply-full-theme'))
spec = spec_from_loader(loader.name, loader)
appearance = module_from_spec(spec)
loader.exec_module(appearance)


class Settings:
    def __init__(self, **values):
        self.values = values
        self.writes = []
        self.locked = set()
        self.props = SimpleNamespace(settings_schema=SimpleNamespace(has_key=values.__contains__))

    def get_string(self, key):
        return self.values[key]

    def set_string(self, key, value):
        self.values[key] = value
        self.writes.append((key, value))

    def is_writable(self, key):
        return key not in self.locked


class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'config'
        self.gtk = self.config / 'gtk-4.0'
        self.gtk.mkdir(parents=True)
        self.interface = Settings(**{'gtk-theme': 'Lyra-OS', 'icon-theme': 'Lyra-OS-Icons',
                                     'accent-color': 'blue', 'color-scheme': 'prefer-dark'})
        self.shell = Settings(name='Lyra-OS')
        for accent in appearance.ACCENTS:
            index = self.root / f'icons/Lyra-OS-Icons-{accent}/index.theme'
            index.parent.mkdir(parents=True)
            index.write_text('[Icon Theme]\n')

    def apply(self, desktop='GNOME', shell_running=True):
        appearance.apply_preferences(self.interface, self.shell, [self.root], self.config,
                                     desktop, shell_running)

    def test_nine_accents_follow_preferences_in_both_color_schemes(self):
        for scheme in ('default', 'prefer-dark'):
            for accent in appearance.ACCENTS:
                with self.subTest(accent=accent, scheme=scheme):
                    self.interface.values.update({'accent-color': accent, 'color-scheme': scheme})
                    self.apply()
                    self.assertEqual(self.interface.values['icon-theme'], f'Lyra-OS-Icons-{accent}')
                    self.assertEqual(self.interface.values['accent-color'], accent)
                    self.assertEqual(self.interface.values['color-scheme'], scheme)
                    self.assertEqual(self.interface.values['gtk-theme'], 'Adwaita')
                    self.assertEqual(self.shell.values['name'], '')

    def test_non_gnome_sessions_are_untouched_even_when_shell_is_running(self):
        css = self.gtk / 'gtk.css'
        css.write_text('/* Lyra OS */')
        (self.gtk / '.lyra-os-managed').touch()
        for desktop in ('KDE', 'XFCE', 'GNOME:KDE', 'GNOME:XFCE', 'LXQt', 'MATE', 'Cinnamon'):
            with self.subTest(desktop=desktop):
                self.apply(desktop)
                self.assertFalse(self.interface.writes)
                self.assertFalse(self.shell.writes)
                self.assertEqual(css.read_text(), '/* Lyra OS */')
                self.assertTrue((self.gtk / '.lyra-os-managed').exists())

    def test_empty_desktop_requires_a_running_gnome_shell(self):
        self.apply('', False)
        self.assertFalse(self.interface.writes)
        self.apply('', True)
        self.assertEqual(self.interface.values['gtk-theme'], 'Adwaita')

    def test_missing_accent_schema_and_unknown_color_fall_back_to_blue(self):
        del self.interface.values['accent-color']
        self.apply()
        self.assertEqual(self.interface.values['icon-theme'], 'Lyra-OS-Icons-blue')
        self.interface.values['accent-color'] = 'future-color'
        self.apply()
        self.assertEqual(self.interface.values['icon-theme'], 'Lyra-OS-Icons-blue')

    def test_custom_themes_and_unmanaged_css_are_preserved(self):
        self.interface.values.update({'gtk-theme': 'Custom', 'icon-theme': 'Papirus'})
        self.shell.values['name'] = 'Custom Shell'
        css = self.gtk / 'gtk.css'
        css.write_text('button { padding: 2px; }')
        self.apply()
        self.assertFalse(self.interface.writes)
        self.assertFalse(self.shell.writes)
        self.assertEqual(css.read_text(), 'button { padding: 2px; }')

    def test_migration_restores_original_css_backup(self):
        (self.gtk / '.lyra-os-managed').write_text('Lyra-OS')
        (self.gtk / 'gtk.css').write_text('/* Lyra OS */\nbutton { color: red; }')
        (self.gtk / 'gtk.css.before-lyra-os').write_text('/* user stylesheet */')
        self.apply()
        self.assertEqual((self.gtk / 'gtk.css').read_text(), '/* user stylesheet */')
        self.assertFalse((self.gtk / '.lyra-os-managed').exists())
        self.assertFalse((self.gtk / 'gtk.css.before-lyra-os').exists())

    def test_managed_css_is_removed_without_a_backup(self):
        (self.gtk / '.lyra-os-managed').touch()
        (self.gtk / 'gtk.css').write_text('/* Lyra OS */')
        self.apply()
        self.assertFalse((self.gtk / 'gtk.css').exists())

    def test_user_replacement_is_not_overwritten_by_old_backup(self):
        (self.gtk / '.lyra-os-managed').touch()
        (self.gtk / 'gtk.css').write_text('/* my new stylesheet */')
        (self.gtk / 'gtk.css.before-lyra-os').write_text('/* old stylesheet */')
        self.apply()
        self.assertEqual((self.gtk / 'gtk.css').read_text(), '/* my new stylesheet */')
        self.assertTrue((self.gtk / 'gtk.css.before-lyra-os').exists())

    def test_legacy_image_import_is_removed_preserving_extra_rules(self):
        css = self.gtk / 'gtk.css'
        for suffix in ('', '-Light'):
            css.write_text(f'@import url("file:///usr/share/themes/Lyra-OS{suffix}/gtk-4.0/gtk.css");\nbutton {{ padding: 3px; }}\n')
            self.apply()
            self.assertEqual(css.read_text(), 'button { padding: 3px; }\n')

    def test_migration_does_not_leave_empty_import_stylesheet(self):
        css = self.gtk / 'gtk.css'
        css.write_text('/* Match the complete Lyra-OS GTK theme used by the reference workstation. */\n@import url("file:///usr/share/themes/Lyra-OS/gtk-4.0/gtk.css");\n')
        self.apply()
        self.assertFalse(css.exists())

    def test_missing_icon_assets_do_not_select_a_broken_theme(self):
        (self.root / 'icons/Lyra-OS-Icons-blue/index.theme').unlink()
        self.apply()
        self.assertEqual(self.interface.values['icon-theme'], 'Lyra-OS-Icons')

    def test_repeat_application_does_not_rewrite_settings(self):
        self.apply()
        self.interface.writes.clear()
        self.shell.writes.clear()
        self.apply()
        self.assertFalse(self.interface.writes)
        self.assertFalse(self.shell.writes)

    def test_locked_settings_are_respected(self):
        self.interface.locked.update(self.interface.values)
        self.shell.locked.add('name')
        self.apply()
        self.assertFalse(self.interface.writes)
        self.assertFalse(self.shell.writes)


if __name__ == '__main__':
    unittest.main()
