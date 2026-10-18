# LibreOffice branding

`libreoffice-branding-Lyra` supplies the openSUSE LibreOffice branding files:
the startup image (1x and HiDPI), flat header, About illustration, the About
dialog brand logo (light and dark variants) and `sofficerc`. The splash
uses a 600 × 240 dark purple surface, the existing official Lyra harp, and the
LibreOffice / The Document Foundation names. All artwork is self-contained.
The splash is deliberately fixed dark regardless of desktop appearance.

The native progress bar occupies x=32, y=206, width=536, height=4. Progress text
uses baseline 189, above the bar. The final PNG contains the track only;
LibreOffice paints the actual progress and its own localized messages.
`rsvg-convert` and Cantarell render the splash during RPM build.

## Files expected by the LibreOffice package

The openSUSE `libreoffice` RPM owns symlinks in `/usr/lib64/libreoffice/program`
that point into `/usr/share/libreoffice/program`, where the branding provider
must place the targets:

| Symlink in `program/`      | Provided here                       | Used by                               |
|----------------------------|-------------------------------------|---------------------------------------|
| `intro.png`                | `intro.png` (600 × 240)             | splash at UI scale 1                  |
| `intro-highres.png`        | `intro-highres.png` (1200 × 480)    | splash at UI scale above 1 (HiDPI)    |
| (none, see below)          | `src/libreoffice/flat_logo.svg`     | kept for layout parity with openSUSE  |
| `shell/about.svg`          | `src/libreoffice/about.svg`         | About dialog illustration             |
| `shell/logo.svg`           | `src/libreoffice/logo.svg`          | About dialog brand logo, light theme  |
| `shell/logo_inverted.svg`  | `src/libreoffice/logo_inverted.svg` | About dialog brand logo, dark theme   |

LibreOffice 26.2 no longer links `flat_logo.svg`; the file is kept only
because the openSUSE provider still ships it. `shell/logo.svg` and
`shell/logo_inverted.svg` are referenced by the About dialog (`libcuilo.so`).

Version 1.0.0 shipped only `intro.png`, `flat_logo.svg`, `sofficerc` and
`shell/about.svg`; `rpm -V libreoffice` then
reported `intro-highres.png`, `shell/logo.svg` and `shell/logo_inverted.svg` as
missing and the About dialog fell back to the built-in Document Foundation logo
(lyra-os-linux/lyraos-desktop-theme#22). Version 1.0.1 adds the three files.
`intro-highres.png` is rendered from the same `intro.svg` at zoom 2, so the
progress geometry in `sofficerc` stays valid. The brand logo keeps the upstream
proportions (346 × 72 like `logo-sc.svg`): harp, "LibreOffice" wordmark and a
"Lyra OS" caption, with dark text for the light variant and light text for the
inverted (dark theme) variant. The CI workflow checks that the built RPM lists
all seven paths. Verified on Leap 16.1 with libreoffice 26.2.5.1: after
installing 1.0.1 and reinstalling `libreoffice`, `rpm -V libreoffice` is clean
and every symlink resolves.

## Packaging and updates

This is an independent noarch RPM. `Provides: libreoffice-branding = 6.0`
implements the capability required by the installed openSUSE LibreOffice;
the artwork itself has version 1.0.0. `Conflicts: libreoffice-branding` follows
the openSUSE packaging convention and makes branding providers mutually
exclusive. It does not constrain or replace the LibreOffice application.
No scriptlets, update locks, user profile edits or direct overwrites of another
package's files are used. Switching providers must be one reviewed package
transaction. Do not use `--replacefiles` or disable conflict checks.

The initial package is opt-in. Publishing it to OBS requires a separate package
and source tarball named `libreoffice-branding-Lyra-1.0.0.tar.gz`, with the same
top-level directory. Including it in the ISO/default installation is a separate
integration step after visual approval. Reinstalling the openSUSE branding
provider in place of this RPM restores its original artwork.

Restart LibreOffice to see a newly installed splash; starting another document
while LibreOffice is already running does not necessarily show it. User settings
or `--nologo` can disable the splash. Do not terminate an existing office process
just to preview the branding: it may contain unsaved documents.

## Provenance

The harp is reused unchanged from Sheliak's `logo/png/lyra-logo-256.png`.
The SVG layouts are Lyra artwork. `sofficerc` is based on openSUSE's
`branding-tumbleweed/libreoffice/sofficerc`, source MD5
`b6fd473674bcdadc102e665c96d5805f`, obtained from
https://build.opensuse.org/package/show/openSUSE:Factory/branding-openSUSE.
Only the progress colors, dimensions and text baseline differ. Bootstrap,
crash-directory and secure-user-configuration settings are preserved.
The original BSD notice is included in `src/libreoffice/LICENSE.openSUSE`.

Build with `rpmbuild -bb packaging/libreoffice-branding-Lyra.spec` after placing
the source archive in the configured RPM SOURCES directory.
