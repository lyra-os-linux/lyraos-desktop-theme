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

token_value() {
  local file=$1 token=$2
  sed -n "s/^\$$token:[[:space:]]*\([^;]*\);/\1/p" "$file"
}

render_wallpaper() {
  local tokens=$1 stem=$2
  local bg surface border text brand_start brand_end watermark_opacity glow_opacity
  bg=$(token_value "$tokens" ent-bg)
  surface=$(token_value "$tokens" ent-surface)
  border=$(token_value "$tokens" ent-border)
  text=$(token_value "$tokens" ent-text)
  brand_start=$(token_value "$tokens" ent-brand-start)
  brand_end=$(token_value "$tokens" ent-brand-end)
  watermark_opacity=$(token_value "$tokens" ent-watermark-opacity)
  glow_opacity=$(token_value "$tokens" ent-glow-opacity)
  sed -e "s/@ENT_BG@/$bg/g" -e "s/@ENT_SURFACE@/$surface/g" \
      -e "s/@ENT_BORDER@/$border/g" -e "s/@ENT_TEXT@/$text/g" \
      -e "s/@ENT_BRAND_START@/$brand_start/g" -e "s/@ENT_BRAND_END@/$brand_end/g" \
      -e "s/@ENT_WATERMARK_OPACITY@/$watermark_opacity/g" \
      -e "s/@ENT_GLOW_OPACITY@/$glow_opacity/g" \
      "$root/src/wallpaper/os.svg" > "$dist/backgrounds/$stem.svg"
  svg_to_png "$dist/backgrounds/$stem.svg" "$dist/backgrounds/$stem.png" \
    3840 2160
  im "$dist/backgrounds/$stem.png" -quality 92 "$dist/backgrounds/$stem.jxl"
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
mkdir -p "$dist/backgrounds" "$dist/gnome-background-properties"
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

render_wallpaper "$root/src/shell/_tokens-dark.scss" os
render_wallpaper "$root/src/shell/_tokens-light.scss" os-light
cp "$root/src/wallpaper/lyra-os.xml" "$dist/gnome-background-properties/"

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
