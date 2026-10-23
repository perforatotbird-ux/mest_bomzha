#!/usr/bin/env python3
"""Normalize the generated pigeon sprite into a self-contained text texture.

The generator returns a baked checkerboard instead of real alpha, so the
background is keyed out here: the checker is both near-neutral and very light,
and every leftover speck is dropped by keeping only the largest component.

Usage: python tools/build_pigeon_asset.py <source.png>
"""
from pathlib import Path
import base64
import io
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
MAX_SIZE = (256, 256)


def cut(source: Image.Image) -> Image.Image:
    rgb = np.array(source.convert("RGB")).astype(np.float32)
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    background = (spread < 26) & (rgb.max(axis=2) > 168)
    labels, count = ndimage.label(~background)
    sizes = ndimage.sum(~background, labels, range(1, count + 1))
    body = labels == int(np.argmax(sizes)) + 1
    alpha = ndimage.binary_fill_holes(body).astype(np.uint8) * 255
    alpha = ndimage.binary_erosion(alpha > 0, iterations=1).astype(np.uint8) * 255
    alpha = ndimage.gaussian_filter(alpha.astype(np.float32), 0.8)
    sprite = Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha.astype(np.uint8)]))
    sprite = sprite.crop(Image.fromarray(alpha.astype(np.uint8)).getbbox())
    sprite.thumbnail(MAX_SIZE, Image.Resampling.LANCZOS)
    return sprite


def texture(sprite: Image.Image, path: Path) -> None:
    buffer = io.BytesIO()
    sprite.save(buffer, format="PNG", optimize=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '[gd_resource type="ImageTexture" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/environment/embedded_png_texture.gd" id="1"]\n\n'
        '[resource]\nscript = ExtResource("1")\n'
        'png_base64 = "' + base64.b64encode(buffer.getvalue()).decode() + '"\n',
        newline="\n",
    )


if __name__ == "__main__":
    sprite = cut(Image.open(sys.argv[1]))
    texture(sprite, ROOT / "Assets/Enemies/pigeon.tres")
    print(f"pigeon texture {sprite.size[0]}x{sprite.size[1]}")
