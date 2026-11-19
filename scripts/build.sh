#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dist="$root/dist"
command -v rsvg-convert >/dev/null 2>&1 || { echo 'error: rsvg-convert is required' >&2; exit 1; }
# Exported so scripts/build-plymouth.sh (run as a separate process below) can use it too.
svg_to_png() {
  local source=$1 output=$2 width=$3 height=$4
  rsvg-convert --width "$width" --height "$height" \
    --output "$output" "$source"
}
export -f svg_to_png

rm -rf "$dist"
mkdir -p "$dist/grub/Lyra-OS"
mkdir -p "$dist/neofetch" "$dist/fastfetch" "$dist/gdm" "$dist/shell"

"$root/scripts/build-plymouth.sh" "$dist"
cp "$root/src/neofetch/config.conf" "$dist/neofetch/"
cp "$root/src/fastfetch/config.jsonc" "$root/src/fastfetch/logo.txt" \
  "$root/src/fastfetch/euri.jsonc" "$root/src/fastfetch/euri.png" \
  "$dist/fastfetch/"
# Sourced by bash and fish at startup, not executed.
cp "$root"/src/shell/lyra-fastfetch.* "$dist/shell/"
cp "$root/src/gdm/logo.svg" "$dist/gdm/"

cp "$root/src/grub/theme.txt" "$dist/grub/Lyra-OS/"
svg_to_png "$root/src/grub/background.svg" \
  "$dist/grub/Lyra-OS/background.png" 1920 1080
# GRUB stretches the middle segment between the fixed left/right caps.
for part in c e n ne nw s se sw w; do
  svg_to_png "$root/src/grub/select.svg" \
    "$dist/grub/Lyra-OS/select_${part}.png" 2 2
done

printf 'Built Lyra OS in %s\n' "$dist"
