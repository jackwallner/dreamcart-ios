#!/usr/bin/env python3
"""Create the DreamCart+ weekly subscription in App Store Connect.

DreamCart had no subscription group at all: the backend already understood
`profiles.is_plus` (double daily coins, unlimited spins) but there was nothing
to sell. This creates, idempotently:

  subscription group   DreamCart+
  subscription         com.jackwallner.shop.plus.weekly, 1 week
  localization         en-US name + description
  price                $0.99 USA, equalized to every other territory
  availability         every territory
  introductory offer   3 days free, all territories

Run from the repo root:  python3 scripts/asc-setup-plus-subscription.py
Add --dry-run to print what it would do without writing.
"""
from __future__ import annotations

import sys
import urllib.parse

sys.path.insert(0, "/Users/jackwallner/ios/pricing")
import asc  # noqa: E402

APP_ID = "6787820106"
GROUP_REF = "DreamCartPlus"
GROUP_NAME = "DreamCart+"
PRODUCT_ID = "com.jackwallner.shop.plus.weekly"
SUB_REF = "DreamCart Plus Weekly"
DISPLAY_NAME = "DreamCart+ Weekly"
# App Store Connect caps the subscription description at 45 characters.
DESCRIPTION = "Double daily coins and unlimited spins."
USA_PRICE = "0.99"
TRIAL_DURATION = "THREE_DAYS"

DRY = "--dry-run" in sys.argv


def say(msg: str) -> None:
    print(msg, flush=True)


def find_group() -> dict | None:
    groups, _ = asc.get_all(f"/v1/apps/{APP_ID}/subscriptionGroups", {"limit": 50})
    for g in groups:
        if g["attributes"].get("referenceName") == GROUP_REF:
            return g
    return groups[0] if groups else None


def ensure_group() -> str:
    existing = find_group()
    if existing:
        say(f"group exists: {existing['id']} ({existing['attributes'].get('referenceName')})")
        return existing["id"]
    if DRY:
        say(f"would create group {GROUP_REF}")
        return "DRY-GROUP"
    r = asc.post("/v1/subscriptionGroups", {
        "data": {
            "type": "subscriptionGroups",
            "attributes": {"referenceName": GROUP_REF},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }
    })
    gid = r["data"]["id"]
    say(f"created group {gid}")
    asc.post("/v1/subscriptionGroupLocalizations", {
        "data": {
            "type": "subscriptionGroupLocalizations",
            "attributes": {"name": GROUP_NAME, "locale": "en-US"},
            "relationships": {
                "subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}
            },
        }
    })
    say("  group localization en-US set")
    return gid


def ensure_subscription(gid: str) -> str:
    subs, _ = asc.get_all(f"/v1/subscriptionGroups/{gid}/subscriptions", {"limit": 50})
    for s in subs:
        if s["attributes"].get("productId") == PRODUCT_ID:
            say(f"subscription exists: {s['id']} state={s['attributes'].get('state')}")
            return s["id"]
    if DRY:
        say(f"would create subscription {PRODUCT_ID}")
        return "DRY-SUB"
    r = asc.post("/v1/subscriptions", {
        "data": {
            "type": "subscriptions",
            "attributes": {
                "name": SUB_REF,
                "productId": PRODUCT_ID,
                "subscriptionPeriod": "ONE_WEEK",
                "familySharable": False,
                "reviewNote": (
                    "DreamCart+ is the app's membership. It doubles the daily coin "
                    "grant and removes the once-a-day limit on the prize wheel. "
                    "Coins are play money inside the app and buy nothing outside it."
                ),
            },
            "relationships": {
                "group": {"data": {"type": "subscriptionGroups", "id": gid}}
            },
        }
    })
    sid = r["data"]["id"]
    say(f"created subscription {sid}")
    return sid


def ensure_localization(sid: str) -> None:
    locs, _ = asc.get_all(f"/v1/subscriptions/{sid}/subscriptionLocalizations", {"limit": 50})
    if any(l["attributes"].get("locale") == "en-US" for l in locs):
        say("localization en-US exists")
        return
    if DRY:
        say("would create en-US localization")
        return
    asc.post("/v1/subscriptionLocalizations", {
        "data": {
            "type": "subscriptionLocalizations",
            "attributes": {"name": DISPLAY_NAME, "description": DESCRIPTION, "locale": "en-US"},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sid}}
            },
        }
    })
    say("localization en-US created")


