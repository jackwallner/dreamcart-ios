// rc-webhook: RevenueCat server notifications land here. This is the ONLY path
// that credits coin packs, so the balance can't be forged from the client.
// RevenueCat authenticates with a shared bearer (RC_WEBHOOK_AUTH); we map the
// product id to a coin amount and call grant_coin_pack (idempotent on the store
// transaction id). Subscription events flip DreamCart+ via set_plus.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_AUTH = Deno.env.get("RC_WEBHOOK_AUTH") ?? "";

// Coin packs (consumables). Keep in sync with ASC product ids + the app.
const PACK_COINS: Record<string, number> = {
  "com.jackwallner.shop.coins.pocket": 1000,
  "com.jackwallner.shop.coins.bag": 3200,
  "com.jackwallner.shop.coins.haul": 8500,
  "com.jackwallner.shop.coins.spree": 20000,
  "com.jackwallner.shop.coins.vault": 60000,
};

const PLUS_PRODUCTS = new Set([
  "com.jackwallner.shop.plus.monthly",
  "com.jackwallner.shop.plus.yearly",
]);

async function rpc(fn: string, args: Record<string, unknown>) {
  return fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
               "content-type": "application/json" },
    body: JSON.stringify(args),
  });
}

Deno.serve(async (req) => {
  if (WEBHOOK_AUTH && req.headers.get("authorization") !== WEBHOOK_AUTH) {
    return new Response("unauthorized", { status: 401 });
  }
  const payload = await req.json().catch(() => null);
  const ev = payload?.event;
  if (!ev) return new Response("no event", { status: 200 });

  const userId: string = ev.app_user_id ?? "";
  const product: string = ev.product_id ?? "";
  const txn: string = ev.transaction_id ?? ev.id ?? crypto.randomUUID();
  const type: string = ev.type ?? "";

  // Coin packs are one-time (NON_RENEWING_PURCHASE). Credit once per txn.
  if (type === "NON_RENEWING_PURCHASE" && PACK_COINS[product]) {
    const r = await rpc("grant_coin_pack", {
      p_user: userId, p_coins: PACK_COINS[product], p_transaction: txn, p_product: product,
    });
    return new Response(await r.text(), { status: r.ok ? 200 : 500 });
  }

  // DreamCart+ subscription lifecycle.
  if (PLUS_PRODUCTS.has(product)) {
    const active = ["INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"].includes(type);
    const inactive = ["CANCELLATION", "EXPIRATION"].includes(type);
    if (active || inactive) {
      await rpc("set_plus", { p_user: userId, p_is_plus: active });
    }
    return new Response("ok", { status: 200 });
  }

  return new Response("ignored", { status: 200 });
});
