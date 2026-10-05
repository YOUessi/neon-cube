# Neon Cube — Target Technical Architecture

## Current architectural pressure points

The current prototype concentrates substantial responsibility in:
- `scripts/game.gd`,
- `scripts/player.gd`,
- `scripts/enemy.gd`,
- `scripts/city_builder.gd`.

These files currently mix state, presentation, spawning, persistence, tuning and gameplay behavior. This is acceptable for a prototype but blocks large-scale production.

## Target module layout

```text
game/
  bootstrap/
  state/
  save/
  settings/
  telemetry/
player/
  movement/
  gravity/
  camera/
  health/
  abilities/
combat/
  weapons/
  projectiles/
  damage/
  recoil/
  hit_reactions/
  vfx/
ai/
  perception/
  navigation/
  behaviors/
  squads/
  archetypes/
world/
  gravity/
  districts/
  encounters/
  streaming/
  props/
  interactables/
missions/
  runtime/
  definitions/
  checkpoints/
ui/
  hud/
  menus/
  accessibility/
audio/
  music/
  sfx/
  ambience/
data/
  weapons/
  enemies/
  encounters/
  difficulty/
tools/
  asset_validation/
  capture/
  profiling/
tests/
  unit/
  integration/
  scenarios/
```

## Data-driven rules

Use Godot Resources for:
- WeaponDefinition,
- EnemyDefinition,
- DifficultyProfile,
- EncounterDefinition,
- DistrictDefinition,
- MissionDefinition,
- Audio/VFX references.

Runtime nodes consume definitions; they should not own all tuning constants.

## AI direction

Replace archetype-only branching with composable states/behaviors:
- perception,
- target selection,
- local surface navigation,
- cross-face route planning,
- combat state,
- ability cooldowns,
- coordination.

The cube must expose a navigation abstraction that understands faces and shared edges.

## Performance gates

Add explicit budgets for:
- active enemies,
- draw calls,
- visible lights,
- particles,
- animation count,
- physics queries,
- frame time,
- memory.

Every new visual system must have a scalable quality level and measurable cost.

## Release discipline

- main should remain releasable,
- feature work uses dedicated branches,
- CI must include parse/import/tests/export,
- graphical captures are evidence, not the sole visual review,
- release candidates receive manual playthrough passes.
