#!/usr/bin/env bash
# Moves OpenNotchi to a released eay-gateway version.
# Usage: scripts/bump-gateway.sh 0.2.0 [--require]
#   Checks out that tag in the sibling ../eay-gateway checkout (local builds) and points CI at it
#   (GitHub variable EAY_GATEWAY_REF). With --require, the apps also refuse older running gateways;
#   use it when OpenNotchi starts calling something the new version added.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/bump-gateway.sh X.Y.Z [--require]}"
TAG="v${VERSION#v}"
GW="${EAY_GATEWAY_DIR:-../eay-gateway}"

gh release view "$TAG" --repo nannndev/eay-gateway >/dev/null || { echo "eay-gateway $TAG is not released yet" >&2; exit 1; }

git -C "$GW" fetch --tags --quiet
git -C "$GW" -c advice.detachedHead=false checkout --quiet "$TAG"
echo "Local eay-gateway checkout ($GW) is now at $TAG"

gh variable set EAY_GATEWAY_REF --body "$TAG"
echo "CI builds will bundle eay-gateway $TAG"

if [[ "${2:-}" == "--require" ]]; then
    V="${TAG#v}"
    sed -i '' -E "s/(static let minimumVersion = \")[^\"]+\"/\1$V\"/" apps/macos/Sources/OpenNotchi/Features/NotchiGatewayService.swift
    sed -i '' -E "s/(const MIN_VERSION: &str = \")[^\"]+\"/\1$V\"/" apps/windows/src-tauri/src/gateway.rs
    echo "Apps now require eay-gateway >= $V; commit the change"
fi
