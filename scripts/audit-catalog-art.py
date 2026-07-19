#!/usr/bin/env python3
"""Build resumable labeled contact sheets for DreamCart's active catalog art."""

from __future__ import annotations

import argparse
import json
import os
import urllib.request
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont, ImageOps

PAGE_SIZE = 1000
TILE_WIDTH = 220
IMAGE_HEIGHT = 275
LABEL_HEIGHT = 76
COLUMNS = 4


@dataclass(frozen=True)
class ProductRow:
    id: str
    name: str
    category: str
    image_url: str


def request_json(url: str, service_key: str, *, range_header: str | None = None) -> list[dict[str, Any]]:
    headers = {
        "apikey": service_key,
        "Authorization": f"Bearer {service_key}",
    }
    if range_header:
        headers["Range"] = range_header
        headers["Range-Unit"] = "items"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        payload = json.load(response)
    if not isinstance(payload, list):
        raise RuntimeError("Expected a JSON array from Supabase")
    return payload


def fetch_products(base_url: str, service_key: str) -> list[ProductRow]:
    rows: list[ProductRow] = []
    endpoint = (
        f"{base_url}/rest/v1/products?select=id,name,category,image_url"
        "&is_active=eq.true&order=created_at.asc"
    )
    for offset in range(0, 100_000, PAGE_SIZE):
        page = request_json(endpoint, service_key, range_header=f"{offset}-{offset + PAGE_SIZE - 1}")
        rows.extend(ProductRow(**row) for row in page)
        if len(page) < PAGE_SIZE:
            return rows
    raise RuntimeError("Catalog exceeded audit safety limit")


def load_image(row: ProductRow, cache_dir: Path) -> Image.Image:
    cache_path = cache_dir / f"{row.id}.jpg"
    if not cache_path.exists():
        request = urllib.request.Request(row.image_url, headers={"Accept": "image/*"})
        with urllib.request.urlopen(request, timeout=90) as response:
            cache_path.write_bytes(response.read())
    with Image.open(cache_path) as image:
        return ImageOps.fit(image.convert("RGB"), (TILE_WIDTH, IMAGE_HEIGHT), method=Image.Resampling.LANCZOS)


def wrap(text: str, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = f"{current} {word}".strip()
        if len(candidate) <= width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines[:2]


def build_sheet(rows: list[ProductRow], output: Path, cache_dir: Path) -> None:
    tile_height = IMAGE_HEIGHT + LABEL_HEIGHT
    sheet = Image.new("RGB", (COLUMNS * TILE_WIDTH, ((len(rows) + COLUMNS - 1) // COLUMNS) * tile_height), "white")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=14)
    small = ImageFont.load_default(size=11)

    for index, row in enumerate(rows):
        x = (index % COLUMNS) * TILE_WIDTH
        y = (index // COLUMNS) * tile_height
        try:
            image = load_image(row, cache_dir)
            sheet.paste(image, (x, y))
        except Exception as error:
            draw.rectangle((x, y, x + TILE_WIDTH, y + IMAGE_HEIGHT), fill="#ececec")
            draw.text((x + 8, y + 8), f"LOAD FAILED\n{error}", fill="black", font=small)
        draw.rectangle((x, y + IMAGE_HEIGHT, x + TILE_WIDTH, y + tile_height), fill="white", outline="#dddddd")
        draw.text((x + 7, y + IMAGE_HEIGHT + 6), f"#{index + 1}  {row.category}", fill="#666666", font=small)
        for line_index, line in enumerate(wrap(row.name, 27)):
            draw.text((x + 7, y + IMAGE_HEIGHT + 25 + line_index * 16), line, fill="black", font=font)
        draw.text((x + 7, y + tile_height - 14), row.id, fill="#888888", font=small)

    sheet.save(output, quality=92)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("build/catalog-audit"))
    parser.add_argument("--batch-size", type=int, default=80)
    args = parser.parse_args()

    base_url = os.environ.get("SHOP_SUPABASE_URL")
    service_key = os.environ.get("SHOP_SUPABASE_SECRET")
    if not base_url or not service_key:
        raise SystemExit("Source .env.shop first")

    args.output.mkdir(parents=True, exist_ok=True)
    cache_dir = args.output / "images"
    cache_dir.mkdir(exist_ok=True)
    products = fetch_products(base_url.rstrip("/"), service_key)
    (args.output / "active-products.json").write_text(
        json.dumps([asdict(row) for row in products], indent=2) + "\n"
    )

    for start in range(0, len(products), args.batch_size):
        batch = products[start:start + args.batch_size]
        output = args.output / f"sheet-{start // args.batch_size + 1:03d}.jpg"
        if output.exists():
            continue
        build_sheet(batch, output, cache_dir)
        print(f"wrote {output} ({len(batch)} products)")

    manifest = args.output / "archive-manifest.json"
    if not manifest.exists():
        manifest.write_text("[]\n")
    print(f"active products: {len(products)}")
    print(f"review sheets: {(len(products) + args.batch_size - 1) // args.batch_size}")
    print(f"archive decisions: {manifest}")


if __name__ == "__main__":
    main()
