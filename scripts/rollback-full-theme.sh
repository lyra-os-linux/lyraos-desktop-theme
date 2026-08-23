#!/usr/bin/env bash
# Convenience wrapper: undoes the local test install done with
# `install-local.sh --full-theme --no-grub --no-plymouth --no-gdm`.
# Restores stock GNOME (default gtk-theme, Shell theme, icon-theme,
# color-scheme, wallpaper) and removes the files installed under
# /usr/share. GRUB/Plymouth/GDM were never touched, so nothing to
# restore there.
set -Eeuo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Route the script's `sudo` calls through pkexec (GUI polkit prompt),
# same as the install did, since this shell has no sudo tty.
shim=$(mktemp -d)
trap 'rm -rf "$shim"' EXIT
cat > "$shim/sudo" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -n) exit 0 ;;
  -v) exit 0 ;;
  *) exec pkexec "$@" ;;
esac
EOF
chmod +x "$shim/sudo"

PATH="$shim:$PATH" "$root/scripts/install-local.sh" --uninstall
