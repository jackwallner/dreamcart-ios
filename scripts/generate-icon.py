#!/usr/bin/env python3
"""DreamCart app icon: a dopamine gradient with a clean shopping-bag glyph.

Regenerates DreamCart/Assets.xcassets/AppIcon.appiconset/icon_1024.png.
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

S = 1024
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "DreamCart/Assets.xcassets/AppIcon.appiconset/icon_1024.png"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient(size, c0, c1):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = lerp(c0, c1, t)
    return img


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)

    # Candy dopamine gradient: violet -> hot pink -> coral.
    base = diagonal_gradient(S, (124, 58, 237), (255, 61, 139))
    # Warm coral glow in the lower corner.
    glow = Image.new("RGB", (S, S), (255, 138, 101))
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([S * 0.45, S * 0.55, S * 1.15, S * 1.25], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(160))
    base = Image.composite(glow, base, mask)

    d = ImageDraw.Draw(base, "RGBA")

    # --- shopping bag glyph, centered ---
    cx, cy = S / 2, S / 2 + 40
    bw, bh = 430, 430
    left, top = cx - bw / 2, cy - bh / 2 + 30
    right, bottom = cx + bw / 2, cy + bh / 2 + 30
    radius = 70
    white = (255, 255, 255, 255)

    # bag body
    d.rounded_rectangle([left, top, right, bottom], radius=radius, fill=white)

    # handle (two arcs) drawn as a thick ring clipped above the bag
    handle_layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(handle_layer)
    hcx, hcy = cx, top + 20
    hr = 120
    hd.arc([hcx - hr, hcy - hr, hcx + hr, hcy + hr], start=180, end=360, fill=white, width=52)
    # erase the lower half so the handle sits on the bag rim
    hd.rectangle([0, hcy, S, S], fill=(0, 0, 0, 0))
    base.alpha_composite(handle_layer) if base.mode == "RGBA" else base.paste(
        Image.alpha_composite(base.convert("RGBA"), handle_layer))

    dd = ImageDraw.Draw(base, "RGBA")

    # sparkle accents (dopamine) on the bag
    def sparkle(px, py, r, col):
        pts = []
        for i in range(8):
            ang = math.pi / 4 * i
            rad = r if i % 2 == 0 else r * 0.38
            pts.append((px + math.cos(ang) * rad, py + math.sin(ang) * rad))
        dd.polygon(pts, fill=col)

    gold = (245, 179, 1, 255)
    sparkle(cx - 70, cy + 40, 62, gold)
    sparkle(cx + 90, cy - 10, 40, (255, 61, 139, 255))
    sparkle(cx + 40, cy + 120, 30, (124, 58, 237, 255))

    base.convert("RGB").save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
