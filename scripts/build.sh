#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dist="$root/dist"
tmp=$(mktemp -d "$root/.build-tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
# Keep ImageMagick's pixel cache with the build's temporary files instead of
# relying on the system /tmp filesystem, which may be space-constrained.
export MAGICK_TEMPORARY_PATH="$tmp"

compile_scss() {
  local tokens=$1 source=$2 output=$3
  if command -v sassc >/dev/null 2>&1; then
    { sed '/^\/\//d' "$tokens"; cat "$source"; } > "$tmp/input.scss"
    sassc --style expanded "$tmp/input.scss" "$output"
    return
  fi

  # Minimal deterministic fallback for release builders without sassc. Sources
  # intentionally use only variables supported here; RPM packaging uses sassc.
  cp "$source" "$output"
  # Replace longer variable names first so, for example, $ent-surface does
  # not corrupt $ent-surface-raised. A second pass resolves token aliases.
  for _ in 1 2; do
    while IFS= read -r line; do
      [[ $line =~ ^\$([a-zA-Z0-9_-]+):[[:space:]]*(.*)\;$ ]] || continue
      name=${BASH_REMATCH[1]}
      value=${BASH_REMATCH[2]}
      sed -i "s|#{\$$name}|$value|g; s|\$$name|$value|g" "$output"
    done < <(awk '{ print length, $0 }' "$tokens" | sort -rn | cut -d' ' -f2-)
  done
}

command -v magick >/dev/null 2>&1 || { echo 'error: ImageMagick is required' >&2; exit 1; }
command -v rsvg-convert >/dev/null 2>&1 || { echo 'error: rsvg-convert is required' >&2; exit 1; }
# Exported so scripts/build-plymouth.sh (run as a separate process below) can use it too.
im() { magick "$@"; }
svg_to_png() {
  local source=$1 output=$2 width=$3 height=$4
  rsvg-convert --width "$width" --height "$height" \
    --output "$output" "$source"
}
export -f im svg_to_png

rm -rf "$dist"
for variant in Lyra-OS Lyra-OS-Light; do
  mkdir -p "$dist/$variant/gnome-shell" "$dist/$variant/gtk-4.0" \
    "$dist/$variant/gtk-3.0"
done
mkdir -p "$dist/grub/Lyra-OS"
mkdir -p "$dist/neofetch" "$dist/fastfetch" "$dist/gdm"

compile_scss "$root/src/shell/_tokens-dark.scss" "$root/src/shell/gnome-shell.scss" \
  "$dist/Lyra-OS/gnome-shell/gnome-shell.css"
compile_scss "$root/src/shell/_tokens-light.scss" "$root/src/shell/gnome-shell.scss" \
  "$dist/Lyra-OS-Light/gnome-shell/gnome-shell.css"
cp "$root/src/gtk4/gtk-dark.css" "$dist/Lyra-OS/gtk-4.0/gtk.css"
cp "$root/src/gtk4/gtk-light.css" "$dist/Lyra-OS-Light/gtk-4.0/gtk.css"
"$root/scripts/build-gtk3.sh" "$dist"
"$root/scripts/build-plymouth.sh" "$dist"
cp "$root/src/neofetch/config.conf" "$dist/neofetch/"
cp "$root/src/fastfetch/config.jsonc" "$root/src/fastfetch/logo.txt" \
  "$dist/fastfetch/"
cp "$root/src/gdm/logo.svg" "$dist/gdm/"

cp "$root/src/grub/theme.txt" "$dist/grub/Lyra-OS/"
svg_to_png "$root/src/grub/background.svg" \
  "$dist/grub/Lyra-OS/background.png" 1920 1080
# GRUB stretches the middle segment between the fixed left/right caps.
for part in c e n ne nw s se sw w; do
  svg_to_png "$root/src/grub/select.svg" \
    "$dist/grub/Lyra-OS/select_${part}.png" 2 2
done

"$root/scripts/check-contrast.js"
printf 'Built Lyra OS in %s\n' "$dist"
