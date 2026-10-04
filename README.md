# Neon Cube / 霓虹立方体

**Neon Cube** is a complete small-scale first-person cyberpunk arena game built with Godot 4.x. The entire combat space is the inside of a giant cube: all six inner faces are walkable city streets, and gravity follows the surface under the player and enemies as they cross cube edges.

## Playable game loop

The game now has a beginning, escalating campaign, boss finale, loss state and replay loop:

- Main menu and control guide.
- Six-wave survival campaign.
- Four regular enemy profiles: grunt, runner, sniper and tank.
- Final boss: the **Null Warden**, supported by elite units.
- Victory and game-over screens.
- Persistent local high score.
- Pause / resume / restart flow.
- Health and ammunition pickups.
- Three switchable hitscan weapons:
  - Pulse Rifle
  - Arc Scattergun
  - Ion Marksman
- Enemy cross-face pursuit using cube-surface routing with obstacle avoidance.
- Enemy wave scaling, scoring and boss rewards.
- Procedural cyberpunk city geometry, emissive road grid and HUD.
- Procedural synthesized sound cues; no external audio pack required.
- Optional Tripo enemy model and Mixamo animation hooks with a built-in procedural fallback.

## Core six-face mechanic

Both player and enemies continuously resolve their nearest inside cube face. When an adjacent surface becomes decisively closer, gravity changes to that face while the actor basis smoothly rotates so local up remains opposite gravity. Hysteresis prevents edge jitter.

Enemies on another face route toward the shared cube edge before continuing pursuit, rather than simply trying to walk through the cube interior.

## Controls

- `W A S D`: move
- Mouse: aim / look
- `Space`: jump
- Left mouse: fire
- `R`: reload
- `1`: Pulse Rifle
- `2`: Arc Scattergun
- `3`: Ion Marksman
- `Esc`: pause / resume

## Run in Godot

1. Open the repository in Godot 4.x.
2. Run the project with F6/F5.
3. Select **START MISSION**.

The main scene is `res://scenes/main.tscn`.

## Tripo / Mixamo integration

The game does not depend on external services at runtime.

If `assets/models/enemy.glb` exists, enemies automatically use it in place of the procedural fallback mesh. An embedded `AnimationPlayer` is detected recursively and common Mixamo-style animation aliases are supported:

- Idle / idle
- Run / run / Walking / walking
- Attack / attack / Shooting / shooting
- Death / death / Dying / dying

See `assets/external/README.md` for the asset workflow.

## Cloud / headless validation

The project is deliberately testable in a Linux cloud environment without an interactive GPU/display session.

```bash
make bootstrap
make validate
make test
# or
make ci
```

The validation pipeline:

1. Uses an existing Godot binary or downloads pinned Godot 4.3 stable.
2. Imports project resources.
3. Parses every GDScript with `--check-only`.
4. Boots the full main scene headlessly.
5. Runs automated tests for:
   - six-face gravity,
   - transition hysteresis,
   - player health/ammo contracts,
   - three-weapon switching,
   - cross-face enemy routing,
   - enemy archetypes and boss profile,
   - six-wave campaign structure,
   - full-project startup and UI.

Any emitted Godot `ERROR:` or `SCRIPT ERROR:` output is treated as CI failure.

GitHub Actions runs the same validation on every push and pull request.

## Project structure

```text
project.godot
scenes/
  main.tscn
  player.tscn
  enemy.tscn
  pickup.tscn
scripts/
  cube_gravity.gd
  city_builder.gd
  player.gd
  enemy.gd
  pickup.gd
  audio_manager.gd
  game.gd
tests/
  test_cube_gravity.gd
  test_face_transitions.gd
  test_player_contract.gd
  test_weapon_system.gd
  test_enemy_routing.gd
  test_campaign.gd
  test_project_smoke.gd
```

## Current scope

This is a self-contained arena game rather than a content-heavy commercial release. It includes a complete playable campaign loop and can be run, won, lost, restarted and regression-tested without downloading proprietary assets.
