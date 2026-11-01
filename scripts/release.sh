#!/bin/zsh
# Builds tiempo.app and packages it as build/tiempo-<version>.dmg for a GitHub Release.
# The disk image holds the app and an Applications shortcut to drag it onto.
# Apple silicon only. Version comes from CFBundleShortVersionString in Info.plist.
set -euo pipefail
cd "${0:A:h}/.."
./build.sh
CACHE="$HOME/Library/Caches/tiempo-build"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
# Lay out the disk image outside iCloud Drive so the signed app stays clean.
DMGROOT="$CACHE/dmg"
rm -rf "$DMGROOT"
mkdir -p "$DMGROOT"
ditto "$CACHE/app/tiempo.app" "$DMGROOT/tiempo.app"
ln -s /Applications "$DMGROOT/Applications"
DMG="build/tiempo-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "tiempo" -srcfolder "$DMGROOT" -fs HFS+ -format UDZO -ov "$CACHE/tiempo.dmg" >/dev/null
cp "$CACHE/tiempo.dmg" "$DMG"
echo "Packaged $PWD/$DMG"
echo "Architecture: $(lipo -archs "$DMGROOT/tiempo.app/Contents/MacOS/tiempo")"
echo "SHA-256: $(shasum -a 256 "$DMG" | cut -d' ' -f1)"
