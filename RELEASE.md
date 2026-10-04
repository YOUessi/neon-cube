# Neon Cube 1.0

Neon Cube 1.0 is the first complete small-game release of the project.

## Included

- Six-face gravity arena traversal.
- Six-wave campaign with boss finale.
- Rookie / Operative / Nightmare difficulty.
- Pulse Rifle, Arc Scattergun and Ion Marksman.
- Regenerating shield and dash movement.
- Grunt, runner, sniper, tank and Null Warden enemy profiles.
- Cross-face pursuit, obstacle avoidance, pickups and scoring.
- Main menu, pause flow, victory/game-over screens and persistent high score.
- Procedural sound and visuals, with optional Tripo/Mixamo asset replacement.
- Headless regression tests and graphical Xvfb screenshot smoke test.
- Linux x86_64 release export produced automatically by CI.

## Build

```bash
make bootstrap
make validate
make test
make build
```

The resulting executable is written to `dist/neon-cube.x86_64`.
