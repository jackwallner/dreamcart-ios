/**
 * Grow the catalog to TARGET products, composing each one locally with the
 * current buildImagePrompt() and caching its image in storage.
 *
 * This does the same job as the generate-products edge function, but from a
 * long-lived local process: the function renders images sequentially inside a
 * request (~40s each — see backfill-product-art.ts for why Pollinations can't
 * be parallelised), so a batch of any size trips the edge runtime's wall clock.
 *
 * Resumable by construction: it counts the catalog on startup and stops once
 * TARGET is reached, so it can be killed and restarted freely.
 *
 * Usage:
 *   set -a && . ./.env.shop && set +a
 *   deno run --allow-net --allow-env scripts/expand-catalog.ts [--target 1800]
 */
import { composeProduct, imageURL } from "../supabase/functions/_shared/catalog.ts";

const SUPABASE_URL = Deno.env.get("SHOP_SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SHOP_SUPABASE_SECRET")!;
const BUCKET = "product-art";
const PREFIX = "art-v3";
const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error("error: source .env.shop first (SHOP_SUPABASE_URL / SHOP_SUPABASE_SECRET)");
  Deno.exit(1);
}

const flagIdx = Deno.args.indexOf("--target");
const TARGET = Number(flagIdx >= 0 ? Deno.args[flagIdx + 1] : 1800);

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

async function brandIds(): Promise<Record<string, string>> {
  const rows = await (await rest("brands?select=id,slug")).json();
  const map: Record<string, string> = {};
  for (const r of rows) map[r.slug] = r.id;
  return map;
}

/** Every existing name, so a growing catalog can't silently accrue duplicates. */
async function existingNames(): Promise<Set<string>> {
  const names = new Set<string>();
  const PAGE = 1000;
  for (let from = 0;; from += PAGE) {
    const res = await rest("products?select=name", {
      headers: { Range: `${from}-${from + PAGE - 1}`, "Range-Unit": "items" },
    });
    const page = await res.json();
    if (!Array.isArray(page) || page.length === 0) break;
    for (const r of page) names.add(r.name);
    if (page.length < PAGE) break;
  }
  return names;
}

async function fetchImage(prompt: string, seed: number): Promise<Uint8Array | null> {
  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      // A hung Pollinations socket would otherwise stall the whole serial loop
      // forever — Deno's fetch has no default timeout. Abort and retry instead.
      const res = await fetch(imageURL(prompt, seed), {
        headers: { "User-Agent": UA },
        signal: AbortSignal.timeout(120_000),
      });
      if (res.ok) {
        const bytes = new Uint8Array(await res.arrayBuffer());
        if (bytes.byteLength > 5000) return bytes;
      } else {
        await res.body?.cancel();
        if (res.status !== 429 && res.status < 500) return null;
      }
    } catch { /* timeout or network blip — fall through to backoff */ }
    await new Promise((r) => setTimeout(r, 15_000 * (attempt + 1)));
  }
  return null;
}

const brands = await brandIds();
const seen = await existingNames();
console.log(`catalog ${seen.size} | target ${TARGET} | to add ${Math.max(0, TARGET - seen.size)}`);

let added = 0, failed = 0, attempts = 0;
while (seen.size < TARGET && attempts < (TARGET - seen.size) * 8 + 200) {
  attempts++;
  // Seed off the catalog size and attempt count: no Math.random(), so a restart
  // walks the same sequence and simply skips names it already inserted.
  const seed = (((seen.size * 2654435761) ^ (attempts * 40503)) >>> 0) & 0x7fffffff;
  const p = composeProduct(seed);
  if (seen.has(p.name)) continue;

  // composeProduct already builds image_prompt via buildImagePrompt().
  const bytes = await fetchImage(p.image_prompt, p.image_seed);
  if (!bytes) {
    console.log(`FAIL ${p.name} (image)`);
    failed++;
    continue;
  }

  const path = `${PREFIX}/${p.image_seed}.jpg`;
  const up = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${path}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "content-type": "image/jpeg",
      "x-upsert": "true",
    },
    body: bytes,
    signal: AbortSignal.timeout(60_000),
  });
  if (!up.ok) {
    console.log(`FAIL ${p.name} (upload ${up.status})`);
    failed++;
    continue;
  }

  const ins = await rest("products", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({
      brand_id: brands[p.brand_slug],
      name: p.name,
      category: p.category,
      slot: p.slot,
      style_tags: p.style_tags,
      color_name: p.color_name,
      price: p.price,
      rarity: p.rarity,
      description: p.description,
      image_url: `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${path}`,
    }),
  });
  if (!ins.ok) {
    console.log(`FAIL ${p.name} (insert ${ins.status})`);
    failed++;
    continue;
  }

  seen.add(p.name);
  added++;
  console.log(`[${seen.size}/${TARGET}] ok ${p.name}`);
  await new Promise((r) => setTimeout(r, 2000));
}

console.log(`done — added ${added}, failed ${failed}, catalog now ${seen.size}`);
