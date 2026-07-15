#!/usr/bin/env bash
# The long catalog-art grind: re-render every existing product as a flat lay,
# then grow the catalog to TARGET. Pollinations is strictly serial (~40s/image),
# so this runs for many hours — it is meant to be driven by launchd, not by a
# terminal you might close.
#
# Both phases are resumable, so this is safe to kill and restart at any point:
#   backfill  — skips rows whose image_url already points at the current prefix
#   expand    — stops once the catalog reaches TARGET
#
# Install/uninstall the launchd agent:
#   launchctl load   ~/Library/LaunchAgents/com.jackwallner.dreamcart.catalog.plist
#   launchctl unload ~/Library/LaunchAgents/com.jackwallner.dreamcart.catalog.plist
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${TARGET:-1800}"
LOG="$ROOT/build/catalog-art.log"
mkdir -p "$ROOT/build"

# shellcheck disable=SC1091
set -a && . "$ROOT/.env.shop" && set +a

echo "=== $(date '+%Y-%m-%d %H:%M:%S') catalog-art job starting (target $TARGET) ===" >> "$LOG"

# caffeinate -i: don't let the machine idle-sleep mid-render. A closed lid still
# sleeps; launchd KeepAlive restarts the job on wake and it resumes where it left off.
caffeinate -i deno run --allow-net --allow-env scripts/backfill-product-art.ts >> "$LOG" 2>&1
BACKFILL=$?
echo "--- backfill exited $BACKFILL at $(date '+%H:%M:%S') ---" >> "$LOG"
[ $BACKFILL -ne 0 ] && exit $BACKFILL

caffeinate -i deno run --allow-net --allow-env scripts/expand-catalog.ts --target "$TARGET" >> "$LOG" 2>&1
EXPAND=$?
echo "=== $(date '+%Y-%m-%d %H:%M:%S') expand exited $EXPAND ===" >> "$LOG"
exit $EXPAND
