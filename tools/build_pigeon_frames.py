#!/usr/bin/env python3
"""Cut the generated pigeon flap sheet into four animation frames.

The generator returns a 2x2 sheet on a flat green backdrop, but the birds are
not confined to their quadrants - wings cross the midlines. So the sheet is
chroma-keyed as a whole and the birds are found as connected components; the
small ones are the watermark and get dropped. Each bird is then aligned by its
feet so the body stays put while the wings move.

Output: four embedded ImageTexture resources plus a SpriteFrames with one
looping "flap" animation, all as text so the repo needs no binary assets.

Usage: python tools/build_pigeon_frames.py <sheet.png>
"""
from pathlib import Path
import base64
import io
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Assets/Enemies"
CANVAS = 256
# Flap cycle: wings down, wings mid, wings up, wings level.
MIN_BIRD = 5000
# The feet sit on this line of the 256 px canvas, the body is centred on it.
FOOT_Y = 236
BODY_X = 128


def key_out(rgb: np.ndarray) -> np.ndarray:
    """Alpha from green dominance, with a soft edge and a despill.

    The backdrop sits around excess 34 (g - max(r,b)); the palest feathers are
    near 7, so the ramp has to fade between 14 and 28 or the wings dissolve.
    """
    # int16, not uint8: g - max(r,b) is negative on the blue feathers and would wrap.
    r = rgb[:, :, 0].astype(np.int16)
    g = rgb[:, :, 1].astype(np.int16)
    b = rgb[:, :, 2].astype(np.int16)
    excess = g - np.maximum(r, b)
    alpha = 255.0 * np.clip((28.0 - excess) / 12.0, 0.0, 1.0)
    cleaned = rgb.copy()
    # Pull the green spill out of the feather edges.
    cleaned[:, :, 0] = np.minimum(cleaned[:, :, 0], g + 48)
    cleaned[:, :, 2] = np.minimum(cleaned[:, :, 2], g + 48)
    return np.dstack([cleaned, alpha.astype(np.uint8)])


def birds(sheet: Image.Image) -> list:
    """Return the four birds as (alpha, bbox) pairs, biggest first."""
    rgba = key_out(np.array(sheet.convert("RGB")))
    alpha = rgba[:, :, 3]
    solid = alpha > 120
    labels, count = ndimage.label(solid)
    sizes = ndimage.sum(solid, labels, range(1, count + 1))
    found = []
    for index in np.argsort(sizes)[::-1]:
        if sizes[index] < MIN_BIRD:
            break
        mask = labels == index + 1
        ys, xs = np.where(mask)
        found.append((mask, (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)))
    return found, rgba


def frame_from(mask: np.ndarray, rgba: np.ndarray, box: tuple, scale: float) -> Image.Image:
    """Cut one bird, drop loose specks and pin it to a shared foot anchor.

    The wings change the silhouette, so the bbox centre is useless as a pivot.
    The feet do not move between poses, so the lowest opaque pixels give a
    stable anchor for both axes and the body stays put while the wings flap.
    """
    labels, count = ndimage.label(mask)
    if count == 0:
        return Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    sizes = ndimage.sum(mask, labels, range(1, count + 1))
    body = labels == int(np.argmax(sizes)) + 1
    alpha = ndimage.binary_fill_holes(body).astype(np.uint8) * 255
    alpha = ndimage.binary_erosion(alpha > 0, iterations=1).astype(np.uint8) * 255
    alpha = ndimage.gaussian_filter(alpha.astype(np.float32), 0.7)
    patch = rgba[box[1]:box[3], box[0]:box[2]].copy()
    patch[:, :, 3] = alpha[box[1]:box[3], box[0]:box[2]].astype(np.uint8)
    sprite = Image.fromarray(patch)
    width = max(1, int(round(sprite.width * scale)))
    height = max(1, int(round(sprite.height * scale)))
    sprite = sprite.resize((width, height), Image.Resampling.LANCZOS)
    # Foot anchor: centre of the opaque pixels in the lowest rows.
    band = sprite.split()[3].crop((0, max(0, height - max(2, height // 14)), width, height))
    foot_x = 0.0
    for y in range(band.height):
        row = band.crop((0, y, width, y + 1)).getbbox()
        if row:
            foot_x = (row[0] + row[2]) * 0.5
    frame = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    frame.alpha_composite(sprite, (int(round(BODY_X - foot_x)), FOOT_Y - height))
    return frame


def texture(sprite: Image.Image, path: Path) -> None:
    buffer = io.BytesIO()
    sprite.save(buffer, format="PNG", optimize=True)
    path.write_text(
        '[gd_resource type="ImageTexture" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/environment/embedded_png_texture.gd" id="1"]\n\n'
        '[resource]\nscript = ExtResource("1")\n'
        'png_base64 = "' + base64.b64encode(buffer.getvalue()).decode() + '"\n',
        newline="\n",
    )


def main() -> None:
    sheet = Image.open(sys.argv[1]).convert("RGB")
    found, rgba = birds(sheet)
    if len(found) < 4:
        raise SystemExit(f"expected four birds, found {len(found)}")
    # Sheet order: top-left up, top-right level, bottom-left down, bottom-right mid.
    order = [3, 2, 0, 1]  # down, mid, up, level
    names = ["down", "mid", "up", "level"]
    # One shared scale for the whole cycle: the body is the same size in every
    # pose, only the wings differ, so scaling per frame would make it breathe.
    widest = max((box[2] - box[0]) for _, box in found)
    scale = (CANVAS * 0.98) / widest
    for index, source in enumerate(order):
        mask, box = found[source]
        frame = frame_from(mask, rgba, box, scale)
        texture(frame, OUT_DIR / f"pigeon_{index:02d}.tres")
        print(f"frame {index} ({names[index]}): bbox {box} -> {frame.getbbox()}")
    lines = ['[gd_resource type="SpriteFrames" load_steps=6 format=3]', ""]
    for index in range(4):
        lines.append(
            f'[ext_resource type="Texture2D" path="res://Assets/Enemies/pigeon_{index:02d}.tres" id="t{index}"]'
        )
    lines += ["", "[resource]", "animations = ["]
    refs = ", ".join(
        '{"duration": 1.0, "texture": ExtResource("t%d")}' % i for i in range(4)
    )
    lines.append('{"frames": [%s], "loop": true, "name": &"flap", "speed": 12.0}' % refs)
    lines += ["]", ""]
    (OUT_DIR / "pigeon_frames.tres").write_text("\n".join(lines), newline="\n")
    print("wrote 4 frames + pigeon_frames.tres")


if __name__ == "__main__":
    main()
