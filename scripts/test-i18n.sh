#!/usr/bin/env bash
# Verifies the i18n catalogs embedded in install-rpm.sh and add-obs-repo.sh:
# that pt-BR/es have the same keys as en-US (no missing translations),
# that LYRA_LANG picks the right catalog, and that an unsupported locale
# falls back to en-US. Runs only the --help and unknown-option code paths,
# so it needs neither root nor zypper/GNOME.
set -Eeuo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail=0

pass() { printf '  ok - %s\n' "$1"; }
fail_() { printf '  FAIL - %s\n' "$1" >&2; fail=1; }

extract_keys() {
  local file=$1 array=$2
  awk -v arr="declare -A $array=(" '
    index($0, arr) { grabbing=1; next }
    grabbing && /^\)/ { grabbing=0 }
    grabbing { print }
  ' "$file" | grep -oE '^[[:space:]]*\[[A-Za-z0-9_]+\]=' \
    | sed -E 's/^[[:space:]]*\[([A-Za-z0-9_]+)\]=/\1/' | sort
}

check_parity() {
  local file=$1
  local en pt es
  en=$(extract_keys "$file" MSG_EN_US)
  pt=$(extract_keys "$file" MSG_PT_BR)
  es=$(extract_keys "$file" MSG_ES)
  if [[ -z $en ]]; then
    fail_ "$file: no keys found in MSG_EN_US (extractor broken?)"
    return
  fi
  if [[ $en == "$pt" ]]; then
    pass "$file: pt_BR has the same keys as en_US ($(wc -l <<<"$en" | tr -d ' ') keys)"
  else
    fail_ "$file: pt_BR keys differ from en_US"
    diff <(printf '%s\n' "$en") <(printf '%s\n' "$pt") | sed 's/^/    /' >&2
  fi
  if [[ $en == "$es" ]]; then
    pass "$file: es has the same keys as en_US"
  else
    fail_ "$file: es keys differ from en_US"
    diff <(printf '%s\n' "$en") <(printf '%s\n' "$es") | sed 's/^/    /' >&2
  fi
}

check_locale_help() {
  local script=$1 locale=$2 expect=$3
  local out
  out=$(LYRA_LANG="$locale" "$script" --help)
  if [[ $out == "$expect"* ]]; then
    pass "$(basename "$script") --help under LYRA_LANG=$locale starts with '$expect'"
  else
    fail_ "$(basename "$script") --help under LYRA_LANG=$locale: expected to start with '$expect', got: $(head -1 <<<"$out")"
  fi
}

check_unsupported_locale_falls_back_to_en() {
  local script=$1 expect=$2
  local out
  out=$(LYRA_LANG=xx_YY "$script" --help)
  if [[ $out == "$expect"* ]]; then
    pass "$(basename "$script") falls back to en_US for an unsupported LYRA_LANG"
  else
    fail_ "$(basename "$script") did not fall back to en_US for an unsupported LYRA_LANG"
  fi
}

check_unknown_option_error() {
  local script=$1 locale=$2 expect_snippet=$3
  local out status
  set +e
  out=$(LYRA_LANG="$locale" "$script" --this-flag-does-not-exist 2>&1)
  status=$?
  set -e
  if [[ $status -ne 2 ]]; then
    fail_ "$(basename "$script") --bogus under $locale: expected exit 2, got $status"
    return
  fi
  if [[ $out == *"$expect_snippet"* ]]; then
    pass "$(basename "$script") reports an unknown option in $locale"
  else
    fail_ "$(basename "$script") unknown-option message under $locale did not contain '$expect_snippet'"
  fi
}

printf 'Catalog key parity\n'
check_parity "$root/install-rpm.sh"
check_parity "$root/scripts/add-obs-repo.sh"

printf 'Locale selection\n'

check_locale_help "$root/install-rpm.sh" pt_BR "Instalador RPM do Lyra OS"
check_locale_help "$root/install-rpm.sh" es "Instalador RPM de Lyra OS"
check_locale_help "$root/install-rpm.sh" en_US "Lyra OS RPM installer"
check_unsupported_locale_falls_back_to_en "$root/install-rpm.sh" "Lyra OS RPM installer"


check_locale_help "$root/scripts/add-obs-repo.sh" pt_BR "Adiciona o repositório"
check_locale_help "$root/scripts/add-obs-repo.sh" es "Agrega el repositorio"
check_locale_help "$root/scripts/add-obs-repo.sh" en_US "Add the openSUSE Build Service repo"
check_unsupported_locale_falls_back_to_en "$root/scripts/add-obs-repo.sh" "Add the openSUSE Build Service repo"

printf 'Error messages\n'
check_unknown_option_error "$root/install-rpm.sh" pt_BR "Opção desconhecida"
check_unknown_option_error "$root/install-rpm.sh" es "Opción desconocida"
check_unknown_option_error "$root/install-rpm.sh" en_US "Unknown option"
check_unknown_option_error "$root/scripts/add-obs-repo.sh" pt_BR "Opção desconhecida"
check_unknown_option_error "$root/scripts/add-obs-repo.sh" es "Opción desconocida"
check_unknown_option_error "$root/scripts/add-obs-repo.sh" en_US "Unknown option"

if ((fail)); then
  printf 'i18n tests FAILED\n' >&2
  exit 1
fi
printf 'All i18n tests passed\n'
