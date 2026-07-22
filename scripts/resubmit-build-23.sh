#!/usr/bin/env bash
# Push, upload DreamCart build 23, attach all consumable IAPs, and submit 1.0.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_NUMBER="23"
APP_ID="6787820106"
PRODUCT_IDS=(
  com.jackwallner.shop.coins.pocket
  com.jackwallner.shop.coins.bag
  com.jackwallner.shop.coins.haul
  com.jackwallner.shop.coins.spree
  com.jackwallner.shop.coins.vault
)

CURRENT_BUILD=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | awk '{print $2}' | tr -d '"')
if [[ "$CURRENT_BUILD" != "$BUILD_NUMBER" ]]; then
  echo "error: project.yml is build $CURRENT_BUILD, expected $BUILD_NUMBER" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is not clean" >&2
  git status --short >&2
  exit 1
fi

echo "Pushing commits..."
git push origin main

echo "Uploading build $BUILD_NUMBER..."
NO_BUILD_BUMP=1 ./scripts/testflight.sh

source "$HOME/.baseball_credentials"

attempt=1
until python3 scripts/asc-submit-for-review.py --build "$BUILD_NUMBER" --dry-run; do
  if (( attempt >= 30 )); then
    echo "error: build $BUILD_NUMBER did not become VALID after 30 checks" >&2
    exit 1
  fi
  echo "Build $BUILD_NUMBER is still processing. Checking again in 60 seconds..."
  sleep 60
  attempt=$((attempt + 1))
done

echo "Updating App Review notes..."
python3 scripts/asc-setup-release.py

echo "Attaching consumable IAPs..."
for product_id in "${PRODUCT_IDS[@]}"; do
  asc web review iaps attach \
    --app "$APP_ID" \
    --iap-id "$product_id" \
    --confirm
done

echo "Submitting build $BUILD_NUMBER for review..."
python3 scripts/asc-submit-for-review.py --build "$BUILD_NUMBER" --submit

echo "DreamCart 1.0 build $BUILD_NUMBER submitted for App Review."
