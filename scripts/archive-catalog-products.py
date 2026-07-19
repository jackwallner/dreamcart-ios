#!/usr/bin/env python3
"""Archive reviewed DreamCart products from an explicit JSON manifest."""

from __future__ import annotations

import argparse
import json
import os
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


def patch_product(base_url: str, service_key: str, product_id: str) -> None:
    quoted = urllib.parse.quote(product_id, safe="")
    request = urllib.request.Request(
        f"{base_url}/rest/v1/products?id=eq.{quoted}",
        method="PATCH",
        data=json.dumps({"is_active": False}).encode(),
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "content-type": "application/json",
            "Prefer": "return=minimal",
        },
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status not in (200, 204):
            raise RuntimeError(f"Archive failed for {product_id}: HTTP {response.status}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    base_url = os.environ.get("SHOP_SUPABASE_URL")
    service_key = os.environ.get("SHOP_SUPABASE_SECRET")
    if not base_url or not service_key:
        raise SystemExit("Source .env.shop first")

    decisions: Any = json.loads(args.manifest.read_text())
    if not isinstance(decisions, list):
        raise SystemExit("Manifest must be a JSON array")

    accepted: list[dict[str, str]] = []
    for decision in decisions:
        if not isinstance(decision, dict):
            raise SystemExit("Every manifest entry must be an object")
        product_id = str(decision.get("id", "")).strip()
        reason = str(decision.get("reason", "")).strip()
        if not product_id or not reason:
            raise SystemExit("Every entry needs non-empty id and reason")
        accepted.append({"id": product_id, "reason": reason})

    print(f"reviewed archive entries: {len(accepted)}")
    for entry in accepted:
        print(f"{entry['id']}  {entry['reason']}")

    if not args.apply:
        print("dry run only, pass --apply to archive these products")
        return

    for index, entry in enumerate(accepted, start=1):
        patch_product(base_url.rstrip("/"), service_key, entry["id"])
        print(f"[{index}/{len(accepted)}] archived {entry['id']}")


if __name__ == "__main__":
    main()
