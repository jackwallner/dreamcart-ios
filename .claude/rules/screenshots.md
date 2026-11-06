---
paths:
  - "fastlane/screenshots/**"
  - "artifacts/asc-screenshots/l10n-20261105/**"
  - "DreamCart/DuoScreenshotMode.swift"
  - "DreamCart/Views/SpinView.swift"
---

# Localized App Store screenshots (2026-11-05)

- Recapture from the repo root with `artifacts/asc-screenshots/l10n-20261105/tools/capture.sh [store-locale ...]`. With no arguments it captures English plus every target locale, composes the frames, runs the catalog gate, writes comparison sheets and replaces only root PNGs in target locale folders. It initializes the Python and Swift tools, fetches the English frames, uses one `gh-sim launch` per device and waits 14 seconds per shot. The one second recording extends the GitHub launch timeout for the full set. This runner can log that it cannot analyze the video when `ffprobe` is unavailable; the screenshot job still succeeds.
- Scenes map in frame order to `today`, `spin`, `foryou`, `spin-result` and `closet`. `-DuoSeed` uses the real public catalog and product art. Do not add `-DreamCartScreenshot`, which substitutes artwork.
- The fourth frame opens the real `RewardOverlay` with a fixed DEBUG-only 1,500 coin result because the seeded shopper has no server session for the spin RPC. The fixture is activated by `-DuoSpinResult`.
- Live frame screens can be newer than their embedded English UI. Try `locate.py FRAME RAW` first. When the content no longer aligns, use `locate.py FRAME --bezel --radius` and retain the English frame's screen geometry.
- `ocr_allowlist` is only for server-owned proper names or tags that happen to match a translatable catalog word. This set allows `Hat`, which appears in a For You product name and tag. Pure numbers are ignored as counts, coin values or prices.
- English references are fetched into the ignored kit directory. Raws, virtual environments and sheets stay out of Git. Commit only final locale PNGs and the kit source files.
