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
REVIEW_NOTES = """DreamCart is a virtual fashion shopping game. All items, coins, and delivery are imaginary and have no cash value.

- Sign in with Apple is required to save closet progress and coins.
- Flow: Today tab → claim daily coins → spin the wheel → Shop tab → browse/add to cart → checkout with coins → items appear in Closet → style outfits in the outfit builder.
- Optional consumable coin packs ($1.99–$49.99) are available via Get more coins; purchases are processed by Apple via RevenueCat.
- Product images are AI-generated fashion photography loaded on demand.
- Account deletion is available under You → Delete account.
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
            "attributes": {"copyright": COPYRIGHT},
        }
    })
    print(f"copyright set ({COPYRIGHT})")

    rd = c.get(f"/appStoreVersions/{vid}/appStoreReviewDetail").get("data")
    if rd:
        print("review detail exists")
    else:
        c.post("/appStoreReviewDetails", {
            "data": {
                "type": "appStoreReviewDetails",
                "attributes": {
                    "contactFirstName": "Jack",
                    "contactLastName": "Wallner",
                    "contactPhone": "14257533411",
                    "contactEmail": "jackwallner+q@gmail.com",
                    "demoAccountRequired": False,
                    "notes": REVIEW_NOTES,
                },
                "relationships": {
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}},
                },
            }
        })
        print("review detail created")

    print("done")


if __name__ == "__main__":
    main()
