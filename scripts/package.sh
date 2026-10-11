#!/usr/bin/env bash
# Packages build/OpenNotchi.app into dist/ as .zip and .dmg.
# Usage: scripts/package.sh 1.2.3
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/package.sh X.Y.Z}"
APP="build/OpenNotchi.app"
[[ -d "$APP" ]] || { echo "Build the app first (make release)"; exit 1; }

rm -rf dist && mkdir -p dist

# Zip (keeps the bundle's extended attributes and signature intact).
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/OpenNotchi-$VERSION.zip"

# DMG with a shortcut to /Applications for drag-to-install.
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "OpenNotchi $VERSION" -srcfolder "$STAGE" -ov -format UDZO "dist/OpenNotchi-$VERSION.dmg" >/dev/null
rm -rf "$STAGE"

# Stable names so https://github.com/<repo>/releases/latest/download/OpenNotchi.dmg always works.
cp "dist/OpenNotchi-$VERSION.dmg" dist/OpenNotchi.dmg
cp "dist/OpenNotchi-$VERSION.zip" dist/OpenNotchi.zip

(cd dist && shasum -a 256 OpenNotchi-"$VERSION".* > SHA256SUMS.txt)
ls -lh dist
