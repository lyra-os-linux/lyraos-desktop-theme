#!/usr/bin/env bash
set -Eeuo pipefail

repo=${LYRA_REPO:-lyra-os-linux/lyraos-desktop-theme}
ref=${LYRA_REF:-main}
variant=dark
activate=1
uninstall=0
grub=1
plymouth=1
gdm=1
full_theme=0

# i18n: this script runs standalone via `curl ... | bash`, so message
# catalogs are embedded here rather than sourced from the repo, which is
# only fetched later. Locale comes from LYRA_LANG, falling back to the
# usual LC_ALL/LC_MESSAGES/LANG chain, and defaults to en_US when none of
# them match a supported locale. Lookups go through associative arrays
# (never eval) so translated text is always treated as data, not code.
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
  [app_title]="Lyra OS installer"
  [usage_label]="Usage:"
  [opt_dark]="Use dark Adwaita with Lyra OS icons (default)"
  [opt_light]="Use light Adwaita with Lyra OS icons"
  [opt_no_activate]="Install files without changing GNOME, GRUB or Plymouth settings, the GDM login screen, or the neofetch config"
  [opt_no_grub]="Skip installing and activating the GRUB theme entirely"
  [opt_no_plymouth]="Skip installing and activating the Plymouth theme entirely"
  [opt_no_gdm]="Skip theming the GDM login screen entirely"
  [opt_full_theme]="Also style window chrome (GTK 3/4 headerbars) and the GNOME Shell top bar/overview with Lyra OS, instead of leaving Adwaita's own chrome in place. This can break the look of GNOME Shell's Quick Settings on some versions."
  [opt_uninstall]="Remove both themes and restore GNOME defaults"
  [unknown_option]="Unknown option: %s"
  [err_sudo_required]="sudo is required"
  [warn_grub_mkconfig_missing]="grub2-mkconfig not found; regenerate grub.cfg manually"
  [info_admin_auth]="Administrator authentication is required"
  [info_removing]="Removing Lyra OS"
  [info_uninstall_complete]="Uninstall complete"
  [info_installing_deps]="Installing build and runtime dependencies"
  [err_opensuse_only]="This installer supports openSUSE (zypper) only."
  [err_curl_missing]="curl was not installed"
  [err_magick_missing]="ImageMagick 7 (magick) is required"
  [err_node_missing]="Node.js is required"
  [err_rsvg_missing]="rsvg-convert is required"
  [err_sassc_missing]="sassc is required"
  [info_downloading]="Downloading %s (%s)"
  [info_building]="Building theme, icons, wallpapers, GRUB theme and Plymouth theme"
  [info_installing_files]="Installing system files"
  [info_installing_neofetch]="Installing Lyra neofetch config"
  [info_installing_fastfetch]="Installing Lyra Fastfetch config"
  [info_activating_adwaita]="Activating Adwaita with Lyra OS icons"
  [info_activating_full_theme]="Activating Lyra OS window and Shell styling (may affect GNOME Quick Settings)"
  [info_activating_grub]="Activating Lyra OS for GRUB"
  [warn_grub_not_activated]="/etc/default/grub not found; GRUB theme was installed but not activated"
  [info_activating_plymouth]="Activating Lyra OS for Plymouth"
  [warn_plymouth_not_activated]="plymouth-set-default-theme not found; Plymouth theme was installed but not activated"
  [info_activating_gdm]="Activating Lyra OS for GDM"
  [warn_gdm_not_activated]="dconf not found; GDM theme was not activated"
  [info_install_complete]="Lyra OS installation complete"
  [info_full_theme_note]="Lyra OS styles GNOME Shell chrome and application windows. Log out and back in for the Shell theme to fully apply."
  [info_adwaita_note]="Adwaita remains active for GNOME Shell and applications; Lyra supplies the icons."
)

