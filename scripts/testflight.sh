#!/usr/bin/env bash
# Bump build number, archive, and upload DreamCart to TestFlight.
# Usage: ./scripts/testflight.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT_YML="$ROOT/project.yml"
ARCHIVE="$ROOT/build/DreamCart.xcarchive"
STAGING="$ROOT/build/upload-staging"
PLIST="$ROOT/AppStoreUploadOptions.plist"

[[ -f "$PLIST" ]] || { echo "error: missing $PLIST" >&2; exit 1; }

OLD=$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | awk '{print $2}' | tr -d '"')
if [[ "${NO_BUILD_BUMP:-0}" == "1" ]]; then
  NEW="$OLD"
  echo "Using existing build: $NEW"
else
  NEW=$((OLD + 1))
  echo "Bumping build: $OLD → $NEW"
  sed -i '' "s/CURRENT_PROJECT_VERSION: \"$OLD\"/CURRENT_PROJECT_VERSION: \"$NEW\"/" "$PROJECT_YML"
fi

echo "Generating xcodeproj..."
xcodegen generate

echo "Resolving package dependencies..."
xcodebuild -resolvePackageDependencies -project DreamCart.xcodeproj -scheme DreamCart

echo "Archiving..."
rm -rf "$ARCHIVE"
xcodebuild -project DreamCart.xcodeproj \
  -scheme DreamCart \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

echo "Uploading to TestFlight..."
mkdir -p "$STAGING"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$STAGING" \
  -exportOptionsPlist "$PLIST" \
  -allowProvisioningUpdates

echo "Done! Build $NEW uploaded. Check App Store Connect → TestFlight for Processing."
