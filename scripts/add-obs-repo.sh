#!/usr/bin/env bash
set -Eeuo pipefail

repo_alias='home_rodrigosbrito_lyra'
# Base repodata directory, not the .repo indirection file: "zypper ar <url>
# <alias>" with an explicit alias treats the URL as the repo's literal
# baseurl instead of downloading and parsing it as a .repo definition, so
# pointing it at the .repo file itself fails with "Repository type can't
# be determined".
repo_url='https://download.opensuse.org/repositories/home:/rodrigosbrito:/lyra/openSUSE_Leap_16.0/'
install=1

# i18n: locale comes from LYRA_LANG, falling back to the usual
# LC_ALL/LC_MESSAGES/LANG chain, and defaults to en_US when none of them
# match a supported locale. Catalogs are embedded (matching install.sh) so
# this script stays runnable on its own if copied out of the checkout.
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
  [app_title]="Add the openSUSE Build Service repo for Lyra packages (home:rodrigosbrito:lyra) and, by default, install the theme and icon RPMs from it."
  [usage_label]="Usage:"
  [opt_no_install]="Only add and refresh the repo; skip installing the packages"
  [unknown_option]="Unknown option: %s"
  [err_zypper_required]="zypper is required (openSUSE only)"
  [err_sudo_required]="sudo is required"
  [info_adding_repo]="Adding repo %s"
  [info_refreshing_key]="Refreshing and importing the repo GPG key"
  [info_installing_pkgs]="Installing lyra-os-theme and lyra-os-icons"
  [info_done]="Done"
)

declare -A MSG_PT_BR=(
  [app_title]="Adiciona o repositório do openSUSE Build Service para os pacotes do Lyra (home:rodrigosbrito:lyra) e, por padrão, instala os RPMs de tema e ícones a partir dele."
  [usage_label]="Uso:"
  [opt_no_install]="Apenas adiciona e atualiza o repositório; não instala os pacotes"
  [unknown_option]="Opção desconhecida: %s"
  [err_zypper_required]="zypper é necessário (apenas openSUSE)"
  [err_sudo_required]="sudo é necessário"
  [info_adding_repo]="Adicionando o repositório %s"
  [info_refreshing_key]="Atualizando e importando a chave GPG do repositório"
  [info_installing_pkgs]="Instalando lyra-os-theme e lyra-os-icons"
  [info_done]="Concluído"
)

declare -A MSG_ES=(
  [app_title]="Agrega el repositorio del openSUSE Build Service para los paquetes de Lyra (home:rodrigosbrito:lyra) y, de forma predeterminada, instala los RPM de tema e íconos desde él."
  [usage_label]="Uso:"
  [opt_no_install]="Solo agrega y actualiza el repositorio; omite instalar los paquetes"
  [unknown_option]="Opción desconocida: %s"
  [err_zypper_required]="se requiere zypper (solo openSUSE)"
  [err_sudo_required]="se requiere sudo"
  [info_adding_repo]="Agregando el repositorio %s"
  [info_refreshing_key]="Actualizando e importando la clave GPG del repositorio"
  [info_installing_pkgs]="Instalando lyra-os-theme y lyra-os-icons"
  [info_done]="Listo"
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
  printf '%s add-obs-repo.sh [--no-install]\n\n' "$(msg usage_label)"
  printf '  --no-install    %s\n' "$(msg opt_no_install)"
}

while (($#)); do
  case $1 in
    --no-install) install=0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf -- "$(msg unknown_option)\n" "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

command -v zypper >/dev/null 2>&1 || die err_zypper_required
command -v sudo >/dev/null 2>&1 || die err_sudo_required

say info_adding_repo "$repo_alias"
# Remove and re-add unconditionally rather than skipping when the alias
# already exists: an earlier version of this script pointed zypper at the
# wrong URL, and a stale existing repo with that URL would otherwise never
# get corrected by a plain "refresh".
if sudo zypper lr "$repo_alias" >/dev/null 2>&1; then
  sudo zypper --non-interactive rr "$repo_alias"
fi
sudo zypper --non-interactive ar --refresh "$repo_url" "$repo_alias"

say info_refreshing_key
sudo zypper --gpg-auto-import-keys refresh "$repo_alias"

if ((install)); then
  say info_installing_pkgs
  sudo zypper --non-interactive install lyra-os-theme lyra-os-icons
fi

say info_done