declare -A MSG_PT_BR=(
  [app_title]="Instalador do Lyra OS"
  [usage_label]="Uso:"
  [opt_dark]="Usa o Adwaita escuro com os ícones do Lyra OS (padrão)"
  [opt_light]="Usa o Adwaita claro com os ícones do Lyra OS"
  [opt_no_activate]="Instala os arquivos sem alterar as configurações do GNOME, GRUB, Plymouth, a tela de login do GDM ou o neofetch"
  [opt_no_grub]="Não instala nem ativa o tema do GRUB"
  [opt_no_plymouth]="Não instala nem ativa o tema do Plymouth"
  [opt_no_gdm]="Não aplica o tema na tela de login do GDM"
  [opt_full_theme]="Também estiliza os contornos das janelas (headerbars do GTK 3/4) e a barra superior/visão geral do GNOME Shell com o Lyra OS, em vez de manter o visual do Adwaita. Isso pode quebrar a aparência das Configurações Rápidas em algumas versões do GNOME."
  [opt_uninstall]="Remove os dois temas e restaura os padrões do GNOME"
  [unknown_option]="Opção desconhecida: %s"
  [err_sudo_required]="sudo é necessário"
  [warn_grub_mkconfig_missing]="grub2-mkconfig não encontrado; regenere o grub.cfg manualmente"
  [info_admin_auth]="É necessária autenticação de administrador"
  [info_removing]="Removendo o Lyra OS"
  [info_uninstall_complete]="Desinstalação concluída"
  [info_installing_deps]="Instalando dependências de build e execução"
  [err_opensuse_only]="Este instalador é compatível apenas com openSUSE (zypper)."
  [err_curl_missing]="curl não foi instalado"
  [err_magick_missing]="ImageMagick 7 (magick) é necessário"
  [err_node_missing]="Node.js é necessário"
  [err_rsvg_missing]="rsvg-convert é necessário"
  [err_sassc_missing]="sassc é necessário"
  [info_downloading]="Baixando %s (%s)"
  [info_building]="Compilando tema, ícones, wallpapers, tema do GRUB e do Plymouth"
  [info_installing_files]="Instalando arquivos do sistema"
  [info_installing_neofetch]="Instalando a configuração do Lyra para o neofetch"
  [info_installing_fastfetch]="Instalando a configuração do Lyra para o Fastfetch"
  [info_activating_adwaita]="Ativando o Adwaita com os ícones do Lyra OS"
  [info_activating_full_theme]="Ativando o estilo de janelas e do Shell do Lyra OS (pode afetar as Configurações Rápidas do GNOME)"
  [info_activating_grub]="Ativando o Lyra OS no GRUB"
  [warn_grub_not_activated]="/etc/default/grub não encontrado; o tema do GRUB foi instalado, mas não ativado"
  [info_activating_plymouth]="Ativando o Lyra OS no Plymouth"
  [warn_plymouth_not_activated]="plymouth-set-default-theme não encontrado; o tema do Plymouth foi instalado, mas não ativado"
  [info_activating_gdm]="Ativando o Lyra OS no GDM"
  [warn_gdm_not_activated]="dconf não encontrado; o tema do GDM não foi ativado"
  [info_install_complete]="Instalação do Lyra OS concluída"
  [info_full_theme_note]="O Lyra OS estiliza o Shell do GNOME e as janelas dos aplicativos. Saia e entre novamente na sessão para o tema do Shell ser aplicado por completo."
  [info_adwaita_note]="O Adwaita continua ativo no Shell do GNOME e nos aplicativos; o Lyra fornece os ícones."
)

