#!/usr/bin/env python3
"""Regenerates PolarBear's icon and logo assets from Design/polarbear-original.png.

    python3 Design/make_assets.py

Outputs (inside PolarBear/PolarBear/Assets.xcassets):
  AppIcon.appiconset      macOS app icon, all sizes
  PolarBearArtwork.imageset  the untouched original artwork (byte-for-byte copy)
  BearLogo.imageset       square face crop for small in-app logos
"""
import json
import math
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Design", "polarbear-original.png")
CATALOG = os.path.join(ROOT, "PolarBear", "Assets.xcassets")

source = Image.open(SOURCE).convert("RGB")
WIDTH, HEIGHT = source.size


def square(center_x, center_y, side):
    x0 = int(round(center_x - side / 2))
    y0 = int(round(center_y - side / 2))
    x0 = max(0, min(x0, WIDTH - side))
    y0 = max(0, min(y0, HEIGHT - side))
    return source.crop((x0, y0, x0 + side, y0 + side))


def resize(image, size, sharpen=True):
    out = image.resize((size, size), Image.LANCZOS)
    if sharpen:
        out = out.filter(ImageFilter.UnsharpMask(radius=1.0, percent=30, threshold=2))
    return out


def squircle_mask(size, n=6.0, supersample=4):
    big = size * supersample
    half = big / 2
    points = []
    for i in range(4000):
        t = 2 * math.pi * i / 4000
        c, s = math.cos(t), math.sin(t)
        points.append((half + half * math.copysign(abs(c) ** (2 / n), c),
                       half + half * math.copysign(abs(s) ** (2 / n), s)))
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask.resize((size, size), Image.LANCZOS)


def make_icon(art, canvas=1024, art_size=824):
    margin = (canvas - art_size) // 2
    mask = squircle_mask(art_size)
    tile = resize(art, art_size).convert("RGBA")
    tile.putalpha(mask)

    shadow_mask = Image.new("L", (canvas, canvas), 0)
    shadow_mask.paste(mask, (margin, margin + 10))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.30))
    shadow = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    shadow.putalpha(shadow_mask)

    icon = Image.alpha_composite(Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0)), shadow)
    icon.alpha_composite(tile, (margin, margin))
    return icon


def write_json(path, payload):
    with open(path, "w") as handle:
        json.dump(payload, handle, indent=2)


# --- App icon: the full height of the original, centred on the bear ---------------
icon_master = make_icon(square(845, HEIGHT / 2, HEIGHT))
icon_dir = os.path.join(CATALOG, "AppIcon.appiconset")
os.makedirs(icon_dir, exist_ok=True)
for name in os.listdir(icon_dir):
    if name.endswith(".png"):
        os.remove(os.path.join(icon_dir, name))

entries = []
for points in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        pixels = points * scale
        filename = f"icon_{points}x{points}" + ("@2x" if scale == 2 else "") + ".png"
        icon_master.resize((pixels, pixels), Image.LANCZOS).save(os.path.join(icon_dir, filename), optimize=True)
        entries.append({"filename": filename, "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"})
write_json(os.path.join(icon_dir, "Contents.json"), {"images": entries, "info": {"author": "xcode", "version": 1}})

# --- Untouched original artwork ----------------------------------------------------
art_dir = os.path.join(CATALOG, "PolarBearArtwork.imageset")
os.makedirs(art_dir, exist_ok=True)
shutil.copyfile(SOURCE, os.path.join(art_dir, "polarbear-original.png"))
write_json(os.path.join(art_dir, "Contents.json"), {
    "images": [{"filename": "polarbear-original.png", "idiom": "universal", "scale": "2x"}],
    "info": {"author": "xcode", "version": 1},
})

# --- Small in-app logo: face crop --------------------------------------------------
logo_dir = os.path.join(CATALOG, "BearLogo.imageset")
os.makedirs(logo_dir, exist_ok=True)
face = square(856, 388, 440)
logo_entries = []
for scale, pixels in ((1, 192), (2, 384)):
    filename = f"bear@{scale}x.png"
    resize(face, pixels).save(os.path.join(logo_dir, filename), optimize=True)
    logo_entries.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
write_json(os.path.join(logo_dir, "Contents.json"), {"images": logo_entries, "info": {"author": "xcode", "version": 1}})

# Preview next to the script (git-ignored scratch)
preview = Image.new("RGBA", (1100, 1024), (30, 30, 30, 255))
preview.alpha_composite(icon_master, (0, 0))
for px, y in ((64, 40), (32, 130), (16, 190)):
    preview.alpha_composite(icon_master.resize((px, px), Image.LANCZOS), (1030, y))
preview.save("/tmp/polarbear_icon_preview.png")
print("assets regenerated from", SOURCE)
