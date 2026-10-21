"""Rebuild SpriteFrames deterministically from the supplied PNGs; no extra dependencies."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
# Idle uses the neutral breathing poses, not unrelated gesturing frames.
ANIMS = {
    'idle': ('idle', [0, 1, 0, 5], 3.0, True),
    'walk': ('walk', list(range(8)), 10.0, True),
    'run': ('run', list(range(8)), 14.0, True),
    'crouch': ('crouch', [0], 1.0, True),
    'crouch_walk': ('crouch_walk', list(range(6)), 8.0, True),
    'jump': ('jump', [0, 1, 2], 12.0, False),
    'fall': ('fall', [0, 1, 2], 10.0, False),
    'landing': ('landing', [0, 1, 2], 22.0, False),
    'throw': ('throw_bottle', list(range(6)), 14.0, False),
    'burp': ('burp_attack', list(range(5)), 12.0, False),
    # Do not include frame 06: it is the projectile, not a player pose.
    'rear_shot': ('legacy_fart', list(range(6)), 14.0, False),
    'drink': ('drink', list(range(6)), 8.0, False),
    'hit': ('hit', list(range(3)), 14.0, False),
    'death': ('death', list(range(6)), 8.0, False),
    'victory': ('victory', list(range(4)), 8.0, False),
}
resources = {}
for folder, frames, _, _ in ANIMS.values():
    for frame in frames:
        path = (f'Assets/Bomzh/frames/fart_{frame:02}.png' if folder == 'legacy_fart'
                else f'Assets/Drifter/frames/{folder}/{frame:02}.png')
        assert (ROOT / path).exists(), path
        if path not in resources:
            resources[path] = f't{len(resources)}'
lines = [f'[gd_resource type="SpriteFrames" load_steps={len(resources)+1} format=3]', '']
lines += [f'[ext_resource type="Texture2D" path="res://{p}" id="{i}"]' for p, i in resources.items()]
lines += ['', '[resource]', 'animations = [']
for name, (folder, frames, fps, loop) in ANIMS.items():
    refs = []
    for frame in frames:
        path = (f'Assets/Bomzh/frames/fart_{frame:02}.png' if folder == 'legacy_fart'
                else f'Assets/Drifter/frames/{folder}/{frame:02}.png')
        refs.append('{"duration": 1.0, "texture": ExtResource("%s")}' % resources[path])
    lines.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s},' %
                 (', '.join(refs), str(loop).lower(), name, fps))
lines[-1] = lines[-1].rstrip(',')
lines += [']', '']
(ROOT / 'Assets/player_frames.tres').write_text('\n'.join(lines))
print(f'Built {len(ANIMS)} animations, {len(resources)} source textures')
