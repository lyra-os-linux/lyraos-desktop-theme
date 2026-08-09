#!/usr/bin/env bash
set -Eeuo pipefail

repo=${LYRA_REPO:-britors/Lyra-Theme}
ref=${LYRA_REF:-main}
variant=dark
activate=1
uninstall=0
grub=1
plymouth=1
gdm=1

usage() {
  cat <<'EOF'
Lyra OS installer

Usage: install.sh [--dark|--light] [--no-activate] [--no-grub]
                   [--no-plymouth] [--no-gdm] [--uninstall]

  --dark          Use dark Adwaita with Lyra OS icons (default)
  --light         Use light Adwaita with Lyra OS icons
  --no-activate   Install files without changing GNOME, GRUB or Plymouth
                   settings, the GDM login screen, or the neofetch config
  --no-grub       Skip installing and activating the GRUB theme entirely
  --no-plymouth   Skip installing and activating the Plymouth theme entirely
  --no-gdm        Skip theming the GDM login screen entirely
  --uninstall     Remove both themes and restore GNOME defaults
EOF
}

while (($#)); do
  case $1 in
    --dark) variant=dark ;;
    --light) variant=light ;;
    --no-activate) activate=0 ;;
    --no-grub) grub=0 ;;
    --no-plymouth) plymouth=0 ;;
    --no-gdm) gdm=0 ;;
    --uninstall) uninstall=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# openSUSE ships GRUB 2 as grub2, configured via /boot/grub2/grub.cfg.
rebuild_grub_config() {
  if command -v grub2-mkconfig >/dev/null 2>&1; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
  elif [[ -x /usr/sbin/grub2-mkconfig ]]; then
    sudo /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
  else
    say 'grub2-mkconfig not found; regenerate grub.cfg manually'
  fi
}

command -v sudo >/dev/null 2>&1 || die 'sudo is required'
if ! sudo -n true 2>/dev/null; then
  say 'Administrator authentication is required'
  sudo -v </dev/tty
fi

