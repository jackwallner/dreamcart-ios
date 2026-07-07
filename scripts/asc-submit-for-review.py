#!/usr/bin/env python3
"""Attach the latest valid build + coin-pack IAPs to the editable App Store
version and submit for review.

Usage: source ~/.baseball_credentials && python3 scripts/asc-submit-for-review.py [--build N] [--dry-run]
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

APP_ID = "6787820106"
BUNDLE = "com.jackwallner.shop"
PLATFORM = "IOS"


def latest_valid_build(c, prefer: int | None):
    builds = c.get(f"/builds?filter[app]={APP_ID}&limit=20").get("data", [])
    cand = []
    for b in builds:
        at = b["attributes"]
        if at.get("processingState") == "VALID" and not at.get("expired"):
            cand.append((int(at["version"]), b["id"], at["version"]))
    if not cand:
        sys.exit("error: no VALID non-expired builds")
    if prefer is not None:
        for v, bid, vs in cand:
            if v == prefer:
                return bid, vs
        sys.exit(f"error: build {prefer} is not VALID/available")
    cand.sort(reverse=True)
    return cand[0][1], cand[0][2]


def ready_iap_ids(c) -> list[str]:
    ids = []
    for iap in asc_lib.list_all(c, f"/apps/{APP_ID}/inAppPurchasesV2?limit=200"):
        state = iap["attributes"].get("state")
        if state in ("READY_TO_SUBMIT", "WAITING_FOR_REVIEW", "IN_REVIEW"):
            ids.append(iap["id"])
            print(f"  iap {iap['attributes']['productId']} ({state})")
    return ids


def find_open_submission(c) -> dict | None:
    for rs in c.get(f"/reviewSubmissions?filter[app]={APP_ID}&limit=20").get("data", []):
        st = rs["attributes"].get("state")
        if st in ("READY_FOR_REVIEW", "WAITING_FOR_REVIEW", "IN_REVIEW") and not rs["attributes"].get("submitted"):
            return rs
    return None


def cancel_open_submissions(c):
    for rs in c.get(f"/reviewSubmissions?filter[app]={APP_ID}&limit=20").get("data", []):
        st = rs["attributes"].get("state")
        if st in ("UNRESOLVED_ISSUES",):
            c.patch(
                f"/reviewSubmissions/{rs['id']}",
                {"data": {"type": "reviewSubmissions", "id": rs["id"], "attributes": {"canceled": True}}},
            )
            print(f"canceled prior submission {rs['id']} (was {st})")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", type=int, default=None)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--submit", action="store_true", help="Final PATCH submitted=true (skip if staging only)")
    args = ap.parse_args()

    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))

    version = asc_lib.find_editable_version(c, APP_ID)
    if version is None:
        sys.exit("error: no editable App Store version found")
    vid = version["id"]
    vstate = version["attributes"].get("appStoreState")
    vstr = version["attributes"].get("versionString")
    print(f"editable version {vstr} state={vstate} id={vid}")

    build_id, build_no = latest_valid_build(c, args.build)
    print(f"selected build {build_no} id={build_id}")

    print("IAPs to include:")
    iap_ids = ready_iap_ids(c)

    if args.dry_run:
        print("dry-run: stopping before any mutation")
        return

    c.request(
        "PATCH",
        f"/appStoreVersions/{vid}/relationships/build",
        {"data": {"type": "builds", "id": build_id}},
    )
    print(f"attached build {build_no} to version {vstr}")

    cancel_open_submissions(c)

    existing = find_open_submission(c)
    if existing:
        rs_id = existing["id"]
        print(f"reusing review submission {rs_id}")
    else:
        rs = c.post(
            "/reviewSubmissions",
            {"data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": PLATFORM},
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }},
        )["data"]
        rs_id = rs["id"]
        print(f"created review submission {rs_id}")

    c.post(
        "/reviewSubmissionItems",
        {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": rs_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}},
            },
        }},
    )
    print("added version to submission")

    # Consumable IAPs cannot be attached via the public REST API
    # (reviewSubmissionItems rejects inAppPurchases; inAppPurchaseSubmissions
    # returns FIRST_CONSUMABLE_MUST_BE_SUBMITTED_ON_VERSION). Attach them in
    # App Store Connect: version page → In-App Purchases → select all coin packs
    # → Submit for Review. Or use `asc web review iaps attach` with a web session.
    if iap_ids:
        print(f"NOTE: {len(iap_ids)} consumable IAPs are READY_TO_SUBMIT but must be")
        print("      selected on the version page in App Store Connect before you submit.")

    if not args.submit:
        print("staged (not submitted). In App Store Connect: open version 1.0 →")
        print("In-App Purchases → select all coin packs → Submit for Review.")
        print("Or rerun with --submit after attaching IAPs in the UI.")
        return

    out = c.patch(
        f"/reviewSubmissions/{rs_id}",
        {"data": {"type": "reviewSubmissions", "id": rs_id, "attributes": {"submitted": True}}},
    )
    print("submitted. state:", out["data"]["attributes"].get("state"))


if __name__ == "__main__":
    main()
