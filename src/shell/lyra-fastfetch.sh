# Lyra OS: shows the Euri mascot as the fastfetch logo in terminals that speak
# the kitty graphics protocol. Everywhere else (GNOME Console, TTY, SSH) and
# for users with their own fastfetch config, fastfetch runs untouched.
fastfetch() {
  if [ "$#" -eq 0 ] && _lyra_fastfetch_euri; then
    command fastfetch --config /usr/share/lyra-os-theme/fastfetch/euri.jsonc
  else
    command fastfetch "$@"
  fi
}

_lyra_fastfetch_euri() {
  [ -z "${SSH_CONNECTION:-}" ] || return 1
  case "${TERM:-}" in
    xterm-kitty|xterm-ghostty) ;;
    *)
      [ -n "${KITTY_WINDOW_ID:-}" ] || [ "${TERM_PROGRAM:-}" = WezTerm ] ||
        [ -n "${KONSOLE_VERSION:-}" ] || return 1
      ;;
  esac
  # Only replace the stock Lyra config; a customized one is left alone.
  _lyra_ff_config=${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc
  [ ! -e "$_lyra_ff_config" ] ||
    grep -q '/usr/share/lyra-os-theme/fastfetch/logo.txt' "$_lyra_ff_config"
}
