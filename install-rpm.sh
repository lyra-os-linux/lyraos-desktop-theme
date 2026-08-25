#!/usr/bin/env bash
set -Eeuo pipefail

repo_alias='home_rodrigosbrito_lyra'
repo_url='https://download.opensuse.org/repositories/home:/rodrigosbrito:/lyra/openSUSE_Leap_16.0/'
variant=dark

# i18n: this script can run from a reviewed checkout, so message
# catalogs are embedded here rather than sourced from the repo. Locale
# comes from LYRA_LANG, falling back to the usual LC_ALL/LC_MESSAGES/LANG
# chain, and defaults to en_US when none of them match a supported locale.
# Lookups go through associative arrays (never eval) so translated text is
# always treated as data, not code.
lyra_locale() {
  local loc=${LYRA_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}
  loc=${loc%%.*}
  loc=${loc%%@*}
  case $loc in
    pt_BR|pt) printf 'pt_BR\n' ;;
    es|es_*) printf 'es\n' ;;
    *) printf 'en_US\n' ;;
  esac
}

declare -A MSG_EN_US=(
  [app_title]="Lyra OS RPM installer"
  [usage_label]="Usage:"
  [opt_dark]="Activate the dark wallpaper and color scheme (default)"
  [opt_light]="Activate the light wallpaper and color scheme"
  [unknown_option]="Unknown option: %s"
  [err_sudo_required]="sudo is required"
  [err_opensuse_only]="This installer supports openSUSE (zypper) only."
  [info_admin_auth]="Administrator authentication is required"
  [info_configuring_repo]="Configuring the Lyra package repository"
  [info_installing_pkgs]="Installing the Lyra theme and icon packages"
  [err_curl_missing]="curl was not installed"
  [info_installing_fastfetch_assets]="Installing the Lyra Fastfetch assets"
  [info_activating_icons_wallpapers]="Activating Lyra icons and wallpapers"
  [warn_gsettings_missing]="gsettings not found; GNOME will use the packaged defaults on a new profile"
  [info_activating_neofetch]="Activating the Lyra Neofetch configuration"
  [info_activating_fastfetch]="Activating the Lyra Fastfetch configuration"
  [info_confirming_grub]="Confirming the Lyra GRUB theme"
  [info_confirming_plymouth]="Confirming the Lyra Plymouth theme"
  [info_confirming_gdm]="Confirming the Lyra GDM theme"
  [info_install_active]="Lyra OS is installed and active"
)

declare -A MSG_PT_BR=(
  [app_title]="Instalador RPM do Lyra OS"
  [usage_label]="Uso:"
  [opt_dark]="Ativa o wallpaper e o esquema de cores escuros (padrão)"
  [opt_light]="Ativa o wallpaper e o esquema de cores claros"
  [unknown_option]="Opção desconhecida: %s"
  [err_sudo_required]="sudo é necessário"
  [err_opensuse_only]="Este instalador é compatível apenas com openSUSE (zypper)."
  [info_admin_auth]="É necessária autenticação de administrador"
  [info_configuring_repo]="Configurando o repositório de pacotes do Lyra"
  [info_installing_pkgs]="Instalando os pacotes de tema e ícones do Lyra"
  [err_curl_missing]="curl não foi instalado"
  [info_installing_fastfetch_assets]="Instalando os arquivos do Fastfetch do Lyra"
  [info_activating_icons_wallpapers]="Ativando os ícones e wallpapers do Lyra"
  [warn_gsettings_missing]="gsettings não encontrado; o GNOME usará os padrões do pacote em um novo perfil"
  [info_activating_neofetch]="Ativando a configuração do Neofetch do Lyra"
  [info_activating_fastfetch]="Ativando a configuração do Fastfetch do Lyra"
  [info_confirming_grub]="Confirmando o tema do Lyra no GRUB"
  [info_confirming_plymouth]="Confirmando o tema do Lyra no Plymouth"
  [info_confirming_gdm]="Confirmando o tema do Lyra no GDM"
  [info_install_active]="O Lyra OS está instalado e ativo"
)

