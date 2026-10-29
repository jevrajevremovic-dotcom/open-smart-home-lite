#!/usr/bin/env bash
# Regenerates every raster app icon from assets/branding/*.svg.
# Needs rsvg-convert (librsvg) and ImageMagick 7 (magick).
# Android adaptive, monochrome, notification and splash icons are vector
# drawables under android/app/src/main/res/drawable and need no rendering.
set -euo pipefail
cd "$(dirname "$0")/.."
src=assets/branding/icon.svg
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Full-bleed square, the master for every size.
rsvg-convert -w 1024 -h 1024 "$src" -o "$tmp/square.png"
# Circle (legacy Android, web, iOS launch image).
magick "$tmp/square.png" \( +clone -alpha extract -fill black -colorize 100 \
  -fill white -draw "circle 512,512 512,0" \) -alpha off \
  -compose CopyOpacity -composite "$tmp/round.png"

sized() { magick "$1" -resize "$2x$2" -strip "$3"; }

# Android launcher icons for API < 26 (26+ uses the adaptive icon).
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  sized "$tmp/round.png" "${d#*:}" "android/app/src/main/res/mipmap-${d%%:*}/ic_launcher.png"
done

# iOS app icons: square, no alpha (Apple rounds the corners).
ios=ios/Runner/Assets.xcassets/AppIcon.appiconset
for f in "$ios"/Icon-App-*.png; do
  name=$(basename "$f" .png)            # Icon-App-83.5x83.5@2x
  pt=${name#Icon-App-}; pt=${pt%%x*}    # 83.5
  scale=${name##*@}; scale=${scale%x}   # 2
  px=$(awk "BEGIN{print int($pt*$scale+0.5)}")
  magick "$tmp/square.png" -resize "${px}x${px}" -background "#9A4114" \
    -alpha remove -alpha off -strip "$f"
done
launch=ios/Runner/Assets.xcassets/LaunchImage.imageset
sized "$tmp/round.png" 120 "$launch/LaunchImage.png"
sized "$tmp/round.png" 240 "$launch/LaunchImage@2x.png"
sized "$tmp/round.png" 360 "$launch/LaunchImage@3x.png"

# Web: round favicon and icons, full-bleed maskable icons.
sized "$tmp/round.png" 32 web/favicon.png
sized "$tmp/round.png" 192 web/icons/Icon-192.png
sized "$tmp/round.png" 512 web/icons/Icon-512.png
sized "$tmp/square.png" 192 web/icons/Icon-maskable-192.png
sized "$tmp/square.png" 512 web/icons/Icon-maskable-512.png
echo "Icons regenerated."
