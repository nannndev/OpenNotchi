#!/usr/bin/env bash
# Builds OpenNotchi and wraps the binary into build/OpenNotchi.app
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/OpenNotchi.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OpenNotchi" "$APP/Contents/MacOS/OpenNotchi"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS can show the Automation (Apple Events) prompt.
codesign --force --sign - "$APP"

echo "Built $APP"
