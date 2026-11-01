#!/bin/zsh
# Builds tiempo.app and packages it as build/tiempo-<version>.zip for a GitHub Release.
# Apple silicon only. Version comes from CFBundleShortVersionString in Info.plist.
set -euo pipefail
cd "${0:A:h}/.."
./build.sh
STAGE="$HOME/Library/Caches/tiempo-build/app/tiempo.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
ZIP="build/tiempo-$VERSION.zip"
rm -f "$ZIP"
# Zip the signed copy outside iCloud Drive; ditto keeps the signature and permissions intact.
ditto -c -k --keepParent "$STAGE" "$ZIP"
echo "Packaged $PWD/$ZIP"
echo "Architecture: $(lipo -archs "$STAGE/Contents/MacOS/tiempo")"
echo "SHA-256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