if ((uninstall)); then
  say 'Removing Lyra OS'
  sudo rm -rf /usr/share/themes/Lyra-OS \
    /usr/share/themes/Lyra-OS-Light \
    /usr/share/icons/Lyra-OS-Icons \
    /usr/share/grub/themes/Lyra-OS \
    /usr/share/plymouth/themes/Lyra-OS \
    /usr/lib/dracut/modules.d/51lyra-plymouth \
    /usr/share/lyra-os-theme
  sudo rm -f /usr/share/backgrounds/lyra/*.png \
    /usr/share/backgrounds/lyra/*.jxl \
    /usr/share/gnome-background-properties/lyra-os.xml
  sudo rmdir /usr/share/backgrounds/lyra 2>/dev/null || true
  if ((activate)) && command -v gsettings >/dev/null 2>&1; then
    [[ $(readlink "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true) == /usr/share/themes/Lyra-OS* ]] && rm -f "$HOME/.config/gtk-4.0/gtk.css"
    gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface icon-theme 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface color-scheme 2>/dev/null || true
  fi
  if ((activate)) && [[ -f /etc/default/grub ]] && \
      sudo grep -qx 'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' /etc/default/grub; then
    sudo sed -i '\|^GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"$|d' /etc/default/grub
    if [[ -s /etc/default/grub.lyra-theme-backup ]]; then
      sudo sh -c 'cat /etc/default/grub.lyra-theme-backup >> /etc/default/grub'
    fi
    sudo rm -f /etc/default/grub.lyra-theme-backup
    rebuild_grub_config
  fi
  if ((activate)) && command -v plymouth-set-default-theme >/dev/null 2>&1; then
    if [[ -s /etc/plymouth/lyra-theme-backup ]]; then
      sudo plymouth-set-default-theme -R "$(sudo cat /etc/plymouth/lyra-theme-backup)"
    else
      sudo plymouth-set-default-theme -R details
    fi
    sudo rm -f /etc/plymouth/lyra-theme-backup
  fi
  if ((activate)) && command -v dconf >/dev/null 2>&1; then
    sudo rm -f /etc/dconf/db/gdm.d/00-lyra-os
    if [[ -f /etc/dconf/profile/gdm.lyra-theme-created ]]; then
      sudo rm -f /etc/dconf/profile/gdm /etc/dconf/profile/gdm.lyra-theme-created
    fi
    sudo dconf update
  fi
  if ((activate)); then
    if [[ -f "$HOME/.config/neofetch/config.conf.lyra-theme-backup" ]]; then
      mv "$HOME/.config/neofetch/config.conf.lyra-theme-backup" \
        "$HOME/.config/neofetch/config.conf"
    else
      rm -f "$HOME/.config/neofetch/config.conf"
    fi
    if [[ -f "$HOME/.config/fastfetch/config.jsonc.lyra-theme-backup" ]]; then
      mv "$HOME/.config/fastfetch/config.jsonc.lyra-theme-backup" \
        "$HOME/.config/fastfetch/config.jsonc"
    else
      rm -f "$HOME/.config/fastfetch/config.jsonc"
    fi
  fi
  say 'Uninstall complete'
  exit 0
fi

install_dependencies() {
  say 'Installing build and runtime dependencies'
  command -v zypper >/dev/null 2>&1 || die 'This installer supports openSUSE (zypper) only.'
  local packages=(
    adwaita-icon-theme curl fastfetch glib2-tools gtk3-tools gzip
    ImageMagick nodejs rsvg-convert sassc tar xz
  )
  ((grub)) && packages+=(grub2)
  ((plymouth)) && packages+=(
    cantarell-fonts dracut plymouth-plugin-two-step plymouth-scripts
    plymouth-theme-spinner
  )
  ((gdm)) && packages+=(dconf gnome-shell-extension-user-theme)
  sudo zypper --non-interactive install "${packages[@]}"
}

install_dependencies
command -v curl >/dev/null 2>&1 || die 'curl was not installed'
command -v magick >/dev/null 2>&1 || die 'ImageMagick 7 (magick) is required'
command -v node >/dev/null 2>&1 || die 'Node.js is required'
command -v rsvg-convert >/dev/null 2>&1 || die 'rsvg-convert is required'
command -v sassc >/dev/null 2>&1 || die 'sassc is required'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/source.tar.gz"
source_dir="$tmp/source"
mkdir -p "$source_dir"

say "Downloading $repo ($ref)"
curl --proto '=https' --tlsv1.2 -fsSL \
  "https://github.com/$repo/archive/$ref.tar.gz" -o "$archive"
tar -xzf "$archive" -C "$source_dir" --strip-components=1

say 'Building theme, icons, wallpapers, GRUB theme and Plymouth theme'
(cd "$source_dir" && ./scripts/build.sh && ./scripts/build-icons.sh && ./scripts/build-wallpaper-variants.sh)

say 'Installing system files'
sudo install -d /usr/share/themes /usr/share/icons \
  /usr/share/backgrounds/lyra /usr/share/gnome-background-properties \
  /usr/share/lyra-os-theme/fastfetch /usr/share/lyra-os-theme/gdm
sudo cp -a "$source_dir/dist/Lyra-OS" \
  "$source_dir/dist/Lyra-OS-Light" /usr/share/themes/
sudo cp -a "$source_dir/dist/Lyra-OS-Icons" /usr/share/icons/
sudo install -m 0644 "$source_dir"/dist/backgrounds/*.{png,jxl} \
  /usr/share/backgrounds/lyra/
sudo install -m 0644 \
  "$source_dir/dist/gnome-background-properties/lyra-os.xml" \
  /usr/share/gnome-background-properties/
sudo install -m 0644 "$source_dir/dist/fastfetch/config.jsonc" \
  "$source_dir/dist/fastfetch/logo.txt" \
  /usr/share/lyra-os-theme/fastfetch/
sudo install -m 0644 "$source_dir/dist/gdm/logo.svg" \
  /usr/share/lyra-os-theme/gdm/logo.svg
if ((grub)); then
  sudo install -d /usr/share/grub/themes
  sudo cp -a "$source_dir/dist/grub/Lyra-OS" /usr/share/grub/themes/
fi
if ((plymouth)); then
  sudo install -d /usr/share/plymouth/themes
  sudo cp -a "$source_dir/dist/plymouth/Lyra-OS" /usr/share/plymouth/themes/
  sudo install -d /usr/lib/dracut/modules.d/51lyra-plymouth
  sudo install -m 0755 "$source_dir/dist/dracut/51lyra-plymouth/module-setup.sh" \
    /usr/lib/dracut/modules.d/51lyra-plymouth/module-setup.sh
fi
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  sudo gtk-update-icon-cache -f /usr/share/icons/Lyra-OS-Icons >/dev/null || true

if ((activate)); then
  say 'Installing Lyra neofetch config'
  mkdir -p "$HOME/.config/neofetch"
  if [[ -f "$HOME/.config/neofetch/config.conf" && \
      ! -f "$HOME/.config/neofetch/config.conf.lyra-theme-backup" ]]; then
    cp "$HOME/.config/neofetch/config.conf" \
      "$HOME/.config/neofetch/config.conf.lyra-theme-backup"
  fi
  cp "$source_dir/dist/neofetch/config.conf" "$HOME/.config/neofetch/config.conf"

  say 'Installing Lyra Fastfetch config'
  mkdir -p "$HOME/.config/fastfetch"
  if [[ -f "$HOME/.config/fastfetch/config.jsonc" && \
      ! -f "$HOME/.config/fastfetch/config.jsonc.lyra-theme-backup" ]]; then
    cp "$HOME/.config/fastfetch/config.jsonc" \
      "$HOME/.config/fastfetch/config.jsonc.lyra-theme-backup"
  fi
  cp "$source_dir/dist/fastfetch/config.jsonc" \
    "$HOME/.config/fastfetch/config.jsonc"
fi

if ((activate)) && command -v gsettings >/dev/null 2>&1; then
  if [[ $variant == light ]]; then
    scheme=prefer-light
  else
    scheme=prefer-dark
  fi
  say 'Activating Adwaita with Lyra OS icons'
  gsettings reset org.gnome.shell.extensions.user-theme name 2>/dev/null || true
  gsettings reset org.gnome.desktop.interface gtk-theme 2>/dev/null || true
  gsettings set org.gnome.desktop.interface icon-theme 'Lyra-OS-Icons'
  gsettings set org.gnome.desktop.interface accent-color 'blue' 2>/dev/null || true
  gsettings set org.gnome.desktop.interface color-scheme "$scheme"
  gsettings set org.gnome.desktop.background picture-uri \
    'file:///usr/share/backgrounds/lyra/nebula-light.png'
  gsettings set org.gnome.desktop.background picture-uri-dark \
    'file:///usr/share/backgrounds/lyra/nebula.png'
  if [[ $(readlink "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true) == /usr/share/themes/Lyra-OS* ]]; then
    rm -f "$HOME/.config/gtk-4.0/gtk.css"
  fi
fi

if ((activate)) && ((grub)); then
  if [[ -f /etc/default/grub ]]; then
    say 'Activating Lyra OS for GRUB'
    if ! sudo grep -qx 'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' /etc/default/grub; then
      sudo sh -c "grep '^[[:space:]]*GRUB_THEME=' /etc/default/grub > /etc/default/grub.lyra-theme-backup || true"
    fi
    sudo sed -i '/^[[:space:]]*GRUB_THEME=/d' /etc/default/grub
    printf '%s\n' 'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' | \
      sudo tee -a /etc/default/grub >/dev/null
    rebuild_grub_config
  else
    say '/etc/default/grub not found; GRUB theme was installed but not activated'
  fi
fi

if ((activate)) && ((plymouth)); then
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    say 'Activating Lyra OS for Plymouth'
    if [[ ! -s /etc/plymouth/lyra-theme-backup ]]; then
      plymouth-set-default-theme 2>/dev/null | sudo tee /etc/plymouth/lyra-theme-backup >/dev/null || true
    fi
    sudo plymouth-set-default-theme -R Lyra-OS
  else
    say 'plymouth-set-default-theme not found; Plymouth theme was installed but not activated'
  fi
fi

if ((activate)) && ((gdm)); then
  if command -v dconf >/dev/null 2>&1; then
    say 'Activating Lyra OS for GDM'
    shell_theme=Lyra-OS
    scheme=prefer-dark
    if [[ $variant == light ]]; then
      shell_theme=Lyra-OS-Light
      scheme=prefer-light
    fi
    if [[ ! -f /etc/dconf/profile/gdm ]]; then
      printf 'user-db:user\nsystem-db:gdm\n' | sudo tee /etc/dconf/profile/gdm >/dev/null
      sudo touch /etc/dconf/profile/gdm.lyra-theme-created
    fi
    sudo install -d /etc/dconf/db/gdm.d
    sudo rm -f /etc/dconf/db/gdm.d/00-lyra-enterprise
    sudo tee /etc/dconf/db/gdm.d/00-lyra-os >/dev/null <<EOF
[org/gnome/desktop/interface]
icon-theme='Lyra-OS-Icons'
color-scheme='$scheme'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/lyra/nebula-light.png'
picture-uri-dark='file:///usr/share/backgrounds/lyra/nebula.png'
picture-options='zoom'

[org/gnome/shell]
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com']

[org/gnome/shell/extensions/user-theme]
name='$shell_theme'

[org/gnome/login-screen]
logo='/usr/share/lyra-os-theme/gdm/logo.svg'
fallback-logo=''
EOF
    sudo dconf update
  else
    say 'dconf not found; GDM theme was not activated'
  fi
fi

say 'Lyra OS installation complete'
printf 'Adwaita remains active for GNOME Shell and applications; Lyra supplies the icons.\n'
