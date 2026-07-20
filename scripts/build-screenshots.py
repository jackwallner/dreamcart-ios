#!/usr/bin/env python3
"""Compose DreamCart App Store 6.5" screenshots from raw simulator captures.

Usage: python3 scripts/build-screenshots.py <raw-shots-dir>
Output: fastlane/screenshots/en-US/ at 1284x2778
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "fastlane" / "screenshots" / "en-US"
W, H = 1284, 2778

BG = (251, 248, 244)
INK = (23, 20, 26)
VIOLET = (124, 58, 237)
PINK = (255, 61, 139)
GRAY = (107, 101, 112)

PLAN = [
    ("shop.png", "appstore_01_shop.png", "Shop without", "the guilt.", "Original fashion. Zero dollars.\nFill your cart with everything you'd never actually buy."),
    ("today.png", "appstore_02_coins.png", "Free coins", "every day.", "Claim your drop, spin the wheel,\nkeep your streak alive."),
    ("cart.png", "appstore_03_checkout.png", "Checkout hits", "different.", "Add to cart, unbox, repeat.\nAll virtual — no buyer's remorse."),
    ("closet.png", "appstore_04_closet.png", "Build your", "dream closet.", "Own the pieces, mix brands,\nstyle full outfits your way."),
    ("spin.png", "appstore_05_spin.png", "Spin to win", "more coins.", "Daily dopamine, on the house.\nOptional packs if you want more."),
]

FONT_PATHS = [
    "/System/Library/Fonts/SFNSRounded.ttf",
    "/System/Library/Fonts/SFNS.ttf",
]


def font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    for path in FONT_PATHS:
        try:
            f = ImageFont.truetype(path, size)
            try:
                f.set_variation_by_name(weight)
            except OSError:
                pass
            return f
        except OSError:
            continue
    return ImageFont.load_default()


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *img.size], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(raw: Path, line1: str, line2: str, subhead: str) -> Image.Image:
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)
    margin = 84
    y = 150
    for line, color in [(line1, INK), (line2, VIOLET)]:
        size = 138
        f = font(size, "Heavy")
        while draw.textbbox((0, 0), line, font=f)[2] > W - 2 * margin and size > 88:
            size -= 6
            f = font(size, "Heavy")
        draw.text((margin, y), line, font=f, fill=color)
        y += int(size * 1.18)
    y += 36
    for line in subhead.split("\n"):
        draw.text((margin, y), line, font=font(54, "Regular"), fill=GRAY)
        y += 72

    shot = Image.open(raw)
    target_w = int(W * 0.72)
    target_h = int(shot.size[1] * target_w / shot.size[0])
    shot = rounded(shot.resize((target_w, target_h), Image.LANCZOS), radius=96)
    pad = 24
    bezel = Image.new("RGBA", (target_w + 2 * pad, target_h + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle([0, 0, target_w + 2 * pad, target_h + 2 * pad], radius=120, fill=(16, 14, 20, 255))
    bezel.paste(shot, (pad, pad), shot)
    x = (W - bezel.size[0]) // 2
    y = H - bezel.size[1] + 120
    canvas.paste(bezel, (x, y), bezel)
    return canvas


def main():
    raw_dir = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    for raw_name, out_name, l1, l2, sub in PLAN:
        raw = raw_dir / raw_name
        if not raw.exists():
            raise SystemExit(f"missing raw capture: {raw}")
        out = OUT / out_name
        compose(raw, l1, l2, sub).save(out, optimize=True)
        print(f"wrote {out.name}")
    print("done")


if __name__ == "__main__":
    main()
