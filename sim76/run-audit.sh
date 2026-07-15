#!/usr/bin/env bash
# Comprehensive DreamCart simulator audit — screenshots + AX tree dumps
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${UDID:-$(agent-sim boot shop)}"
OUT="$ROOT/sim76/screenshots/iphone17pro"
LOG="$ROOT/sim76/logs"
APP=/tmp/agent-dd-shop/Build/Products/Debug-iphonesimulator/DreamCart.app
BID=com.jackwallner.shop

shot() { axe screenshot --output "$OUT/$1" --udid "$UDID" >/dev/null; echo "  shot $1"; }
tree() { axe describe-ui --udid "$UDID" > "$LOG/$1.json" 2>/dev/null; echo "  tree $1.json"; }
tap_label() { axe tap --label "$1" --wait-timeout 3 --udid "$UDID" 2>/dev/null || tap_xy 201 400 0; sleep "${2:-1.5}"; }
tap_xy() { axe tap -x "$1" -y "$2" --udid "$UDID"; sleep "${3:-1.5}"; }
swipe_up() { axe swipe --start-x 201 --start-y 650 --end-x 201 --end-y 250 --udid "$UDID"; sleep 1; }
swipe_left() { axe swipe --start-x 320 --start-y 400 --end-x 80 --end-y 400 --udid "$UDID"; sleep 1; }

mkdir -p "$OUT" "$LOG"
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 2>/dev/null || true

# Fresh launch
xcrun simctl terminate "$UDID" "$BID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BID" >/dev/null
sleep 3

echo "=== WELCOME / AUTH ==="
shot 01-welcome.png; tree 01-welcome

# Sign in as tester if on welcome
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q "Continue as tester"; then
  tap_label "Continue as tester" 5
  shot 02-after-signin.png; tree 02-after-signin
fi

echo "=== TODAY TAB ==="
shot 03-today.png; tree 03-today

# Daily claim if available
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q '"AXLabel" : "Claim now"'; then
  tap_label "Claim now" 3
  shot 04-daily-reward-overlay.png; tree 04-daily-reward
  tap_xy 201 437 2  # dismiss overlay center tap
fi

# Scroll today
swipe_up; shot 05-today-scrolled.png
swipe_up; shot 06-today-brands.png

echo "=== SPIN ==="
tap_label "Spin the wheel" 2
shot 07-spin.png; tree 07-spin
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q '"AXLabel" : "Spin"'; then
  tap_label "Spin" 5
  shot 08-spin-result.png; tree 08-spin-result
  sleep 2
  tap_xy 201 750 2  # dismiss reward overlay
fi
tap_label "Close" 2 || tap_xy 201 800 2

echo "=== SHOP TAB ==="
tap_label "Shop" 3
shot 09-shop.png; tree 09-shop

# Category filter
tap_xy 120 180 2  # Tops chip approx
shot 10-shop-tops.png

# Search
tap_label "Search brands, colors, styles" 1 || true
axe type "emerald" --udid "$UDID" 2>/dev/null || true
sleep 2
shot 11-shop-search.png; tree 11-shop-search
axe button home --udid "$UDID" 2>/dev/null; sleep 1

# Product detail
tap_xy 120 400 3
shot 12-product-detail.png; tree 12-product-detail

# Favorite
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -qi heart; then
  tap_xy 350 200 1
  shot 13-product-favorited.png
fi

# Add to cart
tap_label "Add to cart" 2 || tap_label "Check out" 2
sleep 2
shot 14-checkout-from-detail.png; tree 14-checkout-from-detail
tap_label "Cancel" 2 || tap_xy 60 80 1

echo "=== CART TAB ==="
tap_label "Cart" 2
shot 15-cart.png; tree 15-cart

