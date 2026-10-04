# Neon Cube / 霓虹立方体

A first-person cyberpunk arena shooter for Godot 4.x. The entire level lives on the **inside of a giant cube**: all six inner faces are walkable city streets, and gravity reorients toward the surface under the player while crossing cube edges.

## Current playable vertical slice

- Six-sided interior city arena generated procedurally at runtime.
- Dynamic nearest-face gravity on all 6 faces.
- Smooth character orientation while gravity flips across cube edges.
- First-person WASD + mouse movement, jumping and hitscan shooting.
- Cyberpunk emissive road grid, buildings, signs and HUD.
- Enemy wave system with face-aware gravity, chase behavior, line-of-sight attacks, health/death and scoring.
- Optional automatic loading of a Tripo enemy GLB at `assets/models/enemy.glb`.
- Mixamo animation-name hooks with a procedural enemy fallback, so the project runs without external licensed assets.
- Public gravity math smoke test.

## Engine

Target: **Godot 4.x** (GDScript). The project uses the GL Compatibility renderer and avoids third-party plugins.

## Run

1. Open this folder in Godot.
2. Run the main project (`F6/F5`, main scene is already configured).
3. Click the game window to capture the mouse.

Controls:

- `W A S D`: move
- Mouse: look
- `Space`: jump
- Left mouse: fire
- `R`: reload
- `Esc`: release / recapture mouse

## Core mechanic: six-face gravity

The player is always pulled toward the nearest inside face of the cube. A small hysteresis prevents jitter at edges. When an adjacent wall becomes the closer support surface, the gravity vector changes to that face and the character basis smoothly rotates so local up remains opposite gravity.

This creates the intended transition:

`floor -> wall -> ceiling -> opposite wall -> ...`

without teleporting the character or faking level transitions.

## Project layout

```text
project.godot
scenes/
  main.tscn
  player.tscn
  enemy.tscn
scripts/
  cube_gravity.gd
  city_builder.gd
  player.gd
  enemy.gd
  game.gd
assets/
  models/          # optional Tripo enemy.glb
  animations/      # optional animation source files
  external/README.md
tests/
  test_cube_gravity.gd
```

## Replacing the placeholder enemy

See `assets/external/README.md`. Dropping a compatible Tripo export at `assets/models/enemy.glb` is enough to replace the procedural enemy visual; animations can be supplied through the model's `AnimationPlayer` using the supported Mixamo-style aliases.

## What is intentionally left as follow-on work

The repository already contains a working game loop and the core six-face mechanic. Useful next milestones include animation retargeting polish, navigation around building blocks across face transitions, weapon variety, boss encounters, save/settings menus, audio, VFX optimization and a second authored arena layout.
