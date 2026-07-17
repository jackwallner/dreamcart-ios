# DreamCart — Project Guide

Dopamine-shopping game (iOS). Standalone repo `dreamcart-ios` (dir `~/shop`).
Core fantasy loop: daily coins + spin wheel → browse → cart → **fake checkout with
a real coin cost** → closet ownership → outfit builder, plus a RevenueCat coin shop.
App Store name: **DreamCart: Dopamine Shopping**.

XcodeGen project/scheme: `DreamCart`, bundle `com.jackwallner.shop`.

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- XcodeGen (`project.yml` → `DreamCart.xcodeproj`), iOS 17+, single iOS app target (+ `DreamCartTests`)
- RevenueCat 5.72+ via SPM (coin-pack IAP; gated behind `HAS_REVENUECAT` compilation condition)
- **Supabase backend** (the coins economy / catalog) — separate Supabase account `jtest0979`; service creds in `.env.shop` (gitignored); migrations in `supabase/`
- **Pollinations** for product imagery (keyless image generation)
- `DreamCart.storekit` for local paywall / coin-pack testing

## Architecture

- `DreamCart/` — app target: `DreamCartApp.swift` (entry), `RootView.swift`, `Views/`, `Components/`, `Assets.xcassets`, `Info.plist`, `DreamCart.entitlements`
- `Shared/` — `Models/`, `Services/`, `Utilities/` (business logic; also compiled into the test target)
- `supabase/` — DB migrations for the coins/catalog backend
- `scripts/` — full ASC automation suite (`asc-setup-iap.py`, `asc-setup-metadata.py`, `asc-setup-release.py`, `asc-submit-for-review.py`, `asc-upload-*`, `build-screenshots.py`, `capture-screenshots.sh`, `generate-icon.py`) + `testflight.sh`

## Deviations from the shared iOS conventions

Read these before assuming fleet defaults (global CLAUDE.md + `ios-dev` skill):
- **Not a local-only app** — it has a Supabase backend. Backend/schema changes need a Supabase migration + push, not just SwiftData.
- **Does NOT use the shared `agent-sim` / `agent-<app>` headless device.** DreamCart has its own simulator workflow; the last full audit + methodology is in `sim76.md` (standard Xcode simulator, `DreamCart.storekit` attached). The never-open-Simulator.app / never-shared-destination rules still apply.
- Product images come from Pollinations at runtime — grids show shimmer/retry while loading, and uncached requests can 429 under burst load.

## Backend (Supabase)

- Account `jtest0979`; project creds + service role key in `.env.shop` (never commit).
- Migrations in `supabase/`; apply with the Supabase CLI (`supabase link --project-ref <ref>` then `supabase db push`) after any schema change.

---
Shared iOS conventions (build, release/TestFlight, ASC key + metadata scripts, signing, RevenueCat, review funnel, gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill. To bootstrap a new app like this one, see the `ios-new-project` skill.

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
