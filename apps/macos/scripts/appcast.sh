#!/usr/bin/env bash
# Signs the release zip with the Sparkle EdDSA key and writes dist/appcast.xml.
# Usage: SPARKLE_PRIVATE_KEY=... scripts/appcast.sh 1.2.3
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/appcast.sh X.Y.Z}"
REPO="nannndev/OpenNotchi"
ZIP="dist/OpenNotchi-$VERSION.zip"
[[ -f "$ZIP" ]] || { echo "Missing $ZIP; run scripts/package.sh first"; exit 1; }
[[ -n "${SPARKLE_PRIVATE_KEY:-}" ]] || { echo "SPARKLE_PRIVATE_KEY is not set"; exit 1; }

./scripts/fetch-sparkle.sh
SIGN_UPDATE="Vendor/Sparkle/bin/sign_update"

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE"
# Prints: sparkle:edSignature="..." length="..."
SIGNATURE="$("$SIGN_UPDATE" --ed-key-file "$KEY_FILE" "$ZIP")"

BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist)
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" Resources/Info.plist)
PAGE="https://github.com/$REPO/releases/tag/v$VERSION"

cat > dist/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>OpenNotchi</title>
    <link>https://github.com/$REPO</link>
    <item>
      <title>OpenNotchi $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$PAGE</sparkle:releaseNotesLink>
      <link>$PAGE</link>
      <enclosure url="https://github.com/$REPO/releases/download/v$VERSION/OpenNotchi-$VERSION.zip" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML
echo "Wrote dist/appcast.xml"
