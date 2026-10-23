"""Rebuild SpriteFrames deterministically from the supplied PNGs; no extra dependencies."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
# Idle uses the neutral breathing poses, not unrelated gesturing frames.
ANIMS = {
    'idle': ('idle', [0, 1, 0, 5], 3.0, True),
    'walk': ('walk', list(range(8)), 10.0, True),
    'run': ('smooth_run', list(range(16)), 24.0, True),
    # All four poses: standing, settling, squat, deep squat. Non-looping so the
    # descent plays once and the last frame holds for as long as crouch is held.
    'crouch': ('crouch', list(range(4)), 8.0, False),
    'crouch_walk': ('crouch_walk', list(range(6)), 8.0, True),
    'jump': ('jump', [0, 1, 2], 12.0, False),
    'fall': ('fall', [0, 1, 2], 10.0, False),
    'landing': ('landing', [0, 1, 2], 22.0, False),
    # Attacks run at the pack's 8 fps: 14/12 fps finished a whole swing in ~0.43 s
    # and the release frame flashed by before the pose read on screen.
    'throw': ('throw_bottle', list(range(6)), 8.0, False),
    'burp': ('burp_attack', list(range(5)), 8.0, False),
    # Do not include frame 06: it is the projectile, not a player pose.
    'rear_shot': ('legacy_fart', list(range(6)), 8.0, False),
    'drink': ('drink', list(range(6)), 8.0, False),
    'hit': ('hit', list(range(3)), 14.0, False),
    'death': ('death', list(range(6)), 8.0, False),
    'victory': ('victory', list(range(4)), 8.0, False),
}
resources = {}
for folder, frames, _, _ in ANIMS.values():
    if folder == "smooth_run":
        continue
    for frame in frames:
        path = (f'Assets/Bomzh/frames/fart_{frame:02}.png' if folder == 'legacy_fart'
                else f'Assets/Drifter/frames/{folder}/{frame:02}.png')
        assert (ROOT / path).exists(), path
        if path not in resources:
            resources[path] = f't{len(resources)}'
lines = [f'[gd_resource type="SpriteFrames" load_steps={len(resources)+18} format=3]', '']
lines += [f'[ext_resource type="Texture2D" path="res://{p}" id="{i}"]' for p, i in resources.items()]
lines += ['[ext_resource type="Texture2D" path="res://Assets/Drifter/smooth_run/run_atlas.tres" id="smooth_run"]', '']
for index in range(16):
    lines += [f'[sub_resource type="AtlasTexture" id="run_{index:02}"]', 'atlas = ExtResource("smooth_run")',
              f'region = Rect2({index % 4 * 384}, {index // 4 * 512}, 384, 512)', '']
lines += ['', '[resource]', 'animations = [']
for name, (folder, frames, fps, loop) in ANIMS.items():
    refs = []
    for frame in frames:
        if folder == "smooth_run":
            refs.append('{"duration": 1.0, "texture": SubResource("run_%02d")}' % frame)
            continue
        path = (f'Assets/Bomzh/frames/fart_{frame:02}.png' if folder == 'legacy_fart'
                else f'Assets/Drifter/frames/{folder}/{frame:02}.png')
        refs.append('{"duration": 1.0, "texture": ExtResource("%s")}' % resources[path])
    lines.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s},' %
                 (', '.join(refs), str(loop).lower(), name, fps))
lines[-1] = lines[-1].rstrip(',')
lines += [']', '']
(ROOT / 'Assets/player_frames.tres').write_text('\n'.join(lines), newline='\n')
print(f'Built {len(ANIMS)} animations, {len(resources)} source textures')
