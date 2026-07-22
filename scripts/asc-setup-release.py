#!/usr/bin/env python3
"""Finish DreamCart ASC release prerequisites not covered by asc-setup-metadata.py:
content rights, free app pricing, version copyright, and App Review contact/notes.

Usage: source ~/.baseball_credentials && python3 scripts/asc-setup-release.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

APP_ID = "6787820106"
BUNDLE = "com.jackwallner.shop"
COPYRIGHT = "2026 Jack Wallner"
REVIEW_NOTES = """DreamCart is a virtual fashion shopping game. All brands, products, coins, checkout, and delivery are imaginary and have no cash value. No physical merchandise is sold or shipped.

Reviewer access:
- Sign in with Apple is the production authentication path. It creates a Supabase-backed account so coin balances, the closet, outfits, and purchase reconciliation persist correctly.
- Flow: complete onboarding → Sign in with Apple → claim the free daily coin drop → use the free daily spin → browse Shop/For You → add an item → check out with coins → open Closet.
- The daily wheel is free, cannot be purchased, awards only no-cash-value virtual coins, and has no real-world prize.
- Five optional consumable coin packs ($1.99–$49.99 in the US, localized by Apple) are available through the wallet plus button and coin shop. Apple processes payment and RevenueCat validates the transaction. The first-launch offer is optional and has an always-available Not now button.
- These products are consumables, so the app does not call Apple's Restore Purchases flow. The user's current unspent coin balance is stored on DreamCart's Supabase backend and syncs after signing in to the same DreamCart account. Undelivered completed transactions are reconciled automatically and idempotently by store transaction ID; previously spent coins are never re-granted.
- Product imagery is AI-generated fashion photography loaded on demand. Prompts contain no personal data.
- The optional checkout address is fictional flavor, stored only on device, and is not required. Nothing ships.
- Account deletion is available under You → Delete account and permanently removes the server-side profile and game data.
- Privacy Policy and Apple Standard EULA links are available before sign-in.
- The app does not use non-exempt encryption."""


def ensure_free_pricing(c, app_id: str) -> None:
    has_manual = False
    try:
        sched = c.get(f"/apps/{app_id}/appPriceSchedule")
        sched_id = sched["data"]["id"]
        mp = c.get(f"/appPriceSchedules/{sched_id}/manualPrices")
        has_manual = bool(mp.get("data"))
    except RuntimeError as e:
        if "404" not in str(e):
            raise
    if has_manual:
        print("app price schedule exists")
        return
    points = asc_lib.list_all(c, f"/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")
    free = min(
        (p for p in points if float(p["attributes"]["customerPrice"]) == 0.0),
        key=lambda p: p["id"],
        default=None,
    )
    if not free:
        raise SystemExit("error: no free USA app price point")
    c.post("/appPriceSchedules", {
        "data": {
            "type": "appPriceSchedules",
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${price0}"}]},
            },
        },
        "included": [{
            "type": "appPrices",
            "id": "${price0}",
            "attributes": {"startDate": None},
            "relationships": {
                "appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}},
            },
        }],
    })
    print("app price set to free (USA base)")


def main():
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    app_id = app["id"]
    print(f"app {app_id}")

    c.patch(f"/apps/{app_id}", {
        "data": {
            "type": "apps",
            "id": app_id,
            "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"},
        }
    })
    print("content rights: USES_THIRD_PARTY_CONTENT (AI-generated product imagery)")

    ensure_free_pricing(c, app_id)

    version = asc_lib.find_editable_version(c, app_id)
    if not version:
        sys.exit("error: no editable version")
    vid = version["id"]
    c.patch(f"/appStoreVersions/{vid}", {
        "data": {
            "type": "appStoreVersions",
            "id": vid,
            "attributes": {"copyright": COPYRIGHT, "releaseType": "AFTER_APPROVAL"},
        }
    })
    print(f"copyright set ({COPYRIGHT})")

    review_attributes = {
        "contactFirstName": "Jack",
        "contactLastName": "Wallner",
        "contactPhone": "14257533411",
        "contactEmail": "jackwallner+q@gmail.com",
        "demoAccountRequired": False,
        "notes": REVIEW_NOTES,
    }
    rd = c.get(f"/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if rd:
        c.patch(f"/appStoreReviewDetails/{rd['id']}", {
            "data": {
                "type": "appStoreReviewDetails",
                "id": rd["id"],
                "attributes": review_attributes,
            }
        })
        print("review detail updated")
    else:
        c.post("/appStoreReviewDetails", {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": review_attributes,
                "relationships": {
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}},
                },
            }
        })
        print("review detail created")

    print("done")


if __name__ == "__main__":
    main()
