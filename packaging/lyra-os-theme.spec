Name:           lyra-os-theme
Version:        1.5.0
Release:        1%{?dist}
Summary:        Corporate GNOME, GRUB and Plymouth theme for Lyra OS
License:        GPL-3.0-or-later AND LGPL-2.1-or-later
URL:            https://github.com/britors/lyra-os-theme
Source0:        %{name}-%{version}.tar.xz
BuildArch:      noarch
# cantarell-fonts também precisa estar disponível em build time: o texto
# "LYRA OS" do watermark do Plymouth/GDM vem de um <text> no logo.svg,
# rasterizado por rsvg-convert durante o build (não em runtime).
BuildRequires:  ImageMagick
BuildRequires:  cantarell-fonts
BuildRequires:  nodejs
BuildRequires:  rsvg-convert
BuildRequires:  sassc
Requires:       lyra-os-icons
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
Recommends:     gnome-shell-extension-user-theme
Suggests:       neofetch

%description
Corporate, flat GNOME 48+ theme with dark and light variants for GNOME Shell,
GTK 4/libadwaita and GTK 3, also themed on the GDM login screen. Includes
matching PNG and JPEG XL wallpapers, the Lyra OS boot menu theme for
GRUB 2, a matching Plymouth boot splash theme, plus Fastfetch and Neofetch
configs with a Lyra ascii logo.

%prep
%autosetup

%build
./scripts/build.sh
./scripts/build-wallpaper-variants.sh

%install
install -d %{buildroot}%{_datadir}/themes
cp -a dist/Lyra-OS dist/Lyra-OS-Light %{buildroot}%{_datadir}/themes/

install -d %{buildroot}%{_datadir}/backgrounds/lyra
install -m 0644 dist/backgrounds/*.png dist/backgrounds/*.jxl \
  %{buildroot}%{_datadir}/backgrounds/lyra/

install -d %{buildroot}%{_datadir}/gnome-background-properties
install -m 0644 dist/gnome-background-properties/lyra-os.xml \
  %{buildroot}%{_datadir}/gnome-background-properties/

install -d %{buildroot}%{_datadir}/glib-2.0/schemas
install -m 0644 src/defaults/99-lyra-os.gschema.override \
  %{buildroot}%{_datadir}/glib-2.0/schemas/

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
picture-uri='file:///usr/share/backgrounds/lyra/os-light.png'
picture-uri-dark='file:///usr/share/backgrounds/lyra/os.png'
picture-options='zoom'

[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com']

[org/gnome/shell/extensions/user-theme]
name='Lyra-OS'

[org/gnome/login-screen]
logo='/usr/share/lyra-os-theme/gdm/logo.svg'
fallback-logo=''
GDM_DCONF
%{_bindir}/dconf update || :

# Migrate the pre-rename icon-theme value ('Lyra-Enterprise-Icons') that
# earlier package versions left behind in already-logged-in users' own
# dconf db. The compiled gschema override above only supplies the default
# for sessions with no explicit value, so it can't reach users who already
# have the stale name recorded. Only sessions whose icon-theme is exactly
# the stale value are touched, so a user's deliberate choice of a
# different icon theme is never overwritten. A gsettings write via
# runuser+D-Bus can silently no-op if the target bus isn't actually
# reachable, so every write is read back and a failure is logged instead
# of assumed fixed.
stale_icon_theme='Lyra-Enterprise-Icons'
new_icon_theme='Lyra-OS-Icons'
%{_bindir}/loginctl list-sessions --no-legend 2>/dev/null | while read -r session_id session_uid session_user _; do
  [ "$(%{_bindir}/loginctl show-session "$session_id" -p Class --value 2>/dev/null)" = user ] || continue
  session_bus="/run/user/$session_uid/bus"
  [ -S "$session_bus" ] || continue

  current=$(%{_sbindir}/runuser -u "$session_user" -- env \
    XDG_RUNTIME_DIR="/run/user/$session_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$session_bus" \
    %{_bindir}/gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || :)
  [ "$current" = "'$stale_icon_theme'" ] || continue

  %{_sbindir}/runuser -u "$session_user" -- env \
    XDG_RUNTIME_DIR="/run/user/$session_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$session_bus" \
    %{_bindir}/gsettings set org.gnome.desktop.interface icon-theme "$new_icon_theme" || :

  applied=$(%{_sbindir}/runuser -u "$session_user" -- env \
    XDG_RUNTIME_DIR="/run/user/$session_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=$session_bus" \
    %{_bindir}/gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || :)
  if [ "$applied" = "'$new_icon_theme'" ]; then
    echo "lyra-os-theme: icon-theme obsoleto corrigido para $session_user (sessão $session_id)"
  else
    echo "lyra-os-theme: aviso: não foi possível corrigir o icon-theme de $session_user (sessão $session_id); rode manualmente: gsettings set org.gnome.desktop.interface icon-theme '$new_icon_theme'" >&2
  fi
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
%license LICENSE src/gtk3/COPYING.LGPL
%doc README.md src/gtk3/ATTRIBUTION.md
%{_datadir}/themes/Lyra-OS/
%{_datadir}/themes/Lyra-OS-Light/
# Explicit parent-directory entries below are required because none of
# these come from a Requires of this package (no grub2/plymouth runtime
# dependency, since the theme is meant to be optional on top of whatever
# bootloader/splash the system already has), so nothing else is
# guaranteed to own the parent dirs — rpmbuild's unowned-directory check
# fails without these.
%dir %{_datadir}/backgrounds
%dir %{_datadir}/backgrounds/lyra
%{_datadir}/backgrounds/lyra/*.png
%{_datadir}/backgrounds/lyra/*.jxl
%dir %{_datadir}/gnome-background-properties
%{_datadir}/gnome-background-properties/lyra-os.xml
%{_datadir}/glib-2.0/schemas/99-lyra-os.gschema.override
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
* Fri Jul 24 2026 Lyra OS Team <rodrigo@w3ti.com.br> - 1.5.0-1
- Theme the GDM login screen (icons, wallpaper and Shell colors) via a
  dconf gdm profile

* Thu Jul 23 2026 Lyra OS Team <rodrigo@w3ti.com.br> - 1.4.0-1
- Add Plymouth boot theme matching GRUB, and a neofetch config with a Lyra
  ascii logo
- Drop KDE Plasma/Konsole and XFCE support to focus on GNOME

* Tue Jul 21 2026 Lyra OS Team <rodrigo@w3ti.com.br> - 1.3.0-1
- Add xfwm4 window theme and xfce4-terminal color scheme for XFCE

* Tue Jul 21 2026 Lyra OS Team <rodrigo@w3ti.com.br> - 1.2.0-1
- Add Plasma color schemes and matching Konsole color schemes for KDE

* Sun Jul 19 2026 Lyra OS Team <rodrigo@w3ti.com.br> - 1.1.0-1
- Keep Adwaita active by default and add the GRUB theme

* Sun Jul 19 2026 Lyra OS Team <rodrigo@w3ti.com.br> - 1.0.0-1
- Initial RPM package with dark and light variants
