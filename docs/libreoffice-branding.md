# LibreOffice branding

`libreoffice-branding-Lyra` supplies the openSUSE LibreOffice branding files:
the startup image, flat header, About illustration and `sofficerc`. The splash
uses a 600 × 240 dark purple surface, the existing official Lyra harp, and the
LibreOffice / The Document Foundation names. All artwork is self-contained.
The splash is deliberately fixed dark regardless of desktop appearance.

The native progress bar occupies x=32, y=206, width=536, height=4. Progress text
uses baseline 189, above the bar. The final PNG contains the track only;
LibreOffice paints the actual progress and its own localized messages.
`rsvg-convert` and Cantarell render the splash during RPM build.

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
