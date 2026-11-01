#!/bin/zsh
# Regenerates Resources/AppIcon.png and Resources/AppIcon.icns from scripts/make-icon.swift.
set -euo pipefail
cd "${0:A:h}/.."
swift scripts/make-icon.swift Resources/AppIcon.png
SET=Resources/AppIcon.iconset
mkdir -p "$SET"
for px in 16 32 128 256 512; do
  sips -z $px $px Resources/AppIcon.png --out "$SET/icon_${px}x${px}.png" >/dev/null
  sips -z $((px * 2)) $((px * 2)) Resources/AppIcon.png --out "$SET/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
rm -r "$SET"
echo "Wrote Resources/AppIcon.icns"
