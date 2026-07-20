#!/usr/bin/env python3
"""Read-only DreamCart App Store Connect release readiness audit."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib
import importlib.util

APP_ID = "6787820106"
BUNDLE = "com.jackwallner.shop"


def metadata_module():
    path = Path(__file__).with_name("asc-localize-metadata.py")
    spec = importlib.util.spec_from_file_location("dreamcart_metadata", path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> None:
    blockers: list[str] = []
    warnings: list[str] = []
    metadata = metadata_module()
    data = {locale: metadata.payload(locale) for locale in metadata.LOCALES}
    try:
        metadata.validate(data)
    except SystemExit as exc:
        blockers.append(str(exc))

    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(c, BUNDLE)
    if app["id"] != APP_ID:
        blockers.append(f"unexpected app id {app['id']}")
    if app["attributes"].get("contentRightsDeclaration") != "USES_THIRD_PARTY_CONTENT":
        blockers.append("content rights declaration is not set")

    info = asc_lib.find_editable_app_info(c, APP_ID)
    version = asc_lib.find_editable_version(c, APP_ID)
    if not info or not version:
        blockers.append("missing editable app info or version")
    else:
        info_locs = asc_lib.list_all(c, f"/appInfos/{info['id']}/appInfoLocalizations?limit=200")
        version_locs = asc_lib.list_all(c, f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations?limit=200")
        if len(info_locs) != 50 or len(version_locs) != 50:
            blockers.append(f"locale counts are appInfo={len(info_locs)} version={len(version_locs)}, expected 50/50")
        for loc in info_locs:
            attrs = loc["attributes"]
            locale = attrs["locale"]
            for field, minimum in (("name", 24), ("subtitle", 24)):
                if len(attrs.get(field) or "") < minimum:
                    blockers.append(f"{locale} {field} is below {minimum}")
            if not attrs.get("privacyPolicyUrl"):
                blockers.append(f"{locale} privacy URL missing")
        for loc in version_locs:
            attrs = loc["attributes"]
            locale = attrs["locale"]
            if len(attrs.get("keywords") or "") < 94:
                blockers.append(f"{locale} keywords below 94")
            for field in ("description", "promotionalText", "supportUrl", "marketingUrl"):
                if not attrs.get(field):
                    blockers.append(f"{locale} {field} missing")

        builds = c.get(f"/builds?filter[app]={APP_ID}&limit=20").get("data", [])
        valid = [b for b in builds if b["attributes"].get("processingState") == "VALID" and not b["attributes"].get("expired")]
        latest = max(valid, key=lambda b: int(b["attributes"]["version"])) if valid else None
        attached = c.get(f"/appStoreVersions/{version['id']}/build").get("data")
        if not latest:
            blockers.append("no valid non-expired build")
        elif not attached or attached["id"] != latest["id"]:
            blockers.append(f"latest build {latest['attributes']['version']} is not attached")

        en_us = next((loc for loc in version_locs if loc["attributes"]["locale"] == "en-US"), None)
        if en_us:
            sets = asc_lib.list_all(c, f"/appStoreVersionLocalizations/{en_us['id']}/appScreenshotSets?limit=200")
            canonical = next((s for s in sets if s["attributes"].get("screenshotDisplayType") == "APP_IPHONE_67"), None)
            stale = next((s for s in sets if s["attributes"].get("screenshotDisplayType") == "APP_IPHONE_65"), None)
            if not canonical:
                blockers.append("missing 6.9-inch screenshot set")
            else:
                images = asc_lib.list_all(c, f"/appScreenshotSets/{canonical['id']}/appScreenshots?limit=200")
                if len(images) < 3 or any(i["attributes"].get("assetDeliveryState", {}).get("state") != "COMPLETE" for i in images):
                    blockers.append("canonical screenshots are incomplete")
            if stale:
                warnings.append("stale 6.5-inch screenshot set remains")

        review = c.get(f"/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
        if not review:
            blockers.append("review contact/details missing")
        elif not review["attributes"].get("notes"):
            blockers.append("review notes missing")

    iaps = asc_lib.list_all(c, f"/apps/{APP_ID}/inAppPurchasesV2?limit=200")
    if len(iaps) != 5:
        blockers.append(f"expected 5 IAPs, found {len(iaps)}")
    for iap in iaps:
        state = iap["attributes"].get("state")
        if state not in {"READY_TO_SUBMIT", "WAITING_FOR_REVIEW", "IN_REVIEW", "APPROVED"}:
            blockers.append(f"{iap['attributes']['productId']} state is {state}")
        iid = iap["id"]
        screenshot = c.request("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iid}/appStoreReviewScreenshot").get("data")
        if not screenshot or screenshot.get("attributes", {}).get("assetDeliveryState", {}).get("state") != "COMPLETE":
            blockers.append(f"{iap['attributes']['productId']} review screenshot missing")
        locs = c.request("GET", f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations?limit=200").get("data", [])
        if len(locs) < 50:
            warnings.append(f"{iap['attributes']['productId']} has {len(locs)}/50 localizations")

    submissions = c.get(f"/reviewSubmissions?filter[app]={APP_ID}&limit=20").get("data", [])
    open_submissions = [s for s in submissions if s["attributes"].get("state") == "READY_FOR_REVIEW"]
    if len(open_submissions) != 1:
        blockers.append(f"expected one READY_FOR_REVIEW submission, found {len(open_submissions)}")
    elif not c.get(f"/reviewSubmissions/{open_submissions[0]['id']}/items?limit=200").get("data"):
        blockers.append("open review submission contains no items")

    print(f"blockers: {len(blockers)}")
    for item in blockers:
        print(f"BLOCKER: {item}")
    for item in warnings:
        print(f"WARNING: {item}")
    if blockers:
        raise SystemExit(1)
    print("release audit passed")


if __name__ == "__main__":
    main()
