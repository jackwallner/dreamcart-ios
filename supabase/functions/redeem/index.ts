// redeem: authoritative, dashboard-free coin crediting. The app calls this
// (with the user's Supabase JWT) after any purchase and on launch. We resolve
// the user from their token, ask RevenueCat for that customer's purchases,
// and grant coins for any coin-pack transaction not yet granted (idempotent
// on the store transaction id). Works in sandbox and production without a
// configured webhook, since RC's customer record carries the purchase once
// the SDK syncs it.
//
// Uses the RevenueCat REST API v2 (the project's secret key is a v2 key,
// which the v1 /subscribers endpoint rejects with code 7723).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RC_SECRET = Deno.env.get("RC_SECRET_KEY") ?? "";
const RC_PROJECT = Deno.env.get("RC_PROJECT_ID") ?? "";

const PACK_COINS: Record<string, number> = {
  "com.jackwallner.shop.coins.pocket": 1000,
  "com.jackwallner.shop.coins.bag": 3200,
  "com.jackwallner.shop.coins.haul": 8500,
  "com.jackwallner.shop.coins.spree": 20000,
  "com.jackwallner.shop.coins.vault": 60000,
};

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

async function rpc(fn: string, args: Record<string, unknown>) {
  return fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
               "content-type": "application/json" },
    body: JSON.stringify(args),
  });
}

async function rc(path: string): Promise<Response> {
  return fetch(`https://api.revenuecat.com/v2/projects/${RC_PROJECT}${path}`, {
    headers: { Authorization: `Bearer ${RC_SECRET}` },
  });
}

/** Follow next_page links and return every item of a v2 list endpoint. */
async function rcListAll(path: string): Promise<any[]> {
  const items: any[] = [];
  let url: string | null = path;
  while (url) {
    const res = await rc(url);
    if (!res.ok) throw new Error(`rc ${url} -> ${res.status}`);
    const body = await res.json();
    items.push(...(body.items ?? []));
    // next_page is absolute; keep only the path under the project.
    url = body.next_page
      ? String(body.next_page).replace(/^https:\/\/api\.revenuecat\.com\/v2\/projects\/[^/]+/, "")
      : null;
  }
  return items;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ ok: false, error: "no_token" }, 401);

  // Resolve the caller from their token.
  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!userRes.ok) return json({ ok: false, error: "bad_token" }, 401);
  const user = await userRes.json();
  const userId: string = user.id;

  let purchases: any[] = [];
  let products: any[] = [];
  try {
    // A customer RC has never seen 404s — that just means nothing to redeem.
    const probe = await rc(`/customers/${userId}`);
    if (probe.status === 404) return json({ ok: true, granted: 0, is_plus: false }, 200);
    if (!probe.ok) return json({ ok: false, error: "rc_lookup_failed", status: probe.status }, 200);
    [purchases, products] = await Promise.all([
      rcListAll(`/customers/${userId}/purchases?limit=100`),
      rcListAll(`/products?limit=100`),
    ]);
  } catch {
    return json({ ok: false, error: "rc_lookup_failed" }, 200);
  }

  // v2 purchases carry RC's internal product id; map back to the store id.
  const storeId: Record<string, string> = {};
  for (const p of products) storeId[p.id] = p.store_identifier;

  let granted = 0;
  let coins = 0;
  for (const t of purchases) {
    if (t.status === "refunded") continue;
    const product = storeId[t.product_id] ?? t.product_id;
    const per = PACK_COINS[product];
    if (!per) continue;
    const txnId = t.store_purchase_identifier ?? t.id;
    const r = await rpc("grant_coin_pack", {
      p_user: userId, p_coins: per, p_transaction: String(txnId), p_product: product,
    });
    if (r.ok) {
      const body = await r.json().catch(() => null);
      if (body && !body.duplicate) granted += per;
      if (body?.coins != null) coins = body.coins;
    }
  }

  // DreamCart+ entitlement (if ever added) mirrors here.
  let isPlus = false;
  try {
    const ents = await rcListAll(`/customers/${userId}/active_entitlements?limit=20`);
    isPlus = ents.length > 0;
  } catch { /* entitlements are optional; coins already granted */ }
  await rpc("set_plus", { p_user: userId, p_is_plus: isPlus });

  return json({ ok: true, granted, coins, is_plus: isPlus }, 200);
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "content-type": "application/json" },
  });
}
