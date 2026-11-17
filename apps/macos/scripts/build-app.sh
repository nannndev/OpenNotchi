#!/usr/bin/env bash
# Builds OpenNotchi and wraps the binary into build/OpenNotchi.app
# Usage: scripts/build-app.sh [debug|release]   (UNIVERSAL=1 for arm64 + x86_64)
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/OpenNotchi.app"

./scripts/fetch-sparkle.sh

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/OpenNotchi" "$APP/Contents/MacOS/OpenNotchi"

# Build and bundle notchi-gateway sidecar if Cargo is available.
GATEWAY_DIR="../gateway"
if [[ -f "$GATEWAY_DIR/Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
    CARGO_PROFILE_FLAG=()
    GATEWAY_SUBDIR="debug"
    if [[ "$CONFIG" == "release" ]]; then
        CARGO_PROFILE_FLAG=(--release)
        GATEWAY_SUBDIR="release"
    fi

    if [[ "${UNIVERSAL:-0}" == "1" ]]; then
        cargo build --manifest-path "$GATEWAY_DIR/Cargo.toml" ${CARGO_PROFILE_FLAG[@]+"${CARGO_PROFILE_FLAG[@]}"} --target aarch64-apple-darwin
        cargo build --manifest-path "$GATEWAY_DIR/Cargo.toml" ${CARGO_PROFILE_FLAG[@]+"${CARGO_PROFILE_FLAG[@]}"} --target x86_64-apple-darwin
        lipo -create \
            "$GATEWAY_DIR/target/aarch64-apple-darwin/$GATEWAY_SUBDIR/notchi-gateway" \
            "$GATEWAY_DIR/target/x86_64-apple-darwin/$GATEWAY_SUBDIR/notchi-gateway" \
            -output "$APP/Contents/MacOS/notchi-gateway"
    else
        cargo build --manifest-path "$GATEWAY_DIR/Cargo.toml" ${CARGO_PROFILE_FLAG[@]+"${CARGO_PROFILE_FLAG[@]}"}
        cp "$GATEWAY_DIR/target/$GATEWAY_SUBDIR/notchi-gateway" "$APP/Contents/MacOS/notchi-gateway"
    fi
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/ProviderIcons "$APP/Contents/Resources/ProviderIcons"

# Embed Sparkle (auto-update). The binary finds it via @executable_path/../Frameworks.
SPARKLE="Vendor/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"

# Ad-hoc signature so macOS can show the Automation (Apple Events) prompt.
# Ad-hoc builds get a new identity every build, so macOS forgets Accessibility and Keychain access each time.
# Set SIGN_IDENTITY (e.g. "Apple Development: you@example.com (TEAMID)") for local builds that keep them.
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
