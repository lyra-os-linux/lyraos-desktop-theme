#!/usr/bin/env bash
set -euo pipefail

# Renders the four extra "mood" wallpapers (Nebula, Borealis, Solstice,
# Glacier) alongside the flagship Aurora pair that scripts/build.sh already
# produces from src/wallpaper/os.svg. Each mood only swaps the brand
# gradient (ent-brand-start/ent-brand-end); the neutral bg/surface/border/
# text and the watermark/glow opacity stay the ones already validated for
# dark and light in src/shell/_tokens-{dark,light}.scss, so every variant
# still belongs to the same family as the default wallpaper.
#
# Run this after scripts/build.sh (which creates $dist/backgrounds and
# renders os.svg once for os.png/os-light.png); it does not repeat that
# step or touch gnome-background-properties (the XML with all five entries
# lives at src/wallpaper/lyra-os.xml and is copied verbatim by build.sh).

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dist="$root/dist"
tmp=$(mktemp -d "$root/.build-tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
export MAGICK_TEMPORARY_PATH="$tmp"

command -v magick >/dev/null 2>&1 || { echo 'error: ImageMagick is required' >&2; exit 1; }
command -v rsvg-convert >/dev/null 2>&1 || { echo 'error: rsvg-convert is required' >&2; exit 1; }
[[ -d "$dist/backgrounds" ]] || { echo 'error: run scripts/build.sh first' >&2; exit 1; }

token_value() {
  local file=$1 token=$2
  sed -n "s/^\$$token:[[:space:]]*\([^;]*\);/\1/p" "$file"
}

dark_tokens="$root/src/shell/_tokens-dark.scss"
light_tokens="$root/src/shell/_tokens-light.scss"
bg_dark=$(token_value "$dark_tokens" ent-bg)
surface_dark=$(token_value "$dark_tokens" ent-surface)
border_dark=$(token_value "$dark_tokens" ent-border)
text_dark=$(token_value "$dark_tokens" ent-text)
watermark_dark=$(token_value "$dark_tokens" ent-watermark-opacity)
glow_dark=$(token_value "$dark_tokens" ent-glow-opacity)
bg_light=$(token_value "$light_tokens" ent-bg)
surface_light=$(token_value "$light_tokens" ent-surface)
border_light=$(token_value "$light_tokens" ent-border)
text_light=$(token_value "$light_tokens" ent-text)
watermark_light=$(token_value "$light_tokens" ent-watermark-opacity)
glow_light=$(token_value "$light_tokens" ent-glow-opacity)

render() {
  local stem=$1 bg=$2 surface=$3 border=$4 text=$5 brand_start=$6 brand_end=$7 \
    watermark=$8 glow=$9
  sed -e "s/@ENT_BG@/$bg/g" -e "s/@ENT_SURFACE@/$surface/g" \
      -e "s/@ENT_BORDER@/$border/g" -e "s/@ENT_TEXT@/$text/g" \
      -e "s/@ENT_BRAND_START@/$brand_start/g" -e "s/@ENT_BRAND_END@/$brand_end/g" \
      -e "s/@ENT_WATERMARK_OPACITY@/$watermark/g" -e "s/@ENT_GLOW_OPACITY@/$glow/g" \
      "$root/src/wallpaper/os.svg" > "$dist/backgrounds/$stem.svg"
  rsvg-convert --width 3840 --height 2160 \
    --output "$dist/backgrounds/$stem.png" "$dist/backgrounds/$stem.svg"
  magick "$dist/backgrounds/$stem.png" -quality 92 "$dist/backgrounds/$stem.jxl"
  rm -f "$dist/backgrounds/$stem.svg"
}

# slug:dark-start:dark-end:light-start:light-end
variants=(
  'nebula:#8B5CF6:#EC4899:#7C3AED:#DB2777'
  'borealis:#22D3C7:#6366F1:#0D9488:#4F46E5'
  'solstice:#F5A623:#F2545B:#D97706:#DC2626'
  'glacier:#38BDF8:#34D399:#0284C7:#059669'
)

for entry in "${variants[@]}"; do
  IFS=: read -r slug dstart dend lstart lend <<<"$entry"
  render "$slug" "$bg_dark" "$surface_dark" "$border_dark" "$text_dark" \
    "$dstart" "$dend" "$watermark_dark" "$glow_dark"
  render "$slug-light" "$bg_light" "$surface_light" "$border_light" "$text_light" \
    "$lstart" "$lend" "$watermark_light" "$glow_light"
  printf 'Rendered %s / %s-light\n' "$slug" "$slug"
done

printf 'Built wallpaper variants in %s/backgrounds\n' "$dist"
