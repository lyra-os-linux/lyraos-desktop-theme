# Nautilus watermark

`lyra-nautilus-branding` adds the official Lyra logo behind the file viewport:
96 logical pixels, 8% opacity and a 24-pixel inset. The transparent margins in
the original artwork are preserved. GTK recolors the monochrome image using
the current foreground color, including live light/dark changes.

The module uses the Nautilus module lifecycle and a display CSS provider. It
does not register file/menu providers, traverse user files, create input
widgets, replace `gtk.css`, or change file layout and selection. The selectors
are restricted to Nautilus windows, excluding its file chooser and dialogs.
The background belongs to the fixed scrolled window, not its scrolling child.
Empty-folder status pages have their own background so the logo is painted
once even when the underlying file view is covered.

The watermark is active in a GNOME session when at least one Lyra shell
component is enabled: Dock, Panel, Menus, Search or Animations. The legacy
`sheliak@lyraos.com.br` UUID remains supported for older sessions. Lyra, Ubuntu,
Lyra Classic, Lyra Central and Lyra Floating use the same condition.
Each UUID listed in `disabled-extensions` is excluded independently. Disabling
one component does not remove the watermark while another remains enabled.

GNOME Vanilla, including Desktop Icons enabled on its own, leaves Nautilus
unbranded. Disabling all user extensions or enabling high contrast removes the
provider immediately in existing windows. The original colors/backgrounds are
then supplied by Nautilus and the user theme. A user CSS provider has higher
priority than this application provider.

No Nautilus process is restarted by the package. Initial installation or a
module update takes effect at the next Nautilus process start; subsequent
appearance/profile changes are live. Missing GNOME schemas or logo files leave
Nautilus unmodified. A module shutdown disconnects settings and removes its
provider. Modules can be disabled for troubleshooting with Nautilus's normal
`NAUTILUS_DISABLE_PLUGINS=TRUE` setting.

## Packaging

The main `lyra-os-theme` package remains architecture independent and weakly
recommends this package when Nautilus is installed. The small native module is
built separately from `packaging/lyra-nautilus-branding.spec`, using the same
`lyra-theme-src-VERSION.tar.gz` source snapshot. It requires GTK 4.16+ at build
time and Nautilus 48+ at runtime. It adds no Python, Flatpak or desktop-specific
Vega dependencies. It does not pin an upper Nautilus version or block upgrades.

Install locations:

- `%{_libdir}/nautilus/extensions-4/liblyra-watermark.so`
- `/usr/share/lyra-os-theme/nautilus/watermark-symbolic.svg`

An OBS publication must create/update a **separate `lyra-nautilus-branding`
package**, pin the reviewed source snapshot and use this spec. Publishing only
the existing `lyra-theme` package cannot deliver the module. There are no RPM
scriptlets or host/session modifications in this new package.

The SVG embeds the unchanged alpha mask from
`lyraos-desktop-sheliak/logo/lyra-logo-mono.svg`; the enclosing rectangle applies
foreground recoloring and opacity without redrawing the official logo.

## Validation

The target is Nautilus 48.7 / GTK 4.18.6 / libadwaita 1.7.5 on Leap 16.1. The
Nautilus module API is public; CSS classes and widget nesting are upstream
implementation details and should be rechecked when updating Nautilus. An
unmatched selector leaves the view unbranded rather than changing its layout.

Run the real application in disposable D-Bus, XDG directories, a headless
Mutter and a read-only mount namespace:

```sh
python3 tests/native-nautilus.py --output /tmp/lyra-watermark-scale1
python3 tests/native-nautilus.py --scale 2 --output /tmp/lyra-watermark-scale2
```

Pass `--rpm /path/to/lyra-nautilus-branding.rpm` to extract and exercise the
actual packaged module and artwork in that namespace, without installation.
The checks compare complete screenshots with branding off/on and require all
changed pixels to remain inside the logo rectangle. They also compare view
geometry, scroll position, selection and 25 pointer hit targets. Coverage
includes search, tab changes, a second window, resize, high contrast, extension
disable switches and a higher-priority user stylesheet.

Requires a C compiler, GTK4/libadwaita development packages, Nautilus, Mutter,
bubblewrap, Python GI and GdkPixbuf. The fixture module is compiled solely into
the test namespace and is never included in the RPM. PNGs, widget state and logs
are kept in the output directory. No personal Nautilus process is used.
