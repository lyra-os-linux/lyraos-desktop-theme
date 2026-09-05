Name:           lyra-os-theme
Version:        1.9.3
Release:        1%{?dist}
Summary:        Boot branding and GNOME icon integration for Lyra OS
License:        GPL-3.0-or-later
URL:            https://github.com/lyra-os-linux/lyraos-desktop-theme
Source0:        %{name}-%{version}.tar.xz
BuildArch:      noarch
# cantarell-fonts também precisa estar disponível em build time: o texto
# "LYRA OS" do watermark do Plymouth/GDM vem de um <text> no logo.svg,
# rasterizado por rsvg-convert durante o build (não em runtime).
BuildRequires:  cantarell-fonts
BuildRequires:  rsvg-convert
BuildRequires:  python3
Requires:       python3-gobject
Requires:       lyra-os-icons
Requires:       lyra-os-wallpapers
Requires:       cantarell-fonts
Requires:       dracut
Requires:       plymouth-plugin-two-step
Requires:       plymouth-theme-spinner
Requires(post): grub2
Requires(preun): grub2
Requires(post): plymouth-scripts
Requires(preun): plymouth-scripts
Requires(post): dconf
Requires(preun): dconf
Recommends:     fastfetch
Suggests:       neofetch

%description
GNOME applications and Shell use the standard GNOME theme. Lyra icons follow
the system accent color. Includes the GDM login logo and
the Lyra OS boot menu theme for
GRUB 2, a matching Plymouth boot splash theme, plus Fastfetch and Neofetch
configs with a Lyra ascii logo.

%prep
%autosetup

%build
./scripts/build.sh

%install
install -d %{buildroot}%{_datadir}/glib-2.0/schemas
install -m 0644 src/defaults/99-lyra-os.gschema.override \
  %{buildroot}%{_datadir}/glib-2.0/schemas/

install -d %{buildroot}%{_libexecdir} %{buildroot}%{_sysconfdir}/xdg/autostart
install -m 0755 src/defaults/lyra-os-apply-full-theme \
  %{buildroot}%{_libexecdir}/lyra-os-apply-full-theme
install -m 0644 src/defaults/lyra-os-full-theme.desktop \
  %{buildroot}%{_sysconfdir}/xdg/autostart/

install -d %{buildroot}%{_datadir}/grub/themes
cp -a dist/grub/Lyra-OS %{buildroot}%{_datadir}/grub/themes/

install -d %{buildroot}%{_datadir}/plymouth/themes
cp -a dist/plymouth/Lyra-OS %{buildroot}%{_datadir}/plymouth/themes/

install -d %{buildroot}%{_prefix}/lib/dracut/modules.d/51lyra-plymouth
install -m 0755 dist/dracut/51lyra-plymouth/module-setup.sh \
  %{buildroot}%{_prefix}/lib/dracut/modules.d/51lyra-plymouth/module-setup.sh

install -d %{buildroot}%{_datadir}/%{name}/neofetch
install -m 0644 dist/neofetch/config.conf \
  %{buildroot}%{_datadir}/%{name}/neofetch/config.conf

install -d %{buildroot}%{_datadir}/%{name}/fastfetch
install -m 0644 dist/fastfetch/config.jsonc dist/fastfetch/logo.txt \
  %{buildroot}%{_datadir}/%{name}/fastfetch/

install -d %{buildroot}%{_datadir}/%{name}/gdm
install -m 0644 dist/gdm/logo.svg \
  %{buildroot}%{_datadir}/%{name}/gdm/logo.svg

install -d %{buildroot}%{_sysconfdir}/skel/.config/neofetch
install -m 0644 dist/neofetch/config.conf \
  %{buildroot}%{_sysconfdir}/skel/.config/neofetch/config.conf

install -d %{buildroot}%{_sysconfdir}/skel/.config/fastfetch
install -m 0644 dist/fastfetch/config.jsonc \
  %{buildroot}%{_sysconfdir}/skel/.config/fastfetch/config.jsonc

