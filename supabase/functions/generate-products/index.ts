// generate-products: the daily drop. Upserts the fixed brand roster, then
// composes N fresh products and inserts them with a consistent, deterministic
// product-shot image URL (pollinations on-demand, keyless — a different
// endpoint from Sideline, so it never touches that app's image quota).
//
// Auth: x-cron-secret must match CRON_SECRET. Invoked by pg_cron daily and by
// the seed script for the initial catalog.
//
// Body (all optional): { count?: number, store?: boolean }
//   store=true downloads each image and caches it in the `product-art` bucket
//   (stable, no runtime generation); default false uses the on-demand URL.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { BRANDS, composeProduct, imageURL } from "../_shared/catalog.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const BUCKET = "product-art";

const rest = (path: string, init: RequestInit = {}) =>
  fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });

async function ensureBrands(): Promise<Record<string, string>> {
  await rest("brands?on_conflict=slug", {
    method: "POST",
    headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify(BRANDS.map((b) => ({
      slug: b.slug, name: b.name, tagline: b.tagline, aesthetic: b.aesthetic,
      accent_hex: b.accent_hex, bg_hex: b.bg_hex, sort: b.sort,
    }))),
  });
  const rows = await (await rest("brands?select=id,slug")).json();
  const map: Record<string, string> = {};
  for (const r of rows) map[r.slug] = r.id;
  return map;
}

// Download the on-demand image once and cache it in storage; return the public
// URL. Falls back to the on-demand URL if generation/upload misbehaves.
async function storeImage(name: string, prompt: string, seed: number): Promise<string> {
  const onDemand = imageURL(prompt, seed);
  const path = `${seed}.jpg`;
  const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${path}`;
  try {
    const head = await fetch(publicUrl, { method: "HEAD" });
    if (head.ok) return publicUrl;
    const img = await fetch(onDemand);
    if (!img.ok) { await img.body?.cancel(); return onDemand; }
    const bytes = new Uint8Array(await img.arrayBuffer());
    const up = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${path}`, {
      method: "POST",
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
                 "content-type": "image/jpeg", "x-upsert": "true" },
      body: bytes,
    });
    return up.ok ? publicUrl : onDemand;
  } catch {
    return onDemand;
  }
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== CRON_SECRET || !CRON_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  const body = await req.json().catch(() => ({}));
  const count = Math.min(Math.max(Number(body.count ?? 12), 1), 200);
  const store = Boolean(body.store ?? false);
  const trace = crypto.randomUUID();

  const brandMap = await ensureBrands();

  // Avoid duplicate product names in one run and against the whole catalog.
  // Paginated: a recent-N window silently lets dupes through once the catalog
  // outgrows it.
  const seen = new Set<string>();
  const PAGE = 1000;
  for (let from = 0; ; from += PAGE) {
    const res = await rest("products?select=name", {
      headers: { Range: `${from}-${from + PAGE - 1}`, "Range-Unit": "items" },
    });
    const page = await res.json();
    if (!Array.isArray(page) || page.length === 0) break;
    for (const r of page) seen.add(r.name);
    if (page.length < PAGE) break;
  }

  const rows: Record<string, unknown>[] = [];
  let attempts = 0;
  while (rows.length < count && attempts < count * 6) {
    attempts++;
    const seed = (Math.floor(Math.random() * 2 ** 31) ^ (attempts * 2654435761)) >>> 0;
    const p = composeProduct(seed & 0x7fffffff);
    if (seen.has(p.name)) continue;
    seen.add(p.name);
    const image_url = store
      ? await storeImage(p.name, p.image_prompt, p.image_seed)
      : imageURL(p.image_prompt, p.image_seed);
    rows.push({
      brand_id: brandMap[p.brand_slug],
      name: p.name, category: p.category, slot: p.slot,
      style_tags: p.style_tags, color_name: p.color_name, price: p.price,
      rarity: p.rarity, description: p.description, image_url,
    });
  }

  const ins = await rest("products", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify(rows),
  });
  if (!ins.ok) {
    return new Response(JSON.stringify({ ok: false, error: await ins.text() }), {
      status: 500, headers: { "content-type": "application/json" },
    });
  }
  return new Response(JSON.stringify({ ok: true, trace, inserted: rows.length, stored: store }), {
    headers: { "content-type": "application/json" },
  });
});
