#!/usr/bin/env bash
# TestFlight release for DreamCart. The shared fleet script does the work: bump the
# build in project.yml, xcodegen, archive Release signed with the App Store
# Connect API key, upload, then commit and push the bump once Apple accepts it.
# Flags (--upload-only, --no-bump, --clean, --post-archive) and credentials are
# documented in ~/ios/release/testflight.sh.
cd "$(dirname "$0")/.." || exit 1
[[ "${NO_BUILD_BUMP:-0}" == "1" ]] && set -- --no-bump "$@"
exec "$HOME/ios/release/testflight.sh" --project DreamCart.xcodeproj --scheme DreamCart "$@"
