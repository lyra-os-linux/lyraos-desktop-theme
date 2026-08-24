Name:           lyra-os-icons
Version:        1.1.0
Release:        1%{?dist}
Summary:        Flat sapphire icon theme for Lyra OS
License:        GPL-3.0-or-later
URL:            https://github.com/lyra-os-linux/lyraos-desktop-theme
Source0:        lyra-os-theme-%{version}.tar.xz
BuildArch:      noarch
Requires:       adwaita-icon-theme

%description
Icon theme for Lyra OS. It provides branded vector icons for common
places, devices and applications and inherits Adwaita for complete GNOME coverage.

%prep
%autosetup -n lyra-os-theme-%{version}

%build
./scripts/build-icons.sh

%install
install -d %{buildroot}%{_datadir}/icons
cp -a dist/Lyra-OS-Icons %{buildroot}%{_datadir}/icons/

%files
%license LICENSE
%{_datadir}/icons/Lyra-OS-Icons/

%changelog
* Sun Jul 19 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.1.0-1
- Release icons for Lyra Enterprise 1.1.0

* Sun Jul 19 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.0.0-1
- Initial os icon theme
