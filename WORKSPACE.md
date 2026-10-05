# Workspace: Gameplay / AI Production Pass

This is an existing Godot 4.x six-face gravity FPS vertical slice. It already supports player movement across the inside faces of a giant cube, basic shooting, basic enemies, waves, HUD, and cloud/headless validation.

The next engineering task is to turn the existing vertical slice into a complete replayable combat run without replacing the core project.

## Current constraints

- Preserve the six-face gravity concept and current public interfaces where practical.
- Do not rewrite the project in another engine.
- The final game must remain runnable in Godot 4.x on Linux.
- Enemy logic must work when player and enemy are on different cube faces; do not fake cross-face behavior by teleporting enemies to the player.
- New gameplay systems must be deterministic enough to test headlessly.
- Existing validation must keep passing, and new behavior needs meaningful automated coverage.
- Do not hard-code only the current spawn positions or one scripted path.
- Do not remove existing tests or relax them to hide regressions.

## Existing validation

Read the code first and run the existing validation suite before deciding on the implementation. The repository already contains scripts for bootstrapping Godot, validating scripts/project startup, and running headless tests.

The final delivery should be a coherent playable game loop with documented behavior and reproducible verification, not disconnected feature stubs.
