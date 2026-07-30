#!/usr/bin/env python3
"""Build the README preview images from the cursor frames.

Timing matters here: the GIFs are meant to show what the cursor actually does,
so each frame's duration is derived from the frame rate the app plays it at --
not a flat guess. The click reaction in particular is not played at the
artwork's native rate, it is sped up so it finishes inside a real click.

Usage:
    python3 Scripts/make_previews.py
"""

import os

from PIL import Image

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CURSORS = os.path.join(PROJECT_ROOT, "Resources", "Cursors")
OUTPUT = os.path.join(PROJECT_ROOT, "docs")

SCALE = 1.6          # the artwork is ~110px; a little bigger reads better on a page
NATIVE_FPS = 30.0


def load(name, index, scale=SCALE):
    image = Image.open(os.path.join(CURSORS, name, f"{index:04d}.png")).convert("RGBA")
    if scale != 1:
        image = image.resize((round(image.width * scale), round(image.height * scale)),
                             Image.LANCZOS)
    return image


def write_gif(images, durations, path):
    """Transparent-background GIF.

    Transparency rather than a flat backdrop: the artwork is white with a black
    outline, so it stays legible whether the page is rendered light or dark.
    """
    width = max(i.width for i in images)
    height = max(i.height for i in images)

    frames = []
    for image in images:
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        canvas.paste(image, (0, 0), image)
        palette = canvas.convert("P", palette=Image.ADAPTIVE, colors=255)
        transparent = canvas.split()[3].point(lambda a: 255 if a <= 128 else 0)
        palette.paste(255, transparent)
        frames.append(palette)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, transparency=255,
                   disposal=2, optimize=True)
    size = os.path.getsize(path)
    print(f"{os.path.basename(path):22} {width}x{height}  {len(frames)} frames  "
          f"{size / 1024:.0f} KB")


def build_idle():
    """Every frame at native rate. Most of them are identical -- the cat holds a
    pose and twitches occasionally -- and the encoder collapses those runs while
    summing their durations, so the timing survives."""
    count = len([f for f in os.listdir(os.path.join(CURSORS, "arrow"))
                 if f.endswith(".png")])
    images = [load("arrow", i) for i in range(count)]
    per_frame = round(1000 / NATIVE_FPS)
    write_gif(images, [per_frame] * len(images),
              os.path.join(OUTPUT, "preview-idle.gif"))


def build_click():
    """Press, hold, release -- at the speeds the app actually uses.

    The intro and outro are compressed to 0.30s each because the artwork's own
    0.87s pacing outlasts a real click.
    """
    intro = list(range(0, 26))
    hold = list(range(40, 48)) * 3
    outro = list(range(73, 94))

    images = [load("click", i) for i in intro + hold + outro]
    durations = (
        [max(10, round(300 / len(intro)))] * len(intro)
        + [round(1000 / NATIVE_FPS)] * len(hold)
        + [max(10, round(300 / len(outro)))] * len(outro)
    )
    write_gif(images, durations, os.path.join(OUTPUT, "preview-click.gif"))


def build_shapes():
    """One still of every shape the cursor can take."""
    shapes = [
        ("arrow", "normal"), ("text", "text"), ("click", "link"),
        ("precision", "crosshair"), ("unavailable", "not allowed"),
        ("horizontal", "resize sideways"), ("vertical", "resize up-down"),
        ("diagonal1", "resize corner"), ("diagonal2", "resize corner"),
        ("move", "grab / move"),
    ]

    # Sized by the on-screen width each cursor is actually drawn at, so the
    # sheet shows their real relative sizes. Normalising them to equal height
    # instead would mean upscaling the 32px static artwork three times over,
    # which looks far worse than it does in use.
    import json
    with open(os.path.join(CURSORS, "manifest.json")) as handle:
        manifest = json.load(handle)

    tiles = []
    for name, label in shapes:
        index = 45 if name == "click" else 0
        image = load(name, index, scale=1)
        target = round(manifest[name]["mediumWidthPoints"] * 2.4)
        image = image.resize((target, round(image.height * target / image.width)),
                             Image.LANCZOS)
        tiles.append((image, label))

    from PIL import ImageDraw
    columns = 5
    cell_w, cell_h = 150, 130
    rows = (len(tiles) + columns - 1) // columns
    # A light card rather than transparency: several of these cursors are plain
    # black line art and vanish against a dark page, and GitHub renders READMEs
    # in both themes.
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), (246, 247, 249, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (image, label) in enumerate(tiles):
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        sheet.paste(image, (x + (cell_w - image.width) // 2, y + (108 - image.height) // 2), image)
        draw.text((x + 8, y + 110), label, fill=(110, 112, 118, 255))

    os.makedirs(OUTPUT, exist_ok=True)
    path = os.path.join(OUTPUT, "preview-shapes.png")
    sheet.save(path)
    print(f"{os.path.basename(path):22} {sheet.width}x{sheet.height}  "
          f"{os.path.getsize(path) / 1024:.0f} KB")


if __name__ == "__main__":
    build_idle()
    build_click()
    build_shapes()
