Name:           lyra-nautilus-branding
Version:        1.9.3
Release:        0
Summary:        Lyra OS watermark for GNOME Files
License:        GPL-3.0-or-later
URL:            https://github.com/lyra-os-linux/lyraos-desktop-theme
Source0:        lyra-theme-src-%{version}.tar.gz
BuildRequires:  gcc
BuildRequires:  pkgconfig(gtk4) >= 4.16
BuildRequires:  pkgconfig(gmodule-2.0)
Requires:       nautilus >= 48

%description
Adds a subtle Lyra OS watermark to the fixed file viewport in GNOME Files.
Follows light and dark appearance and is removed immediately when the Sheliak
desktop profile is disabled or high contrast is enabled. User stylesheets,
file layouts and mouse input are preserved.

%prep
%autosetup -n lyra-theme-src-%{version}

%build
cc %{optflags} -Wall -Wextra -Werror -fPIC -shared \
    -Wl,--as-needed,-z,relro,-z,now \
    src/nautilus/lyra-watermark.c -o liblyra-watermark.so \
    $(pkg-config --cflags --libs gtk4 gmodule-2.0)

%install
install -Dm0755 liblyra-watermark.so \
    %{buildroot}%{_libdir}/nautilus/extensions-4/liblyra-watermark.so
install -Dm0644 src/nautilus/watermark-symbolic.svg \
    %{buildroot}%{_datadir}/lyra-os-theme/nautilus/watermark-symbolic.svg

%files
%license LICENSE
%doc docs/nautilus-watermark.md
%dir %{_libdir}/nautilus
%dir %{_libdir}/nautilus/extensions-4
%{_libdir}/nautilus/extensions-4/liblyra-watermark.so
%dir %{_datadir}/lyra-os-theme
%dir %{_datadir}/lyra-os-theme/nautilus
%{_datadir}/lyra-os-theme/nautilus/watermark-symbolic.svg

%changelog
