#!/usr/bin/env bash
# Downloads Sparkle (framework + signing tools) into Vendor/Sparkle and verifies its checksum.
# Package.swift links Vendor/Sparkle/Sparkle.xcframework as a local binary target.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="2.10.0"
SHA256="17e28312b8e18ab7cdbbe09a6fb28cc55a5479ec6c371dbc07cdecd2a14fd959"
DEST="Vendor/Sparkle"

if [[ -f "$DEST/.version" && "$(cat "$DEST/.version")" == "$VERSION" ]]; then
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Sparkle $VERSION…"
curl -fsSL -o "$TMP/sparkle.zip" "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-for-Swift-Package-Manager.zip"
echo "$SHA256  $TMP/sparkle.zip" | shasum -a 256 -c - >/dev/null

rm -rf "$DEST" && mkdir -p "$DEST"
ditto -x -k "$TMP/sparkle.zip" "$DEST"
echo "$VERSION" > "$DEST/.version"
echo "Sparkle $VERSION ready in $DEST"
