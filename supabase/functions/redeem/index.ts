// redeem: authoritative, dashboard-free coin crediting. The app calls this
// (with the user's Supabase JWT) after any purchase and on launch. We resolve
// the user from their token, ask RevenueCat for that subscriber's one-time
// purchases, and grant coins for any coin-pack transaction not yet granted
// (idempotent on transaction id). Works in sandbox and production without a
// configured webhook, since RC's subscriber record carries the purchase once
// the SDK syncs it.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RC_SECRET = Deno.env.get("RC_SECRET_KEY") ?? "";

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

  // Ask RevenueCat what this user has bought.
  const subRes = await fetch(`https://api.revenuecat.com/v1/subscribers/${userId}`, {
    headers: { Authorization: `Bearer ${RC_SECRET}` },
  });
  if (!subRes.ok) return json({ ok: false, error: "rc_lookup_failed", status: subRes.status }, 200);
  const sub = await subRes.json();

  const nonSubs: Record<string, Array<{ id?: string; store_transaction_id?: string; purchase_date?: string }>> =
    sub?.subscriber?.non_subscriptions ?? {};

  let granted = 0;
  let coins = 0;
  for (const [product, txns] of Object.entries(nonSubs)) {
    const per = PACK_COINS[product];
    if (!per) continue;
    for (const t of txns) {
      const txnId = t.store_transaction_id ?? t.id ?? `${product}:${t.purchase_date}`;
      const r = await rpc("grant_coin_pack", {
        p_user: userId, p_coins: per, p_transaction: txnId, p_product: product,
      });
      if (r.ok) {
        const body = await r.json().catch(() => null);
        if (body && !body.duplicate) granted += per;
        if (body?.coins != null) coins = body.coins;
      }
    }
  }

  // DreamCart+ entitlement (if ever added) mirrors here.
  const ent = sub?.subscriber?.entitlements ?? {};
  const isPlus = Object.values(ent).some((e: any) =>
    !e?.expires_date || new Date(e.expires_date).getTime() > Date.now());
  await rpc("set_plus", { p_user: userId, p_is_plus: isPlus });

  return json({ ok: true, granted, coins, is_plus: isPlus }, 200);
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "content-type": "application/json" },
  });
}
