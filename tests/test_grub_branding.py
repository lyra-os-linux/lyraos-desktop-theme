"""Exercise RPM scriptlets and the upstream activator in disposable paths."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPECS = ('packaging/lyra-os-theme.spec', 'packaging/opensuse/lyra-os-theme.spec')
LYRA = '/usr/share/grub/themes/Lyra-OS/theme.txt'


class GrubBrandingTests(unittest.TestCase):
    def fixture(self, initial='GRUB_TIMEOUT=7\nGRUB_THEME="/previous/theme.txt"\n'):
        directory = tempfile.TemporaryDirectory(prefix='lyra-grub-test-')
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        for rel in ('etc/default', 'usr/sbin', 'var/lib/lyra-os-theme',
                    'usr/share/grub2/themes/openSUSE', 'boot/grub2'):
            (root / rel).mkdir(parents=True, exist_ok=True)
        (root / 'etc/default/grub').write_text(initial)
        shutil.copyfile(ROOT / 'src/defaults/grub.lyra-theme', root / 'etc/default/grub.lyra-theme')
        generator = root / 'usr/sbin/grub2-mkconfig'
        generator.write_text('#!/bin/sh\n. "' + str(root / 'etc/default/grub') + '"\n'
                             'printf "%s\\n" "${GRUB_THEME-}" > "' + str(root / 'generated-theme') + '"\n')
        generator.chmod(0o755)
        return root

    def scriptlet(self, root, spec, action, count):
        source = (ROOT / spec).read_text()
        if action == 'install':
            code = source.split('%post\n', 1)[1].split('\nif [ "$1" -eq 1 ]; then\n  %{_sbindir}/plymouth', 1)[0]
        else:
            code = source.split('%preun\n', 1)[1].split('\n  if [ "$(%{_sbindir}/plymouth', 1)[0] + '\nfi\n'
        for macro, value in {'_sysconfdir': '/etc', '_localstatedir': '/var',
                             '_datadir': '/usr/share', '_sbindir': '/usr/sbin',
                             'name': 'lyra-os-theme'}.items():
            code = code.replace('%{' + macro + '}', value)
        # Only the fixture config/state and a recording mkconfig stub are used.
        for path in ('/etc/default', '/var/lib', '/usr/sbin'):
            code = code.replace(path, str(root) + path)
        self.assertNotIn('%{', code)
        subprocess.run(['sh', '-eu', '-c', code, 'rpm-scriptlet', str(count)], check=True)

    def activate_opensuse(self, root):
        code = (ROOT / 'tests/fixtures/opensuse-activate-theme').read_text()
        for path in ('/etc/default/grub', '/boot/grub2/themes', '/usr/share/grub2'):
            self.assertIn('"' + path + '"', code)
            code = code.replace('"' + path + '"', '"' + str(root) + path + '"')
        subprocess.run(['perl', '-e', code], check=True)

    def effective(self, root):
        return subprocess.check_output(['sh', '-eu', '-c',
            '. "$1"; printf "%s" "${GRUB_THEME-}"', 'read-config',
            str(root / 'etc/default/grub')], text=True)

    def test_upstream_update_upgrade_and_removal(self):
        for spec in SPECS:
            with self.subTest(spec=spec):
                root = self.fixture()
                self.scriptlet(root, spec, 'install', 1)
                backup = (root / 'var/lib/lyra-os-theme/grub-theme.backup').read_bytes()
                self.assertEqual(self.effective(root), LYRA)
                for _ in range(2):
                    self.activate_opensuse(root)
                    self.assertEqual(self.effective(root), LYRA)
                self.scriptlet(root, spec, 'install', 2)
                self.assertEqual((root / 'var/lib/lyra-os-theme/grub-theme.backup').read_bytes(), backup)
                text = (root / 'etc/default/grub').read_text()
                self.assertEqual(text.count('|| . '), 1)
                self.assertIn('GRUB_TIMEOUT=7', text)
                self.activate_opensuse(root)
                self.scriptlet(root, spec, 'remove', 0)
                self.assertEqual(self.effective(root), '/previous/theme.txt')
                self.assertEqual((root / 'generated-theme').read_text().strip(), '/previous/theme.txt')
                self.assertNotIn('grub.lyra-theme', (root / 'etc/default/grub').read_text())

    def test_preference_survives_upstream_update_and_lyra_upgrade(self):
        root = self.fixture('GRUB_TIMEOUT=3\n')
        self.scriptlet(root, SPECS[0], 'install', 1)
        preference = root / 'etc/default/grub.lyra-theme'
        preference.write_text('GRUB_THEME="/custom/theme.txt"\n')
        self.activate_opensuse(root)
        self.scriptlet(root, SPECS[0], 'install', 2)
        self.assertEqual(self.effective(root), '/custom/theme.txt')
        preference.write_text('GRUB_THEME=""\n')
        self.activate_opensuse(root)
        self.assertEqual(self.effective(root), '')
        self.scriptlet(root, SPECS[0], 'remove', 0)
        self.assertEqual(self.effective(root), '')

    def test_missing_preference_uses_placeholder_and_missing_grub_is_safe(self):
        root = self.fixture()
        self.scriptlet(root, SPECS[0], 'install', 1)
        (root / 'etc/default/grub.lyra-theme').unlink()
        self.assertEqual(self.effective(root), LYRA)
        (root / 'etc/default/grub').unlink()
        self.scriptlet(root, SPECS[0], 'install', 2)
        self.scriptlet(root, SPECS[0], 'remove', 0)
        self.assertFalse((root / 'etc/default/grub').exists())

    def test_preferences_are_packaged_as_noreplace(self):
        for spec in SPECS:
            self.assertIn('%config(noreplace) %{_sysconfdir}/default/grub.lyra-theme',
                          (ROOT / spec).read_text())

    def test_manual_installer_keeps_include_last(self):
        root = self.fixture()
        self.scriptlet(root, SPECS[0], 'install', 1)
        source = (ROOT / 'install-rpm.sh').read_text()
        block = source[source.index('if [[ -f /etc/default/grub ]]; then'):]
        block = block.split('\nfi\n', 1)[0] + '\nfi\n'
        block = block.replace('/etc/default', str(root / 'etc/default'))
        block = block.replace('sudo grub2-mkconfig', 'sudo ' + str(root / 'usr/sbin/grub2-mkconfig'))
        subprocess.run(['bash', '-eu', '-c', 'sudo() { "$@"; }; say() { :; };\n' + block], check=True)
        self.activate_opensuse(root)
        self.assertEqual(self.effective(root), LYRA)
        self.assertEqual((root / 'etc/default/grub').read_text().count('|| . '), 1)
