# Task 1 visual production rehearsal delivery

This branch represents an independent rehearsal of the proposed visual-production task.

## Delivered

- Six visually distinct cyberpunk districts mapped to the six gravity faces.
- CC0 Kenney first-person weapon meshes for all three existing weapons.
- CC0 Quaternius enemy meshes for grunt, runner, sniper, tank and boss.
- CC0 Quaternius street props integrated into every face.
- Expanded facade lighting, signs, window strips, district landmarks and colored practical lights.
- Weapon tracers and impact feedback.
- Boss health / phase HUD.
- Re-styled menu buttons and HUD presentation.
- Graphical acceptance capture covering menu, all three weapons, all six faces and boss state.
- Reproducible Linux x86_64 release export plus post-export smoke test.

## Verification

Use:

```bash
make validate
make test
make build
```

CI additionally runs the graphical acceptance matrix under Xvfb and uploads the rendered PNGs.

Third-party licenses and provenance are recorded in `THIRD_PARTY_ASSETS.md`.
