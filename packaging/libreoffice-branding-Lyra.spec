Name:           libreoffice-branding-Lyra
Version:        1.0.0
Release:        0
Summary:        Lyra OS branding for LibreOffice
License:        GPL-3.0-or-later AND BSD-3-Clause
URL:            https://github.com/lyra-os-linux/lyraos-desktop-theme
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  rsvg-convert
BuildRequires:  cantarell-fonts
Requires:       cantarell-fonts
# This is the branding interface required by openSUSE LibreOffice, not the
# independent artwork version. Do not constrain the office suite version.
Provides:       libreoffice-branding = 6.0
Conflicts:      libreoffice-branding

%description
Lyra OS splash, header and About artwork for LibreOffice. Replaces the
distribution branding package while retaining the system LibreOffice and
its normal updates. Uses a dark purple surface and the official Lyra logo.

%prep
%autosetup

%build
rsvg-convert --output intro.png src/libreoffice/intro.svg

%install
install -Dm0644 intro.png %{buildroot}%{_datadir}/libreoffice/program/intro.png
install -m0644 src/libreoffice/flat_logo.svg src/libreoffice/sofficerc \
    %{buildroot}%{_datadir}/libreoffice/program/
install -Dm0644 src/libreoffice/about.svg \
    %{buildroot}%{_datadir}/libreoffice/program/shell/about.svg

%files
%license LICENSE src/libreoffice/LICENSE.openSUSE
%doc docs/libreoffice-branding.md
%dir %{_datadir}/libreoffice
%dir %{_datadir}/libreoffice/program
%dir %{_datadir}/libreoffice/program/shell
%{_datadir}/libreoffice/program/intro.png
%{_datadir}/libreoffice/program/flat_logo.svg
%{_datadir}/libreoffice/program/sofficerc
%{_datadir}/libreoffice/program/shell/about.svg

%changelog
