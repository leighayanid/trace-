"""Generates the TRACE launcher icons.

The mark is the app itself reduced to its smallest honest form: four rules of
unequal length on navy — one per category, a day's worth of entries seen from
far enough away that only the record remains. No letterform, no glyph, nothing
that needs explaining at 48px.

Run from anywhere; it locates the repository from its own path:

    python tool/make_icons.py

Requires Pillow (`pip install pillow`).
"""
import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

NAVY = (11, 31, 58, 255)        # #0B1F3A
PAPER = (248, 248, 246, 255)    # #F8F8F6

# Unequal lengths, as a real day is unequal. Ordered BUILD, READ, EXPLORE, LIFE.
RULES = [1.00, 0.62, 0.78, 0.44]


def draw_rules(size, inset_ratio, alpha_bg=None):
    """The mark on a canvas of `size`, rules occupying `inset_ratio` of it."""
    img = Image.new("RGBA", (size, size), alpha_bg or (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    span = size * inset_ratio          # width of the longest rule

    # Ragged right, so geometric centring leaves the mark leaning left. Split
    # the difference between the box centre and the centre of the average rule:
    # full optical centring overshoots and crowds the right edge.
    mean = sum(RULES) / len(RULES)
    left = (size - span) / 2 + span * (1 - mean) / 4

    weight = max(1.0, size * inset_ratio * 0.105)   # rule thickness
    gap = weight * 1.55                             # space between rules
    block = len(RULES) * weight + (len(RULES) - 1) * gap
    top = (size - block) / 2

    for i, length in enumerate(RULES):
        y = top + i * (weight + gap)
        d.rounded_rectangle(
            [left, y, left + span * length, y + weight],
            radius=weight / 2,
            fill=PAPER,
        )
    return img


def full_icon(size, radius_ratio=None):
    """Navy field plus mark, optionally with rounded corners."""
    icon = Image.new("RGBA", (size, size), NAVY)
    icon.alpha_composite(draw_rules(size, 0.58))
    if radius_ratio:
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, size - 1, size - 1], radius=size * radius_ratio, fill=255
        )
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.paste(icon, (0, 0), mask)
        return out
    return icon


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print("  ", os.path.relpath(path, ROOT))


# ── Source of record ──────────────────────────────────────────────────────────
print("source:")
save(full_icon(1024), os.path.join(ROOT, "assets", "icon", "trace-icon.png"))

# ── Android legacy launcher icons ─────────────────────────────────────────────
# Pre-26 devices apply no mask, so the rounding has to be baked in.
print("android legacy:")
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for density, px in LEGACY.items():
    save(
        full_icon(px * 4, radius_ratio=0.22).resize((px, px), Image.LANCZOS),
        os.path.join(ROOT, "android", "app", "src", "main", "res",
                     f"mipmap-{density}", "ic_launcher.png"),
    )

# ── Android adaptive foreground ───────────────────────────────────────────────
# 108dp canvas, of which only the centre 66dp is guaranteed visible under any
# mask. Scaling the mark by 66/108 keeps it inside that safe zone whatever
# shape the launcher crops to.
print("android adaptive foreground:")
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324,
            "xxxhdpi": 432}
SAFE = 0.58 * (66 / 108)
for density, px in ADAPTIVE.items():
    fg = draw_rules(px * 2, SAFE).resize((px, px), Image.LANCZOS)
    save(fg, os.path.join(ROOT, "android", "app", "src", "main", "res",
                          f"mipmap-{density}", "ic_launcher_foreground.png"))

# ── iOS ───────────────────────────────────────────────────────────────────────
# iOS masks the corners itself and rejects transparency, so these stay square
# and fully opaque.
print("ios:")
IOS_DIR = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets",
                       "AppIcon.appiconset")
with open(os.path.join(IOS_DIR, "Contents.json"), encoding="utf-8") as f:
    contents = json.load(f)

for image in contents["images"]:
    side = float(image["size"].split("x")[0])
    scale = int(image["scale"].rstrip("x"))
    px = int(round(side * scale))
    icon = full_icon(max(px * 4, 256)).resize((px, px), Image.LANCZOS)
    save(icon.convert("RGB"), os.path.join(IOS_DIR, image["filename"]))

print("done")