declare -A MSG_ES=(
  [app_title]="Instalador de Lyra OS"
  [usage_label]="Uso:"
  [opt_dark]="Usa Adwaita oscuro con los íconos de Lyra OS (predeterminado)"
  [opt_light]="Usa Adwaita claro con los íconos de Lyra OS"
  [opt_no_activate]="Instala los archivos sin cambiar la configuración de GNOME, GRUB, Plymouth, la pantalla de inicio de GDM ni neofetch"
  [opt_no_grub]="Omite instalar y activar por completo el tema de GRUB"
  [opt_no_plymouth]="Omite instalar y activar por completo el tema de Plymouth"
  [opt_no_gdm]="Omite aplicar el tema en la pantalla de inicio de GDM"
  [opt_full_theme]="También estiliza los bordes de ventana (headerbars de GTK 3/4) y la barra superior/vista general de GNOME Shell con Lyra OS, en vez de mantener el aspecto propio de Adwaita. Esto puede romper la apariencia de la Configuración rápida en algunas versiones de GNOME."
  [opt_uninstall]="Elimina ambos temas y restaura los valores predeterminados de GNOME"
  [unknown_option]="Opción desconocida: %s"
  [err_sudo_required]="se requiere sudo"
  [warn_grub_mkconfig_missing]="no se encontró grub2-mkconfig; regenere grub.cfg manualmente"
  [info_admin_auth]="Se requiere autenticación de administrador"
  [info_removing]="Eliminando Lyra OS"
  [info_uninstall_complete]="Desinstalación completa"
  [info_installing_deps]="Instalando dependencias de compilación y ejecución"
  [err_opensuse_only]="Este instalador solo es compatible con openSUSE (zypper)."
  [err_curl_missing]="curl no se instaló"
  [err_magick_missing]="se requiere ImageMagick 7 (magick)"
  [err_node_missing]="se requiere Node.js"
  [err_rsvg_missing]="se requiere rsvg-convert"
  [err_sassc_missing]="se requiere sassc"
  [info_downloading]="Descargando %s (%s)"
  [info_building]="Compilando tema, íconos, fondos de pantalla, tema de GRUB y de Plymouth"
  [info_installing_files]="Instalando archivos del sistema"
  [info_installing_neofetch]="Instalando la configuración de Lyra para neofetch"
  [info_installing_fastfetch]="Instalando la configuración de Lyra para Fastfetch"
  [info_activating_adwaita]="Activando Adwaita con los íconos de Lyra OS"
  [info_activating_full_theme]="Activando el estilo de ventanas y del Shell de Lyra OS (puede afectar la Configuración rápida de GNOME)"
  [info_activating_grub]="Activando Lyra OS en GRUB"
  [warn_grub_not_activated]="no se encontró /etc/default/grub; el tema de GRUB se instaló pero no se activó"
  [info_activating_plymouth]="Activando Lyra OS en Plymouth"
  [warn_plymouth_not_activated]="no se encontró plymouth-set-default-theme; el tema de Plymouth se instaló pero no se activó"
  [info_activating_gdm]="Activando Lyra OS en GDM"
  [warn_gdm_not_activated]="no se encontró dconf; el tema de GDM no se activó"
  [info_install_complete]="Instalación de Lyra OS completa"
  [info_full_theme_note]="Lyra OS estiliza el Shell de GNOME y las ventanas de las aplicaciones. Cierre sesión y vuelva a iniciarla para que el tema del Shell se aplique por completo."
  [info_adwaita_note]="Adwaita permanece activo en el Shell de GNOME y en las aplicaciones; Lyra aporta los íconos."
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
  printf '%s install.sh [--dark|--light] [--no-activate] [--no-grub]\n' "$(msg usage_label)"
  printf '                   [--no-plymouth] [--no-gdm] [--full-theme] [--uninstall]\n\n'
  printf '  --dark          %s\n' "$(msg opt_dark)"
  printf '  --light         %s\n' "$(msg opt_light)"
  printf '  --no-activate   %s\n' "$(msg opt_no_activate)"
  printf '  --no-grub       %s\n' "$(msg opt_no_grub)"
  printf '  --no-plymouth   %s\n' "$(msg opt_no_plymouth)"
  printf '  --no-gdm        %s\n' "$(msg opt_no_gdm)"
  printf '  --full-theme    %s\n' "$(msg opt_full_theme)"
  printf '  --uninstall     %s\n' "$(msg opt_uninstall)"
}

while (($#)); do
  case $1 in
    --dark) variant=dark ;;
    --light) variant=light ;;
    --no-activate) activate=0 ;;
    --no-grub) grub=0 ;;
    --no-plymouth) plymouth=0 ;;
    --no-gdm) gdm=0 ;;
    --full-theme) full_theme=1 ;;
    --uninstall) uninstall=1 ;;
    -h|--help) usage; exit 0 ;;
    *) printf -- "$(msg unknown_option)\n" "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# openSUSE ships GRUB 2 as grub2, configured via /boot/grub2/grub.cfg.
