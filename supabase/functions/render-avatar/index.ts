// render-avatar: the dressing-room shot, rendered server-side and cached in
// the public `avatar-art` bucket. The prompt/seed mirror Shared/Utilities/
// Avatar.swift exactly, so a given look + item set maps to one stable file.
// First render of a fit costs one generation; every later view (any user,
// any device) is a plain storage fetch.
//
// POST { look: string, product_ids: string[] } with the user's JWT.
// -> { ok: true, url: string, cached: boolean }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "avatar-art";

const LOOK_WORDS: Record<string, string> = {
  aria: "a young woman with long straight dark hair",
  maya: "a young woman with voluminous curly brown hair",
  zoe: "a young woman with a blonde chin-length bob",
  kai: "a young man with short dark hair",
  leo: "a young man with loose curly hair",
  rio: "an androgynous person with a platinum buzz cut",
};

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
};

/** FNV-1a masked to 31 bits — must match Avatar.swift's seed function. */
function fnv1a(text: string): number {
  let h = 0x811c9dc5;
  for (const b of new TextEncoder().encode(text)) {
    h ^= b; h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h & 0x7fffffff;
}

/** "Solstice Blush Slip Dress" -> "blush slip dress", same as Avatar.swift. */
function garmentPhrase(p: { name: string; color_name: string }): string {
  let noun = p.name;
  const firstSpace = noun.indexOf(" ");
  if (firstSpace >= 0) noun = noun.slice(firstSpace + 1);
  noun = noun.replace(p.color_name, "").trim();
  if (noun.length === 0) noun = p.name;
  return `${p.color_name.toLowerCase()} ${noun.toLowerCase()}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ ok: false, error: "no_token" }, 401);
  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${jwt}` },
  });
  if (!userRes.ok) return json({ ok: false, error: "bad_token" }, 401);

  const body = await req.json().catch(() => ({}));
  const look = String(body.look ?? "");
  const ids: string[] = Array.isArray(body.product_ids) ? body.product_ids.map(String) : [];
  const lookWords = LOOK_WORDS[look];
  if (!lookWords || ids.length === 0 || ids.length > 12) {
    return json({ ok: false, error: "bad_request" }, 400);
  }

  // Load the pieces; ordering by slot matches the client's seed computation.
  const rowsRes = await fetch(
    `${SUPABASE_URL}/rest/v1/products?select=id,name,color_name,slot&id=in.(${ids.join(",")})`,
    { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } },
  );
  if (!rowsRes.ok) return json({ ok: false, error: "lookup_failed" }, 500);
  const rows: { id: string; name: string; color_name: string; slot: string }[] =
    await rowsRes.json();
  if (rows.length === 0) return json({ ok: false, error: "no_products" }, 400);
  rows.sort((a, b) => a.slot < b.slot ? -1 : a.slot > b.slot ? 1 : 0);

  const outfit = rows.map(garmentPhrase).join(", ");
  const prompt =
    `full body fashion editorial photograph of ${lookWords}, ` +
    `wearing ${outfit}, standing relaxed pose, full body visible head to toe, ` +
    `centered on a seamless warm ivory studio backdrop, soft even diffused ` +
    `studio lighting, sharp focus, high detail, clean catalog fashion ` +
    `photography, no text, no words, no logo, no watermark`;
  const seed = fnv1a(look + rows.map((r) => r.id).join(""));
  const path = `${seed}.jpg`;
  const publicUrl = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${path}`;

  // Cached fit — done.
  const head = await fetch(publicUrl, { method: "HEAD" });
  if (head.ok) return json({ ok: true, url: publicUrl, cached: true });

  // Render once with patient retries — pollinations rate-limits per IP hard.
  const genURL = `https://image.pollinations.ai/prompt/` +
    encodeURIComponent(prompt).replace(/%2C/g, ",") +
    `?width=800&height=1000&nologo=true&seed=${seed}&model=flux`;
  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
  let bytes: Uint8Array | null = null;
  for (let attempt = 1; attempt <= 8 && !bytes; attempt++) {
    let rateLimited = false;
    try {
      const res = await fetch(genURL, {
        signal: AbortSignal.timeout(120_000),
        headers: { Accept: "image/*" },
      });
      if (res.ok) {
        const b = new Uint8Array(await res.arrayBuffer());
        if (b.length > 5_000 && b[0] === 0xff) { bytes = b; break; }
      } else {
        await res.body?.cancel();
        rateLimited = res.status === 429;
      }
    } catch { /* timeout or network — retry */ }
    const base = rateLimited ? 15_000 : 8_000;
    await sleep(Math.min(base * attempt, 90_000) + Math.random() * 5_000);
  }
  if (!bytes) return json({ ok: false, error: "generation_busy" }, 503);

  const up = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${path}`, {
    method: "POST",
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`,
               "content-type": "image/jpeg", "x-upsert": "true" },
    body: bytes,
  });
  if (!up.ok) return json({ ok: false, error: "store_failed" }, 500);
  return json({ ok: true, url: publicUrl, cached: false });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...cors, "content-type": "application/json" },
  });
}
