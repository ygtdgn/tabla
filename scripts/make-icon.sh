#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from Resources/AppIcon.svg. Run after editing the SVG.
set -euo pipefail
cd "$(dirname "$0")/.."
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
swiftc -O scripts/render-svg.swift -o "$WORK/render-svg"
SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for size in 16 32 128 256 512; do
    "$WORK/render-svg" Resources/AppIcon.svg "$SET/icon_${size}x${size}.png" "$size"
    "$WORK/render-svg" Resources/AppIcon.svg "$SET/icon_${size}x${size}@2x.png" "$((size * 2))"
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Resources/AppIcon.icns güncellendi"