%post
grub_default=%{_sysconfdir}/default/grub
grub_backup=%{_localstatedir}/lib/%{name}/grub-theme.backup
plymouth_backup=%{_localstatedir}/lib/%{name}/plymouth-theme.backup
lyra_theme='GRUB_THEME="%{_datadir}/grub/themes/Lyra-OS/theme.txt"'

install -d -m 0755 %{_localstatedir}/lib/%{name}

if [ -f "$grub_default" ]; then
  if [ "$1" -eq 1 ]; then
    grep '^[[:space:]]*GRUB_THEME=' "$grub_default" > "$grub_backup" || :
  fi
  sed -i '/^[[:space:]]*GRUB_THEME=/d' "$grub_default"
  printf '%s\n' "$lyra_theme" >> "$grub_default"
  %{_sbindir}/grub2-mkconfig -o /boot/grub2/grub.cfg || :
fi

if [ "$1" -eq 1 ]; then
  %{_sbindir}/plymouth-set-default-theme > "$plymouth_backup" || :
fi
%{_sbindir}/plymouth-set-default-theme -R Lyra-OS || :

gdm_profile=%{_sysconfdir}/dconf/profile/gdm
gdm_profile_marker=%{_localstatedir}/lib/%{name}/gdm-profile-created
gdm_db_dir=%{_sysconfdir}/dconf/db/gdm.d

if [ ! -f "$gdm_profile" ]; then
  install -d -m 0755 "$(dirname "$gdm_profile")"
  printf 'user-db:user\nsystem-db:gdm\n' > "$gdm_profile"
  touch "$gdm_profile_marker"
fi

install -d -m 0755 "$gdm_db_dir"
rm -f "$gdm_db_dir/00-lyra-enterprise"
cat > "$gdm_db_dir/00-lyra-os" <<'GDM_DCONF'
[org/gnome/desktop/interface]
icon-theme='Lyra-OS-Icons'
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/lyra/2702-voyage.png'
picture-uri-dark='file:///usr/share/backgrounds/lyra/2702-voyage.png'
picture-options='zoom'

[org/gnome/login-screen]
logo='/usr/share/lyra-os-theme/gdm/logo.svg'
fallback-logo=''
GDM_DCONF
%{_bindir}/dconf update || :

# Apply immediately to every reachable graphical user session. Users who are
# currently logged out are covered by the XDG autostart entry on next login.
%{_bindir}/loginctl list-sessions --no-legend 2>/dev/null | while read -r session_id session_uid session_user _; do
  [ "$(%{_bindir}/loginctl show-session "$session_id" -p Class --value 2>/dev/null)" = user ] || continue
  session_desktop=$(%{_bindir}/loginctl show-session "$session_id" -p Desktop --value 2>/dev/null)
  session_bus="/run/user/$session_uid/bus"
  [ -S "$session_bus" ] || continue
  %{_sbindir}/runuser -u "$session_user" -- env \
    HOME="$(getent passwd "$session_user" | cut -d: -f6)" \
    XDG_CURRENT_DESKTOP="$session_desktop" \
    XDG_RUNTIME_DIR="/run/user/$session_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$session_bus" \
    %{_libexecdir}/lyra-os-apply-full-theme || :
done || :

