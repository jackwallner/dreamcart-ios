#!/usr/bin/env bash
# Capture raw DreamCart simulator screenshots for App Store marketing frames.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RAW="$ROOT/fastlane/screenshots/raw"
mkdir -p "$RAW"

UDID=$(agent-sim boot shop 2>/dev/null || agent-sim udid shop)
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

shot() { agent-sim screenshot shop "$RAW/$1" >/dev/null; echo "captured $1"; }

# Welcome → tester sign-in (DEBUG build)
agent-sim tap shop 200 780 >/dev/null 2>&1 || true
sleep 2
agent-sim tap shop 200 720 >/dev/null 2>&1 || true
sleep 4

shot today.png
agent-sim tap shop 160 820 >/dev/null 2>&1 || true
sleep 2
shot shop.png
agent-sim tap shop 320 820 >/dev/null 2>&1 || true
sleep 2
shot cart.png
agent-sim tap shop 480 820 >/dev/null 2>&1 || true
sleep 2
shot closet.png
agent-sim tap shop 640 820 >/dev/null 2>&1 || true
sleep 1
agent-sim tap shop 200 180 >/dev/null 2>&1 || true
sleep 2
shot spin.png

echo "raw shots in $RAW"
