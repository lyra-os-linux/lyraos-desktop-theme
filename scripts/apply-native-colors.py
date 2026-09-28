#!/usr/bin/python3
"""Opt-in Lyra window/terminal colors for the current user, with undo.

No root, RPM, boot configuration or application restart is involved.
GTK 4 adapts in-process; a user service synchronizes GTK 3 and Terminal.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import tempfile
import subprocess
import sys

from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'src/gtk'
IMPORT = ('/* BEGIN Lyra native colors */\n'
          '@import url("lyra-native-colors.css");\n'
          '/* END Lyra native colors */\n').encode()


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            if path.exists():
                temporary.chmod(path.stat().st_mode & 0o777)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def encode(data):
    return base64.b64encode(data).decode() if data is not None else None


def contents(path):
    # Preserve symlink-based user theme managers; do not replace their links.
    if path.is_symlink():
        raise RuntimeError(f'Refusing to replace a symlink: {path}')
    return path.read_bytes() if path.exists() else None


def settings(schema, path=None):
    source = Gio.SettingsSchemaSource.get_default()
    definition = source.lookup(schema, True)
    return Gio.Settings.new_full(definition, None, path) if definition else None


class Changes:
    def __init__(self, state_dir):
        self.path = state_dir / 'native-colors.json'
        self.state = json.loads(self.path.read_text()) if self.path.exists() else {'files': {}, 'settings': {}}

    def save(self):
        atomic_write(self.path, (json.dumps(self.state, indent=2) + '\n').encode())

    def file(self, path, data):
        previous = contents(path)
        if previous == data and str(path) in self.state['files']:
            return
        record = self.state['files'].get(str(path))
        if record and encode(previous) != record['applied']:
            raise RuntimeError(f'File changed since application; preserving it: {path}')
        if not record:
            record = {'original': encode(previous)}
            self.state['files'][str(path)] = record
        record['applied'] = encode(data)
        self.save()  # Write-ahead recovery record, before changing preferences.
        atomic_write(path, data)

    def setting(self, obj, key, value, preserve_user=False):
        if not obj.is_writable(key):
            raise RuntimeError(f'Setting is locked: {obj.props.schema_id}/{key}')
        identity = json.dumps([obj.props.schema_id, obj.props.path, key])
        record = self.state['settings'].get(identity)
        if record and obj.get_value(key).print_(True) != record['applied']:
            if preserve_user:
                return
            if obj.get_value(key).equal(value):
                # E.g. the user selected light mode in GNOME, then reran
                # --variant auto. That preference now belongs to the user;
                # leave it unchanged and do not revert it on a later undo.
                del self.state['settings'][identity]
                self.save()
                return
            raise RuntimeError(f'Setting changed since application; preserving it: {key}')
        if not record:
            old = obj.get_user_value(key)
            record = {'original': old.print_(True) if old is not None else None}
            self.state['settings'][identity] = record
        record['applied'] = value.print_(True)
        self.save()
        if not obj.set_value(key, value):
            raise RuntimeError(f'Failed to set {key}')

    def undo(self):
        conflicts = []
        for identity, record in list(self.state['settings'].items()):
            schema, path, key = json.loads(identity)
            obj = settings(schema, path)
            if not obj or not obj.is_writable(key):
                conflicts.append(identity)
                continue
            actual = obj.get_value(key).print_(True)
            if actual != record['applied']:
                # A change made after us belongs to the user.
                conflicts.append(identity)
                continue
            if record['original'] is None:
                obj.reset(key)
            else:
                obj.set_value(key, GLib.Variant.parse(None, record['original'], None, None))
            del self.state['settings'][identity]
            self.save()
        Gio.Settings.sync()
        for filename, record in list(self.state['files'].items()):
            path = Path(filename)
            if encode(contents(path)) != record['applied']:
                conflicts.append(filename)
                continue
            if record['original'] is None:
                path.unlink(missing_ok=True)
            else:
                atomic_write(path, base64.b64decode(record['original']))
            del self.state['files'][filename]
            self.save()
        if not conflicts:
            self.path.unlink(missing_ok=True)
        return conflicts


def apply(changes, config, mode):
    palette = json.loads((ASSETS / 'palette.json').read_text())
    interface = settings('org.gnome.desktop.interface')
    if mode == 'auto':
        mode = 'dark' if interface.get_string('color-scheme') == 'prefer-dark' else 'light'
    if interface.get_string('gtk-theme').lower().startswith('highcontrast'):
        raise RuntimeError('High contrast is active; keep its accessibility colors.')
    accessibility = settings('org.gnome.desktop.a11y.interface')
    if accessibility and accessibility.get_boolean('high-contrast'):
        raise RuntimeError('High contrast is active; keep its accessibility colors.')
    # GTK 3 colors belong at theme priority, below application CSS. In
    # particular DING's transparent desktop window must win over theme colors.
    data = Path(GLib.get_user_data_dir())
    for variant in ('light', 'dark'):
        name = 'Lyra-Native' + ('-dark' if variant == 'dark' else '')
        for filename, selected in [('gtk.css', variant), ('gtk-dark.css', 'dark')]:
            stock = 'gtk-contained-dark.css' if selected == 'dark' else 'gtk-contained.css'
            theme = ('@import url("resource:///org/gtk/libgtk/theme/Adwaita/' + stock + '");\n').encode()
            theme += (ASSETS / f'gtk3-{selected}.css').read_bytes()
            changes.file(data / 'themes' / name / 'gtk-3.0' / filename, theme)
    # Refuse an old fixed GTK 3 override: undo must migrate it first, otherwise
    # user CSS would still override the native theme and the desktop window.
    old_gtk3 = config / 'gtk-3.0/gtk.css'
    if IMPORT in (contents(old_gtk3) or b''):
        raise RuntimeError('Run --undo on the old fixed palette before installing automatic colors.')
    directory = config / 'gtk-4.0'
    css = directory / 'gtk.css'
    old = contents(css) or b''
    target = directory / 'lyra-native-colors.css'
    if target.exists() and str(target) not in changes.state['files']:
        raise RuntimeError(f'Unmanaged palette already exists: {target}')
    changes.file(target, (ASSETS / 'gtk4-adaptive.css').read_bytes())
    changes.file(css, IMPORT + old.replace(IMPORT, b''))
    changes.setting(interface, 'gtk-theme', GLib.Variant('s', 'Lyra-Native-dark' if mode == 'dark' else 'Lyra-Native'))
    console = settings('org.gnome.Console')
    if console:
        changes.setting(console, 'theme', GLib.Variant('s', 'auto'), preserve_user=True)
    terminal_settings = settings('org.gnome.Terminal.Legacy.Settings')
    if terminal_settings:
        changes.setting(terminal_settings, 'theme-variant', GLib.Variant('s', 'system'), preserve_user=True)
    profiles = settings('org.gnome.Terminal.ProfilesList')
    if profiles:
        # Change only color keys in the current default; preserve font, shell,
        # scrollback, shortcuts and all other profiles.
        profile = profiles.get_string('default')
        if profile in profiles.get_strv('list'):
            terminal = settings('org.gnome.Terminal.Legacy.Profile',
                                f'/org/gnome/terminal/legacy/profiles:/:{profile}/')
            colors = palette['colors'][mode]
            for key, value in {
                'use-theme-colors': GLib.Variant('b', False),
                'background-color': GLib.Variant('s', colors['view']),
                'foreground-color': GLib.Variant('s', colors['fg']),
                'palette': GLib.Variant('as', palette['ansi'][mode]),
                'bold-color-same-as-fg': GLib.Variant('b', True),
            }.items():
                changes.setting(terminal, key, value)
    Gio.Settings.sync()
    return mode


def watch():
    interface = settings('org.gnome.desktop.interface')
    loop = GLib.MainLoop()
    def update(*_):
        try:
            changes = Changes(Path(GLib.get_user_state_dir()) / 'lyra-os-theme')
            apply(changes, Path(GLib.get_user_config_dir()), 'auto')
        except (OSError, RuntimeError) as error:
            print(f'Lyra colors: {error}', file=sys.stderr, flush=True)
    interface.connect('changed::color-scheme', update)
    profiles = settings('org.gnome.Terminal.ProfilesList')
    if profiles:
        profiles.connect('changed::default', update)
    update()
    Gio.bus_watch_name(Gio.BusType.SESSION, 'org.gnome.Shell',
                       Gio.BusNameWatcherFlags.NONE, lambda *_: None,
                       lambda *_: loop.quit())
    loop.run()


def install(changes):
    data = Path(GLib.get_user_data_dir()) / 'lyra-native-colors'
    changes.file(data / 'scripts/apply-native-colors.py', Path(__file__).read_bytes())
    for asset in ASSETS.iterdir():
        if asset.is_file():
            changes.file(data / 'src/gtk' / asset.name, asset.read_bytes())
    # Quote the executable path for systemd; use an absolute installed copy,
    # so the session never depends on a Git checkout staying in place.
    script = str(data / 'scripts/apply-native-colors.py').replace('%', '%%').replace('\\', '\\\\').replace('"', '\\"')
    unit = f"""[Unit]
