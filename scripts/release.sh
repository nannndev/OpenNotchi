#!/usr/bin/env bash
# Cuts a release: bumps the version in Info.plist, commits, tags and pushes.
# GitHub Actions then builds the app and publishes the GitHub release.
#
# Usage: scripts/release.sh 1.2.3
#   1. Add a "## [1.2.3] - YYYY-MM-DD" section to CHANGELOG.md and commit it.
#   2. Run this script.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh X.Y.Z}"
PLIST=Resources/Info.plist

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Version must look like 1.2.3"; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "Commit or stash your changes first."; exit 1; }
git rev-parse "v$VERSION" >/dev/null 2>&1 && { echo "Tag v$VERSION already exists."; exit 1; }
grep -q "^## \[$VERSION\]" CHANGELOG.md || { echo "Add a '## [$VERSION]' section to CHANGELOG.md first."; exit 1; }

CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
if [[ "$CURRENT" != "$VERSION" ]]; then
    BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST") + 1 ))
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"
    git commit -am "chore: release v$VERSION"
fi

git tag -a "v$VERSION" -m "OpenNotchi v$VERSION"
git push origin HEAD "v$VERSION"
echo "Pushed v$VERSION. GitHub Actions will build and publish the release."