def ensure_availability(sid: str) -> None:
    terrs, _ = asc.get_all("/v1/territories", {"limit": 200})
    ids = [t["id"] for t in terrs]
    if DRY:
        say(f"would make available in {len(ids)} territories")
        return
    try:
        asc.post("/v1/subscriptionAvailabilities", {
            "data": {
                "type": "subscriptionAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": sid}},
                    "availableTerritories": {
                        "data": [{"type": "territories", "id": t} for t in ids]
                    },
                },
            }
        })
        say(f"availability set for {len(ids)} territories")
    except Exception as e:
        say(f"availability: {e}")


def ensure_prices(sid: str) -> None:
    existing, _ = asc.get_all(f"/v1/subscriptions/{sid}/prices", {"limit": 200})
    if len(existing) > 100:
        say(f"prices already set ({len(existing)} rows)")
        return
    points, _ = asc.get_all(f"/v1/subscriptions/{sid}/pricePoints",
                            {"filter[territory]": "USA", "limit": 200})
    usa = next((p for p in points if p["attributes"]["customerPrice"] == USA_PRICE), None)
    if not usa:
        say(f"no USA price point at {USA_PRICE}; available: "
            f"{sorted({p['attributes']['customerPrice'] for p in points})[:12]}")
        return
    if DRY:
        say(f"would set USA {USA_PRICE} and equalize")
        return
    eq, _ = asc.get_all(
        f"/v1/subscriptionPricePoints/{urllib.parse.quote(usa['id'], safe='')}/equalizations",
        {"include": "territory", "limit": 200})
    ok = fail = 0
    for point in eq + [usa]:
        try:
            asc.post("/v1/subscriptionPrices", {
                "data": {
                    "type": "subscriptionPrices",
                    "attributes": {"preserveCurrentPrice": False},
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "subscriptionPricePoint": {
                            "data": {"type": "subscriptionPricePoints", "id": point["id"]}
                        },
                    },
                }
            })
            ok += 1
        except Exception:
            fail += 1
    say(f"prices: {ok} set, {fail} failed")


def ensure_trial(sid: str) -> None:
    offers, _ = asc.get_all(f"/v1/subscriptions/{sid}/introductoryOffers", {"limit": 50})
    if offers:
        say(f"introductory offer exists ({len(offers)} rows)")
        return
    if DRY:
        say(f"would create {TRIAL_DURATION} free trial")
        return
    # There is no "all territories" form: the API demands one offer row per
    # territory, so this walks the same list the availability call used.
    terrs, _ = asc.get_all("/v1/territories", {"limit": 200})
    ok = fail = 0
    first_error = None
    for t in terrs:
        try:
            asc.post("/v1/subscriptionIntroductoryOffers", {
                "data": {
                    "type": "subscriptionIntroductoryOffers",
                    "attributes": {
                        "duration": TRIAL_DURATION,
                        "offerMode": "FREE_TRIAL",
                        "numberOfPeriods": 1,
                    },
                    "relationships": {
                        "subscription": {"data": {"type": "subscriptions", "id": sid}},
                        "territory": {"data": {"type": "territories", "id": t["id"]}},
                    },
                }
            })
            ok += 1
        except Exception as e:
            fail += 1
            if first_error is None:
                first_error = str(e)[:300]
    say(f"introductory offer ({TRIAL_DURATION} free): {ok} territories set, {fail} failed")
    if first_error:
        say(f"  first failure: {first_error}")


def main() -> None:
    say(f"DreamCart+ setup{' (DRY RUN)' if DRY else ''}")
    gid = ensure_group()
    if gid.startswith("DRY"):
        say(f"would create subscription {PRODUCT_ID} (1 week, ${USA_PRICE}, "
            f"{TRIAL_DURATION} free trial) in the new group")
        return
    sid = ensure_subscription(gid)
    if sid.startswith("DRY"):
        return
    ensure_localization(sid)
    ensure_availability(sid)
    ensure_prices(sid)
    ensure_trial(sid)
    sub = asc.get(f"/v1/subscriptions/{sid}")["data"]
    say(f"\nfinal state: {sub['attributes'].get('state')}  productId={sub['attributes'].get('productId')}")


if __name__ == "__main__":
    main()
