# Platformer — agent notes

## Game-dev skills

This project uses the **gamedev-skills** bundle (router + 74 skills):
- Local clone: `C:\Users\inval\.agents\repos\gamedev-skills`
- Global install (OpenCode reads it): `C:\Users\inval\.agents\skills\<skill-name>\SKILL.md`
- Refresh: `npx skills update -g` or re-copy from the clone.

Before game-dev work, load `router`, then only the skills it names for the task.

Current routing for this project (Godot 4.7 in `project.godot`):
- `godot-2d-movement` — CharacterBody2D controller, gravity/jump
- `platformer` — jump feel, level goals, hazards, checkpoints
- `create-game-assets` — sprite/tileset pipeline and raster QA
- `godot-animation`, `game-feel`, `camera-systems`, `level-design` as needed
- `godot-gdscript-headless-testing` — headless validation

## Validation

```powershell
# import assets + parse project
& "K:\Godot_v4.7.2-stable_win64.exe" --path "K:\Platformer" --headless --import

# run the game headless for 180 frames
& "K:\Godot_v4.7.2-stable_win64.exe" --path "K:\Platformer" --headless --quit-after 180
```

Sprite QA (from `create-game-assets`):

```powershell
python "C:\Users\inval\.agents\skills\create-game-assets\scripts\asset_report.py" `
  <png files> --expect-size 384x512 --require-alpha
```
