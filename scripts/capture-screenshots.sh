#!/usr/bin/env bash
# Capture raw DreamCart simulator screenshots for App Store marketing frames.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RAW="$ROOT/fastlane/screenshots/raw"
mkdir -p "$RAW"

OWNER=shop
UDID=$(agent-sim checkout "$OWNER")
trap 'agent-sim checkin "$OWNER"' EXIT
agent-sim boot "$OWNER" >/dev/null
echo "UDID=$UDID"

xcodegen generate >/dev/null
xcodebuild -project DreamCart.xcodeproj -scheme DreamCart -destination "id=$UDID" -configuration Debug build >/tmp/dreamcart_build.log 2>&1 || {
  tail -20 /tmp/dreamcart_build.log; exit 1;
}

APP=$(find ~/Library/Developer/Xcode/DerivedData/DreamCart-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name DreamCart.app | head -1)
BID=$(defaults read "$APP/Info" CFBundleIdentifier)
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BID" >/dev/null
sleep 3

shot() { agent-sim screenshot "$OWNER" "$RAW/$1" >/dev/null; echo "captured $1"; }

# Welcome → tester sign-in (DEBUG build)
axe tap -x 200 -y 780 --udid "$UDID" >/dev/null 2>&1 || true
sleep 2
axe tap -x 200 -y 720 --udid "$UDID" >/dev/null 2>&1 || true
sleep 4

shot today.png
axe tap -x 160 -y 820 --udid "$UDID" >/dev/null 2>&1 || true
sleep 2
shot shop.png
axe tap -x 320 -y 820 --udid "$UDID" >/dev/null 2>&1 || true
sleep 2
shot cart.png
axe tap -x 480 -y 820 --udid "$UDID" >/dev/null 2>&1 || true
sleep 2
shot closet.png
axe tap -x 640 -y 820 --udid "$UDID" >/dev/null 2>&1 || true
sleep 1
axe tap -x 200 -y 180 --udid "$UDID" >/dev/null 2>&1 || true
sleep 2
shot spin.png

echo "raw shots in $RAW"