Description=Lyra native window colors
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 "{script}" --watch
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
"""
    changes.file(Path(GLib.get_user_config_dir()) / 'systemd/user/lyra-native-colors.service', unit.encode())
    subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
    subprocess.run(['systemctl', '--user', 'enable', 'lyra-native-colors.service'], check=True)
    subprocess.run(['systemctl', '--user', 'restart', 'lyra-native-colors.service'], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', choices=('auto', 'dark', 'light'), default='auto')
    parser.add_argument('--undo', action='store_true')
    parser.add_argument('--install', action='store_true', help='Install automatic session integration')
    parser.add_argument('--refresh', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--watch', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error('Run as the desktop user, without sudo.')
    if args.watch:
        watch()
        return 0
    if args.refresh:
        # Package upgrades refresh only sessions that opted in. A backup from
        # a one-off preview, a disabled unit or a user-replaced unit is not
        # permission to enable an automatic theme service.
        changes = Changes(Path(GLib.get_user_state_dir()) / 'lyra-os-theme')
        unit = Path(GLib.get_user_config_dir()) / 'systemd/user/lyra-native-colors.service'
        record = changes.state['files'].get(str(unit))
        if not record or encode(contents(unit)) != record['applied']:
            return 0
        enabled = subprocess.run(['systemctl', '--user', 'is-enabled', '--quiet', 'lyra-native-colors.service'])
        if enabled.returncode:
            return 0
        args.install = True
    if args.undo:
        unit = Path(GLib.get_user_config_dir()) / 'systemd/user/lyra-native-colors.service'
        if unit.exists():
            subprocess.run(['systemctl', '--user', 'disable', '--now', 'lyra-native-colors.service'], check=True)
        changes = Changes(Path(GLib.get_user_state_dir()) / 'lyra-os-theme')
        conflicts = changes.undo()
        subprocess.run(['systemctl', '--user', 'daemon-reload'], check=False)
        if conflicts:
            print('Preserved later edits (backup retained):\n' + '\n'.join(conflicts))
            return 1
        print('Previous preferences restored. Reopen applications once to unload old GTK CSS.')
    else:
        # The watcher writes the same recovery journal. Stop it before
        # refreshing files so it cannot race the installation transaction.
        if args.install:
            subprocess.run(['systemctl', '--user', 'stop', 'lyra-native-colors.service'], check=False)
        changes = Changes(Path(GLib.get_user_state_dir()) / 'lyra-os-theme')
        if args.variant != 'auto':
            interface = settings('org.gnome.desktop.interface')
            changes.setting(interface, 'color-scheme', GLib.Variant('s', 'prefer-dark' if args.variant == 'dark' else 'default'))
        mode = apply(changes, Path(GLib.get_user_config_dir()), args.variant)
        if args.install:
            install(changes)
        print(f'Lyra {mode} colors applied. Backup: {changes.path}')
        print('Reopen applications once to replace the previous fixed CSS; subsequent mode changes are live.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
