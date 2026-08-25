#!/usr/bin/env bash
set -euo pipefail

# Builds the Lyra OS photographic wallpaper collection. Source images use
# stable package-friendly names; release artifacts are normalized to 4K PNG
# and JPEG XL for GNOME and downstream packaging.
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dist="$root/dist"
tmp=$(mktemp -d "$root/.build-tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export MAGICK_TEMPORARY_PATH="$tmp"

command -v magick >/dev/null 2>&1 || { echo 'error: ImageMagick is required' >&2; exit 1; }
[[ -d "$dist/backgrounds" ]] || { echo 'error: run scripts/build.sh first' >&2; exit 1; }

shopt -s nullglob
sources=("$root"/wallpapers/*.png)
(( ${#sources[@]} > 0 )) || { echo 'error: no wallpaper sources found' >&2; exit 1; }
rm -f "$dist"/backgrounds/*.{png,jxl,svg}

for source in "${sources[@]}"; do
  stem=$(basename "$source" .png)
  magick "$source" -filter Lanczos -resize '3840x2160!' -strip \
    "$dist/backgrounds/$stem.png"
  magick "$dist/backgrounds/$stem.png" -quality 92 \
    "$dist/backgrounds/$stem.jxl"
  printf 'Rendered %s\n' "$stem"
done

printf 'Built %d wallpapers in %s/backgrounds\n' "${#sources[@]}" "$dist"
