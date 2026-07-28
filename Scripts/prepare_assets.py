#!/usr/bin/env python3
"""Decode the Windows cursor pack into the PNG frame sets the app ships with.

The generated PNGs under Resources/Cursors are the runtime assets and ship with
the project, so this only needs re-running when changing which cursors ship or
swapping in new artwork.

Usage:
    python3 Scripts/prepare_assets.py [--source /path/to/windows/cursor/folder]

The source folder is the Windows cursor pack holding Normal.ani, Link.ani etc.
"""

import argparse
import json
import os
import struct
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ani_parser import parse_ani

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_ROOT = os.path.join(PROJECT_ROOT, "Resources", "Cursors")
DEFAULT_SOURCE = os.path.join(
    os.path.dirname(PROJECT_ROOT), "普通的鼠标指针V1.5", "安装文件")

# Display width in points at the "medium" size setting.
#
# Animated artwork is drawn at roughly 110-120px, so ~0.43 points per source
# pixel puts its arrow glyph at about the size of the stock macOS pointer.
# The static cursors only exist at 32x32 -- there is no higher-resolution
# source -- so matching the animated cursors means upscaling them ~1.6x. That
# is deliberate: a pointer that changes size on every state change is far more
# noticeable than slightly soft edges.
ANIMATED_POINTS_PER_PIXEL = 0.43
STATIC_WIDTH_POINTS = 26

# app name -> (source file, extra metadata)
ANIMATED = {
    "arrow": "Normal.ani",        # idle pointer
    "click": "Link.ani",          # cat pops out, reused as the mouse-down reaction
    "text": "Text.ani",           # iBeam
    "horizontal": "Horizontal.ani",  # resizeLeftRight and friends
    "vertical": "Vertical.ani",   # resizeUpDown and friends
}

STATIC = {
    "precision": "Precision.cur",      # crosshair
    "unavailable": "Unavailable.cur",  # operationNotAllowed
    "move": "Move.cur",                # openHand / closedHand
    "diagonal1": "Diagonal1.cur",      # resizeNWSE
    "diagonal2": "Diagonal2.cur",      # resizeNESW
}

# Link.ani is authored as one self-contained loop: the cat pops out, sits and
# breathes, then retracts. Splitting it at those seams turns it into a
# press/hold/release reaction. Boundaries come from per-frame difference
# analysis: 0-25 rises, 26-39 is frozen, 40-47 is an exact 8-frame breathing
# cycle repeated four times, 73-93 retracts back to something ~identical to
# frame 0. Frames 26-39 are skipped so a click does not stall on a still image.
SEGMENTS = {
    "click": {
        "intro": [0, 25],
        "hold": [40, 47],
        "outro": [73, 93],
    },
}


def clear_pngs(directory):
    os.makedirs(directory, exist_ok=True)
    for stale in os.listdir(directory):
        if stale.endswith(".png"):
            os.remove(os.path.join(directory, stale))


def export_animated(name, filename, source_dir):
    src = os.path.join(source_dir, filename)
    if not os.path.exists(src):
        raise SystemExit(f"missing source cursor: {src}")

    parsed = parse_ani(src)
    images = parsed["images"]
    if not images:
        raise SystemExit(f"no frames decoded from {src}")

    out_dir = os.path.join(OUTPUT_ROOT, name)
    clear_pngs(out_dir)
    for index, image in enumerate(images):
        image.save(os.path.join(out_dir, f"{index:04d}.png"))

    width, height = images[0].size
    hotspot = parsed["hotspots"][0] or (0, 0)
    points = round(width * ANIMATED_POINTS_PER_PIXEL)
    entry = {
        "type": "animated",
        "frameCount": len(images),
        "fps": parsed["fps"] or 30.0,
        "width": width,
        "height": height,
        "hotspotX": hotspot[0],
        "hotspotY": hotspot[1],
        "mediumWidthPoints": points,
        "source": filename,
    }
    if name in SEGMENTS:
        entry["segments"] = SEGMENTS[name]
    print(f"{name:12} animated {len(images):4} frames  {width}x{height}  "
          f"hotspot {hotspot}  -> {points}pt")
    return entry


def export_static(name, filename, source_dir):
    src = os.path.join(source_dir, filename)
    if not os.path.exists(src):
        raise SystemExit(f"missing source cursor: {src}")

    image = Image.open(src).convert("RGBA")
    out_dir = os.path.join(OUTPUT_ROOT, name)
    clear_pngs(out_dir)
    image.save(os.path.join(out_dir, "0000.png"))

    # CUR header: bytes 10-13 of the first directory entry hold the hotspot.
    with open(src, "rb") as handle:
        raw = handle.read()
    hotspot_x, hotspot_y = struct.unpack("<HH", raw[10:14])

    width, height = image.size
    entry = {
        "type": "static",
        "frameCount": 1,
        "fps": 0,
        "width": width,
        "height": height,
        "hotspotX": hotspot_x,
        "hotspotY": hotspot_y,
        "mediumWidthPoints": STATIC_WIDTH_POINTS,
        "source": filename,
    }
    print(f"{name:12} static      1 frame   {width}x{height}  "
          f"hotspot ({hotspot_x}, {hotspot_y})  -> {STATIC_WIDTH_POINTS}pt")
    return entry


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=DEFAULT_SOURCE,
                        help="folder holding the Windows cursor files")
    args = parser.parse_args()

    if not os.path.isdir(args.source):
        raise SystemExit(f"source folder not found: {args.source}\n"
                         f"pass --source /path/to/windows/cursors")

    os.makedirs(OUTPUT_ROOT, exist_ok=True)
    manifest = {}
    for name, filename in ANIMATED.items():
        manifest[name] = export_animated(name, filename, args.source)
    for name, filename in STATIC.items():
        manifest[name] = export_static(name, filename, args.source)

    manifest_path = os.path.join(OUTPUT_ROOT, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
    print("manifest ->", manifest_path)


if __name__ == "__main__":
    main()
