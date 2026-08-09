#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
"$root/scripts/build.sh"
"$root/scripts/build-wallpaper-variants.sh"
archive="$root/Lyra-OS.tar.xz"
rm -f "$archive"
tar -C "$root/dist" -cJf "$archive" Lyra-OS Lyra-OS-Light backgrounds \
  gnome-background-properties grub plymouth dracut neofetch fastfetch
printf 'Created %s\n' "$archive"
