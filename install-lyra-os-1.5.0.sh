#!/usr/bin/env bash
set -Eeuo pipefail

theme_rpm=/tmp/lyra-rpms-1.5.0/lyra-os-theme-1.5.0-lp160.14.1.noarch.rpm
icons_rpm=/tmp/lyra-rpms-1.5.0/lyra-os-icons-1.5.0-lp160.14.1.noarch.rpm
restart_gnome=0

if [[ ${1:-} == --restart-gnome ]]; then
  restart_gnome=1
elif (($#)); then
  printf 'Uso: sudo %s [--restart-gnome]\n' "$0" >&2
  exit 2
fi

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merro:\033[0m %s\n' "$*" >&2; exit 1; }

((EUID == 0)) || die 'execute este script com sudo'
desktop_user=${SUDO_USER:-}
[[ -n $desktop_user && $desktop_user != root ]] || \
  die 'execute com sudo a partir da sessão do usuário que receberá o tema'

desktop_uid=$(id -u "$desktop_user")
desktop_home=$(getent passwd "$desktop_user" | cut -d: -f6)
[[ -n $desktop_home && -d $desktop_home ]] || \
  die "não foi possível localizar o perfil de $desktop_user"

[[ -f $theme_rpm ]] || die "RPM não encontrado: $theme_rpm"
[[ -f $icons_rpm ]] || die "RPM não encontrado: $icons_rpm"

run_as_desktop_user() {
  runuser -u "$desktop_user" -- env \
    HOME="$desktop_home" \
    XDG_RUNTIME_DIR="/run/user/$desktop_uid" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$desktop_uid/bus" \
    "$@"
}

run_as_desktop_user gdbus call --session --dest org.freedesktop.DBus \
  --object-path /org/freedesktop/DBus --method org.freedesktop.DBus.NameHasOwner \
  org.gnome.Shell | grep -q true || die 'execute a partir de uma sessão GNOME'

say 'Removendo pacotes antigos, se ainda estiverem instalados'
old_packages=()
for package in lyra-enterprise-theme lyra-enterprise-icons; do
  if rpm -q "$package" >/dev/null 2>&1; then
    old_packages+=("$package")
  fi
done
if ((${#old_packages[@]})); then
  zypper --non-interactive remove "${old_packages[@]}"
fi

say 'Instalando Lyra OS 1.5.0 do OBS'
zypper --non-interactive install "$icons_rpm" "$theme_rpm"

say 'Corrigindo o branding do GDM'
install -d /usr/share/lyra-os-theme/gdm /etc/dconf/db/gdm.d
install -m 0644 "$(dirname "$0")/src/gdm/logo.svg" \
  /usr/share/lyra-os-theme/gdm/logo.svg
rm -f /etc/dconf/db/gdm.d/00-lyra-enterprise
cat > /etc/dconf/db/gdm.d/00-lyra-os <<'GDM_DCONF'
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
dconf update

say 'Ativando ícones, esquema escuro e wallpapers no GNOME'
run_as_desktop_user gsettings set \
  org.gnome.desktop.interface icon-theme 'Lyra-OS-Icons'
run_as_desktop_user gsettings set \
  org.gnome.desktop.interface color-scheme 'prefer-dark'
run_as_desktop_user gsettings set \
  org.gnome.desktop.background picture-uri \
  'file:///usr/share/backgrounds/lyra/2702-voyage.png'

# gsettings via runuser+D-Bus pode "ter sucesso" mas escrever numa sessão
# errada, deixando o valor antigo (ex.: um tema já removido) preso no
# dconf sem erro nenhum — reboot não corrige isso. Usa o icon-theme como
# canário porque é o mais visível quando falha silenciosamente.
applied_icon_theme=$(run_as_desktop_user gsettings get \
  org.gnome.desktop.interface icon-theme 2>/dev/null || true)
if [[ $applied_icon_theme != "'Lyra-OS-Icons'" ]]; then
  say "aviso: icon-theme não aplicou na sessão de $desktop_user (valor atual: ${applied_icon_theme:-desconhecido}). Rode manualmente como $desktop_user: gsettings set org.gnome.desktop.interface icon-theme 'Lyra-OS-Icons'"
fi
run_as_desktop_user gsettings set \
  org.gnome.desktop.background picture-uri-dark \
  'file:///usr/share/backgrounds/lyra/2702-voyage.png'

run_as_desktop_user /usr/libexec/lyra-os-apply-full-theme

say 'Ativando configurações do Fastfetch e Neofetch'
run_as_desktop_user mkdir -p \
  "$desktop_home/.config/fastfetch" "$desktop_home/.config/neofetch"

if [[ -f $desktop_home/.config/fastfetch/config.jsonc && \
      ! -f $desktop_home/.config/fastfetch/config.jsonc.lyra-theme-backup ]]; then
  run_as_desktop_user cp \
    "$desktop_home/.config/fastfetch/config.jsonc" \
    "$desktop_home/.config/fastfetch/config.jsonc.lyra-theme-backup"
fi
run_as_desktop_user cp \
  /usr/share/lyra-os-theme/fastfetch/config.jsonc \
  "$desktop_home/.config/fastfetch/config.jsonc"

if [[ -f $desktop_home/.config/neofetch/config.conf && \
      ! -f $desktop_home/.config/neofetch/config.conf.lyra-theme-backup ]]; then
  run_as_desktop_user cp \
    "$desktop_home/.config/neofetch/config.conf" \
    "$desktop_home/.config/neofetch/config.conf.lyra-theme-backup"
fi
run_as_desktop_user cp \
  /usr/share/lyra-os-theme/neofetch/config.conf \
  "$desktop_home/.config/neofetch/config.conf"

say 'Confirmando a versão instalada'
rpm -q lyra-os-theme lyra-os-icons

if ((restart_gnome)); then
  say 'Reiniciando o gerenciador gráfico; a sessão atual será encerrada'
  systemctl restart display-manager.service
else
  say 'Lyra OS 1.5.0 instalado e ativo'
  say "Para reiniciar o GNOME agora: sudo $0 --restart-gnome"
fi
