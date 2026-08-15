#!/usr/bin/env python3
"""Attach the App Review screenshot to the DreamCart+ subscription.

A subscription stays in MISSING_METADATA until App Review can see the screen
that sells it. Capture with scripts/capture-plus-paywall.sh, then run this.

Usage: python3 scripts/asc-upload-subscription-screenshot.py [image.png]
"""
from __future__ import annotations

import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, "/Users/jackwallner/ios/pricing")
import asc  # noqa: E402

APP_ID = "6787820106"
PRODUCT_ID = "com.jackwallner.shop.plus.weekly"
DEFAULT_IMG = Path(__file__).parent.parent / "fastlane/iap_screenshots/plus_weekly.png"


def find_subscription() -> str:
    groups, _ = asc.get_all(f"/v1/apps/{APP_ID}/subscriptionGroups", {"limit": 50})
    for g in groups:
        subs, _ = asc.get_all(f"/v1/subscriptionGroups/{g['id']}/subscriptions", {"limit": 50})
        for s in subs:
            if s["attributes"].get("productId") == PRODUCT_ID:
                return s["id"]
    raise SystemExit(f"subscription {PRODUCT_ID} not found")


def main() -> None:
    img_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_IMG
    img = img_path.read_bytes()
    sid = find_subscription()

    existing = asc.get(f"/v1/subscriptions/{sid}/appStoreReviewScreenshot").get("data")
    if existing and existing.get("attributes", {}).get("assetDeliveryState", {}).get("state") == "COMPLETE":
        print("screenshot already attached")
        return

    reserve = asc.post("/v1/subscriptionAppStoreReviewScreenshots", {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "attributes": {"fileSize": len(img), "fileName": img_path.name},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sid}}
            },
        }
    })["data"]

    for op in reserve["attributes"]["uploadOperations"]:
        chunk = img[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=180).read()

    asc.patch(f"/v1/subscriptionAppStoreReviewScreenshots/{reserve['id']}", {
        "data": {
            "type": "subscriptionAppStoreReviewScreenshots",
            "id": reserve["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(img).hexdigest()},
        }
    })
    print(f"uploaded {img_path.name} ({len(img)} bytes)")

    state = asc.get(f"/v1/subscriptions/{sid}")["data"]["attributes"]["state"]
    print(f"subscription state: {state}")


if __name__ == "__main__":
    main()
