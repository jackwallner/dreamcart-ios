#!/usr/bin/env python3
"""DreamCart launch mark: the icon's bag glyph, white, on transparent.

The static launch screen (Info.plist UILaunchScreen) can only show a flat colour
plus one image, so the mark is drawn here and the violet LaunchBackground stands
in for the candy gradient that SplashView then picks up.

Regenerates DreamCart/Assets.xcassets/LaunchMark.imageset/.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

PT = 120  # points; @1x/@2x/@3x are rendered from this
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "DreamCart/Assets.xcassets/LaunchMark.imageset"


def draw_mark(size: int) -> Image.Image:
    """The bag glyph from generate-icon.py, scaled to `size` and unfilled behind."""
    s = size * 4  # supersample, then downscale for clean edges
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img, "RGBA")

    white = (255, 255, 255, 255)
    cx, cy = s / 2, s / 2
    bw = bh = s * 0.60
    left, top = cx - bw / 2, cy - bh / 2 + s * 0.06
    right, bottom = cx + bw / 2, cy + bh / 2 + s * 0.06
    radius = s * 0.10

    d.rounded_rectangle([left, top, right, bottom], radius=radius, fill=white)

    # handle: a thick ring, lower half erased so it sits on the bag rim
    handle = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    hd = ImageDraw.Draw(handle)
    hr = s * 0.17
    hcx, hcy = cx, top + s * 0.03
    hd.arc([hcx - hr, hcy - hr, hcx + hr, hcy + hr], start=180, end=360, fill=white, width=int(s * 0.073))
    hd.rectangle([0, hcy, s, s], fill=(0, 0, 0, 0))
    img.alpha_composite(handle)

    dd = ImageDraw.Draw(img, "RGBA")

    def sparkle(px, py, r, col):
        pts = []
        for i in range(8):
            ang = math.pi / 4 * i
            rad = r if i % 2 == 0 else r * 0.38
            pts.append((px + math.cos(ang) * rad, py + math.sin(ang) * rad))
        dd.polygon(pts, fill=col)

    sparkle(cx - s * 0.10, cy + s * 0.06, s * 0.087, (245, 179, 1, 255))
    sparkle(cx + s * 0.13, cy - s * 0.01, s * 0.056, (255, 61, 139, 255))
    sparkle(cx + s * 0.06, cy + s * 0.17, s * 0.042, (124, 58, 237, 255))

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        name = f"launch_mark@{scale}x.png"
        draw_mark(PT * scale).save(OUT / name)
        images.append({"idiom": "universal", "filename": name, "scale": f"{scale}x"})

    (OUT / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    print("wrote", OUT)


if __name__ == "__main__":
    main()
