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

# Build and bundle the gateway sidecar (the Ask AI gateway). The app needs it, so a missing
# Rust toolchain is an error rather than a silently smaller app.
# Source: $EAY_GATEWAY_DIR, else a sibling checkout of github.com/nannndev/eay-gateway.
# Set SKIP_GATEWAY=1 only for quick UI-only local builds.
GATEWAY_DIR="${EAY_GATEWAY_DIR:-../../../eay-gateway}"
GATEWAY_BIN=eay-gateway
if [[ "${SKIP_GATEWAY:-0}" != "1" ]]; then
    command -v cargo >/dev/null 2>&1 || { echo "error: cargo not found; install Rust (https://rustup.rs) or set SKIP_GATEWAY=1" >&2; exit 1; }
    [[ -f "$GATEWAY_DIR/Cargo.toml" ]] || { echo "error: eay-gateway not found at $GATEWAY_DIR; clone github.com/nannndev/eay-gateway next to OpenNotchi, set EAY_GATEWAY_DIR, or set SKIP_GATEWAY=1" >&2; exit 1; }
    CARGO_PROFILE_FLAG=()
    GATEWAY_SUBDIR="debug"
    if [[ "$CONFIG" == "release" ]]; then
        CARGO_PROFILE_FLAG=(--release)
        GATEWAY_SUBDIR="release"
    fi
    echo "Bundling $GATEWAY_BIN from $GATEWAY_DIR"

    if [[ "${UNIVERSAL:-0}" == "1" ]]; then
        rustup target add aarch64-apple-darwin x86_64-apple-darwin >/dev/null
        for T in aarch64-apple-darwin x86_64-apple-darwin; do
            cargo build --locked --manifest-path "$GATEWAY_DIR/Cargo.toml" --bin "$GATEWAY_BIN" ${CARGO_PROFILE_FLAG[@]+"${CARGO_PROFILE_FLAG[@]}"} --target "$T"
        done
        lipo -create \
            "$GATEWAY_DIR/target/aarch64-apple-darwin/$GATEWAY_SUBDIR/$GATEWAY_BIN" \
            "$GATEWAY_DIR/target/x86_64-apple-darwin/$GATEWAY_SUBDIR/$GATEWAY_BIN" \
            -output "$APP/Contents/MacOS/$GATEWAY_BIN"
    else
        cargo build --locked --manifest-path "$GATEWAY_DIR/Cargo.toml" --bin "$GATEWAY_BIN" ${CARGO_PROFILE_FLAG[@]+"${CARGO_PROFILE_FLAG[@]}"}
        cp "$GATEWAY_DIR/target/$GATEWAY_SUBDIR/$GATEWAY_BIN" "$APP/Contents/MacOS/$GATEWAY_BIN"
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
for helper in "$APP/Contents/MacOS/eay-gateway" "$APP/Contents/MacOS/notchi-gateway"; do
    if [[ -f "$helper" ]]; then codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$helper"; fi
done
codesign --force --deep --sign "${SIGN_IDENTITY:--}" "$APP"

echo "Built $APP"
