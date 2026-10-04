# Neon Cube / 霓虹立方体

**Neon Cube** is a self-contained first-person cyberpunk arena shooter built with Godot 4.x. The entire combat space is the inside of a giant cube: all six inner faces are walkable city streets, and gravity follows the surface under the player and enemies while crossing cube edges.

## Complete game loop

- Main menu with three difficulty levels: Rookie, Operative, Nightmare.
- Six-wave campaign with escalating enemy mixes.
- Final boss: **Null Warden**, with three aggression phases.
- Victory, game-over, pause, restart and replay flow.
- Persistent local high score.
- Regenerating cyber-shield plus health.
- Dash movement for fast cross-face combat.
- Health, ammo and shield pickups.
- Three switchable weapons:
  - Pulse Rifle
  - Arc Scattergun
  - Ion Marksman
- Four regular enemy profiles: grunt, runner, sniper and tank.
- Cross-face enemy pursuit with shared-edge routing and obstacle avoidance.
- First-person weapon viewmodels and recoil feedback.
- Damage-screen feedback, wave messaging, score, objective and gravity HUD.
- Procedural cyberpunk city, neon road grid and fallback enemy visuals.
- Procedurally synthesized sound cues.
- Optional Tripo enemy model and Mixamo animation hooks; no external asset is required to play.

## Controls

- `W A S D`: move
- Mouse: aim / look
- `Space`: jump
- `Shift`: dash
- Left mouse: fire
- `R`: reload
- `1`: Pulse Rifle
- `2`: Arc Scattergun
- `3`: Ion Marksman
- `Esc`: pause / resume

## Run

Open the repository in Godot 4.x and run `res://scenes/main.tscn` or press F5.

## Cloud validation

```bash
make bootstrap
make validate
make test
```

The GitHub Actions pipeline downloads pinned Godot 4.3 stable, parses all scripts, boots the main scene headlessly, executes the automated gameplay suite, then launches Godot under Xvfb and captures an actual rendered gameplay frame as a build artifact.

Automated coverage includes:

- all six gravity faces and edge hysteresis,
- player health/shield/ammo contracts,
- weapon switching,
- enemy cross-face routing,
- boss phase transitions,
- campaign wave composition,
- menu/pause/end-state existence,
- whole-project startup with zero Godot `ERROR:` / `SCRIPT ERROR:` output.

## Tripo / Mixamo

If `assets/models/enemy.glb` exists, the game automatically uses it. Otherwise the procedural enemy remains fully functional. Common Mixamo animation aliases for idle/run/attack/death are detected recursively through `AnimationPlayer`.

See `assets/external/README.md`.

## Scope

This repository is a finished small arena game rather than a content-heavy commercial title. It has a complete start-to-finish campaign, multiple weapons and enemy types, a boss encounter, progression, difficulty selection, win/loss states, replayability, persistence, sound/visual feedback and automated cloud validation.
