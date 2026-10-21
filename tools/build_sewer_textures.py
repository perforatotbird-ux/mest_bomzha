"""Embed the generated PNGs losslessly as Godot Texture2D resources."""
from pathlib import Path
import base64
root = Path(__file__).resolve().parents[1]
for path in sorted((root / 'Assets/Environment/Sewer').glob('*.png')):
    encoded = base64.b64encode(path.read_bytes()).decode('ascii')
    path.with_suffix('.tres').write_text(
        '[gd_resource type="ImageTexture" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://scripts/environment/embedded_png_texture.gd" id="1"]\n\n'
        '[resource]\nscript = ExtResource("1")\npng_base64 = "' + encoded + '"\n')
    print(path.with_suffix('.tres').relative_to(root))
