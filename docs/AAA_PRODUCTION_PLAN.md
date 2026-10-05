# Neon Cube — AAA Production Plan

## Product goal

Neon Cube is no longer treated as a benchmark fixture or small arena prototype. The product target is a premium single-player cyberpunk FPS whose defining mechanic is continuous combat across the six interior faces of a giant cube city.

The production standard is AAA-grade in:
- moment-to-moment gun feel,
- character/enemy animation,
- authored level design,
- environmental density,
- lighting and VFX,
- combat AI,
- sound design and music,
- UI/UX,
- stability and performance,
- build/release quality.

"AAA-grade" is an acceptance standard, not a claim that a tiny team can instantly match the raw content volume of a multi-year 300-person production. Content must be expanded systematically and no milestone is called finished only because CI passes.

## Current-state diagnosis

The current repository is a functional prototype/early vertical slice. Major gaps:
- city is still mostly procedural/repeated,
- most gameplay logic is concentrated in a few very large scripts,
- enemy behavior is simple and largely stat/archetype driven,
- weapon presentation and feedback are shallow,
- animation/IK/locomotion pipeline is not production-ready,
- audio is synthetic placeholder quality,
- no authored mission/encounter scripting pipeline,
- no narrative/cinematic layer,
- no robust streaming/LOD/content-budget system,
- no real performance budget or GPU/CPU profiling gates,
- no accessibility/localization/controller production pass,
- no dedicated save/settings/profile architecture,
- no production asset validation/import pipeline.

## Production phases

### Phase A — Foundation / architecture
Goal: turn the current prototype codebase into a scalable game architecture.

Required work:
- split player, weapons, AI, campaign, UI, audio, save/settings and world systems into modules,
- move tunable gameplay data into Godot Resources,
- introduce event/state boundaries instead of cross-script global coupling,
- create authored level/encounter data format,
- create enemy behavior/state architecture,
- create weapon definition / recoil / animation / FX data pipeline,
- create save/profile/settings service,
- add debug tooling, logging, performance counters and deterministic test hooks,
- create asset validation and import conventions,
- add Git LFS policy for large binary assets,
- preserve six-face gravity as a reusable world service rather than embedding its assumptions everywhere.

Exit gate:
- no core gameplay feature depends on one monolithic game script,
- existing gameplay remains playable,
- CI and release export are green,
- major systems have contract tests.

### Phase B — AAA vertical slice
Goal: one 30–45 minute mission that represents the final quality bar.

Mission working title: **Neon Market Siege**.

Content:
- one authored district with interior/exterior spaces,
- multiple combat arenas connected by traversal,
- scripted intro and extraction,
- 6 polished weapons / alt-fire or ability variants,
- 6 enemy roles with distinct behaviors,
- one mini-boss and one full boss,
- checkpoint/save flow,
- authored lighting,
- production sound/music pass,
- first-person arms + weapon animation,
- hit reactions/death reactions,
- VFX and decals,
- tutorialization without debug-text dependency,
- difficulty tuning,
- controller + mouse/keyboard,
- final-quality HUD/menu/settings for this slice.

Exit gate:
- a new player can start, learn, complete and replay the mission without developer intervention,
- no placeholder primitive is visible in the critical path,
- combat and traversal hold target frame-time budgets on reference hardware,
- screenshots/video can be used as portfolio/storefront-quality material.

### Phase C — Campaign production
Target content:
- 6 visually distinct cube districts/faces,
- 4–8 hour campaign initially,
- 8–12 weapons,
- 12–16 enemy types/variants,
- 3–4 major bosses,
- upgrade/economy layer,
- authored missions and side encounters,
- narrative/codex/cinematics,
- multiple encounter archetypes,
- challenge/replay modes.

### Phase D — Release candidate polish
- performance/LOD/occlusion/streaming,
- memory budgets,
- shader/VFX budgets,
- accessibility,
- localization pipeline,
- save migration,
- crash recovery,
- input rebinding,
- achievements/platform hooks where applicable,
- full regression matrix,
- release packaging and patch workflow.

## Acceptance philosophy

A feature is not complete when the code compiles. It is complete only when:
1. it works in the actual game,
2. it has production presentation,
3. it has audio/visual feedback where required,
4. it is testable,
5. it meets performance budgets,
6. it survives replay/restart/save/load,
7. it has no placeholder dependency on the shipping path.

## Immediate milestone

The next development milestone is **Phase A: AAA Foundation**.

Do not spend further effort increasing raw content on top of the current monolithic architecture before this refactor. New content should be built on the production architecture so it can scale.
