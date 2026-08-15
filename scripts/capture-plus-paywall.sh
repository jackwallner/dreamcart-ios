#!/usr/bin/env bash
# Capture the DreamCart+ purchase screen for App Store Review.
#
# The subscription sits in MISSING_METADATA until it has a review screenshot,
# and that screenshot has to show the real price and trial terms. `simctl`
# cannot supply either: StoreKit Testing is applied by the scheme, so a plain
# simulator launch renders the no-price fallback. This drives the
# DreamCartUITests scheme instead, whose test action carries
# DreamCart.storekit, and pulls the screenshot back out of the .xcresult.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="${1:-$ROOT/fastlane/iap_screenshots/plus_weekly.png}"
mkdir -p "$(dirname "$OUT")"
RESULT="/tmp/dreamcart_plus_shot.xcresult"
rm -rf "$RESULT"

OWNER=shop
UDID=$(agent-sim checkout "$OWNER" --any | tail -1)
trap 'agent-sim checkin "$OWNER" >/dev/null 2>&1 || true' EXIT
echo "UDID=$UDID"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true

xcodegen generate >/dev/null
xcodebuild test \
  -project DreamCart.xcodeproj \
  -scheme DreamCartUITests \
  -destination "id=$UDID" \
  -resultBundlePath "$RESULT" \
  -only-testing:DreamCartUITests/PlusPaywallScreenshotTests \
  >/tmp/dreamcart_shot_test.log 2>&1 || {
    grep -E "error:|XCTAssert|failed" /tmp/dreamcart_shot_test.log | head -20
    exit 1
  }

# xcresulttool needs the attachment's export name; --test-id is fragile across
# Xcode versions, so export everything and pick the one we named.
EXPORT_DIR=$(mktemp -d)
xcrun xcresulttool export attachments \
  --path "$RESULT" --output-path "$EXPORT_DIR" >/dev/null 2>&1

SHOT=$(find "$EXPORT_DIR" -name "*.png" -size +50k | head -1)
if [ -z "$SHOT" ]; then
  echo "no screenshot attachment found in $RESULT" >&2
  exit 1
fi
cp "$SHOT" "$OUT"
rm -rf "$EXPORT_DIR"
echo "captured $OUT"
sips -g pixelWidth -g pixelHeight "$OUT" | tail -2