rebuild_grub_config() {
  if command -v grub2-mkconfig >/dev/null 2>&1; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
  elif [[ -x /usr/sbin/grub2-mkconfig ]]; then
    sudo /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
  else
    say warn_grub_mkconfig_missing
  fi
}

command -v sudo >/dev/null 2>&1 || die err_sudo_required
if ! sudo -n true 2>/dev/null; then
  say info_admin_auth
  sudo -v </dev/tty
fi

if ((uninstall)); then
  say info_removing
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
    if [[ $(readlink "$HOME/.config/gtk-4.0/gtk.css" 2>/dev/null || true) == /usr/share/themes/Lyra-OS* ]]; then
      rm -f "$HOME/.config/gtk-4.0/gtk.css"
      [[ -e "$HOME/.config/gtk-4.0/gtk.css.lyra-theme-backup" ]] && \
        mv "$HOME/.config/gtk-4.0/gtk.css.lyra-theme-backup" "$HOME/.config/gtk-4.0/gtk.css"
    fi
    uuid=user-theme@gnome-shell-extensions.gcampax.github.com
    current=$(gsettings get org.gnome.shell enabled-extensions)
    if [[ $current == *"'$uuid'"* ]]; then
      gsettings set org.gnome.shell enabled-extensions \
        "$(sed -E "s/'$uuid', //; s/, '$uuid'//; s/'$uuid'//" <<<"$current")"
    fi
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
    if [[ $(plymouth-set-default-theme 2>/dev/null) == Lyra-OS ]]; then
      if [[ -s /etc/plymouth/lyra-theme-backup ]]; then
        sudo plymouth-set-default-theme -R "$(sudo cat /etc/plymouth/lyra-theme-backup)"
      else
        sudo plymouth-set-default-theme -R details
      fi
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
  say info_uninstall_complete
  exit 0
fi

install_dependencies() {
  say info_installing_deps
  command -v zypper >/dev/null 2>&1 || die err_opensuse_only
  local packages=(
    adwaita-icon-theme curl fastfetch glib2-tools gtk3-tools gzip
    ImageMagick nodejs rsvg-convert sassc tar xz
  )
  ((grub)) && packages+=(grub2)
  ((plymouth)) && packages+=(
    cantarell-fonts dracut plymouth-plugin-two-step plymouth-scripts
    plymouth-theme-spinner
  )
  { ((gdm)) || ((full_theme)); } && packages+=(dconf gnome-shell-extension-user-theme)
  sudo zypper --non-interactive install "${packages[@]}"
}

install_dependencies
command -v curl >/dev/null 2>&1 || die err_curl_missing
command -v magick >/dev/null 2>&1 || die err_magick_missing
command -v node >/dev/null 2>&1 || die err_node_missing
command -v rsvg-convert >/dev/null 2>&1 || die err_rsvg_missing
command -v sassc >/dev/null 2>&1 || die err_sassc_missing

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
archive="$tmp/source.tar.gz"
source_dir="$tmp/source"
mkdir -p "$source_dir"

say info_downloading "$repo" "$ref"
curl --proto '=https' --tlsv1.2 -fsSL \
  "https://github.com/$repo/archive/$ref.tar.gz" -o "$archive"
tar -xzf "$archive" -C "$source_dir" --strip-components=1

say info_building
(cd "$source_dir" && ./scripts/build.sh && ./scripts/build-icons.sh && ./scripts/build-wallpaper-variants.sh)

