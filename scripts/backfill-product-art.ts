/**
 * Re-render product art for rows that already exist, using the current
 * buildImagePrompt() (flat lay). The original composition seed isn't stored, so
 * the prompt is rebuilt from the row's own fields:
 *
 *   garment  <- longest known noun that the product name ends with
 *   material <- parsed from the description's "Cut in X" opener, else a stable
 *               deterministic pick from that garment's material list
 *   brand    <- brand_id -> BRANDS entry (aesthetic + bgWords)
 *
 * Images are written to a NEW storage path (art-v2/<image_seed>.jpg) rather than
 * overwritten in place, so the public CDN can't keep serving the stale object.
 * Rows already pointing at art-v2/ are skipped, which makes this resumable.
 *
 * Pollinations' keyless tier allows exactly one in-flight request — a second
 * concurrent request 429s immediately (measured), so this is strictly serial
 * with backoff. Budget ~40s per image, i.e. ~7h for a 600-product catalog.
 *
 * Usage:
 *   set -a && . ./.env.shop && set +a
 *   deno run --allow-net --allow-env scripts/backfill-product-art.ts [--limit N] [--category top,dress]
 */
import {
  BRANDS,
  buildImagePrompt,
  type Category,
  fnv1a,
  GARMENTS,
  imageURL,
  mulberry32,
} from "../supabase/functions/_shared/catalog.ts";

const SUPABASE_URL = Deno.env.get("SHOP_SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SHOP_SUPABASE_SECRET")!;
const BUCKET = "product-art";
/** Bump this when buildImagePrompt() changes: it re-opens every row for a redo. */
const PREFIX = "art-v3";
const UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36";

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error("error: source .env.shop first (SHOP_SUPABASE_URL / SHOP_SUPABASE_SECRET)");
  Deno.exit(1);
}

const flag = (name: string): string | undefined => {
  const i = Deno.args.indexOf(name);
  return i >= 0 ? Deno.args[i + 1] : undefined;
};
const limit = Number(flag("--limit") ?? 0);
const categories = flag("--category")?.split(",").map((c) => c.trim());

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

interface Row {
  id: string;
  name: string;
  category: Category;
  color_name: string;
  description: string;
  image_url: string;
  brands: { slug: string } | null;
}

/** name is `${series} ${color} ${noun}` — recover the garment by noun suffix. */
const NOUNS = Object.entries(GARMENTS).flatMap(([cat, gs]) =>
  gs.map((g) => ({ cat: cat as Category, g }))
).sort((a, b) => b.g.noun.length - a.g.noun.length);

function garmentFor(row: Row) {
  const hit = NOUNS.find(({ cat, g }) =>
    cat === row.category && row.name.toLowerCase().endsWith(g.noun.toLowerCase())
  ) ?? NOUNS.find(({ g }) => row.name.toLowerCase().endsWith(g.noun.toLowerCase()));
  return hit?.g;
}

function materialFor(row: Row, materials: string[]): string {
  const m = row.description?.match(/Cut in ([a-z ]+?) for that/i);
  if (m && materials.includes(m[1].trim())) return m[1].trim();
  const rng = mulberry32(fnv1a(row.name));
  return materials[Math.floor(rng() * materials.length)];
}

async function fetchImage(prompt: string, seed: number): Promise<Uint8Array | null> {
  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      const res = await fetch(imageURL(prompt, seed), { headers: { "User-Agent": UA } });
      if (res.ok) {
        const bytes = new Uint8Array(await res.arrayBuffer());
        if (bytes.byteLength > 5000) return bytes;
      } else {
        await res.body?.cancel();
        if (res.status !== 429 && res.status < 500) return null;
      }
    } catch { /* network blip — fall through to backoff */ }
    await new Promise((r) => setTimeout(r, 15_000 * (attempt + 1)));
  }
  return null;
}

let query = `products?select=id,name,category,color_name,description,image_url,brands(slug)` +
  `&order=created_at.asc`;
if (categories) query += `&category=in.(${categories.join(",")})`;

const all: Row[] = await (await rest(query)).json();
const todo = all.filter((r) => !r.image_url?.includes(`/${PREFIX}/`));
const work = limit > 0 ? todo.slice(0, limit) : todo;

console.log(
  `catalog ${all.length} | already backfilled ${all.length - todo.length} | this run ${work.length}`,
);

let ok = 0, failed = 0;
for (const [i, row] of work.entries()) {
  const brand = BRANDS.find((b) => b.slug === row.brands?.slug);
  const g = garmentFor(row);
  if (!brand || !g) {
    console.log(`[${i + 1}/${work.length}] SKIP ${row.name} (brand/garment unresolved)`);
    failed++;
    continue;
  }

  const prompt = buildImagePrompt({
    color: row.color_name,
    material: materialFor(row, g.materials),
    visual: g.visual,
    aesthetic: brand.aesthetic,
    bgWords: brand.bgWords,
  });
  const seed = fnv1a(row.name + brand.slug);

  const bytes = await fetchImage(prompt, seed);
  if (!bytes) {
    console.log(`[${i + 1}/${work.length}] FAIL ${row.name} (image)`);
    failed++;
    continue;
  }

  const path = `${PREFIX}/${seed}.jpg`;
  const up = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${path}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "content-type": "image/jpeg",
      "x-upsert": "true",
    },
    body: bytes,
  });
  if (!up.ok) {
    console.log(`[${i + 1}/${work.length}] FAIL ${row.name} (upload ${up.status})`);
    failed++;
    continue;
  }

  const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${path}`;
  const patch = await rest(`products?id=eq.${row.id}`, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify({ image_url: publicUrl }),
  });
  if (!patch.ok) {
    console.log(`[${i + 1}/${work.length}] FAIL ${row.name} (patch ${patch.status})`);
    failed++;
    continue;
  }

  ok++;
  console.log(`[${i + 1}/${work.length}] ok ${row.name}`);
  await new Promise((r) => setTimeout(r, 2000));
}

console.log(`done — updated ${ok}, failed ${failed}`);