# If cart has items, try checkout
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q "Check out"; then
  tap_label "Check out" 2
  shot 16-checkout.png; tree 16-checkout
  # Fill address
  tap_label "Full name" 1 || true
  axe type "Test User" --udid "$UDID" 2>/dev/null || true
  tap_xy 201 300 1
  axe type "123 Main St" --udid "$UDID" 2>/dev/null || true
  tap_xy 120 360 1
  axe type "San Francisco" --udid "$UDID" 2>/dev/null || true
  tap_xy 300 360 1
  axe type "CA" --udid "$UDID" 2>/dev/null || true
  tap_xy 201 420 1
  axe type "94102" --udid "$UDID" 2>/dev/null || true
  axe button home --udid "$UDID" 2>/dev/null
  sleep 1
  shot 17-checkout-filled.png
  swipe_up
  shot 18-checkout-receipt.png
  if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q "Place order"; then
    tap_label "Place order" 4
    shot 19-unboxing.png; tree 19-unboxing
    tap_label "Love it" 2 || tap_xy 201 750 2
  fi
  tap_label "Cancel" 1 2>/dev/null || true
fi

echo "=== CLOSET TAB ==="
tap_label "Closet" 3
shot 20-closet.png; tree 20-closet

# Outfit builder
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q "Dress up"; then
  tap_label "Dress up your avatar" 3
  shot 21-outfit-builder.png; tree 21-outfit-builder
  swipe_up; shot 22-outfit-builder-scrolled.png
  # Try picking a slot
  tap_xy 201 500 2
  sleep 2
  shot 23-slot-picker.png; tree 23-slot-picker
  tap_label "Close" 1 2>/dev/null || tap_xy 350 80 1
  axe button home --udid "$UDID" 2>/dev/null || true
  sleep 1
fi

echo "=== PROFILE TAB ==="
tap_label "You" 3
shot 24-profile.png; tree 24-profile

# Coin shop
tap_label "Get more coins" 2 || tap_xy 350 80 2
shot 25-coin-shop.png; tree 25-coin-shop

# Try purchase (StoreKit sandbox)
if axe describe-ui --udid "$UDID" 2>/dev/null | grep -q "Pocket"; then
  tap_label "Pocket" 2 || tap_xy 201 250 2
  sleep 3
  shot 26-storekit-purchase.png; tree 26-storekit
  # Dismiss StoreKit dialog if present
  tap_label "Subscribe" 1 2>/dev/null || tap_label "Buy" 1 2>/dev/null || tap_xy 201 600 1 2>/dev/null || true
  sleep 2
  shot 27-after-purchase-attempt.png
fi
tap_label "Done" 2 || tap_xy 350 80 1

# Coin history
tap_label "Coin history" 2
shot 28-ledger.png; tree 28-ledger
tap_label "Done" 1

# Dark mode
tap_xy 300 350 1  # appearance segmented control dark
sleep 1
shot 29-profile-dark.png

echo "=== DARK MODE TOUR ==="
xcrun simctl ui "$UDID" appearance dark 2>/dev/null || true
sleep 1
tap_label "Today" 2; shot 30-today-dark.png
tap_label "Shop" 2; shot 31-shop-dark.png
tap_label "Cart" 2; shot 32-cart-dark.png
tap_label "Closet" 2; shot 33-closet-dark.png
tap_label "You" 2; shot 34-profile-dark-system.png

# Reset light
xcrun simctl ui "$UDID" appearance light 2>/dev/null || true

echo "=== EMPTY STATES (fresh account would show these - capture signed-out) ==="
# Sign out
tap_label "Sign out" 3
sleep 2
shot 35-welcome-signed-out.png; tree 35-welcome
# Swipe onboarding slides
axe swipe --start-x 320 --start-y 400 --end-x 80 --end-y 400 --udid "$UDID"; sleep 1
shot 36-onboarding-slide2.png
axe swipe --start-x 320 --start-y 400 --end-x 80 --end-y 400 --udid "$UDID"; sleep 1
shot 37-onboarding-slide3.png

# Sign back in
tap_label "Continue as tester" 5
shot 38-signed-back-in.png

echo "=== LOW COINS FLOW ==="
# Open coin shop from wallet pill
tap_xy 330 90 2
shot 39-wallet-coin-shop.png

echo "DONE — screenshots in $OUT"
