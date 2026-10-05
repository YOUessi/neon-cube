# Workspace: Visual Production Pass

This is an existing Godot 4.x first-person game, not a greenfield project. The gameplay loop, six-face gravity, campaign, weapons, enemy archetypes, boss phases, UI states, save data, and cloud validation already exist.

The current build has failed an internal visual acceptance pass: the game is functionally complete but still looks too close to a prototype. The next engineering task is to productionize the visual/game-feel layer while preserving existing gameplay behavior.

## Current constraints

- Keep the existing six-face gravity mechanic and campaign rules working.
- Do not replace the project with a different engine or rewrite it from scratch.
- The final repository must remain runnable in Godot 4.x on Linux.
- All third-party art/audio used must be redistributable for a public repository and must keep license/provenance records.
- Avoid dependencies on paid/login-only services at runtime.
- Cloud/headless validation must keep working; graphical verification should also run in CI or via reproducible command-line steps.
- Do not weaken or delete existing automated tests to make the task pass.

## Existing validation

Start by reading the repository and running the current project/CI commands. The repository already contains headless validation and a graphical smoke path. Treat the existing build as the behavioral baseline; visual changes must not break it.

The final delivery should be a repository state that can be reviewed as a real game build rather than a collection of isolated screenshots or mockups.
