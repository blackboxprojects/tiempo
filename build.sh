#!/bin/zsh
# Builds build/tiempo.app (Apple silicon). The app is assembled and signed in a cache folder
# outside the repo, because iCloud Drive and Finder attach extended attributes that codesign
# rejects; the signed app is then copied into build/.
set -euo pipefail
cd "${0:A:h}"
SCRATCH="$HOME/Library/Caches/tiempo-build"
swift build -c release --scratch-path "$SCRATCH"
STAGE="$SCRATCH/app/tiempo.app"
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$SCRATCH/release/tiempo" "$STAGE/Contents/MacOS/"
cp Info.plist "$STAGE/Contents/"
cp Resources/AppIcon.icns "$STAGE/Contents/Resources/"
xattr -cr "$STAGE"
codesign --force --sign - "$STAGE"
mkdir -p build
rm -rf build/tiempo.app
ditto "$STAGE" build/tiempo.app
echo "Built $PWD/build/tiempo.app"
