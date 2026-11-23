#!/usr/bin/env bash
# Renders branding/svg/*.svg into branding/png/ (needs rsvg-convert, and ImageMagick for favicon.ico).
# Order: python3 branding/build_kit.py -> branding/render_kit.sh -> dart run flutter_launcher_icons
# -> cp branding/png/favicon-32.png web/favicon.png (the generator writes a favicon from the big icon).
set -euo pipefail
cd "$(dirname "$0")"
S=svg
P=png
mkdir -p "$P"

r() { rsvg-convert "$@"; }

# App icon: full-bleed square (iOS / stores apply their own mask) and a pre-rounded one for decks/README.
r -w 1024 -h 1024 $S/miaunero-app-icon.svg -o $P/app-icon-1024.png
r -w 512 -h 512 $S/miaunero-app-icon.svg -o $P/play-store-512.png
r -w 1024 -h 1024 $S/miaunero-app-icon-rounded.svg -o $P/app-icon-rounded-1024.png

# Android adaptive icon layers (API 26+) and Android 13 themed (monochrome) layer.
for l in background foreground monochrome; do
  r -w 1024 -h 1024 $S/android-adaptive-$l.svg -o $P/android-adaptive-$l.png
done

# iOS 18 dark and tinted appearances (transparent).
r -w 1024 -h 1024 $S/ios-dark.svg -o $P/ios-dark-1024.png
r -w 1024 -h 1024 $S/ios-tinted.svg -o $P/ios-tinted-1024.png

# Favicons: small cut (bigger eyes), no glow.
for z in 16 32 48 180 192 512; do
  r -w $z -h $z $S/miaunero-favicon.svg -o $P/favicon-$z.png
done

magick $P/favicon-16.png $P/favicon-32.png $P/favicon-48.png $P/favicon.ico

# Symbol and wordmark, transparent.
for c in lime ink black white; do
  r -w 512 $S/miaunero-symbol-$c.svg -o $P/symbol-$c-512.png
  r -w 128 $S/miaunero-symbol-small-$c.svg -o $P/symbol-small-$c-128.png
done
for v in on-dark on-light black white; do
  r -w 1200 $S/miaunero-wordmark-$v.svg -o $P/wordmark-$v-1200.png
done
echo "PNGs in $(pwd)/$P"
