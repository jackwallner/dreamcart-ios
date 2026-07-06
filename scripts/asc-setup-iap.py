#!/usr/bin/env python3
"""Create DreamCart's 5 consumable coin-pack IAPs in App Store Connect:
product + USD price schedule + en-US localization. Idempotent.

Usage: source ~/.baseball_credentials && python3 scripts/asc-setup-iap.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.shop"
V1 = "https://api.appstoreconnect.apple.com/v1"
V2 = "https://api.appstoreconnect.apple.com/v2"

PACKS = [
    ("com.jackwallner.shop.coins.pocket", "Pocket of Coins", "1000 coins to shop with.", 1.99),
    ("com.jackwallner.shop.coins.bag",    "Bag of Coins",     "3,200 coins. Best for a full look.", 4.99),
    ("com.jackwallner.shop.coins.haul",   "Haul of Coins",    "8,500 coins. Build a whole wardrobe.", 9.99),
    ("com.jackwallner.shop.coins.spree",  "Shopping Spree",   "20,000 coins. Go on a spree.", 19.99),
    ("com.jackwallner.shop.coins.vault",  "The Vault",        "60,000 coins. Never run dry.", 49.99),
]


def paginate(c, url):
    """Follow absolute `next` links (v2 endpoints return absolute URLs)."""
    items = []
    while url:
        data = c.request("GET", url)
        items.extend(data.get("data", []))
        url = data.get("links", {}).get("next")
    return items


def closest_price_point(c, iap_id, target):
    points = paginate(c, f"{V2}/inAppPurchases/{iap_id}/pricePoints?filter[territory]=USA&limit=200")
    best, best_diff = None, 1e9
    for p in points:
        diff = abs(float(p["attributes"]["customerPrice"]) - target)
        if diff < best_diff:
            best, best_diff = p, diff
    return best


def main():
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app_id = asc_lib.find_app(c, BUNDLE)["id"]
    print(f"app {app_id}")

    existing = {i["attributes"]["productId"]: i
                for i in asc_lib.list_all(c, f"/apps/{app_id}/inAppPurchasesV2?limit=200")}

    for product_id, name, desc, price in PACKS:
        iap = existing.get(product_id)
        if iap:
            iap_id = iap["id"]
            print(f"= {product_id} ({iap['attributes']['state']})")
        else:
            iap = c.request("POST", f"{V2}/inAppPurchases", {
                "data": {
                    "type": "inAppPurchases",
                    "attributes": {"name": name, "productId": product_id,
                                   "inAppPurchaseType": "CONSUMABLE"},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            })["data"]
            iap_id = iap["id"]
            print(f"+ created {product_id}")

        # en-US localization
        locs = {l["attributes"]["locale"]
                for l in c.get(f"{V2}/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")["data"]}
        if "en-US" not in locs:
            c.request("POST", f"{V1}/inAppPurchaseLocalizations", {
                "data": {
                    "type": "inAppPurchaseLocalizations",
                    "attributes": {"locale": "en-US", "name": name, "description": desc},
                    "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}},
                }
            })
            print("  + en-US localization")

        # USD price schedule (404 => none yet)
        try:
            sched = c.get(f"{V2}/inAppPurchases/{iap_id}/iapPriceSchedule")
        except RuntimeError as e:
            sched = {"data": None} if "404" in str(e) else (_ for _ in ()).throw(e)
        if not sched.get("data"):
            pp = closest_price_point(c, iap_id, price)
            c.request("POST", f"{V1}/inAppPurchasePriceSchedules", {
                "data": {
                    "type": "inAppPurchasePriceSchedules",
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                        "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price1}"}]},
                        "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    },
                },
                "included": [{
                    "type": "inAppPurchasePrices",
                    "id": "${price1}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "inAppPurchasePricePoint": {
                            "data": {"type": "inAppPurchasePricePoints", "id": pp["id"]}},
                    },
                }],
            })
            print(f"  + price ${pp['attributes']['customerPrice']}")
        else:
            print("  = price set")

        # territory availability (required to leave MISSING_METADATA)
        try:
            avail = c.get(f"{V2}/inAppPurchases/{iap_id}/inAppPurchaseAvailability").get("data")
        except RuntimeError as e:
            avail = None if "404" in str(e) else (_ for _ in ()).throw(e)
        if not avail:
            territories = [t["id"] for t in asc_lib.list_all(c, "/territories?limit=200")]
            c.request("POST", f"{V1}/inAppPurchaseAvailabilities", {
                "data": {
                    "type": "inAppPurchaseAvailabilities",
                    "attributes": {"availableInNewTerritories": True},
                    "relationships": {
                        "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                        "availableTerritories": {
                            "data": [{"type": "territories", "id": t} for t in territories]},
                    },
                }
            })
            print("  + availability (all territories)")

    print("done")


if __name__ == "__main__":
    main()
