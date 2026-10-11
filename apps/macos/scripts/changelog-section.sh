#!/usr/bin/env bash
# Prints the CHANGELOG.md section for one version (used as GitHub release notes).
# Usage: scripts/changelog-section.sh 1.2.3
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/changelog-section.sh X.Y.Z}"
awk -v v="$VERSION" '
    $0 ~ "^## \\[" v "\\]" { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
' ../../CHANGELOG.md