%preun
if [ "$1" -eq 0 ]; then
  grub_default=%{_sysconfdir}/default/grub
  grub_backup=%{_localstatedir}/lib/%{name}/grub-theme.backup
  plymouth_backup=%{_localstatedir}/lib/%{name}/plymouth-theme.backup
  lyra_theme='GRUB_THEME="%{_datadir}/grub/themes/Lyra-OS/theme.txt"'

  if [ -f "$grub_default" ] && grep -Fqx "$lyra_theme" "$grub_default"; then
    sed -i '\|^[[:space:]]*GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"$|d' "$grub_default"
    if [ -s "$grub_backup" ]; then
      cat "$grub_backup" >> "$grub_default"
    fi
    %{_sbindir}/grub2-mkconfig -o /boot/grub2/grub.cfg || :
  fi

  if [ "$(%{_sbindir}/plymouth-set-default-theme 2>/dev/null)" = "Lyra-OS" ]; then
    if [ -s "$plymouth_backup" ]; then
      read -r previous_plymouth < "$plymouth_backup"
      %{_sbindir}/plymouth-set-default-theme -R "$previous_plymouth" || :
    else
      %{_sbindir}/plymouth-set-default-theme -R --reset || :
    fi
  fi

  gdm_profile=%{_sysconfdir}/dconf/profile/gdm
  gdm_profile_marker=%{_localstatedir}/lib/%{name}/gdm-profile-created

  rm -f %{_sysconfdir}/dconf/db/gdm.d/00-lyra-os
  if [ -f "$gdm_profile_marker" ]; then
    rm -f "$gdm_profile" "$gdm_profile_marker"
  fi
  %{_bindir}/dconf update || :

  rm -f "$grub_backup"
  rm -f "$plymouth_backup"
  rmdir %{_localstatedir}/lib/%{name} 2>/dev/null || :
fi

%files
%license LICENSE
%doc README.md
# Explicit parent-directory entries below are required because none of
# these come from a Requires of this package (no grub2/plymouth runtime
# dependency, since the theme is meant to be optional on top of whatever
# bootloader/splash the system already has), so nothing else is
# guaranteed to own the parent dirs — rpmbuild's unowned-directory check
# fails without these.
%{_datadir}/glib-2.0/schemas/99-lyra-os.gschema.override
%{_libexecdir}/lyra-os-apply-full-theme
%{_sysconfdir}/xdg/autostart/lyra-os-full-theme.desktop
%dir %{_datadir}/grub
%dir %{_datadir}/grub/themes
%{_datadir}/grub/themes/Lyra-OS/
%dir %{_datadir}/plymouth
%dir %{_datadir}/plymouth/themes
%{_datadir}/plymouth/themes/Lyra-OS/
%{_prefix}/lib/dracut/modules.d/51lyra-plymouth/
%dir %{_datadir}/%{name}
%dir %{_datadir}/%{name}/neofetch
%{_datadir}/%{name}/neofetch/config.conf
%dir %{_datadir}/%{name}/fastfetch
%{_datadir}/%{name}/fastfetch/config.jsonc
%{_datadir}/%{name}/fastfetch/logo.txt
%dir %{_datadir}/%{name}/gdm
%{_datadir}/%{name}/gdm/logo.svg
%dir %{_sysconfdir}/skel/.config
%dir %{_sysconfdir}/skel/.config/neofetch
%config(noreplace) %{_sysconfdir}/skel/.config/neofetch/config.conf
%dir %{_sysconfdir}/skel/.config/fastfetch
%config(noreplace) %{_sysconfdir}/skel/.config/fastfetch/config.jsonc

%changelog
* Fri Jul 24 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.5.0-1
- Theme the GDM login screen (icons, wallpaper and Shell colors) via a
  dconf gdm profile

* Thu Jul 23 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.4.0-1
- Add Plymouth boot theme matching GRUB, and a neofetch config with a Lyra
  ascii logo
- Drop KDE Plasma/Konsole and XFCE support to focus on GNOME

* Tue Jul 21 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.3.0-1
- Add xfwm4 window theme and xfce4-terminal color scheme for XFCE

* Tue Jul 21 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.2.0-1
- Add Plasma color schemes and matching Konsole color schemes for KDE

* Sun Jul 19 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.1.0-1
- Keep Adwaita active by default and add the GRUB theme

* Sun Jul 19 2026 Lyra OS Team <rodrigo@lyraos.com.br> - 1.0.0-1
- Initial RPM package with dark and light variants
