#!/usr/bin/env bash
set -Eeuo pipefail

repo_alias='home_rodrigosbrito_lyra'
repo_url='https://download.opensuse.org/repositories/home:/rodrigosbrito:/lyra/openSUSE_Leap_16.0/'
variant=dark

usage() {
  cat <<'EOF'
Lyra OS RPM installer

Usage: install-rpm.sh [--dark|--light]

  --dark     Activate the dark wallpaper and color scheme (default)
  --light    Activate the light wallpaper and color scheme
EOF
}

while (($#)); do
  case $1 in
    --dark) variant=dark ;;
    --light) variant=light ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v zypper >/dev/null 2>&1 || die 'This installer supports openSUSE (zypper) only.'
command -v sudo >/dev/null 2>&1 || die 'sudo is required'

if ! sudo -n true 2>/dev/null; then
  say 'Administrator authentication is required'
  sudo -v </dev/tty
fi

say "Configuring the Lyra package repository"
if sudo zypper lr "$repo_alias" >/dev/null 2>&1; then
  sudo zypper --non-interactive rr "$repo_alias"
fi
sudo zypper --non-interactive ar --refresh "$repo_url" "$repo_alias"
sudo zypper --gpg-auto-import-keys refresh "$repo_alias"

say 'Installing the Lyra theme and icon packages'
sudo zypper --non-interactive install \
  curl fastfetch glib2-tools gnome-shell-extension-user-theme \
  lyra-os-theme lyra-os-icons
command -v curl >/dev/null 2>&1 || die 'curl was not installed'

fastfetch_share=/usr/share/lyra-os-theme/fastfetch
if [[ ! -f "$fastfetch_share/config.jsonc" || \
      ! -f "$fastfetch_share/logo.txt" ]]; then
  say 'Installing the Lyra Fastfetch assets'
  fastfetch_tmp=$(mktemp -d)
  trap 'rm -rf "$fastfetch_tmp"' EXIT
  curl --proto '=https' --tlsv1.2 -fsSL \
    https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/src/fastfetch/config.jsonc \
    -o "$fastfetch_tmp/config.jsonc"
  curl --proto '=https' --tlsv1.2 -fsSL \
    https://raw.githubusercontent.com/lyra-os-linux/lyraos-desktop-theme/main/src/fastfetch/logo.txt \
    -o "$fastfetch_tmp/logo.txt"
  sudo install -d "$fastfetch_share"
  sudo install -m 0644 "$fastfetch_tmp/config.jsonc" \
    "$fastfetch_tmp/logo.txt" "$fastfetch_share/"
fi

if command -v gsettings >/dev/null 2>&1; then
  say 'Activating Lyra icons and wallpapers'
  gsettings set org.gnome.desktop.interface icon-theme 'Lyra-OS-Icons'
  gsettings set org.gnome.desktop.interface accent-color 'blue' 2>/dev/null || true

  if [[ $variant == light ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  fi

  gsettings set org.gnome.desktop.background picture-uri \
    'file:///usr/share/backgrounds/lyra/nebula-light.png'
  gsettings set org.gnome.desktop.background picture-uri-dark \
    'file:///usr/share/backgrounds/lyra/nebula.png'
else
  say 'gsettings not found; GNOME will use the packaged defaults on a new profile'
fi

if [[ -f /usr/share/lyra-os-theme/neofetch/config.conf ]]; then
  say 'Activating the Lyra Neofetch configuration'
  mkdir -p "$HOME/.config/neofetch"
  if [[ -f "$HOME/.config/neofetch/config.conf" && \
      ! -f "$HOME/.config/neofetch/config.conf.lyra-theme-backup" ]]; then
    cp "$HOME/.config/neofetch/config.conf" \
      "$HOME/.config/neofetch/config.conf.lyra-theme-backup"
  fi
  cp /usr/share/lyra-os-theme/neofetch/config.conf \
    "$HOME/.config/neofetch/config.conf"
fi

if [[ -f /usr/share/lyra-os-theme/fastfetch/config.jsonc ]]; then
  say 'Activating the Lyra Fastfetch configuration'
  mkdir -p "$HOME/.config/fastfetch"
  if [[ -f "$HOME/.config/fastfetch/config.jsonc" && \
      ! -f "$HOME/.config/fastfetch/config.jsonc.lyra-theme-backup" ]]; then
    cp "$HOME/.config/fastfetch/config.jsonc" \
      "$HOME/.config/fastfetch/config.jsonc.lyra-theme-backup"
  fi
  cp /usr/share/lyra-os-theme/fastfetch/config.jsonc \
    "$HOME/.config/fastfetch/config.jsonc"
fi

if [[ -f /etc/default/grub ]]; then
  say 'Confirming the Lyra GRUB theme'
  sudo sed -i '/^[[:space:]]*GRUB_THEME=/d' /etc/default/grub
  printf '%s\n' \
    'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' |
    sudo tee -a /etc/default/grub >/dev/null
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  say 'Confirming the Lyra Plymouth theme'
  sudo plymouth-set-default-theme -R Lyra-OS
fi

if command -v dconf >/dev/null 2>&1; then
  say 'Confirming the Lyra GDM theme'
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
fi

say 'Lyra OS is installed and active'
