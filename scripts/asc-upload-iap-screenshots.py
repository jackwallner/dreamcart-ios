#!/usr/bin/env python3
"""Attach an App Review screenshot to each coin-pack IAP so they leave
MISSING_METADATA and become sandbox/App-Store submittable. Idempotent: skips an
IAP that already has a completed screenshot.

Usage: source ~/.baseball_credentials && python3 scripts/asc-upload-iap-screenshots.py <image.png>
"""
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.shop"
V1 = "https://api.appstoreconnect.apple.com/v1"
V2 = "https://api.appstoreconnect.apple.com/v2"


def upload(c, iap_id, img: bytes, name: str):
    reserve = c.request("POST", f"{V1}/inAppPurchaseAppStoreReviewScreenshots", {
        "data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "attributes": {"fileSize": len(img), "fileName": name},
            "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}},
        }
    })["data"]
    for op in reserve["attributes"]["uploadOperations"]:
        chunk = img[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=120).read()
    c.request("PATCH", f"{V1}/inAppPurchaseAppStoreReviewScreenshots/{reserve['id']}", {
        "data": {
            "type": "inAppPurchaseAppStoreReviewScreenshots",
            "id": reserve["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(img).hexdigest()},
        }
    })


def main():
    img_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("/tmp/shop_coins3.png")
    img = img_path.read_bytes()
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app_id = asc_lib.find_app(c, BUNDLE)["id"]

    for iap in asc_lib.list_all(c, f"/apps/{app_id}/inAppPurchasesV2?limit=200"):
        pid, iid = iap["attributes"]["productId"], iap["id"]
        existing = c.get(f"{V2}/inAppPurchases/{iid}/appStoreReviewScreenshot").get("data")
        if existing and existing.get("attributes", {}).get("assetDeliveryState", {}).get("state") == "COMPLETE":
            print(f"= {pid} screenshot present")
            continue
        upload(c, iid, img, f"{pid.split('.')[-1]}.png")
        print(f"+ {pid} screenshot uploaded")

    print("done")


if __name__ == "__main__":
    main()
