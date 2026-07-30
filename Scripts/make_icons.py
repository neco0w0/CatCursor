#!/usr/bin/env python3
"""Generate the app icon and the menu bar icon from one artwork frame.

The source frame is only 46x55 pixels, so it is upscaled and then run through a
steep contrast curve on both alpha and luminance. Plain interpolation at this
magnification leaves the outline visibly soft; the curve pulls the edges back to
something close to the flat, solid look the artwork is drawn in.

Usage:
    python3 Scripts/make_icons.py [--source /path/to/frame.png]
"""

import argparse
import math
import os
import shutil
import subprocess
import sys

from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(PROJECT_ROOT, "Resources")
DEFAULT_SOURCE = os.path.join(
    os.path.dirname(PROJECT_ROOT), "普通的鼠标指针V1.5",
    "工程文件", "普通（第二版）", "【鼠标计划】普通（第二版）.0058.png")

# Fraction of the icon canvas the glyph occupies. Icons that touch the edges
# look oversized next to everything else in the Dock.
GLYPH_FRACTION = 0.80

ICNS_SIZES = [16, 32, 64, 128, 256, 512]
MENU_BAR_HEIGHT_POINTS = 18


def steep(channel, k, mid=128):
    """Sigmoid contrast curve: pushes soft interpolated pixels back to the ends."""
    lut = [max(0, min(255, int(255 / (1 + math.exp(-k * (i - mid) / 255)))))
           for i in range(256)]
    return channel.point(lut)


def load_glyph(path):
    image = Image.open(path).convert("RGBA")
    box = image.getbbox()
    if box is None:
        raise SystemExit(f"{path} is empty")
    return image.crop(box)


def upscale(glyph, target_height):
    """Upscale and re-sharpen. Returns RGBA at the requested height."""
    width = max(1, round(glyph.width * target_height / glyph.height))
    scaled = glyph.resize((width, target_height), Image.LANCZOS)
    red, _, _, alpha = scaled.split()
    alpha = steep(alpha, k=18)
    luminance = steep(red, k=12)
    return Image.merge("RGBA", (luminance, luminance, luminance, alpha))


def centred_on_square(glyph, size):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = round(size * GLYPH_FRACTION)
    scaled = upscale(glyph, inner)
    canvas.paste(scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2), scaled)
    return canvas


def build_icns(glyph):
    iconset = os.path.join(RESOURCES, "AppIcon.iconset")
    shutil.rmtree(iconset, ignore_errors=True)
    os.makedirs(iconset)

    for size in ICNS_SIZES:
        centred_on_square(glyph, size).save(
            os.path.join(iconset, f"icon_{size}x{size}.png"))
        centred_on_square(glyph, size * 2).save(
            os.path.join(iconset, f"icon_{size}x{size}@2x.png"))

    output = os.path.join(RESOURCES, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", output], check=True)
    shutil.rmtree(iconset, ignore_errors=True)
    print(f"app icon    -> {output} ({os.path.getsize(output)} bytes)")


def build_menu_bar_icon(glyph):
    """Menu bar icons are template images: macOS renders them from alpha alone.

    Feeding it the artwork as-is would make the white interior opaque too, so the
    whole thing would come out as one solid blob with no cat face. Inverting
    luminance into alpha keeps the black linework and drops the white fill.
    """
    for scale in (1, 2, 3):
        height = MENU_BAR_HEIGHT_POINTS * scale
        sharpened = upscale(glyph, height)
        red, _, _, alpha = sharpened.split()
        ink = red.point(lambda v: 255 - v)                       # black -> opaque
        combined = Image.new("L", sharpened.size)
        combined.putdata([min(a, i) for a, i in zip(alpha.getdata(), ink.getdata())])
        black = Image.new("L", sharpened.size, 0)
        template = Image.merge("RGBA", (black, black, black, combined))

        suffix = "" if scale == 1 else f"@{scale}x"
        path = os.path.join(RESOURCES, f"MenuBarIcon{suffix}.png")
        template.save(path)
        print(f"menu bar    -> {path} ({template.width}x{template.height})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=DEFAULT_SOURCE)
    args = parser.parse_args()

    if not os.path.exists(args.source):
        raise SystemExit(f"source frame not found: {args.source}")

    glyph = load_glyph(args.source)
    print(f"source glyph: {glyph.width}x{glyph.height} from "
          f"{os.path.basename(args.source)}")
    build_icns(glyph)
    build_menu_bar_icon(glyph)


if __name__ == "__main__":
    main()
