#!/usr/bin/env python3
"""Tops the shared QA tester account back up to a working coin balance.

Every gate run checks out with tester@dreamcart.dev on the live backend, so
its coins drain run after run until the core-loop journey cannot afford a
piece. Run this before a gate (it is a no-op above the floor). Reads the
service key from .env.shop and writes a coin_ledger row, so the balance stays
reconstructable.
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

EMAIL = "tester@dreamcart.dev"
PASSWORD = "dreamcart-test-1"  # DEBUG-only tester, also in AuthController.devSignIn
FLOOR = 5_000
TARGET = 20_000


def load_env() -> dict[str, str]:
    env = {}
    path = Path(__file__).resolve().parent.parent / ".env.shop"
    for line in path.read_text().splitlines():
        m = re.match(r"(?:export\s+)?([A-Z_]+)=(.*)", line.strip())
        if m:
            env[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return env


def call(url: str, key: str, method: str = "GET", body=None, bearer: str | None = None, prefer: str = ""):
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header("apikey", key)
    req.add_header("Authorization", f"Bearer {bearer or key}")
    req.add_header("Content-Type", "application/json")
    if prefer:
        req.add_header("Prefer", prefer)
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
    return json.loads(raw) if raw else None


def main() -> int:
    env = load_env()
    base, anon, secret = env["SHOP_SUPABASE_URL"].rstrip("/"), env["SHOP_SUPABASE_PUBLISHABLE"], env["SHOP_SUPABASE_SECRET"]
    session = call(f"{base}/auth/v1/token?grant_type=password", anon, "POST", {"email": EMAIL, "password": PASSWORD})
    uid = session["user"]["id"]
    profile = call(f"{base}/rest/v1/profiles?id=eq.{uid}&select=coins", secret)[0]
    coins = profile["coins"]
    if coins >= FLOOR:
        print(f"tester has {coins:,} coins; no top-up needed")
        return 0
    delta = TARGET - coins
    call(f"{base}/rest/v1/profiles?id=eq.{uid}", secret, "PATCH", {"coins": TARGET}, prefer="return=minimal")
    call(f"{base}/rest/v1/coin_ledger", secret, "POST",
         {"user_id": uid, "delta": delta, "reason": "qa_topup", "balance_after": TARGET}, prefer="return=minimal")
    print(f"tester topped up from {coins:,} to {TARGET:,} coins")
    return 0


if __name__ == "__main__":
    sys.exit(main())
