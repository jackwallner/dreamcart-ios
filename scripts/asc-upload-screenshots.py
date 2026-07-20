#!/usr/bin/env python3
"""Upload 6.9" iPhone App Store screenshots for DreamCart's editable version.

Usage: source ~/.baseball_credentials && python3 scripts/asc-upload-screenshots.py [dir]
Default dir: fastlane/screenshots/en-US
"""
from __future__ import annotations

import argparse
import hashlib
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

APP_ID = "6787820106"
# 6.9" (iPhone 16/17 Pro Max, 1320x2868) screenshots upload under the 6.7"
# display bucket — App Store Connect has no separate APP_IPHONE_69 type.
DISPLAY = "APP_IPHONE_67"


def upload_file(c, reservation: dict, img: bytes) -> None:
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = img[op["offset"]: op["offset"] + op["length"]]
        req = urllib.request.Request(op["url"], data=chunk, method=op["method"])
        for h in op["requestHeaders"]:
            req.add_header(h["name"], h["value"])
        urllib.request.urlopen(req, timeout=120).read()
    c.patch(f"/appScreenshots/{reservation['id']}", {
        "data": {
            "type": "appScreenshots",
            "id": reservation["id"],
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": hashlib.md5(img).hexdigest(),
            },
        }
    })


def ensure_set(c, loc_id: str) -> str:
    for s in c.get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]:
        if s["attributes"].get("screenshotDisplayType") == DISPLAY:
            return s["id"]
    return c.post("/appScreenshotSets", {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": DISPLAY},
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id},
                },
            },
        },
    })["data"]["id"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("dir", nargs="?", default=str(Path(__file__).resolve().parent.parent / "fastlane/screenshots/en-US"))
    parser.add_argument("--replace", action="store_true", help="Delete existing files in the 6.9-inch bucket first")
    parser.add_argument("--delete-display", choices=["APP_IPHONE_65"], help="Delete a stale screenshot display bucket")
    args = parser.parse_args()
    shot_dir = Path(args.dir)
    images = sorted(p for p in shot_dir.glob("*.png") if p.is_file())
    if not images:
        sys.exit(f"error: no PNG screenshots in {shot_dir}")

    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    version = asc_lib.find_editable_version(c, APP_ID)
    if not version:
        sys.exit("error: no editable version")
    loc_id = None
    for loc in c.get(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]:
        if loc["attributes"]["locale"] == "en-US":
            loc_id = loc["id"]
            break
    if not loc_id:
        sys.exit("error: no en-US localization")

    sets = c.get(f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")["data"]
    if args.delete_display:
        stale = next((s for s in sets if s["attributes"].get("screenshotDisplayType") == args.delete_display), None)
        if stale:
            for screenshot in c.get(f"/appScreenshotSets/{stale['id']}/appScreenshots")["data"]:
                c.request("DELETE", f"/appScreenshots/{screenshot['id']}")
            c.request("DELETE", f"/appScreenshotSets/{stale['id']}")
            print(f"deleted screenshot set {stale['id']} ({args.delete_display})")
        else:
            print(f"no screenshot set for {args.delete_display}")
        return

    set_id = ensure_set(c, loc_id)
    screenshots = c.get(f"/appScreenshotSets/{set_id}/appScreenshots")["data"]
    if args.replace:
        for screenshot in screenshots:
            c.request("DELETE", f"/appScreenshots/{screenshot['id']}")
        screenshots = []
        print(f"cleared screenshot set {set_id} ({DISPLAY})")
    existing = {s["attributes"]["fileName"] for s in screenshots}
    print(f"screenshot set {set_id} ({DISPLAY})")

    for img_path in images:
        if img_path.name in existing:
            print(f"= {img_path.name}")
            continue
        img = img_path.read_bytes()
        reservation = c.post("/appScreenshots", {
            "data": {
                "type": "appScreenshots",
                "attributes": {"fileName": img_path.name, "fileSize": len(img)},
                "relationships": {
                    "appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}},
                },
            },
        })["data"]
        upload_file(c, reservation, img)
        print(f"+ {img_path.name} ({len(img)//1024} KB)")

    print("done")


if __name__ == "__main__":
    main()
