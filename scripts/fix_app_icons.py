#!/usr/bin/env python3
from pathlib import Path
from PIL import Image

CONTENT_SCALE = 1.0
SUPERELLIPSE_N = 5.0

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "Type Bot" / "Assets.xcassets" / "AppIcon.appiconset"
BASE_PATH = Path("/Users/ryderthomas/Downloads/icon.png")

if not BASE_PATH.exists():
    raise SystemExit(f"Missing base icon: {BASE_PATH}")

base = Image.open(BASE_PATH).convert("RGBA")


def superellipse_mask(size: int, n: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    pixels = mask.load()
    a = size / 2.0
    for y in range(size):
        dy = abs((y + 0.5 - a) / a) ** n
        for x in range(size):
            dx = abs((x + 0.5 - a) / a) ** n
            if dx + dy <= 1.0:
                pixels[x, y] = 255
    return mask

for path in sorted(ICON_DIR.glob("*.png")):
    size = Image.open(path).size[0]
    resized = base.resize((size, size), Image.LANCZOS)
    mask = superellipse_mask(size, SUPERELLIPSE_N)
    resized.putalpha(mask)
    resized.save(path)

print("Updated icons in", ICON_DIR)