declare -A MSG_ES=(
  [app_title]="Instalador RPM de Lyra OS"
  [usage_label]="Uso:"
  [opt_dark]="Activa el fondo de pantalla y el esquema de colores oscuros (predeterminado)"
  [opt_light]="Activa el fondo de pantalla y el esquema de colores claros"
  [unknown_option]="Opción desconocida: %s"
  [err_sudo_required]="se requiere sudo"
  [err_opensuse_only]="Este instalador solo es compatible con openSUSE (zypper)."
  [info_admin_auth]="Se requiere autenticación de administrador"
  [info_configuring_repo]="Configurando el repositorio de paquetes de Lyra"
  [info_installing_pkgs]="Instalando los paquetes de tema e íconos de Lyra"
  [err_curl_missing]="curl no se instaló"
  [info_installing_fastfetch_assets]="Instalando los archivos de Fastfetch de Lyra"
  [info_activating_icons_wallpapers]="Activando los íconos y fondos de pantalla de Lyra"
  [warn_gsettings_missing]="no se encontró gsettings; GNOME usará los valores predeterminados del paquete en un perfil nuevo"
  [info_activating_neofetch]="Activando la configuración de Neofetch de Lyra"
  [info_activating_fastfetch]="Activando la configuración de Fastfetch de Lyra"
  [info_confirming_grub]="Confirmando el tema de Lyra en GRUB"
  [info_confirming_plymouth]="Confirmando el tema de Lyra en Plymouth"
  [info_confirming_gdm]="Confirmando el tema de Lyra en GDM"
  [info_install_active]="Lyra OS está instalado y activo"
)

case $(lyra_locale) in
  pt_BR) declare -n MSG=MSG_PT_BR ;;
  es) declare -n MSG=MSG_ES ;;
  *) declare -n MSG=MSG_EN_US ;;
esac

msg() { printf '%s' "${MSG[$1]:-${MSG_EN_US[$1]:-$1}}"; }

say() {
  local key=$1; shift || true
  # shellcheck disable=SC2059
  printf "\033[1;34m==>\033[0m $(msg "$key")\n" "$@"
}

die() {
  local key=$1; shift || true
  # shellcheck disable=SC2059
  printf "\033[1;31merror:\033[0m $(msg "$key")\n" "$@" >&2
  exit 1
}

usage() {
  printf '%s\n\n' "$(msg app_title)"
  printf '%s install-rpm.sh [--dark|--light]\n\n' "$(msg usage_label)"
  printf '  --dark     %s\n' "$(msg opt_dark)"
  printf '  --light    %s\n' "$(msg opt_light)"
}

while (($#)); do
  case $1 in
    --dark) variant=dark ;;
    --light) variant=light ;;
    -h|--help) usage; exit 0 ;;
    *) printf -- "$(msg unknown_option)\n" "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v zypper >/dev/null 2>&1 || die err_opensuse_only
command -v sudo >/dev/null 2>&1 || die err_sudo_required

if ! sudo -n true 2>/dev/null; then
  say info_admin_auth
  sudo -v </dev/tty
fi

say info_configuring_repo
if sudo zypper lr "$repo_alias" >/dev/null 2>&1; then
  sudo zypper --non-interactive rr "$repo_alias"
fi
sudo zypper --non-interactive ar --refresh "$repo_url" "$repo_alias"
sudo zypper --gpg-auto-import-keys refresh "$repo_alias"

say info_installing_pkgs
sudo zypper --non-interactive install \
  curl fastfetch glib2-tools gnome-shell-extension-user-theme \
  lyra-os-theme lyra-os-icons
command -v curl >/dev/null 2>&1 || die err_curl_missing

fastfetch_share=/usr/share/lyra-os-theme/fastfetch
if [[ ! -f "$fastfetch_share/config.jsonc" || \
      ! -f "$fastfetch_share/logo.txt" ]]; then
  say info_installing_fastfetch_assets
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
  say info_activating_icons_wallpapers
  gsettings set org.gnome.desktop.interface icon-theme 'Lyra-OS-Icons'
  gsettings set org.gnome.desktop.interface accent-color 'blue' 2>/dev/null || true

  if [[ $variant == light ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  fi

  gsettings set org.gnome.desktop.background picture-uri \
    'file:///usr/share/backgrounds/lyra/lyra-voyage.png'
  gsettings set org.gnome.desktop.background picture-uri-dark \
    'file:///usr/share/backgrounds/lyra/lyra-voyage.png'
else
  say warn_gsettings_missing
fi

if [[ -f /usr/share/lyra-os-theme/neofetch/config.conf ]]; then
  say info_activating_neofetch
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
  say info_activating_fastfetch
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
  say info_confirming_grub
  sudo sed -i '/^[[:space:]]*GRUB_THEME=/d' /etc/default/grub
  printf '%s\n' \
    'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' |
    sudo tee -a /etc/default/grub >/dev/null
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg
fi

if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  say info_confirming_plymouth
  sudo plymouth-set-default-theme -R Lyra-OS
fi

if command -v dconf >/dev/null 2>&1; then
  say info_confirming_gdm
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
picture-uri='file:///usr/share/backgrounds/lyra/lyra-voyage.png'
picture-uri-dark='file:///usr/share/backgrounds/lyra/lyra-voyage.png'
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

say info_install_active