say info_installing_files
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
  say info_installing_neofetch
  mkdir -p "$HOME/.config/neofetch"
  if [[ -f "$HOME/.config/neofetch/config.conf" && \
      ! -f "$HOME/.config/neofetch/config.conf.lyra-theme-backup" ]]; then
    cp "$HOME/.config/neofetch/config.conf" \
      "$HOME/.config/neofetch/config.conf.lyra-theme-backup"
  fi
  cp "$source_dir/dist/neofetch/config.conf" "$HOME/.config/neofetch/config.conf"

  say info_installing_fastfetch
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
    shell_gtk_theme=Lyra-OS-Light
  else
    scheme=prefer-dark
    shell_gtk_theme=Lyra-OS
  fi
  say info_activating_adwaita
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
    if [[ -e "$HOME/.config/gtk-4.0/gtk.css.lyra-theme-backup" ]]; then
      mv "$HOME/.config/gtk-4.0/gtk.css.lyra-theme-backup" "$HOME/.config/gtk-4.0/gtk.css"
    fi
  fi
  uuid=user-theme@gnome-shell-extensions.gcampax.github.com
  current=$(gsettings get org.gnome.shell enabled-extensions)
  if [[ $current == *"'$uuid'"* ]]; then
    gsettings set org.gnome.shell enabled-extensions \
      "$(sed -E "s/'$uuid', //; s/, '$uuid'//; s/'$uuid'//" <<<"$current")"
  fi
  if ((full_theme)); then
    say info_activating_full_theme
    gsettings set org.gnome.desktop.interface gtk-theme "$shell_gtk_theme"
    mkdir -p "$HOME/.config/gtk-4.0"
    if [[ -f "$HOME/.config/gtk-4.0/gtk.css" && \
        ! -f "$HOME/.config/gtk-4.0/gtk.css.lyra-theme-backup" ]]; then
      cp "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css.lyra-theme-backup"
    fi
    ln -sf "/usr/share/themes/$shell_gtk_theme/gtk-4.0/gtk.css" \
      "$HOME/.config/gtk-4.0/gtk.css"
    # gnome-extensions enable talks to the running Shell's extension manager,
    # which has not scanned a system extension installed mid-session; write
    # enabled-extensions directly via dconf instead so it takes effect on the
    # next login, when the Shell re-scans /usr/share/gnome-shell/extensions.
    current=$(gsettings get org.gnome.shell enabled-extensions)
    if [[ $current != *"'$uuid'"* ]]; then
      if [[ $current == *'[]' ]]; then
        gsettings set org.gnome.shell enabled-extensions "['$uuid']"
      else
        gsettings set org.gnome.shell enabled-extensions "${current%]}, '$uuid']"
      fi
    fi
    gsettings set org.gnome.shell.extensions.user-theme name "$shell_gtk_theme"
  fi
fi

if ((activate)) && ((grub)); then
  if [[ -f /etc/default/grub ]]; then
    say info_activating_grub
    if ! sudo grep -qx 'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' /etc/default/grub; then
      sudo sh -c "grep '^[[:space:]]*GRUB_THEME=' /etc/default/grub > /etc/default/grub.lyra-theme-backup || true"
    fi
    sudo sed -i '/^[[:space:]]*GRUB_THEME=/d' /etc/default/grub
    printf '%s\n' 'GRUB_THEME="/usr/share/grub/themes/Lyra-OS/theme.txt"' | \
      sudo tee -a /etc/default/grub >/dev/null
    rebuild_grub_config
  else
    say warn_grub_not_activated
  fi
fi

if ((activate)) && ((plymouth)); then
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    say info_activating_plymouth
    if [[ ! -s /etc/plymouth/lyra-theme-backup ]]; then
      plymouth-set-default-theme 2>/dev/null | sudo tee /etc/plymouth/lyra-theme-backup >/dev/null || true
    fi
    sudo plymouth-set-default-theme -R Lyra-OS
  else
    say warn_plymouth_not_activated
  fi
fi

if ((activate)) && ((gdm)); then
  if command -v dconf >/dev/null 2>&1; then
    say info_activating_gdm
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
    say warn_gdm_not_activated
  fi
fi

say info_install_complete
if ((activate)) && ((full_theme)); then
  printf '%s\n' "$(msg info_full_theme_note)"
else
  printf '%s\n' "$(msg info_adwaita_note)"
fi
