#!/usr/bin/env python3
"""Refresh DreamCart's tracked US Astro keyword metrics."""
from __future__ import annotations

import json
from pathlib import Path

from astro_mcp import call

APP_ID = "118"
STORE = "us"
OUT = Path(__file__).with_name("astro-keyword-metrics-us.json")


def main() -> None:
    rows = call("http://127.0.0.1:8089/mcp", "get_app_keywords", {"appId": APP_ID, "store": STORE})
    rows.sort(key=lambda item: (-item.get("popularity", 0), item.get("difficulty", 999)))
    payload = {
        "appId": APP_ID,
        "appName": "DreamCart: Dopamine Shopping",
        "store": STORE,
        "popularityFloor": 5,
        "rule": "Treat Astro popularity 5 as effectively zero for acquisition strategy.",
        "keywords": rows,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    useful = [row for row in rows if row.get("popularity", 0) > 5]
    print(f"wrote {len(rows)} metrics ({len(useful)} above the popularity floor)")


if __name__ == "__main__":
    main()
