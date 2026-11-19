# Lyra OS: shows the Euri mascot as the fastfetch logo in terminals that speak
# the kitty graphics protocol. Everywhere else (GNOME Console, TTY, SSH) and
# for users with their own fastfetch config, fastfetch runs untouched.
status is-interactive; or return

function __lyra_fastfetch_euri
    set -q SSH_CONNECTION; and return 1
    if not contains -- "$TERM" xterm-kitty xterm-ghostty
        and not set -q KITTY_WINDOW_ID
        and test "$TERM_PROGRAM" != WezTerm
        and not set -q KONSOLE_VERSION
        return 1
    end
    # Only replace the stock Lyra config; a customized one is left alone.
    set -l config_home $HOME/.config
    set -q XDG_CONFIG_HOME; and set config_home $XDG_CONFIG_HOME
    set -l user_config $config_home/fastfetch/config.jsonc
    test -e $user_config; or return 0
    grep -q /usr/share/lyra-os-theme/fastfetch/logo.txt $user_config
end

function fastfetch --description 'fastfetch with the Euri logo where supported'
    if test (count $argv) -eq 0; and __lyra_fastfetch_euri
        command fastfetch --config /usr/share/lyra-os-theme/fastfetch/euri.jsonc
    else
        command fastfetch $argv
    end
end
